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
  ///ToDo must be a compleetly downloaded one!! rename
  var latestIssueIssueDate: Date?
  
  /// The date of the last check for an new issue
  /// will be set due check for new issues
  /// is used by timed Background download
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
    log ("Update updateLatestIssueDownloadDate...")
    if let lastIssue = StoredIssue.lastCompleete(feed: feed) {
      log ("... with date \(lastIssue.date.short)")
      updateLatestIssueDownloadDate(ifNewer: lastIssue.date)
    }
    else {
      log ("... no last issue found")
    }
//    updateLatestIssueDownloadDate(ifNewer: feed.lastIssue)//its maybe just an overview
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

