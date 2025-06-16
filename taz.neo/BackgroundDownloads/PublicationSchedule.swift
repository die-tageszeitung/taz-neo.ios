//
//  PublicationSchedule.swift
//  taz.neo
//
//  Created by Ringo Müller on 16.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import Foundation

enum PublicationSchedule: String {
  
  case taz, wochentaz, lmd
  
  /// Returns the next scheduled check time for a given publication type.
  /// - Parameters:
  ///   - publication: The type of publication (.taz, .wochentaz, .lmd)
  ///   - lastIssueDate: The date of the last known issue
  ///   - now: The current date/time (defaults to Date())
  /// - Returns: The next Date to run `checkForNewIssue`, or nil if none needed
  func nextScheduledCheck(lastIssueDate: Date?, now: Date = Date()) -> Date {
    
    guard let lastIssueDate = lastIssueDate else {
      return now.addingTimeInterval(60*1)//1 minute
    }
    
    switch self {
      case .taz:
        return nextScheduledCheck_taz(lastIssueDate: lastIssueDate, now: now)
      case .wochentaz:
        return nextScheduledCheck_wochentaz(lastIssueDate: lastIssueDate, now: now)
      case .lmd:
        return nextScheduledCheck_lmd(lastIssueDate: lastIssueDate, now: now)
    }
  }
}

fileprivate extension PublicationSchedule {
  
  // MARK: - TAZ (Daily)

  /// Returns the next scheduled check time for the daily taz publication.
  func nextScheduledCheck_taz(lastIssueDate: Date, now: Date = Date()) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    
    let currentHour = Int(now.secondsSinceStartOfDay / 3600)
    let targetHour = checkTargetHour(currentHour: currentHour)
    
    //the day the issue appears to is the day when the next issue comes out for tomorow
    var nextIssueDate = lastIssueDate.startOfDay
    
    /// in case of wochentaz add a extra Day due there is no sunday issue but the monday issue appears sunday
    if calendar.component(.weekday, from: lastIssueDate) == 7 {
      nextIssueDate.addTimeInterval(60*60*24)
    }
    
    return max(nextIssueDate.addingHours(19), now.startOfDay.addingHours(targetHour))
  }

  // MARK: - Wochentaz (Weekly)

  /// Returns the next scheduled check time for the weekly wochentaz publication.
  func nextScheduledCheck_wochentaz(lastIssueDate: Date, now: Date = Date()) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    
    let currentHour = Int(now.secondsSinceStartOfDay / 3600)
    let targetHour = checkTargetHour(currentHour: currentHour)
    
    // Fallback: 6 days after last issue, start of day
    var fallbackDate = lastIssueDate.startOfDay
    fallbackDate.addTimeInterval(60*60*24*6)
    
    // Try to get the next Friday after lastIssueDate
    let nextIssueDate = nextWeekday(6, after: lastIssueDate, calendar: calendar)
    
    // Use next Friday or fallback
    let nextCheckDate = nextIssueDate ?? fallbackDate
    
    // If that check date is in the past, schedule check today at targetHour
    return max(nextCheckDate.addingHours(19), now.startOfDay.addingHours(targetHour))
  }
  
  // MARK: - Wochentaz (LMd)
  
  /// calculates target Date&Time for next check expecting LMd appears every 2nd Friday per month
  /// in case of expired appeariance continious check until next appeariance
  func nextScheduledCheck_lmd(lastIssueDate: Date, now: Date = Date()) -> Date {
      let calendar = Calendar(identifier: .gregorian)

      let currentHour = Int(now.secondsSinceStartOfDay / 3600)
      let targetHour = checkTargetHour(currentHour: currentHour)

      var components = calendar.dateComponents([.year, .month], from: lastIssueDate)

      if let month = components.month {
          if month == 12 {
              components.month = 1
              components.year! += 1
          } else {
              components.month! += 1
          }
      }

      components.weekday = 5 // Thursday
      components.weekdayOrdinal = 2 // 2nd Thursday

      let nextIssueDate = calendar.date(from: components)

      let nextCheckDate = nextIssueDate ?? lastIssueDate.startOfDay.addingTimeInterval(60 * 60 * 24 * 28)

      return max(nextCheckDate.addingHours(19), now.startOfDay.addingHours(targetHour))
  }
  
  
  
  /// calculates target Date&Time for next check expecting LMd appears every 2nd Friday per month
  /// in case of expired appeariance continious check until next appeariance
  #warning("Did not work as expected @see UNITTESTS")
  ///e.g. today 2nd friday lmd did not appeared yet => next scheduled is in 4 Weeks (dismissed current issue)
  func nextScheduledCheck_lmd1(lastIssueDate: Date, now: Date = Date()) -> Date {
    let calendar = Calendar.current
    
    func calcTargetHour(h: Int) -> Int {
      let checkHours = [7, 19, 20, 23, 30]
      for hour in checkHours {
        if h < hour { return hour }
      }
      return h + 1
    }
    
    func secondFriday(ofMonth month: Int, year: Int) -> Date? {
      var components = DateComponents()
      components.year = year
      components.month = month
      components.weekday = 6 // Friday
      components.weekdayOrdinal = 2 // 2nd Friday
      return calendar.date(from: components)
    }
    
    let secondsSinceIssue = now.startOfDay.timeIntervalSince(lastIssueDate.startOfDay)
    let currentHour = Int(now.secondsSinceStartOfDay / 3600)
    let targetHour = calcTargetHour(h: currentHour)
    
    // Fall 1: Ausgabe ist älter als 35 Tage → sofort nächster Check
    if secondsSinceIssue > 35 * 24 * 3600 {
      return now.startOfDay.addingHours(targetHour)
    }
    
    let useNow = secondsSinceIssue < 0 ? lastIssueDate : now
    
    guard let nowComponents = calendar.dateComponents([.year, .month], from: useNow) as DateComponents?,
          let month = nowComponents.month,
          let year = nowComponents.year,
          let currentSecondFriday = secondFriday(ofMonth: month, year: year) else {
      return useNow.startOfDay.addingHours(targetHour)
    }
    
    // Falls nach 2. Freitag → nächsten Monat nehmen
    var issueDate = currentSecondFriday
    if issueDate < useNow {
      guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: useNow),
            let comps = calendar.dateComponents([.year, .month], from: nextMonth) as DateComponents?,
            let nextMonthValue = comps.month,
            let nextYear = comps.year,
            let nextSecondFriday = secondFriday(ofMonth: nextMonthValue, year: nextYear) else {
        return useNow.startOfDay.addingHours(targetHour)
      }
      issueDate = nextSecondFriday
    }
    
    // Ausgabe erscheint am Donnerstagabend vorher
    guard let releaseDate = calendar.date(byAdding: .day, value: -1, to: issueDate),
          let releaseCheck = calendar.date(bySettingHour: targetHour, minute: 0, second: 0, of: releaseDate) else {
      return useNow.startOfDay.addingHours(targetHour)
    }
    
    if releaseCheck > useNow {
      return releaseCheck
    } else {
      return useNow.startOfDay.addingHours(targetHour)
    }
  }
  
  
  
  
  
  
  
  
  
}

