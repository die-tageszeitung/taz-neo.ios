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
  static var darkMode : Bool {
    get { return Defaults.singleton["colorMode"] == "dark" }
    set {
      if (Defaults.singleton["colorMode"] == "dark") == newValue { return }
      Defaults.singleton["colorMode"] = newValue ? "dark" : nil
      if #available(iOS 13.0, *) {
        UIApplication.shared.keyWindow?.overrideUserInterfaceStyle = newValue ? .dark : .light
      } else {
       
      }
       NorthLib.Notification.send(globalStylesChangedNotification)
//          UINavigationBar.appearance().barStyle = .blackOpaque
//      if #available(iOS 13.0, *) {
//        if let statusBarManager = UIApplication.shared.keyWindow?.windowScene?.statusBarManager {
//          statusBarManager.set = newValue ? UIStatusBarStyle.darkContent : UIStatusBarStyle.lightContent
//
//
//          /**
//
//           UIStatusBarStyleDefault                                  = 0, // Automatically chooses light or dark content based on the user interface style
//           UIStatusBarStyleLightContent     API_AVAILABLE(ios(7.0)) = 1, // Light content, for use on dark backgrounds
//           UIStatusBarStyleDarkContent     API_AVAILABLE(ios(13.0)) = 3, // Dark content, for use on light backgrounds
//
//           UIStatusBarStyleBlackTranslucent NS_ENUM_DEPRECATED_IOS(2_0, 7_0, "Use UIStatusBarStyleLightContent") = 1,
//           UIStatusBarStyleBlackOpaque
//
//           */
//        }
//      } else {
//        // Fallback on earlier versions
//      }
//
//      guard let statusBarView = UIApplication.shared.value(forKeyPath: "statusBarWindow.statusBar") as? UIView else {
//              return
//          }
//      statusBarView.backgroundColor = UIColor.red
//
//      Thread 1: Exception: "App called -statusBar or -statusBarWindow on UIApplication: this code must be changed as there's no longer a status bar or status bar window. Use the statusBarManager object on the window scene instead."
      
    }
  }
}
