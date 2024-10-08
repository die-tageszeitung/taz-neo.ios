//
//  NotificationBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 09.02.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// **NotificationBusiness**
/// A singleton class that manages notification settings and behaviors within the app.
///
/// **Motivation**
/// - This helper is designed for multiple parts of the application:
///   1. **Settings:** Handles changes in text notifications and auto-download toggles.
///   2. **App Startup:** Checks if system settings still match with in-app user settings.
///
/// **Note:** This implementation does not utilize NorthLib's PushNotification as it handles remote push notifications.
public final class NotificationBusiness: DoesLog {
  /// Shared instance of `NotificationBusiness`
  public static let sharedInstance = NotificationBusiness()
  
  // Private initializer to enforce singleton pattern
  private init() {}
  
  // Default user preferences
  @Default("isTextNotification")
  var isTextNotification: Bool
  
  // Check if notifications are required based on user preferences
  /// Indicates whether notifications are required based on user preferences.
  var notificationsRequired: Bool {
    get {
      return isTextNotification // || autoloadNewIssues
    }
  }
  
  /// Indicates if a notifications popup is currently displayed.
  var showingNotificationsPopup = false
  
  // Store the last accessed authorization status for notifications
  var systemNotificationsStatus: UNAuthorizationStatus?
  var alertStyle: UNAlertStyle?
  var notificationCenterSetting: UNNotificationSetting?
  var lockScreenSetting: UNNotificationSetting?
  var criticalAlertSetting: UNNotificationSetting?
  var badgeSetting: UNNotificationSetting?
  var soundSetting: UNNotificationSetting?
  var alertSetting: UNNotificationSetting?
  
  /// Asynchronously checks the notification settings against system settings.
  /// - Parameter finished: A closure called after the check is complete.
  func checkNotificationStatus(finished: (()->())? = nil) {
    let notifCenter = UNUserNotificationCenter.current()
    notifCenter.getNotificationSettings { [weak self] (settings) in
      guard let self = self else { return }
      
      self.systemNotificationsStatus = settings.authorizationStatus
      
      // If the authorization status is not determined, it may allow silent notifications.
      if settings.authorizationStatus == .notDetermined {
        self.updateSettingsDetailText()
        finished?()
        return
      }
      
      // Store notification settings
      self.alertStyle = settings.alertStyle
      self.notificationCenterSetting = settings.notificationCenterSetting
      self.lockScreenSetting = settings.lockScreenSetting
      self.criticalAlertSetting = settings.criticalAlertSetting
      self.badgeSetting = settings.badgeSetting
      self.soundSetting = settings.soundSetting
      self.alertSetting = settings.alertSetting
      
      self.updateSettingsDetailText()
      finished?()
    }
  }
  
