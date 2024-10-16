//
//  ConfigDefaults.swift
//
//  Created by Norbert Thies on 06.03.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import UIKit

/**
 Configuration variables and default values to store in Apple's UserDefaults
 */

private let configValues = [
  // Default Feeder & Server
  "defaultFeeder" : "taz",
  // shall text notifications be displayed on notification screen
  "isTextNotification" : "true", 
  // number of starts since installation
  "nStarted" : "0", 
  // last time app has been started (as UsTime)
  "lastStarted": "0", 
  // has our data policy been accepted
  "dataPolicyAccepted" : "false",
  // Article/Section font size in percent (100% => 18px)
  "articleTextSize" : "100",
  // Article/Section font size in percent (100% => 18px)
  "articleColumnPercentageWidth" : "100",
  // Text alignment in Articles (eg. left/justify)
  "textAlign" : "left",
  // Color mode - currently dark/light
  "colorMode" : "light",
  // Carousel scroll from left to right
  "carouselScrollFromLeft" : "false",
  // Automtically download new issues
  "autoDownload" : "true",
  // Allow automatic download over mobile networks
  "autoMobileDownloads" : "false",
  // Use facsimile mode if available
  "isFacsimile" : "false",
  // Tap in PDF open ArticleView
  "articleFromPdf" : "true",
  // double Tap in PDF zoom in/out
  "doubleTapToZoomPdf" : "true",
  // show/hide Toolbar in PDF View at page switch
  "showToolbarOnPageSwitch" : "true",
  // display full PDF Page on Page switch in Landscape
  "fullPdfOnPageSwitch" : "true",
  // need to show PDF Info Toast on startup
  "showPdfInfoToast" : "true",
  // need to show Bottom Tiles Animation
  "showBottomTilesAnimation" : "true",
  // Experimental
  "autoloadOnlyInWLAN" : "false",
  "showBarsOnContentChange" : "false",
  "autoloadPdf" : "false",
  // "autoloadNewIssues" : "true",
  "persistedIssuesCount": "20",
  // show teaser text in bookmarks list
  "bookmarksListTeaserEnabled" : "true",
  "smartBackFromArticle" : "false",
  "autoHideToolbar" : "true",
  "tabbarInSection" : "false",
  "simulateFailedMinVersion" : "false",
  "simulateNewVersion" : "false",
  "autoPlayNext" : "true",
  "playbackRate": "1.0",
  "edgeTapToNavigate" : "false",
  "edgeTapToNavigateVisible2" : "false",
  // coachmark defaults
  "showCoachmarks" : "true",
  "cmLastPrio": "1",
  "cmSessionCount": "0",
  "multiColumnModeLandscape": "false",
  "multiColumnModePortrait": "false",
  "columnCountLandscape": "3",
  "articleLineLengthAdjustment": "0",
  "multiColumnOnboardingAnswered" : "false",
]

private let configValuesLMD = [
  // Use facsimile mode for LMD
  "isFacsimile" : "true",
  "usageTrackingAllowed" : "false",
]

#if LMD
  public let ConfigDefaults = Defaults.Values(configValues.merging(configValuesLMD) {
    (_,lmd) in lmd
  })
#else
  public let ConfigDefaults = Defaults.Values(configValues)
#endif

extension Defaults {
  ///Provide getter only
  public static var isTextNotification:Bool { Defaults.singleton["isTextNotification"]!.bool }

  ///Helper to get current server from user defaults
  static var expiredAccountDate : Date? {
    get {
      if let curr = Defaults.singleton["expiredAccountDate"] {
        return Date.fromString(curr)
      }
      return nil
    }
    set {
      if expiredAccountDate == newValue { return }
      if let date = newValue {
        Defaults.singleton["expiredAccountDate"] = Date.toString(date)
      }
      else {
        Defaults.singleton["expiredAccountDate"] = nil
      }
      Notification.send(Const.NotificationNames.expiredAccountDateChanged)
    }
  }
  
