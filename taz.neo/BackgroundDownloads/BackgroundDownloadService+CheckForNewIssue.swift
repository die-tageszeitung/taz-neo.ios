//
//  BackgroundDownloadService+CheckForNewIssue.swift
//  taz.neo
//
//  Created by Ringo Müller on 22.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit
import Network

fileprivate actor IssueCheckerGuard {
  
  static let instance = IssueCheckerGuard()
  
  private var isRunning = false
  
  func shouldRun() -> Bool {
    if isRunning {
      return false
    }
    isRunning = true
    return true
  }
  
  func finish() {
    isRunning = false
  }
}

// MARK: - BackgroundDownloadService :: checkForNewIssue

extension BackgroundDownloadService {
  public static func checkForNewIssue(isPush: Bool, _ fetchCompletionHandler: FetchCompletionHandler?) {
    Self.shared.log("...static checkForNewIssue requested, App State: \(UIApplication.shared.stateDescription)")
    let currentAppState = UIApplication.shared.applicationState
    
    guard Self.shared.autoloadNewIssues else {
      fetchCompletionHandler?(.noData)
      return
    }
    
    if let date = Self.shared.latestIssueIssueDate, abs(date.startOfDay.timeIntervalSinceNow) < 60*60*17 {
      Self.shared.log("...static checkForNewIssue skipped, last downloaded issue is from: \(date.short) \(abs(date.startOfDay.timeIntervalSinceNow)) < \(60*60*17)")
      fetchCompletionHandler?(.noData)
      return
    }
    
    Task {
      Self.shared.log("...static checkForNewIssue in \(currentAppState == .background ? "background" : "\(currentAppState)")")
      await BackgroundDownloadService.shared.doCheckForNewIssue(isPush: isPush, fetchCompletionHandler)
      Self.shared.log("...static checkForNewIssue done")
    }
  }
}

// MARK: - BackgroundDownloadService :: checkForNewIssue logic

