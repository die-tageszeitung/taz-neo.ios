//
//  taz_unittest.swift
//  taz unittest
//
//  Created by Ringo (taz) on 12.06.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import XCTest
@testable import die_tageszeitung

final class taz_unittest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
      let service = BackgroundDownloadService.shared
      
      var checkCallDates: [Date] = []
      
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 0, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 1, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 2, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 3, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 5, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 7, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 9, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 11, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 12, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 14, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 15, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 17, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 18, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 19, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 19, minute: 10))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 19, minute: 20))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 19, minute: 30))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 19, minute: 40))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 19, minute: 50))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 20, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 21, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 22, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 23, minute: 0))
      checkCallDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 24, minute: 59))
      
      var lastIssueDates: [Date] = []
      
      lastIssueDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-13", hour: 12, minute: 0))
      lastIssueDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-12", hour: 12, minute: 0))
      lastIssueDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-11", hour: 12, minute: 0))
      lastIssueDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-10", hour: 12, minute: 0))
      lastIssueDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-09", hour: 12, minute: 0))
      lastIssueDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-08", hour: 12, minute: 0))
      lastIssueDates.appendIfPresent(Date.from(yyyyMMdd: "2025-06-01", hour: 12, minute: 0))
      lastIssueDates.appendIfPresent(Date.from(yyyyMMdd: "2025-05-01", hour: 12, minute: 0))

      for date in checkCallDates {
        let checkDate = service.testNextEligibleCheckDate(tz: TimeZone.current,
                                                      type: .taz,
                                                          lastFullyDownloadedIssueDate: nil,
                                                      now: date)
        print("### for no Download and current time: \(date.dateAndTime) next checkDate is: \(checkDate.dateAndTime)")
        
        for lastDate in lastIssueDates {
          let nextCheckDate = service.testNextEligibleCheckDate(tz: TimeZone.current,
                                                        type: .taz,
                                                            lastFullyDownloadedIssueDate: lastDate,
                                                        now: date)
          print("### for last issue \(lastDate.short) and current time: \(date.dateAndTime) next checkDate is: \(nextCheckDate.dateAndTime)")
        }
      }
      
      
      XCTAssertNotNil(checkCallDates, "date should not be nil")
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
