//
//  BackgroundDownloadService+AppRestart.swift
//  taz.neo
//
//  Created by Ringo Müller on 20.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthFoundation
// MARK: - Application Restart Handling
extension BackgroundDownloadService {
  
  func notifyHome(_ homeHeaderStatus: FetchNewStatusHeader.status) {
    guard let service = TazAppEnvironment.sharedInstance.service else {
      log("No Service available")
      return
    }
    onMain {
      Notification.send(Const.NotificationNames.checkForNewIssues,
                        content: homeHeaderStatus,
                        error: nil,
                        sender: service)
    }
  }
    
  
  /// call after Application Restart to load issues data from JSON files and persist them
  /// called in Background Thread
  func applicationRestarted( with feederContext: FeederContext) {
    Task.detached { [weak self] in
      guard let self = self else { return }
      var downloadMissing = false
      for issueDateKey in downloadDateKeys {
        notifyHome(.loadIssue)
        do {
          let feed = try await loadFeedFromJsonFile(feederContext: feederContext,
                                                    feedName: feederContext.defaultFeed.name,
                                                    issueDateKey: issueDateKey)
          guard let issue = feed.issues?.first else {
            throw BackgroundDownloadError("No Issue found!")
          }
          tempStorage.add(feed.publicationDates ?? [])
          #warning("CHECK: try")
          try tempStorage.add(issue)
          log("...loaded data for issue: \(issueDateKey)")
          
          guard let zipUrl = issue.zipUrl else {
            log("No zipUrl for issue: \(issueDateKey)")
            continue
          }
            
          guard let idd = getDownloadData(forDownloadUrl: zipUrl) else {
            log("No DownloadData for issue: \(issueDateKey)")
            continue
          }
          log("DownloadData for issue: \(issueDateKey) found issue is: \(idd.isDownloaded ? "downloaded" : "not downloaded")")
          if idd.isDownloaded == true {
            issue.setAutodownloadCompleete()
          } else {
            downloadMissing = true
          }
        } catch {
          log("⚠️ Failed to load data for issue \(issueDateKey): \(error)")
          log("Delete Default for: \(issueDateKey)")
          removeDownloadData(forIssueKey: issueDateKey)
        }
      }
      notifyHome(downloadMissing ? .downloadError : .none)
      handlePendingTasks()
    }
    
    do {
      log("restart AllArchivedDownloads...")
      try BackgroundSession.restartAllArchivedDownloads { [weak self] url, err in
        self?.log("restarted AllArchivedDownloads callback")
        self?.dlCallback(downloadUrl: url, err: err)
      }
    } catch {
      log("restart failed with: \(error)")
    }
  }
}
