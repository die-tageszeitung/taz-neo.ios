//
//  Downloader.swift
//
//  Created by Norbert Thies on 27.11.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/**
 The following Downloader class expects the following directory organisation:
   base directory
     -> resources   -  resource files for all feeds/issues
     -> global      -  global files shared by all issues
     -> feed-1      -  all data belonging only to feed1
          -> issue-date-1 - all data belonging to issue-date-1
               -> resources  - symbolic links to above noted "resources"
               -> global     - symbolic link to above noted "global"
          -> issue-date-2 - all data belonging to issue-date-2
          ...
 */
open class Downloader: DoesLog {
  
  /// The Feeder providing data
  public var feeder: Feeder
  
  // The HttpSession to use for downloading files
  private var dlSession: HttpSession
  
  /// Initialize with base directory and create global sub directories
  public init(feeder: Feeder) {
    self.feeder = feeder
    //self.dlSession = HttpSession.background("DL:\(feeder.baseUrl)")
    self.dlSession = HttpSession(name: "DL:\(feeder.baseUrl)")
    createDirs()
  }
  
  private func createDirs() {
    feeder.globalDir.create()
    feeder.resourcesDir.create()
    if !feeder.resVersionFile.exists { feeder.storedResVersion = 0 }
  }
  
  private func createIssueDir(feed: String, issue: String) {
    createDirs()
    let idir = feeder.issueDir(feed: feed, issue: issue)
    idir.create()
    let rlink = File(dir: idir.path, fname: "resources")
    let glink = File(dir: idir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: feeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: feeder.globalDir.path) }
  }
  
  /// Download global files (ie. files with storage type .global)
  private func downloadGlobalFiles(files: [FileEntry], closure: @escaping (Error?)->()) {
    let globals = files.filter { $0.storageType == .global }
    if globals.count == 0 { closure(nil); return }
    let hloader = HttpLoader(session: dlSession, baseUrl: feeder.globalBaseUrl,
                             toDir: feeder.globalDir.path)
    hloader.download(globals) { [weak self] hl in
      self?.debug("Global files:\n\(hloader)")
      if hloader.errors > 0 { closure(hloader.lastError) }
      else { closure(nil) }
    }
  }
  
  /// Download files with storage type .issue
  private func downloadIssueFiles(url: String, feed: String, issue: String, 
    files: [FileEntry], closure: @escaping (Error?)->()) {
    let ifiles = files.filter { $0.storageType == .issue }
    if ifiles.count == 0 { closure(nil); return }
    createIssueDir(feed: feed, issue: issue)
    let idir = feeder.issueDir(feed: feed, issue: issue)
    let hloader = HttpLoader(session: dlSession, baseUrl: url, toDir: idir.path)
    hloader.download(ifiles) { [weak self] hl in
      self?.debug("Issue files:\n\(hloader)")
      if hloader.errors > 0 { closure(hloader.lastError) }
      else { closure(nil) }
    }    
  }
  
  /// Download most current Resources 
  private func downloadResources(closure: @escaping (Error?)->()) {
    let vCurrent = feeder.resourceVersion
    let vStored = feeder.storedResVersion
    guard vStored < vCurrent else { closure(nil); return }
    debug("resources at version \(vStored) < current version \(vCurrent)")
    feeder.resources { [weak self] result in
      guard let res = result.value() else { return }
      guard let self = self else { return }
      let hloader = HttpLoader(session: self.dlSession, baseUrl: res.resourceBaseUrl,
                               toDir: self.feeder.resourcesDir.path)
      hloader.download(res.resourceFiles) { [weak self] hl in
        self?.debug("Resource files:\n\(hloader)")
        if hloader.errors > 0 { closure(hloader.lastError) }
        else { 
          self?.feeder.storedResVersion = vCurrent
          closure(nil) 
        }
      }
    }
  }

  /// Download Issue data
  public func downloadIssueData(issue: Issue, files: [FileEntry], 
                                closure: @escaping (Error?)->()) {
    downloadResources { [weak self] err in
      guard err == nil else { closure(err); return }
      guard let self = self else { return }
      self.downloadGlobalFiles(files: files) { [weak self] err in
        guard err == nil else { closure(err); return }
        guard let self = self else { return }
        let name = self.feeder.date2a(issue.date)
        self.downloadIssueFiles(url: issue.baseUrl, feed: issue.feed.name, 
                                issue: name, files: files) { err in
          closure(err)
        }
      }
    }
  }
  
  /// Download "Moment" files"
  public func downloadMoment(issue: Issue, closure: @escaping (Error?)->()) {
    downloadIssueData(issue: issue, files: issue.moment.files, closure: closure)
  }

  /// Download complete Issue
  public func downloadIssue(issue: Issue, closure: @escaping (Error?)->()) {
    downloadIssueData(issue: issue, files: issue.files, closure: closure)
  }
  
  /// Download Section (no articles)
  public func downloadSection(issue: Issue, section: Section, 
                              closure: @escaping (Error?)->()) {
    downloadIssueData(issue: issue, files: section.files, closure: closure)
  }

  /// Download Article
  public func downloadArticle(issue: Issue, article: Article, 
                              closure: @escaping (Error?)->()) {
    downloadIssueData(issue: issue, files: article.files, closure: closure)
  }

} // Downloader
