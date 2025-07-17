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
  
  @Default("autoloadOnlyInWLAN2")
  var autoloadOnlyInWLAN: Bool
  
  @Default("useTestServer")
  var useTestServer: Bool
  
  var tempStorage = BackgroundDownloadsTempStorage()
  
  var saveDatabase = false
  
  var nextScheduledCheck : Date?
  
  var informUIAfterSave = false
  
  @Default("autoloadPublicationType")
  var autoloadPublicationType: String
  
  @Default("remoteResourcesBaseUrl")
  var remoteResourcesBaseUrl: String
  
  @Default("updatedResourcesLocalPath")
  var updatedResourcesLocalPath: String
  
  @Default("autoloadNotifications")
  var autoloadNotifications: Bool
  
  var updatedResourcesFiles: [FileEntry] = []
  
  /// The date of the last issue that was fully downloaded based on the user's auto-download settings.
  ///
  /// This value reflects the latest issue for which all enabled types (PDF and/or audio)
  /// were successfully downloaded:
  /// - If `autoloadPdf` is enabled, the issue must include the facsimiles.
  /// - If `autoloadAudio` is enabled, the issue must include the audio files.
  /// - If both are enabled, both downloads must be complete for the date to be updated.
  /// - If no suitable issue has been fully downloaded yet, this value is `nil`.
  var lastFullyDownloadedIssueDate: Date?
  
  var publicationSchedule: PublicationSchedule = .taz //just initial value
  
  var preventDownloadOnce = false
  
  var feederContext: FeederContext? {
    TazAppEnvironment.sharedInstance.feederContext
  }
  
  lazy var backgroundSession
  = BackgroundSession.shared(callback: BackgroundDownloadService.dlCallback)
  
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
      autoloadPublicationType = PublicationSchedule.lmd.rawValue
    }
    else if feed.cycle == .weekly {
      autoloadPublicationType = PublicationSchedule.wochentaz.rawValue
    }
    else {
      autoloadPublicationType = PublicationSchedule.taz.rawValue
    }
    updatePublicationtype()
    log ("Update updateLatestIssueDownloadDate...")
    if let lastIssue = StoredIssue.lastCompleete(feed: feed,
                                                 isPages: autoloadPdf,
                                                 withAudio: autoloadAudio) {
      log ("... with date \(lastIssue.date.short)")
      updateLatestIssueDownloadDate(ifNewer: lastIssue.date)
    }
    else {
      log ("... no last issue found")
    }
  }
  
  fileprivate func updatePublicationtype(){
    switch autoloadPublicationType {
      case PublicationSchedule.lmd.rawValue:
        publicationSchedule = .lmd
      case PublicationSchedule.wochentaz.rawValue:
        publicationSchedule = .wochentaz
      default:
        publicationSchedule = .taz
    }
  }
}
