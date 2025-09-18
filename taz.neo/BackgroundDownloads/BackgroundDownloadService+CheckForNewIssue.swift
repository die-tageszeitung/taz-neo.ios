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
  public static func downloadNewIssueOnAppForeground(caller: String, delay: Double = 1.0){
    BackgroundDownloadService.shared.log("app FG DL Called from: \(caller)")
    onMainAfter(delay) {///a little delay is required after app start/init feeder otherwise someone throws an error and autodownload not enqueued
      /// DO NOT USE ON THREAD AFTER IT WILL CAUSE CRASH
      checkForNewIssue(isPush: false, isBackground: false){ res in
        BackgroundDownloadService.shared.log("app FG DL Called from: \(caller)")
        Self.shared.log("...publication dates changed, autodownload status: \(res.message)")
        if res == .newData {  shared.notifyHome(.loadIssue) }
      }
    }
  }
  
  public static func checkForNewIssue(isPush: Bool, isBackground: Bool, _ fetchCompletionHandler: FetchCompletionHandler?) {
    Self.shared.log("...static checkForNewIssue requested, App State: \(UIApplication.shared.stateDescription) isBackground: \(isBackground)")
    let currentAppState = UIApplication.shared.applicationState
    
    guard Self.shared.autoloadNewIssues,
          let gqlFeeder = Self.shared.feederContext?.gqlFeeder,
          gqlFeeder.hasValidAbo == true else {
      Self.shared.log("...static checkForNewIssue skipped, no auto-load enabled or no valid abo")
      fetchCompletionHandler?(.noData)
      return
    }
    
    if isPush == false &&
        Self.shared.isLastFullyDownloadedIssueOutdated == false {
      Self.shared.log("...static checkForNewIssue skipped, last fully downloaded issue from: \(Self.shared.lastFullyDownloadedIssueDate?.short ?? "-")")
      fetchCompletionHandler?(.noData)
      ///maybe enqueued not downloaded, not saved to db
      Self.shared.handlePendingTasks()//persist stuff
      ///maybe re-start download? BackgroundSession.restartAllArchivedDownloads EXPERIMENTELL!!!
      return
    }
    
    Task {
      Self.shared.log("...static checkForNewIssue in \(currentAppState == .background ? "background" : "\(currentAppState)")")
      await BackgroundDownloadService.shared.doCheckForNewIssue(isPush: isPush, isBackground: isBackground, fetchCompletionHandler)
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
  func doCheckForNewIssue(isPush: Bool, isBackground: Bool, _ fetchCompletionHandler: FetchCompletionHandler? = nil) async {
    
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
    var fetchResult = UIBackgroundFetchResult.noData
    
    do {
      // MARK: - Logging context
      
      ///remember current localResources, after fetch its updated but not downloaded here
      let localResources = StoredResources.latest()
      
      log("""
          ...checkForNewIssue 
             autoload: \(autoloadOnlyInWLAN ? "only in WLAN" : "in any network")
             Triggered by \(isPush ? "Push" : "BackgroundTask")
              \(localResources?.resourceVersion.description.prepend("lastLocalResourceVersion: ") ?? "WARNING: No local resources found!")
             Latest known publication date: \(feederContext.latestPublicationDate?.short ?? "none")
          """)
      ///   isMobile connected/isConnected: \(feederContext.netAvailability.isMobile)/\(feederContext.netAvailability.isConnected) did not work!
      // MARK: - Fetch & Validate Issue
      ///if latest local known issue is from 1.7.25 and this is also the latest on server, the server returns 1.7. again
      let issue = try await fetchFromRemote(isBackground: isBackground)
      log("...fetched issue: \(issue.date.short)")
      
      guard let zipUrl = issue.zipUrl else {
        log("latestIssue baseUrl: \(issue.baseUrl) zipName: \(issue.zipName ?? "-")")
        fetchResult = .failed
        throw BackgroundDownloadError("No Zip to Download!")
      }
      
      await prepareResourcesUpdateIfNeeded(issueMinResourceVersion: issue.minResourceVersion,
                                           localResources: localResources,
                                           feederContext: feederContext,
                                           isBackground: isBackground)
      
      let downloadSession = BackgroundSession.shared(callback: dlCallback)
      downloadSession.allowMobile = !autoloadOnlyInWLAN
      downloadSession.waitForAvailability = true
      
      // MARK: - Start Issue Download
      downloadSession.download(urlString: zipUrl, destPath: issue.dir.path, unzip: true)
      fetchResult = .newData
      log("...downloading IssueData \(zipUrl.lastPathComponent) from: \(zipUrl) to: \(issue.dir.path)")
      
      let (downloadId, startTime) = try await feederContext.gqlFeeder
        .markStartDownloadAsync(feed: feederContext.defaultFeed,
                                issue: issue,
                                isAutomatically: true,
                                returnOnMain: false)
      saveDownloadData(forDownloadUrl: zipUrl,
                       date: issue.date,
                       downloadId: downloadId,
                       startTime: startTime.sec)
      
      
      // MARK: - Optional Audio Download
      if autoloadAudio, let audioUrl = issue.zipAudioUrl {
        downloadSession.download(urlString: audioUrl, destPath: issue.dir.path, unzip: true)
        log("...downloading Audio \(zipUrl.lastPathComponent) from: \(zipUrl) to: \(issue.dir.path)")
      }
      
      // MARK: - Optional Resouces Download
      if updatedResourcesLocalPath.length > 6 {
        for file in updatedResourcesFiles {
          log("download \(file.name)")
          let urlString = "\(remoteResourcesBaseUrl)/\(file.name)"
          downloadSession.download(urlString: urlString, destPath: updatedResourcesLocalPath, unzip: false)
          log("...downloading Resource \(file.name) from: \(urlString) to: \(updatedResourcesLocalPath)")
        }
        UserDefaults.standard.addDownloadingResourceFiles( updatedResourcesFiles.compactMap{$0.name})
        updatedResourcesFiles = []
      }
      // MARK: - Finish Tasks
      /// Schedule background task to resume Download if Autodownload did not started
      scheduleBackgroundIssueCheck(earliestBeginDate: Date(timeIntervalSinceNow: 60 * 60))
      ///persist data to db
      handlePendingTasks()
      ///push notification callback
      ///
      ///In case of app restart in celuar show user info to enable wlan for download
      if isBackground == false,
         autoloadOnlyInWLAN,
         TazAppEnvironment.sharedInstance.feederContext?.netAvailability.isMobile == true {
        notifyHome(.autoloadErrorNoWlan)
      }
      
      if isBackground {
        notify(issueDate: issue.date, finished: false)
      }
      log("⏰ fin...download(s) enqueued, ui informed")
    }
    catch {
      fetchResult = .failed
      log("❌ Autodownload Error: \(error)")
      log("\((error as? BackgroundDownloadError)?.message ?? "-") == \(BackgroundDownloadError.noNewIssue.message)")
      if let bde = error as? BackgroundDownloadError,
         bde.message == BackgroundDownloadError.noNewIssue.message {
        scheduleBackgroundIssueCheck()
        //        BackgroundSession.restartAllPendingDownloads()
      }
      else {
        ///Edge Case Fetch failed: retry soon! ...maybe its a lot fo later, if internet is not available for long time
        scheduleBackgroundIssueCheck(earliestBeginDate: Date(timeIntervalSinceNow: 60 * 10))
      }
    }
    fetchCompletionHandler?(fetchResult)
  }
}

// MARK: - BackgroundDownloadService :: load structure data

fileprivate extension BackgroundDownloadService {
  /// fetches latest issue and publicationDates from remote
  /// throws an error, if fetched issue is not newer than last local
  /// - Returns: the latest issue, the current resourcesUrl if update required
  /// resourcesUrl brauche ich nicht mehr zurückgeben, das mache ich über die userDefault Variablen
  
  func fetchFromRemote(isBackground: Bool) async throws -> Issue {
    //add to publicationsdates and issues, returns latest issue
    
    guard let feederContext = feederContext else {
      throw BackgroundDownloadError("Currently no feederContext available!")
    }
    
    
    let lastLocalIssueDate = try lastLocalIssueDate(feederContext: feederContext)
    log("lastLocalIssueDate: \(lastLocalIssueDate?.short ?? "-")")
    
    // MARK: fetch latest issue and publication Dates from server
    let response
    = try await feederContext.gqlFeeder
      .latestIssueAndFeed(feed: feederContext.defaultFeed,
                          isPages: Defaults.autoloadPdfOrFacsimile,
                          withAudio: autoloadAudio,
                          latestKnownPublicationDate: lastLocalIssueDate,
                          returnOnMain: false,
                          isBackGround: isBackground)
    let fetchedFeed = response.0//feed
    
    if fetchedFeed.issues?.count ?? 0 > 1  {
      log("WARNING: more than one issue found, using the first one")
    }
    
    guard let issue = fetchedFeed.issues?.first else {
      throw BackgroundDownloadError("No Issue found!")
    }
    
    print(">>> self.gqlFeeder.resVersionFile: \((fetchedFeed.feeder as? GqlFeeder)?.resourceZipUrl ?? "-")")
    remoteResourcesBaseUrl = (fetchedFeed.feeder as? GqlFeeder)?.resourceBaseUrl ?? ""
    
    /// Checks whether the server-provided issue is newer than the most recent local one.
    ///
    /// The most recent local issue may come from the database (already downloaded)
    /// or from a pending download (enqueued but not yet completed).
    ///
    /// If the server issue is not newer, an error is thrown to avoid redundant downloads.
    guard issue.date.ISO8601 > (lastLocalIssueDate ?? Date.distantPast).ISO8601 else {
      throw BackgroundDownloadError.noNewIssue
    }
    log("\(issue.date.dateAndTime) > \(lastLocalIssueDate?.dateAndTime ?? "-")")
    
    issue.createFolderStructureIfNeeded(for: feederContext)
    
    if let data = response.1 {
      let jsonFile = issue.jsonFile
      jsonFile.data = data
      log("persist \(data.count) bytes of data to filesystem for later use in: \(jsonFile.path)")
    }
    //wie passt publicationDate und issue zusammen?...egal solange das publicationDate existiert kann ich diese persitieren, es werden nur nicht in der db bekannte pubDates in die db übernommen
    
    tempStorage.add(fetchedFeed.publicationDates ?? [])
    try tempStorage.add(issue)
    return issue
  }
}

fileprivate extension BackgroundDownloadService {
  
  /// Returns the most recent available issue date from the local data sources, or `nil` if none are available.
  /// - Throws: An error if accessing the database fails.
  ///
  /// - Attention: lastFromJsonFile uses the last json File, there are probably multiple json files, the json files are stored in the issue folder e.g. 2025-07-01
  ///
  /// This property checks three possible sources in the following order:
  /// - `lastFromDatabase`: The latest issue date stored in the local database.
  /// - `lastFromJsonFile`: The latest issue date loaded from a local JSON file.
  /// - `lastFromSingleton`: The latest issue date held in memory (e.g., a singleton).
  func lastLocalIssueDate(feederContext: FeederContext) throws -> Date? {
    let dbDate = try lastFromDatabase(for: feederContext)
    let lastFromJsonFile = try lastFromJsonFile(for: feederContext)
    let allDates = [dbDate, lastFromJsonFile, lastFromSingleton]
    log("db: \(String(describing: dbDate?.short)), json: \(String(describing: lastFromJsonFile?.short)), singleton: \(String(describing: lastFromSingleton?.short))")
    return allDates.compactMap { $0 }.max()
  }
  
  private func lastFromDatabase(for feederContext: FeederContext) throws -> Date? {
    guard let feed = feederContext.defaultFeed else {
      throw BackgroundDownloadError("db not initialized yet, try again later")
    }
    return StoredIssue.lastComplete(feed: feed,
                                     isPages: autoloadPdf,
                                     withAudio: autoloadAudio)?.date
  }
  
  /// check userDefault for last downloaded in earlier session, check if json is available **current feed!** TODO FEED SWITCH is not supported here ...for autodownload!
  /// returns the date
  private func lastFromJsonFile(for feederContext: FeederContext) throws -> Date? {
    guard let issueDateKey = downloadDateKeys.max() else { return nil }
    guard let feed = feederContext.defaultFeed else {
      throw BackgroundDownloadError("db not initialized yet, try again later")
    }
    let feedPath = feederContext.storedFeeder.feedDir(feed.name).path
    let filePath = "\(feedPath)/\(issueDateKey)/\(BackgroundDownloadService.jsonDataFilename)"
    let file = File(filePath)
    guard file.exists else {
      throw BackgroundDownloadError("File \(filePath) does not exist.")
    }
    
    
    let date = UsTime(iso: issueDateKey).date
    guard date.ISO8601 == issueDateKey else {
      throw BackgroundDownloadError("ToDo used wrong formater to parse date from string: \(issueDateKey) != \(date.ISO8601)")
    }
    log("...lastIssue in json File: \(date.short)")
    return date
  }
  
  private var lastFromSingleton: Date? {
    ///Hack shortcut: publicationDate is in sync with latest issueDate!
    tempStorage.latestPublicationDate()
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
    log("...fetch issue/feed data for \(feed.name) return on Main: \(returnOnMain) inBackground: \(isBackGround) last issue: \(dateString)")
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
  
  func createFolderStructureIfNeeded(for feederContext: FeederContext) {
    let issueDir = self.dir
    if !issueDir.exists { issueDir.create() }
    let rlink = File(dir: issueDir.path, fname: "resources")
    let glink = File(dir: issueDir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: feederContext.storedFeeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: feederContext.storedFeeder.globalDir.path) }
  }
  
  var zipAudioUrl: String? {
    guard let zipAudioName = zipAudioName else { return nil }
    return baseUrl.appending("/\(zipAudioName)")
  }
}

fileprivate extension UIBackgroundFetchResult {
  var message: String {
    switch self {
      case .newData:
        return "New data available"
      case .noData:
        return "No new data available"
      case .failed:
        return "Fetch failed"
      @unknown default:
        return "Unknown result"
    }
  }
}
