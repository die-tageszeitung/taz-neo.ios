//
//  BackgroundDownloadServiceSheduledCheck.swift
//  taz.neo
//
//  Created by Ringo Müller on 02.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import UIKit
import BackgroundTasks
import NorthLib

extension BackgroundDownloadService {
  
  fileprivate var timeZone: TimeZone {
    return TimeZone(identifier: GqlFeeder.tz) ?? TimeZone.current
  }
  
  func handleGoingBackground() {
    scheduleBackgroundIssueCheck()
  }
}

///Mark: - Background Task Handling
extension BackgroundDownloadService {
  func handleIssueCheckTask(task: BGTask) {
    scheduleBackgroundIssueCheck() // Schedule the next background task
    
    log("Start timed check \(lastFullyDownloadedIssueDate?.short.prepend("Latest Issue Date: ") ?? "")")
    
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    
    (task as? BGProcessingTask ?? task as? BGAppRefreshTask)?.expirationHandler = {
      queue.cancelAllOperations()
    }
    
    // Define the operation
    let checkOperation = BlockOperation { [weak self] in
      let group = DispatchGroup()
      group.enter()
      self?.log("Starting background issue check...")
        
      Self.checkForNewIssue(isPush: false, isBackground: true){ _ in
        self?.log("Finished issue check.")
        group.leave()
      }
      
      // Wait until done or timeout (optional)
      let waitResult = group.wait(timeout: .now() + 25) // safety timeout fallback
      if waitResult == .timedOut {
        self?.log("Issue check operation timed out.")
      }
    }
    
    checkOperation.completionBlock = {
      task.setTaskCompleted(success: !checkOperation.isCancelled)
    }
    
    queue.addOperation(checkOperation)
  }
  
  /// Executes a background issue check if `nextScheduledCheck` is in the past or within the next 30 seconds.
  /// Returns `true` if the check was performed, otherwise `false`.
  func executeScheduledCheckIfNeeded() -> Bool {
    // Only proceed if the next scheduled check is in the past or within the next 30 seconds
    guard (nextScheduledCheck?.timeIntervalSinceNow ?? 60) < 30 else {
      return false
    }
    
    guard UIApplication.shared.applicationState == .background else {
      log("App not in background, skipping background issue check")
      return false
    }
    
    log("Starting background issue check due to net status change and schedule reached")
    
    Self.checkForNewIssue(isPush: false, isBackground: true) { [weak self] _ in
      self?.log("Finished issue check triggered by schedule")
    }
    
    return true
  }
  
  func scheduleBackgroundIssueCheck(earliestBeginDate: Date? = nil) {
    let request = BGProcessingTaskRequest(identifier: "de.taz.taz.neo.refresh")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    let nextCheck = earliestBeginDate
    ?? publicationSchedule.nextScheduledCheck(lastIssueDate: lastFullyDownloadedIssueDate)
    
    log("Scheduling background task at \(nextCheck.dateAndTime) (in \(nextCheck.timeIntervalSinceNow.readable))")
    request.earliestBeginDate = nextCheck
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      print("Could not schedule background task: \(error)")
    }
  }
}

extension BackgroundDownloadService {
  
  /// Returns `true` if the last fully downloaded issue is considered outdated based on the publication type.
  ///
  /// The threshold for being "outdated" varies per publication:
  /// - `.lmd`: Considered outdated at the earliest 25 days after the last issue's 5 PM
  /// - `.wochentaz`: Considered outdated at the earliest 5 days after the last issue's 5 PM
  /// - `.taz`: Considered outdated once the current date passes the last issue's 5 PM
  ///
  /// If no issue has been downloaded yet, it is considered outdated by default.
  var isLastFullyDownloadedIssueOutdated: Bool {
    guard let lastDownload5PM = Self.shared.lastFullyDownloadedIssueDate?.fivePM else {
          // No last download available → considered outdated
          return true
      }

      let now = Date()
      switch publicationSchedule {
      case .lmd:
          /// Outdated if at least 28 days have passed since last issue
          return now > lastDownload5PM.addingTimeInterval(60 * 60 * 24 * 28)
          
      case .wochentaz:
          // Outdated if 6 days have passed since the last issue
          return now > lastDownload5PM.addingTimeInterval(60 * 60 * 24 * 6)
          
      case .taz:
          // Outdated as soon as current time is past 5 PM of the issue day
          return now > lastDownload5PM
      }
  }
}


fileprivate extension Date {
  /// Calculates the expected publication date for an given date.
  /// The expected publication date is determined as follows:
  /// 1. It is set to 18:00 (6 PM) on the day before the issue's `self.date`.
  /// 2. Alternatively, it could use `moment.files.first?.moTime`, but this is avoided
  ///    due to potential inaccuracies if the moment time has been modified.
  ///
  /// The logic assumes that 18:00 on the previous day is the most accurate and reliable
  /// publication time, even though publication times between 18:00 and 22:00 are common.
  /// The calculation respects the time zone specified in `self.feed.feeder.timeZone`,
  /// falling back to "Europe/Berlin" or the system's current time zone if unavailable.
  var expectedPublicationDateForIssueDate: Date {
    let timeZone = TimeZone(identifier: GqlFeeder.tz) ?? TimeZone.current
    
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    
    // Subtract one day from the given date
    let previousDay = calendar.date(byAdding: .day, value: -1, to: self)!
    
    // Set the time to 18:00 (6 PM)
    var components = calendar.dateComponents([.year, .month, .day], from: previousDay)
    components.hour = 18
    components.minute = 0
    components.second = 0
    
    return calendar.date(from: components)!
  }
}


fileprivate extension Date {
  
  /// Returns a new `Date` set to 5:00 PM on the same calendar day as the original date.
  var fivePM:Date {
    return newWith(hour: 17, minute: 0, second: 0)
  }
  
  /// Returns a new `Date` object by adding the given number of seconds to the start of the day.
  /// - Parameter seconds: The number of seconds to add to the start of the day.
  /// - Returns: A new `Date` representing `startOfDay + seconds`.
  func sameDateAtTime(seconds: TimeInterval) -> Date {
      return self.startOfDay.addingTimeInterval(seconds)
  }
  
  /// Returns a new `Date` set to given components on the same calendar day as the original date.
  func newWith(year: Int? = nil, month: Int? = nil, day: Int? = nil, hour: Int? = nil, minute: Int? = nil, second: Int? = nil) -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day], from: self)
    
    var newComponents = DateComponents()
    newComponents.year = year ?? components.year
    newComponents.month = month ?? components.month
    newComponents.day = day ?? components.day
    newComponents.hour = hour ?? components.hour
    newComponents.minute = minute ?? components.minute
    newComponents.second = second ?? components.second
    
    if let newDate = calendar.date(from: newComponents) {
        return newDate
    } else {
        // Optional: Log unexpected failure
        print("⚠️ Warning: Failed to create date from \(self)")
        return self
    }
  }
}
