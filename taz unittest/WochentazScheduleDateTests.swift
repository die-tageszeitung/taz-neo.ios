//
//  WochentazScheduleDateTests.swift
//  taz unittest
//
//  Created by Ringo Müller on 16.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import XCTest
import NorthLib
@testable import die_tageszeitung

final class WochentazScheduleDateTests: XCTestCase {
  
  func test(lastPub:String, now: String) -> String {
    let last =  UsTime(iso: lastPub).date
    let nowDate = UsTime(iso: now).date
//    print("test f last: \(lastPub) == \(last.dateAndTime) && now: \(now) == \(nowDate.dateAndTime)")
    return UsTime(PublicationSchedule.wochentaz.nextScheduledCheck(lastIssueDate: last, now: nowDate)).toString()
  }
    
  func testSaturday1() {
    ///last Publication Saturday 1.11.
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-01 07:00:00"), "2025-11-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-01 19:00:00"), "2025-11-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-01 20:00:00"), "2025-11-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-02 19:10:00"), "2025-11-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-03 20:00:00"), "2025-11-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-04 23:00:00"), "2025-11-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-05 06:00:00"), "2025-11-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-06 07:00:00"), "2025-11-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-07 07:00:00"), "2025-11-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-07 19:00:00"), "2025-11-07 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-07 20:00:00"), "2025-11-07 23:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-07 23:00:00"), "2025-11-08 07:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-08 07:00:00"), "2025-11-08 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-08 12:00:00"), "2025-11-08 19:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-08 19:00:00"), "2025-11-08 20:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-08 23:00:00"), "2025-11-09 07:00:00")
    XCTAssertEqual(test(lastPub: "2025-11-01 12:00:00", now: "2025-11-09 07:00:00"), "2025-11-09 19:00:00")
  }
  
  func testSaturdayHolyday() {
    ///last Publication Friday 31.12.21 next => 8.1.22 released 7.1.22 19:00
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-01 07:00:00"), "2022-01-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-02 19:00:00"), "2022-01-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-03 20:00:00"), "2022-01-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-04 19:10:00"), "2022-01-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-05 20:00:00"), "2022-01-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-06 23:00:00"), "2022-01-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-07 06:00:00"), "2022-01-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-07 07:00:00"), "2022-01-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-07 07:00:00"), "2022-01-07 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-07 19:00:00"), "2022-01-07 20:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-07 20:00:00"), "2022-01-07 23:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-07 23:00:00"), "2022-01-08 07:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-08 07:00:00"), "2022-01-08 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-08 12:00:00"), "2022-01-08 19:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-08 19:00:00"), "2022-01-08 20:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-09 23:00:00"), "2022-01-10 07:00:00")
    XCTAssertEqual(test(lastPub: "2021-12-31 12:00:00", now: "2022-01-10 07:00:00"), "2022-01-10 19:00:00")
  }
}
