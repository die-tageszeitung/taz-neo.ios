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
  
  ///remember last accessed auth status due its maybe not determinated after new install
  var systemNotificationsStatus: UNAuthorizationStatus?
  var alertStyle: UNAlertStyle?
  var notificationCenterSetting: UNNotificationSetting?
  var lockScreenSetting: UNNotificationSetting?
  var criticalAlertSetting: UNNotificationSetting?
  var badgeSetting: UNNotificationSetting?
  var soundSetting: UNNotificationSetting?
  var alertSetting: UNNotificationSetting?

  /// Check if in app notifications settings are applyable for current setting in ios system settings
  /// - Parameter finished: callback after async check is finished
  func checkNotificationStatus(finished: (()->())? = nil){
    let notifCenter = UNUserNotificationCenter.current()
    notifCenter.getNotificationSettings(
      completionHandler: { [weak self] (settings) in
        guard let self = self else { return }
        self.systemNotificationsStatus = settings.authorizationStatus
        if settings.authorizationStatus == .notDetermined {//possible to send PN, but silent recive
          updateSettingsDetailText()
          finished?()
          return;
        }
        
        self.alertStyle = settings.alertStyle
        self.notificationCenterSetting = settings.notificationCenterSetting
        self.lockScreenSetting = settings.lockScreenSetting
        self.criticalAlertSetting = settings.criticalAlertSetting
        self.badgeSetting = settings.badgeSetting
        self.soundSetting = settings.soundSetting
        self.alertSetting = settings.alertSetting
        updateSettingsDetailText()
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
  
  var settingsDetailTextAlert: Bool = true
  var settingsLink: Bool = true
  var settingsDetailText: NSMutableAttributedString = NSMutableAttributedString(string: "")
  
  func updateSettingsDetailText() {
    settingsDetailText = NSMutableAttributedString(string: "")
    
    if isTextNotification == false {
      settingsDetailText
      = NSMutableAttributedString(string: "\nErhalten Sie täglich Push-Benachrichtigungen zur aktuellen Ausgabe und bleiben Sie stets auf dem Laufenden. Detaillierte Einstellungen finden Sie in den Systemeinstellungen unter „Mitteilungen“.")
      settingsDetailText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 154, length: 20))
      settingsDetailTextAlert = true
      settingsLink = true
      return
    }
    
    ///**notifications are enabled, but are they silent&invisible?**
    ///alertStyle == .alert{ //alert, banner, none, some
    ///systemNotificationsStatus == .authorized { //none, some, notDetermined, denied, authorized, provisional, ephemeral(flüchtig)
    ///notificationCenterSetting == .enabled { //notSupported, disabled, enabled, none, some
    ///lockScreenSetting == .enabled { //notSupported, disabled, enabled, none, some
    ///criticalAlertSetting == .enabled { //notSupported, disabled, enabled, none, some
    /// badgeSetting == .enabled { //notSupported, disabled, enabled, none, some
    /// soundSetting != .enabled { //notSupported, disabled, enabled, none, some
    /// alertSetting == .enabled { //notSupported, disabled, enabled, none, some
    var items: [String] = []
    var bannerAdditionalText: String = ""
    
    if soundSetting != .enabled { items.append("Töne")}
    if lockScreenSetting != .enabled { items.append("Mitteilungen auf dem Sperrbildschirm")}
    if notificationCenterSetting != .enabled { items.append("Mitteilungen in der Mitteilungszentrale")}
    if alertStyle == UNAlertStyle.none {
      items.append("Banner")
      bannerAdditionalText = " Mitteilungs-Banner sind kurze Benachrichtigungen, die oben auf dem Bildschirm erscheinen, wenn das Gerät entsperrt ist."
    }
    
    if items.count == 0 {///Everything is perfect
      settingsDetailTextAlert = false
      settingsLink = false
      settingsDetailText = NSMutableAttributedString(string: "\nBleiben Sie immer informiert mit einem täglichen Push-Hinweis, auf die aktuelle Ausgabe.")
      return
    }
    settingsLink = true
    settingsDetailTextAlert = items.count > 1//2 things are red otherwise not
    
    let itemsText = items.joined(separator: ", ", lastSeparator: " und ")
    
    settingsDetailText = NSMutableAttributedString(string: "\nDie Mitteilungseinstellungen für die \(App.shortName) App lassen derzeit keine \(itemsText) zu.\(bannerAdditionalText)\nTippen Sie hier, um zu den Systemeinstellungen für die taz App zu gelangen und diese anzupassen.")
    settingsDetailText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 5, length: 25))
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
    
    ///if status unavailable: recheck later
    if self.systemNotificationsStatus == .notDetermined {
      onThreadAfter(5.0){[weak self] in
        self?.checkNotificationStatus{
          onMain {[weak self] in
            self?.showPopupIfNeeded(newIssueAvailableSince: newIssueAvailableSince)
          }
        }
      }
      return;
    }
    
    ///if status unchecked: check now
    //wenn status nicht gecheckt, checke status, und re-evaluiere
    if self.systemNotificationsStatus == nil {
      self.checkNotificationStatus{
        onMain {[weak self] in
          self?.showPopupIfNeeded(newIssueAvailableSince: newIssueAvailableSince)
        }
      }
      return;
    }
    
    ///erlier user choice to ignore: do nothing
    guard Defaults.notificationsActivationPopupRejectedDate != nil else {
      return
    }
    
    ///if no problem: do nothing
    if self.settingsDetailTextAlert == false {
      return;
    }
    
    ///if noot on Home: do nothing
    guard TazAppEnvironment.sharedInstance.rootViewController is MainTabVC else {
      return
    }
    
    ///skip 10 days by pressed x
    if let skippedDate = Defaults.notificationsActivationPopupRejectedTemporaryDate,
       abs(skippedDate.timeIntervalSinceNow) < 3600*24*10 {
      return
    }
    
    showingNotificationsPopup = true
    
    //show popup on new issue appear
    let toast = NotificationsView(newIssueAvailableSince: newIssueAvailableSince)
    toast.onDismiss {[weak self] in
      self?.showingNotificationsPopup = false
    }
    toast.show()
    Usage.track(Usage.event.dialog.AllowNotificationsInfo)
  }
}
