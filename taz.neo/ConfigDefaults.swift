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
  // Use mobile networks
  "useMobile" : "true",
  // Automtically download new issues
  "autoDownload" : "true",
  // Allow automatic download over mobile networks
  "autoMobileDownloads" : "false",
  // Allow trial subscriptions
  "offerTrialSubscription" : "true",
  // Use facsimile mode if available
  "isFacsimile" : "false",
  // Tap in PDF open ArticleView
  "articleFromPdf" : "true",
  // show/hide Toolbar in PDF View at page switch
  "showToolbarOnPageSwitch" : "true",
  // display full PDF Page on Page switch in Landscape
  "fullPdfOnPageSwitch" : "true",
  // need to show PDF Info Toast on startup
  "showPdfInfoToast" : "true",
  // need to show Bottom Tiles Animation
  "showBottomTilesAnimation" : "false",
  // Experimental
  "autoloadInWLAN" : "true",
  "autoloadNewIssues" : "true",
  "persistedIssuesCount": "20",
])
