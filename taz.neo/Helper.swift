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
  
  static var darkMode : Bool {
    get { return Defaults.singleton["colorMode"] == "dark" }
    set {
      ///only update if changed
      if (Defaults.singleton["colorMode"] == "dark") == newValue { return }
      Defaults.singleton["colorMode"] = newValue ? "dark" : nil
      if #available(iOS 13.0, *) {
        //Use Trait Collection for Change
        UIApplication.shared.keyWindow?.overrideUserInterfaceStyle = newValue ? .dark : .light
      }
      /// Some (Article/HTML/CSS) iOS 13+ need also this Info
      NorthLib.Notification.send(globalStylesChangedNotification)
    }
  }
}
