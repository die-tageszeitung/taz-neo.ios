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
  
  /// Previously marked with #warning("IMPORTANT TO USE!")
  /// Intended to remove the "Offline Listen Not Possible" notification.
  /// This function was never actually called anywhere in the app.
  /// Its purpose would be to remove the offline notification from NotificationCenter
  /// due no negative User Feedback this seams not to be required
  /// iOS automatically replaces notifications with the same identifier, so duplicates are generally avoided.
  /// Could be called, for example, in FeederContext's notifyNetStatus(isConnected:) when network reconnects.
  /// or on App-Start online....
//  static func removeOfflineListenNotPossibleNotifications(){
//    UNUserNotificationCenter.current()
//      .removePendingNotificationRequests(withIdentifiers:[tazAppOfflineListenNotPossibleIdentifier])
//    UNUserNotificationCenter.current()
//      .removeDeliveredNotifications(withIdentifiers:[tazAppOfflineListenNotPossibleIdentifier])
//  }
}
