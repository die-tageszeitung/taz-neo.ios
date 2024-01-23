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
  
  var short:String{
    get{
      let dateFormatterGet = DateFormatter()
      dateFormatterGet.dateFormat = "d.M.yyyy"
      return dateFormatterGet.string(from: self)
    }
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
}
