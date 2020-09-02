//
//  Helper.swift
//  taz.neo
//
//  Created by Ringo on 01.09.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

class Bla:UIView{
  
  override init(frame: CGRect) {
    print("blub")
    super.init(frame: frame)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension Defaults{
  static var darkMode : Bool {
    get { return Defaults.singleton["colorMode"] == "dark" }
    set {
      if (Defaults.singleton["colorMode"] == "dark") == newValue { return }
      Defaults.singleton["colorMode"] = newValue ? "dark" : nil
      if #available(iOS 13.0, *) {
        UIApplication.shared.keyWindow?.overrideUserInterfaceStyle = newValue ? .dark : .light
      } else {
           Notif.send(Const.Notifications.colorModeChanged)
//        Notification.send(Const.Notifications.colorModeChanged)
      }
    }
  }
}
