//
//  TazScheduledDateTests.swift
//  taz unittest
//
//  Created by Ringo Müller on 16.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import XCTest
import NorthLib
@testable import die_tageszeitung

final class TazScheduledDateTests: XCTestCase {
      
  func test(lastPub:String, now: String) -> String {
    let last =  UsTime(iso: lastPub).date
    let nowDate = UsTime(iso: now).date
//    print("test f last: \(lastPub) == \(last.dateAndTime) && now: \(now) == \(nowDate.dateAndTime)")
    return UsTime(PublicationSchedule.taz.nextScheduledCheck(lastIssueDate: last, now: nowDate)).toString()
  }
    
    func testMonday() {
      ///last Publication Monday 1.9.
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-01 07:00:00"), "2025-09-01 19:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-01 12:00:00"), "2025-09-01 19:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-01 19:00:00"), "2025-09-01 20:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-01 19:10:00"), "2025-09-01 20:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-01 20:00:00"), "2025-09-01 23:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-01 23:00:00"), "2025-09-02 07:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-02 06:00:00"), "2025-09-02 07:00:00")
      ///maybe the todays issue did not appear due holiday
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-02 07:00:00"), "2025-09-02 19:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-02 19:00:00"), "2025-09-02 20:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-02 20:00:00"), "2025-09-02 23:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-02 23:00:00"), "2025-09-03 07:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-03 07:00:00"), "2025-09-03 19:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-03 19:00:00"), "2025-09-03 20:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-04 19:00:00"), "2025-09-04 20:00:00")
      XCTAssertEqual(test(lastPub: "2025-09-01 12:00:00", now: "2025-09-05 19:00:00"), "2025-09-05 20:00:00")
    }
  
  func testThuesday() {
    ///last Publication Thuesday 2.9.
    XCTAssertEqual(test(lastPub: "2025-09-02 12:00:00", now: "2025-09-02 07:00:00"), "2025-09-02 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-02 12:00:00", now: "2025-09-02 12:00:00"), "2025-09-02 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-02 12:00:00", now: "2025-09-02 19:00:00"), "2025-09-02 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-02 12:00:00", now: "2025-09-02 19:10:00"), "2025-09-02 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-02 12:00:00", now: "2025-09-02 20:00:00"), "2025-09-02 23:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-02 12:00:00", now: "2025-09-02 23:00:00"), "2025-09-03 07:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-02 12:00:00", now: "2025-09-03 06:00:00"), "2025-09-03 07:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-02 12:00:00", now: "2025-09-03 07:00:00"), "2025-09-03 19:00:00")///maybe the todays issue did not appear due holiday
  }
  
  func testFriday() {
    ///last Publication Friday 5.9.
    XCTAssertEqual(test(lastPub: "2025-09-05 12:00:00", now: "2025-09-05 07:00:00"), "2025-09-05 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-05 12:00:00", now: "2025-09-05 12:00:00"), "2025-09-05 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-05 12:00:00", now: "2025-09-05 19:00:00"), "2025-09-05 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-05 12:00:00", now: "2025-09-05 19:10:00"), "2025-09-05 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-05 12:00:00", now: "2025-09-05 20:00:00"), "2025-09-05 23:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-05 12:00:00", now: "2025-09-05 23:00:00"), "2025-09-06 07:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-05 12:00:00", now: "2025-09-06 06:00:00"), "2025-09-06 07:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-05 12:00:00", now: "2025-09-06 07:00:00"), "2025-09-06 19:00:00")///maybe the todays issue did not appear due holiday
  }
  
  func testSaturday() {
    ///last Publication Saturday 6.9.
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-06 07:00:00"), "2025-09-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-06 12:00:00"), "2025-09-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-06 19:00:00"), "2025-09-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-06 19:10:00"), "2025-09-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-06 20:00:00"), "2025-09-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-06 23:00:00"), "2025-09-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-07 06:00:00"), "2025-09-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-07 07:00:00"), "2025-09-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-07 19:00:00"), "2025-09-07 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-07 20:00:00"), "2025-09-07 23:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-07 23:00:00"), "2025-09-08 07:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-08 07:00:00"), "2025-09-08 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-09 07:00:00"), "2025-09-09 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-06 12:00:00", now: "2025-09-09 19:00:00"), "2025-09-09 20:00:00")
  }
  
  func testSunday() {
    ///last Publication Sunday 7.9. => did not exist!! but expect today evening or next day
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-07 07:00:00"), "2025-09-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-07 19:00:00"), "2025-09-07 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-08 07:00:00"), "2025-09-08 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-08 12:00:00"), "2025-09-08 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-08 19:00:00"), "2025-09-08 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-08 19:10:00"), "2025-09-08 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-08 20:00:00"), "2025-09-08 23:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-08 23:00:00"), "2025-09-09 07:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-09 06:00:00"), "2025-09-09 07:00:00")
    XCTAssertEqual(test(lastPub: "2025-09-07 12:00:00", now: "2025-09-09 07:00:00"), "2025-09-09 19:00:00")///maybe the todays issue did not appear due holiday
  }
}
