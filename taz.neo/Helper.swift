//
//  Helper.swift
//  taz.neo
//
//  Created by Ringo on 01.09.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib


extension Defaults{
  
  static var autoloadInWLAN : Bool = false
  static var autoloadNewIssues : Bool = true
  
  private static var tDarkMode:Bool?
  static var darkMode : Bool {
    get {
      if let tmp = tDarkMode {
        print("return tmddarkmodevalue: \(tmp)")
        return tmp }
      return Defaults.singleton["colorMode"] == "dark" }
    set {
      ///only update if changed
      if darkMode == newValue || tDarkMode == newValue { return }
      print("set tmddarkmodevalue: \(newValue)")
      tDarkMode = newValue
      Defaults.singleton["colorMode"] = newValue ? "dark" : nil
//      Defaults.singleton.
      if #available(iOS 13.0, *) {
        //Use Trait Collection for Change
        UIApplication.shared.keyWindow?.overrideUserInterfaceStyle = newValue ? .dark : .light
      }
      /// Some (Article/HTML/CSS) iOS 13+ need also this Info
      NorthLib.Notification.send(globalStylesChangedNotification)
    }
  }
}
