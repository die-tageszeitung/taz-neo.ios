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
  
  // Payload queue entry
  private struct PayloadEntry {
    var payload: StoredPayload 
    var onProgress: ((Int64, Int64)->())?
    var atEnd: (Error?)->()
    
    public func download(dl: Downloader) {
      var files = payload.files
      if files.count > 0 {
        dl.downloadStoredGlobalFiles(files: files) { err in
          guard err == nil else { self.atEnd(err); return }
          let hloader = HttpLoader(session: dl.dlSession, 
                                   baseUrl: self.payload.remoteBaseUrl!,
                                   toDir: self.payload.localDir)
          var isComplete = false
          self.payload.downloadStarted = Date()
          files = files.filter { $0.storageType != .global }
          hloader.download(self.payload.files,
            onProgress: { (hl, bytesLoaded, totalBytes) in
              if !isComplete {
                self.onProgress?(bytesLoaded, totalBytes)
                isComplete = bytesLoaded == totalBytes
              }
            },
            atEnd: { hl in
              self.payload.bytesLoaded = hl.downloadSize
              self.payload.downloadStopped = Date()
              for f in files { f.storedSize = f.size }
              ArticleDB.save()
              dl.debug("Payload:\n\(hloader)")
              if hloader.errors > 0 { self.atEnd(hloader.lastError) }
              else { self.atEnd(nil) }
            }
          )
        }
      }
      else { dl.error("Can't download empty payload") }
    }
    
  } // PayloadEntry 
  
  // Queue of pending payloads
  private var payloadQueue: [PayloadEntry] = []
  
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
  
  /// Update StoredFileEntries
  private func updateStoredFiles(files: [StoredFileEntry], toDir: String) {
    for f in files {
      f.storedSize = f.size
      f.subdir = String(toDir.dropFirst(Database.appDir.count + 1))
    }    
  }
  
  /// Download global files (ie. files with storage type .global)
  private func downloadGlobalFiles(files: [FileEntry], closure: @escaping (Error?)->()) {
    let globals = files.filter { $0.storageType == .global }
    if globals.count == 0 { closure(nil); return }
    let toDir = feeder.globalDir.path
    let hloader = HttpLoader(session: dlSession, baseUrl: feeder.globalBaseUrl,
                             toDir: toDir)
    hloader.download(globals) { [weak self] hl in
      self?.debug("Global files:\n\(hloader)")
      if hloader.errors > 0 { closure(hloader.lastError) }
      else { closure(nil) }
    }
  }
  
  /// Download global files to store in the DB
  public func downloadStoredGlobalFiles(files: [StoredFileEntry],  
                                         closure: @escaping (Error?)->()) {
    let globals = files.filter { $0.storageType == .global }
    guard globals.count > 0 else { closure(nil); return }
    downloadGlobalFiles(files: globals) { [weak self] err in
      guard let self = self, err == nil else { closure(err); return }
      self.updateStoredFiles(files: globals, toDir: self.feeder.globalDir.path)
      closure(nil)
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
  
  /// Download files with storage type .issue to store in the DB
  private func downloadStoredIssueFiles(url: String, feed: String, issue: String,
                                        files: [StoredFileEntry],  
                                        closure: @escaping (Error?)->()) {
    downloadIssueFiles(url: url, feed: feed, issue: issue, files: files) { 
      [weak self] err in
      guard let self = self, err == nil else { closure(err); return }
      let idir = self.feeder.issueDir(feed: feed, issue: issue)
      self.updateStoredFiles(files: files, toDir: idir.path)
      closure(nil)
    }
  }
  
  /// Returns true when Resources out of date or not already downloaded
  public func needDownloadResources() -> Bool {
    let vCurrent = feeder.resourceVersion
    let vStored = feeder.storedResVersion
    let dlNeeded = vStored < vCurrent
    debug("resources at version \(vStored) \(dlNeeded ? "<" : ">=") current version \(vCurrent)")
    return dlNeeded
  }
  
  /// Download most current Resources 
  public func downloadResources(closure: @escaping (Error?)->()) {
    guard needDownloadResources() else { closure(nil); return }
    feeder.resources { [weak self] result in
      guard let res = result.value() else { return }
      guard let self = self else { return }
      if res.isDownloading || res.isComplete { closure(nil); return }
      /////////////
      let _ = StoredResources.persist(res: res, localDir: self.feeder.resourcesDir.path)
      /////////////
      res.isDownloading = true
      let hloader = HttpLoader(session: self.dlSession, baseUrl: res.resourceBaseUrl,
                               toDir: self.feeder.resourcesDir.path)
      hloader.download(res.resourceFiles) { [weak self] hl in
        guard let self = self else { return }
        res.isDownloading = false
        self.debug("Resource files:\n\(hloader)")
        if hloader.errors > 0 { closure(hloader.lastError) }
        else { 
          self.feeder.storedResVersion = self.feeder.resourceVersion
          res.isComplete = true
          closure(nil) 
        }
      }
    }
  }
  
  /// Download a payload of files
  public func downloadPayload(payload: StoredPayload, 
                              onProgress: ((Int64, Int64)->())? = nil, 
                              atEnd: @escaping (Error?)->()) {
    let pe = PayloadEntry(payload: payload, onProgress: onProgress) { [weak self] err in
      if let self = self {
        self.payloadQueue.removeFirst()
        if self.payloadQueue.count > 0 { self.payloadQueue[0].download(dl: self) }
        atEnd(err)
      }
    }
    payloadQueue += pe
    if payloadQueue.count == 1 { pe.download(dl: self) }
  }

  /// Download Issue files
  public func downloadIssueFiles(issue: Issue, files: [FileEntry], 
                                 closure: @escaping (Error?)->()) {
    let name = self.feeder.date2a(issue.date)
    self.downloadIssueFiles(url: issue.baseUrl, feed: issue.feed.name, 
      issue: name, files: files, closure: closure)   
  }
                                
  /// Download Issue data
  public func downloadIssueData(issue: Issue, files: [FileEntry], 
                                closure: @escaping (Error?)->()) {
    if issue.isComplete { closure(nil); return }
    downloadResources { [weak self] err in
      guard err == nil else { closure(err); return }
      guard let self = self else { return }
      self.downloadGlobalFiles(files: files) { [weak self] err in
        guard err == nil else { closure(err); return }
        guard let self = self else { return }
        self.downloadIssueFiles(issue: issue, files: files, closure: closure)
      }
    }
  }
  
  /// Download "Moment" files"
  public func downloadMoment(issue: Issue, closure: @escaping (Error?)->()) {
    if issue.isComplete { closure(nil) }
    else {
      let name = self.feeder.date2a(issue.date)
      downloadIssueFiles(url: issue.baseUrl, feed: issue.feed.name, issue: name,
                         files: issue.moment.carouselFiles, closure: closure)
    }
  }
  
  /// Download "Moment" files" to store in the DB
  public func downloadStoredMoment(issue: StoredIssue, closure: @escaping (Error?)->()) {
    if issue.isOvwComplete { closure(nil) }
    else {
      let name = self.feeder.date2a(issue.date)
      var files: [StoredFileEntry] = []
      for f in issue.moment.carouselFiles {
        switch f {
          case let f as StoredFileEntry: files += f
          case let img as StoredImageEntry: files += StoredFileEntry(persistent: img.pf)
          default: break 
        }
      }
      downloadStoredIssueFiles(url: issue.baseUrl, feed: issue.feed.name, issue: name,
                               files: files, closure: closure)
    }
  }

  /// Download complete Issue
  public func downloadIssue(issue: Issue, closure: @escaping (Error?)->()) {
    if issue.isDownloading || issue.isComplete { closure(nil) }
    else {
      downloadIssueData(issue: issue, files: issue.files) { err in
        issue.isDownloading = false
        if err == nil { 
          let mark = self.feeder.issueDir(issue: issue).path + "/.downloaded"
          File.open(path: mark) { file in file.writeline("done") }
          issue.isComplete = true 
        }
        closure(err)
      }
    }
  }
  
  /// Download Section (no articles)
  public func downloadSection(issue: Issue, section: Section, 
                              closure: @escaping (Error?)->()) {
    if issue.isComplete { closure(nil) }
    else { downloadIssueData(issue: issue, files: section.files, closure: closure) }
  }

  /// Download Article
  public func downloadArticle(issue: Issue, article: Article, 
                              closure: @escaping (Error?)->()) {
    if issue.isComplete { closure(nil) }
    else { downloadIssueData(issue: issue, files: article.files, closure: closure) }
  }

} // Downloader