  /// Opens the app's settings in the system settings.
  func openAppInSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      } else {
        handleFailOpenAppInSystemSettings()
      }
    } else {
      handleFailOpenAppInSystemSettings()
    }
  }
  
  // Flags and attributes for settings detail text
  var settingsDetailTextAlert: Bool = true
  var settingsLink: Bool = true
  var settingsDetailText: NSMutableAttributedString = NSMutableAttributedString(string: "")
  
  /// Updates the detailed text displayed in the settings.
  func updateSettingsDetailText() {
    settingsDetailText = NSMutableAttributedString(string: "")
    
    if isTextNotification == false {
      settingsDetailText = NSMutableAttributedString(string: "\nErhalten Sie täglich Push-Benachrichtigungen zur aktuellen Ausgabe und bleiben Sie stets auf dem Laufenden. Detaillierte Einstellungen finden Sie in den Systemeinstellungen unter „Mitteilungen“.")
      settingsDetailText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 154, length: 20))
      settingsDetailTextAlert = true
      settingsLink = true
      return
    }
    
    // Collects issues with current notification settings
    var items: [String] = []
    var bannerAdditionalText: String = ""
    
    if soundSetting != .enabled { items.append("Töne") }
    if lockScreenSetting != .enabled { items.append("Mitteilungen auf dem Sperrbildschirm") }
    if notificationCenterSetting != .enabled { items.append("Mitteilungen in der Mitteilungszentrale") }
    if alertStyle == UNAlertStyle.none {
      items.append("Banner")
      bannerAdditionalText = " Mitteilungs-Banner sind kurze Benachrichtigungen, die oben auf dem Bildschirm erscheinen, wenn das Gerät entsperrt ist."
    }
    
    if items.isEmpty { // no user interaction/Change required
      settingsDetailTextAlert = false
      settingsLink = false
      settingsDetailText = NSMutableAttributedString(string: "\nBleiben Sie immer informiert mit einem täglichen Push-Hinweis, auf die aktuelle Ausgabe.")
      return
    }
    
    settingsLink = true
    settingsDetailTextAlert = items.count > 1 // More than one issue
    let itemsText = items.joined(separator: ", ", lastSeparator: " und ")
    
    settingsDetailText = NSMutableAttributedString(string: "\nDie Mitteilungseinstellungen für die \(App.shortName) App lassen derzeit keine \(itemsText) zu.\(bannerAdditionalText)\nTippen Sie hier, um zu den Systemeinstellungen für die taz App zu gelangen und diese anzupassen.")
    settingsDetailText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 5, length: 25))
  }
  
  /// Handles the failure of opening the system settings.
  func handleFailOpenAppInSystemSettings() {
    Alert.confirm(title: "Öffnen der Systemeinstellungen fehlgeschlagen.", message: "Bitte öffnen Sie die Systemeinstellungen und suchen nach \"\(App.name)\"", okText: "Wiederholen", cancelText: "Abbrechen") { [weak self] _ in
      self?.openAppInSystemSettings()
    }
  }
}

// MARK: - Popup Notification Management
extension NotificationBusiness {
  
  /// Shows a notification popup if conditions are met.
  /// - Parameter newIssueAvailableSince: A timestamp indicating when a new issue became available.
  func showPopupIfNeeded(newIssueAvailableSince: TimeInterval) {
    guard !showingNotificationsPopup else { return }
    
    // If the notification status is not determined, recheck later
    if self.systemNotificationsStatus == .notDetermined {
      onThreadAfter(5.0) { [weak self] in
        self?.checkNotificationStatus {
          onMain { [weak self] in
            self?.showPopupIfNeeded(newIssueAvailableSince: newIssueAvailableSince)
          }
        }
      }
      return
    }
    
    // If the notification status is unchecked, check now
    if self.systemNotificationsStatus == nil {
      self.checkNotificationStatus {
        onMain { [weak self] in
          self?.showPopupIfNeeded(newIssueAvailableSince: newIssueAvailableSince)
        }
      }
      return
    }
    
    // Earlier user choice to ignore notifications
    guard Defaults.notificationsActivationPopupRejectedDate != nil else {
      return
    }
    
    // If no issues with settings, do nothing
    if self.settingsDetailTextAlert == false {
      return
    }
    
    // If not on Home, do nothing
    guard TazAppEnvironment.sharedInstance.rootViewController is MainTabVC else {
      return
    }
    
    // Skip if the popup was dismissed less than 10 days ago
    if let skippedDate = Defaults.notificationsActivationPopupRejectedTemporaryDate,
       abs(skippedDate.timeIntervalSinceNow) < 3600 * 24 * 10 {
      return
    }
    
    showingNotificationsPopup = true
    
    // Show the popup when a new issue appears
    let toast = NotificationsView(newIssueAvailableSince: newIssueAvailableSince)
    toast.onDismiss { [weak self] in
      self?.showingNotificationsPopup = false
    }
    toast.show()
    Usage.track(Usage.event.dialog.AllowNotificationsInfo)
  }
}