//Mark: checkForNewIssue (called by push and sceduled background task)
fileprivate extension BackgroundDownloadService {
  /// check remote for new issues and enqueue download in Background Mode
  /// triggert by Push Notification or timed background task
  /// - Parameters:
  ///   - fetchCompletionHandler: optional completion handler for required if called by push notification
  func doCheckForNewIssue(isPush: Bool, _ fetchCompletionHandler: FetchCompletionHandler? = nil) async {
    
    // MARK: - Initial Checks
    guard let feederContext = feederContext else {
      log("No feeder context... try later")
      fetchCompletionHandler?(.noData)
      return
    }
    
    guard await IssueCheckerGuard.instance.shouldRun() else {
      log("Skipped checkForNewIssue – already running.")
      fetchCompletionHandler?(.noData)
      log("...fin")
      return
    }
    
    // Ensure guard reset
    defer { Task { await IssueCheckerGuard.instance.finish() } }
    
    var issueDownloadEnqueued = false
    var fetchSuccess = false
    
    do {
      // MARK: - Logging context
      
      log("""
          ...checkForNewIssue 
             autoload: \(autoloadOnlyInWLAN ? "only in WLAN" : "in any network")
             Triggered by \(isPush ? "Push" : "BackgroundTask")
             Latest known publication date: \(feederContext.latestPublicationDate?.short ?? "none")
          """)
      
      // MARK: - Fetch & Validate Issue
      
      let issue = try await fetchFromRemote()
      fetchSuccess = true
      log("...fetched issue: \(issue.date.short)")
      
      latestCheckForNewIssue = Date()
      
      guard let zipUrl = issue.zipUrl else {
        log("latestIssue baseUrl: \(issue.baseUrl) zipName: \(issue.zipName ?? "-")")
        throw BackgroundDownloadError("No Zip to Download!")
      }
      
      guard !BackgroundSession.search(url: zipUrl) else {
        throw BackgroundDownloadError("Already Downloading!")
        
        return
        // TODO: check if download restart required!
        /// **Where are the existing Downloads? In Active or archived?**
        
        log("restartAllArchivedDownloads")
        try BackgroundSession.restartAllArchivedDownloads { [weak self] url, err in
          self?.log("restarted AllArchivedDownloads callback")
          if url != zipUrl {
            self?.log("ERROR: URL mismatch for issue download \(url) != \(zipUrl)")
          }
          self?.dlCallback(downloadUrl: zipUrl, err: err)
        }
        //        BackgroundSession.restartAllPendingDownloads()
        throw BackgroundDownloadError("Already Downloading!")
      }
      
      if BackgroundSession.waitingCount > 5 {
        log("Too many downloads, stop older ones...")
        BackgroundSession.cleanupAllSessions()
      }
      
      // MARK: - Start Issue Download
      
      let issueDownloadSession
      = try BackgroundSession(zipUrl,
                              asBackgroundSession: true) { [weak self] url, err in
        if url != zipUrl {
          self?.log("ERROR: URL mismatch for issue download \(url) != \(zipUrl)")
        }
        self?.dlCallback(downloadUrl: zipUrl, err: err)
      }
      
      issueDownloadSession.allowMobile = !autoloadOnlyInWLAN
      
      let (downloadId, startTime) = try await feederContext.gqlFeeder
        .markStartDownloadAsync(feed: feederContext.defaultFeed,
                                issue: issue,
                                isAutomatically: true,
                                returnOnMain: false)
      
      log("...downloading \(zipUrl.lastPathComponent) from: \(zipUrl) to: \(issue.tempDir.path)")
      
      let targetDirs: [String: String] = [
        "global": feederContext.storedFeeder.globalDir.path,
        ".": ".."
      ]
      
      issueDownloadSession.downloadZip(toDir: issue.tempDir.path,
                                       moveFilesRealtion: targetDirs)
      
      issueDownloadEnqueued = true
      
      saveDownloadData(forDownloadUrl: zipUrl,
                       date: issue.date,
                       downloadId: downloadId,
                       startTime: startTime.sec)
      
      // MARK: - Optional Audio Download
      
      if autoloadAudio, let audioUrl = issue.zipAudioUrl {
        let audioDownloadSession = try BackgroundSession(audioUrl, asBackgroundSession: true) { [weak self] url, err in
          if url != audioUrl {
            self?.log("ERROR: URL mismatch for audio download \(url) != \(audioUrl)")
          }
          self?.log("Audio Download finished with Error: \(err ?? "-")")
        }
        audioDownloadSession.allowMobile = !autoloadOnlyInWLAN
        log("...downloading audio zip \(audioUrl.lastPathComponent) from: \(audioUrl) to: \(issue.dir.path)")
        audioDownloadSession.downloadZip(toDir: issue.dir.path)
      }
      
      // MARK: - Finish Tasks
      /// Schedule background task to resume Download if Autodownload did not started
      scheduleBackgroundIssueCheck(earliestBeginDate: Date(timeIntervalSinceNow: 60 * 60))
      ///persist data to db
      onMain { [weak self] in
        self?.handlePendingTasks()
      }
      ///push notification callback
      fetchCompletionHandler?(.newData)
    }
    catch {
      log("❌ Autodownload Error: \(error) issueDownloadEnqueued: \(issueDownloadEnqueued)")
      
      if fetchSuccess == false {
        ///Fetch failed: retry soon!
        scheduleBackgroundIssueCheck(earliestBeginDate: Date(timeIntervalSinceNow: 60 * 10))
      }
      
      if issueDownloadEnqueued {
        fetchCompletionHandler?(.newData)
      } else {
        fetchCompletionHandler?(.noData)
      }
    }
    
    log("⏰ fin...download(s) enqueued")
  }
}

// MARK: - BackgroundDownloadService :: load structure data

