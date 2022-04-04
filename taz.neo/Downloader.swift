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
  
  public var isDownloading: Bool {
    get {
      if payloadQueue.isEmpty == false { return true }
      return dlSession.isDownloading
    }
  }
  
  public func killAll(){
    payloadQueue = []
    dlSession._session?.invalidateAndCancel()
  }
  
  // The HttpSession to use for downloading files
  private var dlSession: HttpSession
  
  // Payload queue entry
  private struct PayloadEntry {
    var payload: StoredPayload 
    var onProgress: ((Int64, Int64)->())?
    var atEnd: (Error?)->()
    var fromCacheDir: String?
    
    public init(payload: StoredPayload, onProgress: ((Int64, Int64)->())? = nil,
                fromCacheDir: String? = nil, atEnd: @escaping (Error?)->()) {
      self.payload = payload
      self.onProgress = onProgress
      self.fromCacheDir = fromCacheDir
      self.atEnd = atEnd
    }
    
    public func download(dl: Downloader) {
      var files = payload.files as! [StoredFileEntry]
      if files.count > 0 {
        dl.downloadStoredGlobalFiles(files: files) { err in
          guard err == nil else { self.atEnd(err); return }
          let hloader = HttpLoader(session: dl.dlSession, 
                                   baseUrl: self.payload.remoteBaseUrl,
                                   toDir: self.payload.localDir,
                                   fromCacheDir: self.fromCacheDir)
          var isComplete = false
          self.payload.downloadStarted = Date()
          files = files.filter { $0.storageType != .global }
          hloader.download(files,
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
              if hloader.downloaded > 0 { dl.debug("Payload:\n\(hloader)") }
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
  
  public func createDirs() {
    feeder.globalDir.create()
    feeder.resourcesDir.create()
    if !feeder.resVersionFile.exists { feeder.storedResVersion = 0 }
  }
  
  public func createIssueDir(feed: String, issue: String) {
    createDirs()
    let idir = feeder.issueDir(feed: feed, issue: issue)
    idir.create()
    let rlink = File(dir: idir.path, fname: "resources")
    let glink = File(dir: idir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: feeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: feeder.globalDir.path) }
  }
  
  public func createIssueDir(issue: Issue) {
    let name = self.feeder.date2a(issue.date)
    createIssueDir(feed: issue.feed.name, issue: name)
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
  
  /// Download a payload of files
  public func downloadPayload(payload: StoredPayload,
                              fromCacheDir: String? = nil,
                              onProgress: ((Int64, Int64)->())? = nil, 
                              atEnd: @escaping (Error?)->()) {
    let pe = PayloadEntry(payload: payload, onProgress: onProgress,
                          fromCacheDir: fromCacheDir) { [weak self] err in
      if let self = self {
        if self.payloadQueue.count > 0 { self.payloadQueue.removeFirst() }
        if self.payloadQueue.count > 0 { self.payloadQueue[0].download(dl: self) }
        atEnd(err)
      }
    }
    payloadQueue += pe
    if payloadQueue.count == 1 { pe.download(dl: self) }
  }
  
  /// Download files for temp Articles (from Search)
  public func downloadSearchResultFiles(url: String, files: [FileEntry], closure: @escaping (Error?)->()) {
    let idir = Dir.searchResults
    idir.create()
    
    let rlink = File(dir: idir.path, fname: "resources")
    let glink = File(dir: idir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: feeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: feeder.globalDir.path) }

    if files.count == 0 { closure(nil); return }
    let hloader = HttpLoader(session: dlSession, baseUrl: url, toDir: Dir.searchResultsPath)
    hloader.download(files) { [weak self] hl in
      self?.debug("Temp Article Files load Stat:\(hloader)\n             targetDir:\(idir.path)")
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

  /// Download Issue files
  public func downloadIssueFiles(issue: Issue, files: [FileEntry], 
                                 closure: @escaping (Error?)->()) {
    if let di = issue as? SearchResultIssue {
      self.downloadSearchResultFiles(url: di.baseUrlForFiles(files),
                         files: files, closure: closure)
      return
    }
    
    let name = self.feeder.date2a(issue.date)
    self.downloadIssueFiles(url: issue.baseUrl, feed: issue.feed.name, 
      issue: name, files: files, closure: closure)   
  }
                                
  /// Download Issue data
  public func downloadIssueData(issue: Issue, files: [FileEntry], 
                                closure: @escaping (Error?)->()) {
    if issue.isComplete { closure(nil); return }
    downloadGlobalFiles(files: files) { [weak self] err in
      guard err == nil else { closure(err); return }
      guard let self = self else { return }
      self.downloadIssueFiles(issue: issue, files: files, closure: closure)
    }
  }
  
  /// Download Section (no articles)
  public func downloadSection(issue: Issue, section: Section, 
                              closure: @escaping (Error?)->()) {
    if issue.isComplete { closure(nil) }
    else { downloadIssueData(issue: issue, files: section.files, closure: closure) }
  }

} // Downloader
