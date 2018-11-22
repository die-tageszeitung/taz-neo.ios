//
//  Time.swift
//
//  Created by Norbert Thies on 06.07.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import Foundation

public extension Date {
  
  /// Returns components relative to current calendar
  public func components() -> DateComponents {
    let cset = Set<Calendar.Component>([.year, .month, .day, .hour, .minute, .second])
    return Calendar.current.dateComponents(cset, from: self)
  }
  
} // extension Date

/// Time as seconds and microseconds since 1970-01-01 00:00:00 UTC
public struct UsTime: Comparable, CustomStringConvertible {
  
  private var tv = timeval()
  public var sec: Int64 { return Int64(tv.tv_sec) }
  public var usec: Int64 { return Int64(tv.tv_usec) }
  public var timeInterval: TimeInterval {
    return TimeInterval(sec) + (TimeInterval(usec) / 1000000)
  }
  public var date: Date { return Date( timeIntervalSince1970: timeInterval ) }
  public var description: String { return toString() }
  
  /// Returns the current time
  public static func now() -> UsTime {
    var ut = UsTime()
    gettimeofday(&(ut.tv), nil)
    return ut
  }
  
  /// Init from optional Date
  public init( _ date: Date? = nil ) {
    if let d = date {
      var nsec = d.timeIntervalSince1970
      tv.tv_sec = type(of: tv.tv_sec).init( nsec.rounded(.down) )
      nsec = (nsec - TimeInterval(tv.tv_sec)) * 1000000
      tv.tv_usec = type(of: tv.tv_usec).init( nsec.rounded() )
    }
  }
  
  /// Converts UsTime to "YYYY-MM-DD hh:mm:ss.uuuuuu"
  public func toString() -> String {
    let dc = date.components()
    return String( format: "%04d:%02d:%02d %02d:%02d:%02d.%06d", dc.year!, dc.month!,
                   dc.day!, dc.hour!, dc.minute!, dc.second!, usec )
  }
  
  static public func <(lhs: UsTime, rhs: UsTime) -> Bool {
    if lhs.sec == rhs.sec { return lhs.usec < rhs.usec }
    else { return lhs.sec < rhs.sec }
  }
  
  static public func ==(lhs: UsTime, rhs: UsTime) -> Bool {
    return (lhs.sec == rhs.sec) && (lhs.usec == rhs.usec)
  }
  
}  // struct UsTime
