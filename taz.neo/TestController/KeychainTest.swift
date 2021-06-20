//
//  KeychainTest.swift
//  taz.neo
//
//  Created by Norbert Thies on 19.06.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

// A view controller to test Colors
class KeychainTest: UIViewController {
  
  @Key("testBool")
  var testBool: Bool
  @Key("testString")
  var testString: String
  @Key("testCGFloat")
  var testCGFloat: CGFloat
  @Key("testDouble")
  var testDouble: Double
  @Key("testInt")
  var testInt: Int
  
  func AssertEqual<T: Equatable>(_ arg1: T, _ arg2: T, file: String = #file,
                                  line: Int = #line) {
    guard arg1 == arg2 else {
      print("Failure (\(line)@\(file):\n  \(arg1) != \(arg2)")
      return
    }
  }
  
  func AssertEqual<T: Equatable>(_ arg1: T?, _ arg2: T, file: String = #file,
                                  line: Int = #line) {
    guard arg1 == arg2 else {
      print("Failure (\(line)@\(file):\n  \(String(describing: arg1)) != \(arg2)")
      return
    }
  }
  
  func AssertNil<T>(_ arg: T?, file: String = #file,
                     line: Int = #line) {
    guard arg == nil else {
      print("Failure (\(line)@\(file):\n  \(String(describing: arg)) != nil")
      return
    }
  }
  
  private var keys = ["geheim", "testBool", "testString", "testInt",
                      "testCGFloat", "testDouble", "id", "password"]
  
  func clear() {
    for k in keys { Keychain.singleton.delete(key: k) }
  }
  
  func checkPrevious() {
    let kc = Keychain.singleton
    print("Previous values " +
          "(access group: \(String(describing: Keychain.accessGroup)))")
    for key in keys {
      if let val = kc[key] { print("  \(key): \(val)") }
      else { print("  key '\(key)' is undefined") }
    }
  }

  func testKeychain() {
    print("Checking keychain")
    let kc = Keychain.singleton
    kc["geheim"] = "huhu"
    AssertEqual(kc["geheim"], "huhu")
    kc["geheim"] = nil
    AssertNil(kc["geheim"])
    kc["geheim"] = "was weiß ich"
  }
  
  func testWrappers() {
    print("Checking wrapper")
    testBool = false
    $testBool.onChange { val in print("  testBool changed to: \(val)") }
    testBool = true
    AssertEqual(testBool, true)
    testBool = true
    testBool = false
    testString = ""
    $testString.onChange { val in print("  testString changed to: \(val)") }
    testString = "test"
    AssertEqual(testString, "test")
    testInt = 0
    $testInt.onChange { val in print("  testInt changed to: \(val)") }
    testInt = 14
    AssertEqual(testInt, 14)
    testCGFloat = 0
    $testCGFloat.onChange { val in print("  testCGFloat changed to: \(val)") }
    testCGFloat = 15
    AssertEqual(testCGFloat, 15)
    testDouble = 0
    $testDouble.onChange { val in print("  testDouble changed to: \(val)") }
    testDouble = 16
    AssertEqual(testDouble, 16)
  }

  override func viewDidLoad() {
    //Keychain.accessGroup = "geheim"
    checkPrevious()
    //testKeychain()
    //testWrappers()
    //clear()
  }

} // ColorTests

