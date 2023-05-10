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
    
  var showingNotificationsPopup = false
  
  
  
  /// remember async called system setting
  var systemNotificationsEnabled: Bool?
  
  /// Check if in app notifications settings are applyable for current setting in ios system settings
  /// - Parameter finished: callback after async check is finished
  func checkNotificationStatus(finished: (()->())? = nil){
    let notifCenter = UNUserNotificationCenter.current()
    notifCenter.getNotificationSettings(
      completionHandler: { [weak self] (settings) in
        guard let self = self else { return }
        self.systemNotificationsEnabled
        = settings.authorizationStatus == .provisional
        || settings.authorizationStatus == .authorized
        && settings.notificationCenterSetting == .enabled
        || settings.lockScreenSetting == .enabled
        finished?()
      })
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
}

extension NotificationBusiness {
  func showPopupIfNeeded(newIssueAvailableSince: TimeInterval){
    guard !showingNotificationsPopup else { return }
    
    if self.systemNotificationsEnabled == nil {
      self.checkNotificationStatus{
        onMain {[weak self] in
          self?.showPopupIfNeeded(newIssueAvailableSince: newIssueAvailableSince)
        }
      }
      return;
    }
    
    if self.systemNotificationsEnabled == true {
      return;
    }
    
    guard TazAppEnvironment.sharedInstance.rootViewController is MainTabVC else {
      return
    }
    
    guard Defaults.notificationsActivationPopupRejectedDate == nil else {
      return
    }
    
    if let skippedDate = Defaults.notificationsActivationPopupRejectedTemporaryDate,
       abs(skippedDate.timeIntervalSinceNow) < 3600*24*10 {
      return
    }
    
    showingNotificationsPopup = true
    
    let toast = NotificationsView(newIssueAvailableSince: newIssueAvailableSince)
    toast.onDismiss {[weak self] in
      self?.showingNotificationsPopup = false
    }
    toast.show()
  }
}
