//
//  LMdScheduleDateTests.swift
//  taz unittest
//
//  Created by Ringo Müller on 16.06.25.
//  Copyright © 2025 taz. All rights reserved.
//



import XCTest
import NorthLib
@testable import die_tageszeitung

final class LMdScheduleDateTests: XCTestCase {
    
  func testLMd() {
    var testCount = 0
    let pubDatesString: [String] = ["2025-06-13", "2025-05-09", "2025-04-11","2025-03-14","2025-02-14", "2025-01-10"].reversed()
    var lastPubDate = UsTime(iso: "2024-12-13").date
    for pubDateString in pubDatesString {
      let realNext = UsTime(iso: pubDateString).date.addingTimeInterval(-60*60*24)
      for i in -10..<100 {
        let now = lastPubDate.addingTimeInterval(TimeInterval(i) * 60 * 60 * 12)
        let next = PublicationSchedule.lmd.nextScheduledCheck(lastIssueDate: lastPubDate, now: now)
        
        let compareBase = now > realNext ? now : realNext
        XCTAssertEqual(UsTime(next).isoDate(), compareBase.isoDate(), "Assertion Failure!\nFor now: \(now.dateAndTime) & lastIssue: \(lastPubDate.dateAndTime) & real next: \(realNext.dateAndTime)\nExpected: \(next.dateAndTime) matches: \(compareBase.dateAndTime)")
        testCount += 1
        if i == -10 || i == 0 || i == 99 {
          print("i: \(i) last Issue: \(lastPubDate.short) now: \(now.dateAndTime) next: \(next.dateAndTime) matches: \(pubDateString)")
        }
      }
      lastPubDate = realNext.addingTimeInterval(-60*60*24)
    }
    print("executed \(testCount) tests")
    /*
     Output is correct:
     i: -10 last Issue: 7.5.2025 now: 02.05.25 12:00:00 next: 12.06.25 19:00:00 matches: 2025-06-13
     >> issue appeared multiple days earlier ...no problem correct next check date found for next issue date 13.6.
     i: 0 last Issue: 7.5.2025 now: 07.05.25 12:00:00 next: 12.06.25 19:00:00 matches: 2025-06-13
     >>...same
     i: 99 last Issue: 7.5.2025 now: 26.06.25 00:00:00 next: 26.06.25 07:00:00 matches: 2025-06-13
     >>in case of a missing issue the next valid time is returned
     */
  }
}