  ///Helper to get current server from user defaults
  static var notificationsActivationPopupRejectedDate : Date? {
    get {
      if let curr = Defaults.singleton["notificationsActivationPopupRejectedDate"] {
        return Date.fromString(curr)
      }
      return nil
    }
    set {
      if let date = newValue {
        Defaults.singleton["notificationsActivationPopupRejectedDate"] = Date.toString(date)
      }
      else {
        Defaults.singleton["notificationsActivationPopupRejectedDate"] = nil
      }
    }
  }
  
  ///Helper to get current server from user defaults
  static var notificationsActivationPopupRejectedTemporaryDate : Date? {
    get {
      if let curr = Defaults.singleton["notificationsActivationPopupRejectedTemporaryDate"] {
        return Date.fromString(curr)
      }
      return nil
    }
    set {
      if let date = newValue {
        Defaults.singleton["notificationsActivationPopupRejectedTemporaryDate"] = Date.toString(date)
      }
      else {
        Defaults.singleton["notificationsActivationPopupRejectedTemporaryDate"] = nil
      }
    }
  }
  
  static var customerType : GqlCustomerType? {
    get {
      if let curr = Defaults.singleton["customerType"] {
        return GqlCustomerType.fromExternal(curr)
      }
      return nil
    }
    set {
      if let type = newValue {
        Defaults.singleton["customerType"] = type.toString()
      }
      else {
        Defaults.singleton["customerType"] = nil
      }
    }
  }
  
  typealias columnSettingData = (used:Int, available: Int, setting: Int)
  
  static var columnSetting : columnSettingData {
    get {
      let isLandscape = UIWindow.isLandscapeInterface
      let articleTextSize = Defaults.singleton["articleTextSize"]?.int ?? 100
      let width = TazAppEnvironment.sharedInstance.nextWindowSize.width
      let calculatedColumnWidth = 3.1 * CGFloat(articleTextSize) + 30.0 //+padding
      let maxCount = isLandscape ? 4.0 : 2.0
      let availableColumnsCount = Int(min(maxCount, width/calculatedColumnWidth))//1..4
      let columnCountLandscape = Defaults.singleton["columnCountLandscape"]?.int ?? 3
      let columnsCountSetting = isLandscape ? columnCountLandscape : 2
      let used
      = columnsCountSetting >= availableColumnsCount
      ? availableColumnsCount
      : columnsCountSetting
      Self.multiColumnsAvailable = availableColumnsCount >= 2
      return (used, availableColumnsCount, columnsCountSetting)
    }
  }
  
  static var multiColumnsAvailable: Bool = false
  
  /**
   fileprivate func updateColumnButtons(){
     let isLandscape = UIWindow.isLandscapeInterface
     #warning("MAYBE WRONG!")//Portrait also Calc ...ro o fo
     let availableColumnsCount = Defaults.availableColumnsCount
     let columnsCountSetting = isLandscape ? columnCountLandscape : 2
     let selectedColumnCount
     = columnsCountSetting >= availableColumnsCount
     ? availableColumnsCount
     : columnsCountSetting
  */
  
  static var expiredAccount : Bool { return expiredAccountDate != nil }
  static var expiredAccountText : String? {
    guard let d = expiredAccountDate else { return nil }
    return "Abo abgelaufen am: \(d.gDate())"
  }
  
  static func deleteAppStateDefaults(){
    let dfl = Defaults.singleton
    dfl["nStarted"] = "0"
    dfl["lastStarted"] = "0"
    dfl["installationId"] = nil
    dfl["pushToken"] = nil
    
    dfl["bottomTilesLastShown"] = nil
    dfl["bottomTilesShown"] = nil
    dfl["showBottomTilesAnimation"] = nil
    dfl["bottomTilesAnimationLastShown"] = nil
    
    dfl["ratingCount"] = nil
    dfl["ratingRequestedForVersion"] = nil
    dfl["ratingRequestedDate"] = nil
    
    Defaults.notificationsActivationPopupRejectedTemporaryDate = nil
    Defaults.notificationsActivationPopupRejectedDate = nil
    Defaults.lastKnownPushToken = nil
    
    dfl["usageTrackingAllowed"] = nil
  }
}
