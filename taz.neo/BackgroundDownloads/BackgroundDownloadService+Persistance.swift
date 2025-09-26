//
//  BackgroundDownloadService+Persistance.swift
//  taz.neo
//
//  Handles persistence-related tasks
//  such as saving issues and publication dates
//
//  Created by Ringo Müller on 13.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

// MARK: - Helper Class for BackgroundDownloadService to hold temporary issues and publication dates
class BackgroundDownloadsTempStorage: DoesLog {
  
  var hasActiveDownloads: Bool { return !issues.isEmpty  }

  // MARK: - Internal Data
  
  fileprivate var publicationDates: [PublicationDate] = []
  fileprivate var issues: [Issue] = []

  // MARK: - Queues

  fileprivate let issuesQueue
  = DispatchQueue(label: "de.taz.bds.issuesQueue",
                  attributes: .concurrent)
  fileprivate let pubDatesQueue
  = DispatchQueue(label: "de.taz.bds.publicationDatesQueue",
                  attributes: .concurrent)

  // MARK: - Issue Handling

  /// Adds a new issue if it's not already present (based on issueKey).
  /// Removes the oldest issues if there are more than 7, and deletes their files.
  func add(_ issue: Issue) throws{
    let newKey = issue.date.issueKey

    // Check outside of queue for performance
    let exists = issuesQueue.sync {
      issues.contains(where: { $0.date.issueKey == newKey })
    }

    guard !exists else {
      // Do not throw an error here. Due to a race condition during app restart,
      // a new download may already be queued. If a push notification arrives
      // before that download completes, it may conflict with finalization logic.
      // Skip processing if the key already exists to avoid errors.
      log("Issue with key \(newKey) already exists. Skipping.")
      return
    }

    // Append issue and clean up oldest ones if needed
    issuesQueue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }

      self.issues.append(issue)

      let numberOfIssuesToRemove = self.issues.count - 7
      guard numberOfIssuesToRemove > 0 else { return }

      let sorted = self.issues.sorted(by: { $0.date < $1.date })
      let toDelete = sorted.prefix(numberOfIssuesToRemove)

      for case let issue as StoredIssue in toDelete {
        log("Delete files for issue \(issue.date.short)")
        ///Prevent 30 Downloaded Issues fill Device Storage if App is not started
        issue.dir.remove()
      }

      self.issues = Array(sorted.suffix(7))

      log("Deleted \(toDelete.count) oldest issues. Kept latest 7.")
    }
  }
  
  /// get issue by server base url
  func getIssue(with serverBaseUrl: String) -> Issue? {

    // Check outside of queue for performance
    return issuesQueue.sync {
      issues.first(where: { $0.baseUrl == serverBaseUrl })
    }
  }
    
  /// Deletes the JSON files associated with the given stored issues and
  /// removes the corresponding issues from the `issues` array.
  /// This operation is performed asynchronously with a barrier to ensure thread safety.
  ///
  /// - Parameter storedIssues: An array of `StoredIssue` objects whose JSON files should be deleted.
  func deleteJsonFiles(for storedIssues: [StoredIssue]) {
    issuesQueue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      
      for issue in storedIssues {
        let file = issue.jsonFile
        
        if file.exists {
          file.remove()
          log("File deleted: \(file.path)")
        } else {
          log("File not found: \(file.path)")
        }
        
        self.issues.removeAll { $0.date.issueKey == issue.date.issueKey }
      }
    }
  }
  

  // MARK: - PublicationDate Handling

  /// Adds multiple publication dates, skipping duplicates based on exact date.
  func add(_ pubDates: [PublicationDate]) {
    // Filter out dates that already exist (outside the queue for performance)
    let existingDates: Set<Date> = pubDatesQueue.sync {
      Set(publicationDates.map { $0.date })
    }

    let newDates = pubDates.filter { !existingDates.contains($0.date) }
    guard !newDates.isEmpty else {
      log("All publicationDates already exist. Skipping batch.")
      return
    }

    // Append new dates thread-safely
    pubDatesQueue.async(flags: .barrier) { [weak self] in
      self?.publicationDates.append(contentsOf: newDates)
    }
  }
  
  /// Returns the latest publication date, or nil if none exist.
  func latestPublicationDate() -> Date? {
    return pubDatesQueue.sync {
      publicationDates.map { $0.date }.max()
    }
  }
}

// MARK: - Persistance Helper Extensions
extension BackgroundDownloadService {
  
  /// Updates the latest issue download date if the given date is more recent.
  func updateLatestIssueDownloadDate(ifNewer date: Date) {
    if let latest = lastFullyDownloadedIssueDate, date > latest {
      log("Updating latest issue download date from \(latest) to \(date)")
      lastFullyDownloadedIssueDate = date
    } else if lastFullyDownloadedIssueDate == nil {
      lastFullyDownloadedIssueDate = date
      log("Setting initial latest issue download date to \(date)")
    }
  }
  
  /// execute tasks that need to be performed to persist data, generate facsimile or inform UI
  func handlePendingTasks() {
    ensureMain { [weak self] in
      self?.handlePendingTasksOnMain()
    }
  }
  
