//
//  ConfigDefaults.swift
//
//  Created by Norbert Thies on 06.03.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/**
 Configuration variables and default values to store in Apple's UserDefaults
 */
public let ConfigDefaults = Defaults.Values([
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
  "smartBackFromArticle" : "true",
  "autoHideToolbar" : "true",
  "tabbarInSection" : "false",
  "simulateFailedMinVersion" : "false",
  "simulateNewVersion" : "false",
  "autoPlayNext" : "true",
  "playbackRate": "1.0",
])


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

  static var expiredAccount : Bool { return expiredAccountDate != nil }
  static var expiredAccountText : String? {
    guard let d = expiredAccountDate else { return nil }
    return "Abo abgelaufen am: \(d.gDate())"
  }
}