fileprivate extension BackgroundDownloadService {
  /// fetches latest issue and publicationDates from remote
  /// - Returns: the latest issue
  func fetchFromRemote() async throws -> Issue {
    //add to publicationsdates and issues, returns latest issue
    
    guard let feederContext = feederContext else {
      throw BackgroundDownloadError("Currently no feederContext available!")
    }
    
    let latestPublicationDate = feederContext.latestPublicationDate
    // MARK: fetch latest issue and publication Dates from server
    let response
    = try await feederContext.gqlFeeder
      .latestIssueAndFeed(feed: feederContext.defaultFeed,
                          isPages: autoloadPdf,
                          withAudio: autoloadAudio,
                          latestKnownPublicationDate: latestPublicationDate,
                          returnOnMain: false,
                          isBackGround: true)
    let publicationDatesAndIssue = response.0
    
    if publicationDatesAndIssue.issues?.count ?? 0 > 1  {
      log("WARNING: more than one issue found, using the first one")
    }
    
    guard let issue = publicationDatesAndIssue.issues?.first else {
      throw BackgroundDownloadError("No Issue found!")
    }
    
    issue.createFolderStructureIfNeeded(for: feederContext)
    
    if let data = response.1 {
      let jsonFile = issue.jsonFile
      jsonFile.data = data
      log("persist \(data.count) bytes of data to filesystem for later use in: \(jsonFile.path)")
    }
    //wie passt publicationDate und issue zusammen?...egal solange das publicationDate existiert kann ich diese persitieren, es werden nur nicht in der db bekannte pubDates in die db übernommen
    
    tempStorage.add(publicationDatesAndIssue.publicationDates ?? [])
    try tempStorage.add(issue)
    return issue
  }
  
  
}


// MARK: - GqlFeeder helper extension

fileprivate extension GqlFeeder {
  func latestIssueAndFeed(feed: Feed,
                          key: String? = nil,
                          isPages: Bool,
                          withAudio: Bool,
                          latestKnownPublicationDate: Date?,
                          returnOnMain: Bool = true,
                          isBackGround: Bool = true) async throws -> (Feed, Data?) {
    var dateString = ""
    if let date = latestKnownPublicationDate { dateString = ", latestKnownPublicationDate: \(date.ISO8601)" }
    log("...fetch issue/feed data for \(feed.name) return on Main: \(returnOnMain) inBackground: \(isBackGround)\(dateString)")
    return try await withCheckedThrowingContinuation { continuation in
      feedWithIssues(feed: feed, date: nil, key: key, count: 1,
                     isOverview: false, isPages: isPages, withAudio: withAudio,
                     latestKnownPublicationDate: latestKnownPublicationDate,
                     returnOnMain: returnOnMain, isBackGround: isBackGround) { result, data in
        switch result {
          case .success(let feed):
            continuation.resume(returning: (feed, data))
          case .failure(let error):
            continuation.resume(throwing: error)
        }
      }
    }
  }
}

// MARK: - Issue helper extension

fileprivate extension Issue {
  
  var tempDir: Dir {
    if !dir.exists { dir.create() }
    let tmpDir = Dir("\(dir.path)/tmp")
    if !tmpDir.exists { tmpDir.create() }
    return tmpDir
  }
  
  func createFolderStructureIfNeeded(for feederContext: FeederContext) {
    let issueDir = self.dir
    if !issueDir.exists { issueDir.create() }
    let rlink = File(dir: issueDir.path, fname: "resources")
    let glink = File(dir: issueDir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: feederContext.storedFeeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: feederContext.storedFeeder.globalDir.path) }
    let tmpDir = Dir("\(issueDir.path)/tmp")
    if !tmpDir.exists { tmpDir.create() }
  }
  
  var zipAudioUrl: String? {
    guard let zipAudioName = zipAudioName else { return nil }
    return baseUrl.appending("/\(zipAudioName)")
  }
}
