//
//  BackgroundDownloadService+FinishedCallback.swift
//  taz.neo
//
//  Created by Ringo Müller on 22.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

extension BackgroundDownloadService {
  static func dlCallback(downloadUrl: String, err: Error?) {
    Self.shared.dlCallback(downloadUrl: downloadUrl, err: err)
  }
  
  /// Callback for Download completion
  /// - Parameters:
  ///   - downloadUrl: the URL of the downloaded file
  ///   - err: an error if the download failed, nil otherwise
  /// - Note: This method could be in background App State or on App-Re-Start in Foreground
  /// - Attention: After App Termination e.g. die Device-Restart there is maybe no currentIssue available
  /// In this Case the final actions will to be done in IssueOverviewService
  func dlCallback(downloadUrl: String, err: Error?) {
    
    log("...Download finished for URL: \(downloadUrl)")
    
    ///** Error Handling
    if let err = err {
      ///since now this only happend after server switch; in case of missing downloads maybe handle later
      ///after server switch &
      ///happen also, if zip file is not available e.g. on older issues on testserver
      log("⚠️⚠️...Failed to Download for: \(downloadUrl)\n  with err: \(err)")
      onMainAfter(4.0) {
        Notification.send(Const.NotificationNames.checkForNewIssues,
                          content: FetchNewStatusHeader.status.downloadError,
                          error: nil,
                          sender: TazAppEnvironment.sharedInstance.service)
      }
      return
    }
    
    if remoteResourcesBaseUrl.isEmpty == false,
       downloadUrl.contains(remoteResourcesBaseUrl) {
      handleResourcesDownloadFinished(for: downloadUrl)
      return
    }
    
    ///** lookup for additional Data in Defaults
    guard let downloadData = getDownloadData(forDownloadUrl: downloadUrl) else {
      log("...No DownloadData for url: \(downloadUrl). Audio or Resources Download")
      return
    }
        
    guard downloadData.isDownloaded == false else {
      log("⚠️WARNING: ...already downloaded, nothing to do")
      return
    }
    
    ///** sendDownloadStopAndTrack
    sendDownloadStopAndTrack(for: downloadData, with: downloadUrl, feederContext: feederContext)
    ///delete autoDownload and download startTime ...no more needed (sendDownloadStopAndTrack is fire and forgett)
    setDownloadFinished(forDownloadUrl: downloadUrl)
    
    let serverBaseUrl = downloadUrl.urlByDeleetingLastPathComponent
    
    ///** collect some environment
    guard let feederContext = feederContext,
          let storedFeeder = feederContext.storedFeeder else {
      log("⚠️ WARNING: no storedFeed available")
      return
    }
    
    ///** lookup in Temp Storage
    if let issue = tempStorage.getIssue(with: serverBaseUrl) {
      log("...found issue in tempStorage: \(issue.date.short)")
      ensureMain {[weak self] in
        guard let self else { return }
        updateLatestIssueDownloadDate(ifNewer: issue.date)
        log("...set isAutodownloading compleete!")
        issue.setAutodownloadCompleete()
        notify(issueDate: issue.date, finished: true)
        handlePendingTasks(in: storedFeeder.masterFeed)
      }
      return
    }
    ///App Restarted by system!?
    log("...issue NOT FOUND in tempStorage, try to fetch from database")
       
    ///** lookup in Database#
    ensureMain {[weak self] in
      if let issue = StoredIssue.get(baseUrl: serverBaseUrl,
                                     inFeed: storedFeeder.masterFeed as! StoredFeed),
         issue.isAutodownloading == true {
        self?.log("...found issue in databse: \(issue.date.short)")
        /// If auto-downloading is true, full data is available—not just overview data.
        self?.log("...set isAutodownloading compleete!")
        issue.setAutodownloadCompleete()
        self?.notify(issueDate: issue.date, finished: true)
        self?.handlePendingTasks(in: storedFeeder.masterFeed)
        return
      }
      self?.log("issue not found in database, restore from JSON")
      ///** No valid Entry found, load from JSON ...in a detatched Task
      Task.detached { [weak self] in
        await self?
          .loadFromJsonAndFinish(feederContext: feederContext,
                                 feed: storedFeeder.masterFeed,
                                 issueDateKey: downloadData.isoDateKey)
      }
    }
  }
}

///Mark: - external call
fileprivate extension BackgroundDownloadService {
  
  /// Loads a feed from a local JSON file and finalizes processing for its first issue.
  ///
  /// This method attempts to load the feed from a JSON file using the given context, feed name, and issue date.
  /// If successful, it adds the publication dates and the first issue found to the temporary storage,
  /// marks the issue as finished, and triggers any pending tasks. If no issue is found, a warning is logged.
  ///
  /// - Parameters:
  ///   - feederContext: The context containing configuration and access info for loading the feed.
  ///   - feedName: The name of the feed to load.
  ///   - issueDateKey: The key used to determine the relevant issue by date.
  func loadFromJsonAndFinish(
    feederContext: FeederContext,
    feed: Feed,
    issueDateKey: String
  ) async {
    do {
      let feed = try await loadFeedFromJsonFile(
        feederContext: feederContext,
        feedName: feed.name,
        issueDateKey: issueDateKey
      )
      
      guard let issue = feed.issues?.first else {
        throw BackgroundDownloadError("No issue found in feed.")
      }
      
      if let publicationDates = feed.publicationDates {
        tempStorage.add(publicationDates)
      }
#warning("CHECK: try")
      try tempStorage.add(issue)
      log("...set isAutodownloading compleete!")
      issue.setAutodownloadCompleete()
      notify(issueDate: issue.date, finished: true)
      handlePendingTasks(in: feed)
      
    } catch {
      log("⚠️ Failed to process JSON for date \(issueDateKey): \(error)")
    }
  }
}

extension String {
  var urlByDeleetingLastPathComponent: String {
    guard let url = URL(string: self) else { return self }
    var baseUrl = url.deletingLastPathComponent().absoluteString
    if baseUrl.hasSuffix("/") {
      baseUrl.removeLast() // Entfernt den abschließenden Slash, falls vorhanden
    }
    return baseUrl
  }
}
