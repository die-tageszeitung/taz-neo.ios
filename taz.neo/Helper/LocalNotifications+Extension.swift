//
//  LocalNotifications+Extension.swift
//  taz.neo
//
//  Created by Ringo Müller on 07.08.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import UIKit

extension LocalNotifications {
  static let tazAppOfflineListenNotPossibleIdentifier = "tazAppOfflineListenNotPossible"
  static func notifyOfflineListenNotPossible(){
    Self.notify(title: "Sie müssen online sein, um die Vorlesefunktion zu nutzen!",
                              message: "Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.",
                              notificationIdentifier: tazAppOfflineListenNotPossibleIdentifier)
  }
  #warning("IMPORTANT TO USE!")
  static func removeOfflineListenNotPossibleNotifications(){
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers:[tazAppOfflineListenNotPossibleIdentifier])
    UNUserNotificationCenter.current()
      .removeDeliveredNotifications(withIdentifiers:[tazAppOfflineListenNotPossibleIdentifier])
  }
}
