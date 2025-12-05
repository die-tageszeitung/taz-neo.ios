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
  
  func applicationRestarted(with feederContext: FeederContext) {
    Task{[weak self] in
      guard let self = self else { return }
      /// Helper
      var outdatedDurationDays : Double {
        switch publicationSchedule {
          case .wochentaz: return 15.0
          case .lmd: return 60.0
          default: return 7.0 //taz
        }
      }
      
      func isOutdated(date:Date?) -> Bool {
        guard let date = date else { return true }
        return date.timeIntervalSinceNow  < -outdatedDurationDays * 24 * 60 * 60
      }
      
      ///local var for reuse
      let downloadDateKeys = downloadDateKeys
      
      log("BDL: restore Download Data from UserDefaults for: \(downloadDateKeys.count) issue dates and resume all download Tasks")
      for issueDateKey in downloadDateKeys { //only issue downloads here
        notifyHome(.loadIssue)
        do {
          let feed = try await loadFeedFromJsonFile(feederContext: feederContext,
                                                    feedName: feederContext.defaultFeed.name,
                                                    issueDateKey: issueDateKey)
          guard let issue = feed.issues?.first else {
            throw BackgroundDownloadError("No Issue found!")
          }
          tempStorage.add(feed.publicationDates ?? [])
          /// In Case of error the next issueDateKey is handled
          /// in case of error e.g. the issue is already in temp storage it woun't be added again
          try tempStorage.add(issue)
          log("BDL ...loaded data for issue: \(issueDateKey)")
          
          guard let zipUrl = issue.zipUrl else {
            log("BDL No zipUrl for issue: \(issueDateKey)")
            continue
          }
          
          guard let idd = getDownloadData(forDownloadUrl: zipUrl) else {
            log("BDL No DownloadData for issue: \(issueDateKey)")
            continue
          }
          log("BDL DownloadData for issue: \(issueDateKey) found issue is: \(idd.isDownloaded ? "downloaded" : "not downloaded")")
          if idd.isDownloaded == true {
            log("set isAutodownloading compleete!")
            issue.setAutodownloadCompleete()
          }
          else if isOutdated(date: idd.date) && useTestServer == false {
            ///KISS: in case of outdated download data, remove it
            ///maybe background session download it and moves files to issue folder; cleanup deletes them later
            ///multiple newer issues will be loaded meanwhile
            throw BackgroundDownloadError("Download outdated for issue \(issueDateKey) remove data!")
          }
        } catch {
          log("BDL ⚠️ Failed to load data for issue \(issueDateKey): \(error)")
          log("BDL ...Delete Default for: \(issueDateKey)")///could not be restored
          removeDownloadData(forIssueKey: issueDateKey)
        }
      }
      let openDl = backgroundSession.hasOpenDownloads ///issue, audio and resources downloads
      notifyHome(openDl ? .loadIssue : feederContext.isConnected ? .online : .offline)
      handlePendingTasks()
      if openDl { backgroundSession.resume(archived: true, priority: 1.0)}
    }
  }
}
