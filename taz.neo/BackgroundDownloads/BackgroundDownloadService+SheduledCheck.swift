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
  func handleIssueCheckTask(task: BGAppRefreshTask) {
    scheduleBackgroundIssueCheck() // Schedule the next background task
    
    log("Start timed check \(latestIssueIssueDate?.short.prepend("Latest Issue Date: ") ?? "")")
    
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    
    task.expirationHandler = {
      queue.cancelAllOperations()
    }
    
    guard let storedFeed = feederContext?.defaultFeed else {
      log("Skipping check: No stored feed available.")
      task.setTaskCompleted(success: true)
      return
    }
    
    guard shouldCheckForNewIssue(tz: timeZone,
                                 typ: publicationType,
                                 lastPublicationDate: latestIssueIssueDate?.expectedPublicationDateForIssueDate) else {
      log("Skipping check: Not yet time for next issue.")
      task.setTaskCompleted(success: true)
      return
    }
    
    // Define the operation
    let checkOperation = BlockOperation { [weak self] in
      let group = DispatchGroup()
      group.enter()
      self?.log("Starting background issue check...")
      Self.checkForNewIssue{ _ in
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
  
  func scheduleBackgroundIssueCheck(earliestBeginDate: Date? = nil) {
    let request = BGAppRefreshTaskRequest(identifier: "de.taz.taz.neo.refresh")
#warning("TODO LAST DOWNLOAD IS CURRENTLY NOW!")
    let nextCheck = earliestBeginDate ?? nextEligibleCheckDate(tz: self.timeZone, type: self.publicationType, lastDownload: Date())
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
  enum PublicationType: String {
    case taz, wochentaz, lmd
  }
  
  fileprivate func nextEligibleCheckDate(tz: TimeZone, type: PublicationType, lastDownload: Date) -> Date {
    let now = Date()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    
    let today = calendar.startOfDay(for: now)
    
    func nextDateMatching(hour: Int) -> Date? {
      let components = DateComponents(hour: hour)
      return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents)
    }
    
    func nextHourFromList(_ hours: [Int], excludingSaturdays: Bool = false) -> Date? {
      for offset in 0..<7 {
        guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
        let weekday = calendar.component(.weekday, from: day)
        if excludingSaturdays && weekday == 7 { continue }
        
        for hour in hours {
          if let candidate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), candidate > now {
            return candidate
          }
        }
      }
      return nil
    }
    
    switch type {
      case .taz:
        let triggerHours = [6, 19, 20, 23]
        if let next = nextHourFromList(triggerHours, excludingSaturdays: true),
           next.timeIntervalSince(lastDownload) > 60 * 60 * 20 {
          return next
        }
        
      case .wochentaz:
        let triggerWeekdays = [5, 6, 7] // Thursday, Friday, Saturday
        let triggerHour = 20
        
        for offset in 0..<7 {
          if let day = calendar.date(byAdding: .day, value: offset, to: today),
             triggerWeekdays.contains(calendar.component(.weekday, from: day)),
             let candidate = calendar.date(bySettingHour: triggerHour, minute: 0, second: 0, of: day),
             candidate > now,
             candidate.timeIntervalSince(lastDownload) > 60 * 60 * 24 * 4 {
            return candidate
          }
        }
        
      case .lmd:
        let triggerWeekdays = [4, 5, 6, 7] // Wednesday, Thursday, Friday, Saturday
        let triggerHours = [8, 20]
        
        for offset in 0..<7 {
          if let day = calendar.date(byAdding: .day, value: offset, to: today),
             triggerWeekdays.contains(calendar.component(.weekday, from: day)) {
            for hour in triggerHours {
              if let candidate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                 candidate > now,
                 candidate.timeIntervalSince(lastDownload) > 60 * 60 * 24 * 25 {
                return candidate
              }
            }
          }
        }
    }
    // fallback: in 1h
    return Date(timeIntervalSinceNow: 60 * 60)
  }
  
  fileprivate func shouldCheckForNewIssue(tz: TimeZone, typ: PublicationType, lastPublicationDate: Date?) -> Bool {
    
    guard let lastPublicationDate = lastPublicationDate else {
      log("LastDownload/lastPublicationDate is nil => Download now")
      return true
    }
    
    let now = Date()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    
    guard let lastCheck = latestCheckForNewIssue else {
      log("never checked before ...do now")
      return true
    }
    
    let weekday = calendar.component(.weekday, from: now)
    let hour = calendar.component(.hour, from: now)
    let minute = calendar.component(.minute, from: now)
    
    func timeIs(_ h: Int, _ m: Int) -> Bool {
      return hour == h && minute == m
    }
    
    func isWithinTimeWindow(_ targetHour: Int, _ targetMinute: Int, window: Int) -> Bool {
      guard let targetDate = calendar.date(bySettingHour: targetHour, minute: targetMinute, second: 0, of: now) else {
        log("targetHour: \(targetHour) and targeMinute: \(targetMinute) are invalid")
        return false
      }
      let windowStart = targetDate.addingTimeInterval(-TimeInterval(window * 60))
      
      let ret = lastCheck < windowStart && now >= targetDate
      
      if ret == false {
        log("targetHour: \(targetHour) and targeMinute: \(targetMinute) are not in time window: \(window) minutes")
      }
      return ret
    }
    
    switch typ {
      case .taz:
        // Sunday = 1, Saturday = 7
        guard weekday != 7 else { return false }
        let triggerTimes = [(19,30), (20,0), (23,0), (6,0)]
        let isOldEnough = now.timeIntervalSince(lastPublicationDate) > 20 * 3600
        let isRightTime = triggerTimes.contains { isWithinTimeWindow($0.0, $0.1, window: 5) }
        log("⏰ shouldCheck: \(isOldEnough && isRightTime) lastPublicationDate: \(lastPublicationDate.ddMMyy_HHmmss)")
        return isOldEnough && isRightTime
        
      case .wochentaz:
        guard (5...7).contains(weekday) else { return false }
        let isRightTime = isWithinTimeWindow(20, 0, window: 5)
        let isOldEnough = now.timeIntervalSince(lastPublicationDate) > 4 * 86400
        return isOldEnough && isRightTime
        
      case .lmd:
        guard (4...7).contains(weekday) else { return false }
        let isRightTime = isWithinTimeWindow(8, 0, window: 5) || isWithinTimeWindow(20, 0, window: 5)
        let isOldEnough = now.timeIntervalSince(lastPublicationDate) > 25 * 86400
        return isOldEnough && isRightTime
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
