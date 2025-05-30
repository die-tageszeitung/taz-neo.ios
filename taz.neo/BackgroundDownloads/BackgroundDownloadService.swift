//
//  BackgroundDownloadService.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.03.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//
import NorthLib
import UIKit
import Network

class BackgroundDownloadService: DoesLog {
  
  @Default("autoloadNewIssues")
  var autoloadNewIssues: Bool
  
  @Default("autoloadPdf")
  var autoloadPdf: Bool
  
  @Default("autoloadAudio")
  var autoloadAudio: Bool
  
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  @Default("autoloadOnlyInWLAN2")
  var autoloadOnlyInWLAN: Bool
  
  var tempStorage = BackgroundDownloadsTempStorage()
  
  var saveDatabase = false
  
  var informUIAfterSave = false
  
  @Default("autoloadPublicationType")
  var autoloadPublicationType: String
  
  var latestIssueIssueDate: Date?
  
  var latestCheckForNewIssue: Date?
  
  var publicationType: PublicationType = .taz //just initial value
  
  var feederContext: FeederContext? {
    TazAppEnvironment.sharedInstance.feederContext
  }
  
  static let shared = BackgroundDownloadService()
  
  private init(){ updatePublicationtype()}
}

extension BackgroundDownloadService {
  /// The filename used to persist temporary JSON data within an issue's folder.
  ///
  /// Note: This property cannot be defined in an `Issue` extension unless it is explicitly
  /// declared in the `Issue` protocol, due to Swift's limitations on accessing static members
  /// via protocol types.
  static var jsonDataFilename: String { "issue-tmp-data.json" }
  
  func updateFeed(_ feed: StoredFeed) {
    if feed.name == FeedName.LMd.rawValue {
      autoloadPublicationType = PublicationType.lmd.rawValue
    }
    else if feed.cycle == .weekly {
      autoloadPublicationType = PublicationType.wochentaz.rawValue
    }
    else {
      autoloadPublicationType = PublicationType.taz.rawValue
    }
    updatePublicationtype()
    updateLatestIssueDownloadDate(ifNewer: feed.lastIssue)
  }
  
  fileprivate func updatePublicationtype(){
    switch autoloadPublicationType {
      case PublicationType.lmd.rawValue:
        publicationType = .lmd
      case PublicationType.wochentaz.rawValue:
        publicationType = .wochentaz
      default:
        publicationType = .taz
    }
  }
}

