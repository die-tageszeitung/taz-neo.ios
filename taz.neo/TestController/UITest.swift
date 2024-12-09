//
//  UITest.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import XCTest

final class UITest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()
      // wait x*60 seconds to manually controll the app
      let waitTime: TimeInterval = 10*60 // x minutes x 60 seconds
      print("Test is started and maused for \(waitTime/60) minutes. You can controll the app manually to gather code coverage.")
      
      // XCTWaiter wird verwendet, um asynchron auf Zeitablauf zu warten
      let expectation = XCTestExpectation(description: "waiting for userinteraction")
      _ = XCTWaiter.wait(for: [expectation], timeout: waitTime)
      
      // Füge am Ende des Tests eine Dummy-Assertion hinzu, um sicherzustellen, dass der Test erfolgreich ist
      XCTAssertTrue(true, "Test done.")
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
