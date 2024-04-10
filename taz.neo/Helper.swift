//
//  Helper.swift
//  taz.neo
//
//  Created by Ringo on 01.09.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib


extension Defaults{
  
  private static var tDarkMode:Bool?
  
  static var darkMode : Bool {
    get {
      if let tmp = tDarkMode {
        return tmp }
      return Defaults.singleton["colorMode"] == "dark" }
    set {
      ///only update if changed
      if darkMode == newValue || tDarkMode == newValue { return }
      tDarkMode = newValue
      Defaults.singleton["colorMode"] = newValue ? "dark" : nil
      //      Defaults.singleton.
      //Use Trait Collection for Change
      UIWindow.keyWindow?.overrideUserInterfaceStyle = newValue ? .dark : .light
      /// Some (Article/HTML/CSS) iOS 13+ need also this Info
      Notification.send(globalStylesChangedNotification)
    }
  }
  
  private static var tmpLastKnownPushToken:String?
  
  static var lastKnownPushToken : String? {
    get {
      return tmpLastKnownPushToken ?? Defaults.singleton["lastKnownPushToken"] }
    set {
      guard newValue != nil else { Log.log("not delete lastKnownPushToken" ); return }
      Defaults.singleton["lastKnownPushToken"] = newValue
      tmpLastKnownPushToken = newValue
    }
  }
  
  struct articleTextSize {
    @Default("articleTextSize")
    static var articleTextSize: Int {
      didSet {
        print("articleTextSize changed to: \(articleTextSize)")
        calculateMinColumnWidth()
      }
    }
    
    static let lbl = UILabel()
    
    static func calculateMinColumnWidth() {
      print("calculateMinColumnWidth")
      /// 49 Char Blindtext to determine the column width minimal complexity
      onMain {
        lbl.numberOfLines = 0
        lbl.text = "die Tageszeitung, Politik, Zukunft, Gesellschaft"
        lbl.doLayout()
        print("label width for \(lbl.text?.count ?? 0) is: \(lbl.width)")
      }
    }
    
    @discardableResult
    static func increase() -> Int { if articleTextSize < 200 { articleTextSize += 10 }
      return articleTextSize
    }
    
    @discardableResult
    static func decrease() -> Int { if articleTextSize > 30 { articleTextSize -= 10 }
      return articleTextSize
    }
    
    @discardableResult
    static func set(_ newValue: Int? = 100) -> Int {
      if let val = newValue, 30 < val, val < 200 { articleTextSize = val }
      return articleTextSize
    }
  }
  
  static var usageTrackingAllowed : Bool? {
    get {
      return Defaults.singleton["usageTrackingAllowed"]?.bool
    }
    set {
      Defaults.singleton["usageTrackingAllowed"] = newValue?.stringRepresentation
    }
  }
}

fileprivate extension Bool {
  var stringRepresentation: String {
    return self == true ? "true" : "false"
  }
}

class nonsens {
  let sidePadding = 34.0
  //Problem at 150% TextSize rowCount == 2 => SOLVED NOW
  //MainWindowWidth: 1194.0 colWidth: 580.0 colGAp: 15.0 rowCount:2.0 rowCountCalc: 2.0586206896551724
  func colWidth1(maxRowCount: CGFloat) -> CGFloat {
    if maxRowCount < 3.0 {
      return (UIWindow.size.width - sidePadding) * 0.5  //2 Rows
    }
    if maxRowCount < 4.0 {
      return (UIWindow.size.width - sidePadding) * 0.33  //3 Rows
    }
    if maxRowCount < 5.0 {
      return (UIWindow.size.width - sidePadding) * 0.25 //4 Rows
    }
    return (UIWindow.size.width - sidePadding) * 0.2 // 5 Rows
  }
}