  private func handlePendingTasksOnMain() {
    log("handlePendingTasks")
    
    let finishedStoredIssues = persistCurrentIssues()
    ///1st persist existing if available > this should delete used json then load jsons available
    ///das mach ich doch beim neu erstellen des FeederContext.  => brauche ich hier nicht.
    ///
    #warning("TODO")
    //    persistJsonData()...nö nicht (mehr?)
    
    if let storedFeed = feederContext?.defaultFeed,
       tempStorage.publicationDates.count > 0
    {
      log("...Persisting \(tempStorage.publicationDates.count) publication dates reset feed to: \(storedFeed.name)")
      for date in tempStorage.publicationDates {
        let spd = StoredPublicationDate.persist(object: date)
        storedFeed.pr.addToPublicationDates(spd.pr)
        saveDatabase = true
      }
    }
    else {
      log("No (\(tempStorage.publicationDates.count)) PublicationDates to persist!")
    }
    
    if saveDatabase {
      log("...save database")
      ArticleDB.save()
      saveDatabase = false
      log("...saved database")
      tempStorage.deleteJsonFiles(for: finishedStoredIssues)
      log("...removed obsolete JSON files for: \(finishedStoredIssues.count) issues")
      removeDownloadData(for: finishedStoredIssues)
      log("...removed obsolete UserDefaults Entries")
    }
    
    if informUIAfterSave {
      debug(">>..informUIAfterSave")
      onMainAfter {
        Notification.send(Const.NotificationNames.newAutolIssueLoaded)
        for issue in finishedStoredIssues {
          Notification.send("issueStructure", sender: issue)
        }
      }
    }
  }
  
  private func removeDownloadData(for storedIssues: [StoredIssue]) {
    for issue in storedIssues {
      ///Remove all stored Issue Data or only compleete ones?
      ///What happen if Push > persistDB > wait > callback > sendDownload STop wount work
      ///if only compleete ones....
      ///enqueued > download did not start > manuell start & download ::
      /// 1. what happen with BAckgroundSession ones? ToDo
      ///   on App resume./restart.. check db status ...only start last 2-3 Downloads remove others
      /// 2. what happen with downloadData? ToDo
      ///     onApp resume/restart
      ///
      /// only remove completed ones
      guard issue.isComplete else {
        log("Warning Issue \(issue.date.short) is not complete, skipping removal of download data.")
        continue
      }
      removeDownloadData(forIssueKey: issue.date.ISO8601)
    }
  }
  
  /// Persists all issues currently in the temporary storage.
  /// is called from main Thread!
  ///
  /// This method processes the issues in `tempStorage`:
  /// - Persists each issue to storage.
  /// - Separates finished (complete) issues from unfinished ones.
  /// - Updates `tempStorage.issues` to retain only unfinished issues.
  /// - Marks the database as needing to be saved if any issues were processed.
  ///
  /// - Returns: An array of completed (finished) `StoredIssue` instances.
  private func persistCurrentIssues() -> [StoredIssue] {
    log("wait for persistCurrentIssues...")
    return self.tempStorage.issuesQueue.sync(flags: .barrier) { [weak self] in
      
      guard let self = self else { return [] }
      
      log("Do persistCurrentIssues...")
      
      var finishedIssues = [StoredIssue]()
      var unfinishedIssues = [StoredIssue]()
      
      for issue in tempStorage.issues {
        let storedIssue = persistIssue(issue: issue)
        
        if storedIssue.isComplete {
          finishedIssues.append(storedIssue)
        } else {
          unfinishedIssues.append(storedIssue)
        }
        
        saveDatabase = true
      }
      
      log("Finished issues: \(finishedIssues.count), Unfinished issues: \(unfinishedIssues.count)")
      
      tempStorage.issues = unfinishedIssues
      return finishedIssues
    }
  }
  
  /// Persists or updates a given `Issue` object as a `StoredIssue`.
  ///
  /// - If the issue is not a `StoredIssue`, it creats and persist it as a new `StoredIssue`.
  /// - If the issue is marked as complete:
  ///   - Marks the stored issue as complete.
  ///   - Fixes potential metadata (e.g., time fields).
  ///   - Create the facsimile for the first page if available.
  ///   - Notifies the UI that data has been saved.
  ///
  /// - Parameter issue: The `Issue` object to persist, which may or may not already be a `StoredIssue`.
  /// - Returns: The corresponding `StoredIssue` instance, newly created or updated.
  private func persistIssue(issue: Issue) -> StoredIssue {
      if issue is StoredIssue {
          log("Updating persisted issue: (\(issue.date.short))")
      } else {
          log("Persisting new issue: (\(issue.date.short))")
      }

      let storedIssue = issue as? StoredIssue ?? StoredIssue.persist(object: issue)

      // If the issue is complete, update its completion state and perform finalization steps.
      if issue.isComplete {
          storedIssue.isComplete = true // Needed if not persisted between fetch and download complete
          storedIssue.isOvwComplete = true
          storedIssue.fixMoTime()

          // Preload facsimile if available (triggers lazy loading)
          _ = storedIssue.pages?.first?.facsimile

          informUIAfterSave = true
          log("✅ Issue \(issue.date.short) is marked as finished.")
        scheduleBackgroundIssueCheck()
      } else {
        log("Issue \(issue.date.short) is not complete...")
      }
      
      return storedIssue
  }
  
}

fileprivate extension StoredIssue {
  
  ///fix moTime for issue
  ///downloaded and extracted file have different moTime then the one in the database
  func fixMoTime() {
    let issuePath = self.dir.path
    let globalPath = self.feed.feeder.globalDir.path
    for file in self.files {
      let path = file.storageType == .global ? globalPath : issuePath
      let f = File(dir: path, fname: file.name)
      guard f.exists else {
        debug("File \(file.name) not exist in \(path)")
        continue
      }
      guard f.size == file.size else {
        debug("File \(file.name) size not equal")
        continue
      }
      ///exist & time is correct: perfect, do nothing
      if f.mTime == file.moTime { continue }
      //fix mTime
      f.mTime = file.moTime
    }
  }
}
