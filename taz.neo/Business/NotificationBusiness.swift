//
//  NotificationBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 09.02.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// **Motivation**
/// - this is a Helper for multiple (currently 2) parts of the app
///   1. Settings, on Change TextNotifications and Autodownload Toggle
///   2. on App Start Check if System Settings still Match with In App User Settings
/// - not using NorthLib's PushNotification due it handle(remote) PushNotifications
public final class NotificationBusiness: DoesLog {
  private var didShowNotificationsDisabledWarning = false
  public static let sharedInstance = NotificationBusiness()
  private init(){}
  
  @Default("isTextNotification")
  var isTextNotification: Bool
  
//  @Default("autoloadNewIssues")
//  var autoloadNewIssues: Bool
  
  /// helper
  var notificationsRequired: Bool {
    get {
      return isTextNotification // || autoloadNewIssues
    }
  }
  
  /// remember async called system setting
  var systemNotificationsEnabled: Bool = false {
    didSet {
      if systemNotificationsEnabled == false
         && notificationsRequired == true {
        showNotificationsDisabledWarning()
      }
    }
  }
  
  /// Check if in app notifications settings are applyable for current setting in ios system settings
  /// - Parameter finished: callback after async check is finished
  func checkNotificationStatusIfNeeded(finished: (()->())? = nil){
    if !isTextNotification /*&& !autoloadNewIssues*/ { finished?(); return }
    let notifCenter = UNUserNotificationCenter.current()
    notifCenter.getNotificationSettings(
      completionHandler: { [weak self] (settings) in
        guard let self = self else { return }
        self.systemNotificationsEnabled
                   = settings.authorizationStatus == .authorized
                   && settings.notificationCenterSetting == .enabled
                   && settings.lockScreenSetting == .enabled
        finished?()
      })
  }
  
  /// Helper to show popup, to open system settings
  func showNotificationsDisabledWarning(){
    if didShowNotificationsDisabledWarning { return }
    didShowNotificationsDisabledWarning = true
    ///Optional subtext:  "Bitte aktivieren Sie Mitteilungen in den Systemeinstellungen.\n\nMitteilungen werden benötigt um den automatischen Download von Ausgaben zu starten.\nSie können Textnachrichten deaktivieren, falls Sie den automatischen Download von Ausgaben möchten aber nicht die Benachrichtigung außerhalb der App erlauben möchten. "
    Alert.confirm(title: "Bitte erlauben Sie Mitteilungen!",
                  message: "Mitteilungen sind in den Systemeinstellungen deaktiviert.",
                  okText: "Einstellungen öffnen") {  [weak self] accept in
      if accept { self?.openAppInSystemSettings() }
      self?.didShowNotificationsDisabledWarning = false
    }
  }
  
  /// Helper to open system settings
  func openAppInSystemSettings(){
    if let url = URL(string: UIApplication.openSettingsURLString) {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
      else { handleFailOpenAppInSystemSettings() }
    }
    else { handleFailOpenAppInSystemSettings() }
  }
  
  /// Helper if system settings open failed
  func handleFailOpenAppInSystemSettings(){
    Alert.confirm(title: "Öffnen der Systemeinstellungen fehlgeschlagen.", message: "Bitte öffnen Sie die Systemeinstellungen und suchen nach \"\(App.name)\"", okText: "Wiederholen", cancelText: "Abbrechen", closure: { [weak self] _ in
      self?.openAppInSystemSettings()
    })
  }
  
  func updateTextNotificationSettings(){
    guard let feederContext = TazAppEnvironment.sharedInstance.feederContext else {
      debug("Fail to update TextNotificationSettings to: \(isTextNotification)")
      return
    }
    feederContext.gqlFeeder.notification(pushToken: feederContext.pushToken,
                                         oldToken:  Defaults.lastKnownPushToken ?? feederContext.pushToken,
                                         isTextNotification: isTextNotification) {[weak self] res in
      if let err = res.error() {
        self?.debug("Update pushToken and Notification Settings failed \(err)")
      }
      else {
        self?.debug("Updated pushToken and Notification Settings")
        Defaults.lastKnownPushToken = feederContext.pushToken
      }
    }
  }
}
