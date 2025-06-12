//
//  GermanDate.swift
//
//  Created by Norbert Thies on 30.01.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation

/// A small Date extension to provide German string representations
public extension Date {
  
  /// German week day names
  static let gWeekDays = ["", "Sonntag", "Montag", "Dienstag", "Mittwoch", 
                          "Donnerstag", "Freitag", "Samstag"]
  /// German month names
  static let gMonthNames = ["", "Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", 
                            "August", "September", "Oktober", "November", "Dezember"]
 
  /// Returns String in German format: <weekday>, <day>.<month>.<year>
  func gDate(tz: String? = nil) -> String {
    let dc = components(tz: tz)
    return "\(Date.gWeekDays[dc.weekday!]), \(dc.day!)." +
           "\(dc.month!).\(dc.year!)"
  }  
  
  /// Returns String in German format: <weekday>, <day>.<month>.<year>
  func gLowerDate(tz: String? = nil) -> String {
    return gDate(tz: tz).lowercased()
  }  

  /// Returns String in German format: <weekday>, <day>.<monthname> <year>
  func gDateString(tz: String? = nil) -> String {
    let dc = components(tz: tz)
    return "\(Date.gWeekDays[dc.weekday!]), \(dc.day!). " +
           "\(Date.gMonthNames[dc.month!]) \(dc.year!)"
  }
  
  /// German date String in lowercase letters
  func gLowerDateString(tz: String?) -> String {
    return gDateString(tz: tz).lowercased()
  }
  
  /// German month and year <month> <year>
  func gMonthYear(tz: String?, isNumeric: Bool = false) -> String {
    let dc = components(tz: tz)
    return isNumeric ? "\(dc.month!)/\(dc.year!)" :
      "\(Date.gMonthNames[dc.month!]) \(dc.year!)"
  }
  
  /// German month and year in lowercase letters
  func gLowerMonthYear(tz: String?) -> String {
    return gMonthYear(tz: tz).lowercased()
  }
  
  var shorter:String{
    get{
      let dateFormatterGet = DateFormatter()
      dateFormatterGet.dateFormat = "d.M.yy"
      return dateFormatterGet.string(from: self)
    }
  }
  
  var dateAndTime:String{
    get{
      let dateFormatterGet = DateFormatter()
      dateFormatterGet.dateFormat = "dd.MM.yy HH:mm:ss"
      return dateFormatterGet.string(from: self)
    }
  }
  
  var yearMonthDay:String{
    get{
      let dateFormatterGet = DateFormatter()
      dateFormatterGet.dateFormat = "yyMMdd"
      return dateFormatterGet.string(from: self)
    }
  }
  
  var short:String{
    get{
      let dateFormatterGet = DateFormatter()
      dateFormatterGet.dateFormat = "d.M.yyyy"
      return dateFormatterGet.string(from: self)
    }
  }

  
  /// Helper to create date strings with given date format
  /// - Parameter dateFormat: date format to use
  /// - Returns: string from date with format
  func stringWith(dateFormat: String) -> String {
    let dateFormatterGet = DateFormatter()
    dateFormatterGet.dateFormat = dateFormat
    return dateFormatterGet.string(from: self)
  }
  
  var dbIssueRepresentation:String{ filename }

  var filename:String{ ISO8601 }
  
  var ISO8601:String{
    get{
      let dateFormatterGet = DateFormatter()
      dateFormatterGet.dateFormat = "yyyy-MM-dd"
      return dateFormatterGet.string(from: self)
    }
  }
  
  /// Creates a `Date` from a string in `"yyyy-MM-dd"` format using the `en_US_POSIX` locale.
  /// - Parameter dateString: The date string in `"yyyy-MM-dd"` format.
  /// - Returns: A `Date` if parsing succeeds, otherwise `nil`.
  static func from(yyyyMMdd dateString: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    ///important additionally to dateFormat, makes sure the date is parsed correctly regardless of the user's locale settings
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: dateString)
  }
  
  /// Parses a date from a "yyyy-MM-dd" string and optional hour/minute values.
  /// Defaults to 12:00 (noon) if time is not provided.
  ///
  /// - Parameters:
  ///   - dateString: The date string in "yyyy-MM-dd" format.
  ///   - hour: Optional hour (defaults to 12).
  ///   - minute: Optional minute (defaults to 0).
  ///   - timeZone: The timezone to interpret the date in (defaults to Europe/Berlin).
  /// - Returns: A `Date` if parsing succeeds, otherwise `nil`.
  static func from(
    yyyyMMdd dateString: String,
    hour: Int? = nil,
    minute: Int? = nil,
    timeZone: TimeZone? = TimeZone(identifier: "Europe/Berlin")
  ) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    
    guard let baseDate = formatter.date(from: dateString) else {
      return nil
    }
    
    var calendar = Calendar(identifier: .gregorian)
    if let tz = timeZone {
      calendar.timeZone = tz
    }
    
    var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
    components.hour = hour ?? 12
    components.minute = minute ?? 0
    components.second = 0
    
    return calendar.date(from: components)
  }
}