fileprivate extension PublicationSchedule {
  /// Determines the next suitable check hour based on the current hour.
  ///
  /// This function returns the next scheduled check time from a predefined list
  /// of check hours (`[7, 19, 20, 23, 30]`). It finds the first hour in that list
  /// which is greater than the current hour. If no suitable hour is found
  /// (e.g., the current hour is later than all listed), it returns `currentHour + 1`
  /// as a fallback.
  ///
  /// - Parameter currentHour: The current hour of the day (0–23).
  /// - Returns: The next hour at which a check should be performed.
  func checkTargetHour(currentHour: Int) -> Int {
      let checkHours = [7, 19, 20, 23, 31]//31=24+7 a.m.
      for hour in checkHours {
          if currentHour < hour { return hour }
      }
      return currentHour + 1
  }
  
  // MARK: - Helpers

  /// Returns the next occurrence of the specified weekday (1 = Sunday, ..., 7 = Saturday) after the given date.
  /// Returns `nil` if input is invalid.
  func nextWeekday(_ weekday: Int, after date: Date, calendar: Calendar) -> Date? {
      guard (1...7).contains(weekday) else { return nil }

      let currentWeekday = calendar.component(.weekday, from: date)
      let daysUntilNext = (weekday + 7 - currentWeekday) % 7
      let offset = daysUntilNext == 0 ? 7 : daysUntilNext // Always go forward

      return calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date))
  }
  
  /// Returns the second Friday of the month that comes after the given date.
  /// If the second Friday of the current month is today or earlier, returns the one in the next month.
  /// - Parameters:
  ///   - date: The reference date.
  ///   - calendar: The calendar to use.
  /// - Returns: The date of the second Friday, or `nil` if calculation fails.
  func secondFriday(after date: Date, calendar: Calendar) -> Date? {
      var components = calendar.dateComponents([.year, .month], from: date)
      components.day = 1

      // Start at first day of the month
      guard let firstOfMonth = calendar.date(from: components) else { return nil }

      // Find weekday of the first of the month
      let weekday = calendar.component(.weekday, from: firstOfMonth)
      let friday = 6 // Friday = 6 in Calendar (1 = Sunday)

      // Days to add to get to first Friday
      let daysToFirstFriday = (friday + 7 - weekday) % 7
      let firstFriday = calendar.date(byAdding: .day, value: daysToFirstFriday, to: firstOfMonth)

      // Add 7 more days for second Friday
      guard let targetFriday = firstFriday.flatMap({ calendar.date(byAdding: .day, value: 7, to: $0) }) else {
          return nil
      }

      // If the second Friday is after the given date → return it
      if targetFriday > date {
          return calendar.startOfDay(for: targetFriday)
      }

      // Otherwise, calculate second Friday of next month
      guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else { return nil }
      return secondFriday(after: nextMonth, calendar: calendar)
  }
  
}


