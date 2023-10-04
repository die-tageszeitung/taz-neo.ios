//
//  FeederContext+IssueDownload.swift
//  taz.neo
//
//  Created by Ringo Müller on 07.08.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import UIKit

extension FeederContext {
  
  /// Download partial Payload of Issue
  private func downloadPartialIssue(issue: StoredIssue) {
    self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated) issueDate: \(issue.date.short)")
    self.dloader.downloadPayload(payload: issue.payload as! StoredPayload, atEnd: { [weak self] err in
      var res: Result<StoredIssue,Error>
      if err == nil {
        issue.isOvwComplete = true
        res = .success(issue)
        ArticleDB.save()
        self?.didDownload(issue)
      }
      else { res = .failure(err!) }
      Notification.send("issueOverview", result: res, sender: issue)
    })
  }
  
  /// Download complete Payload of Issue
  func downloadCompleteIssue(issue: StoredIssue, isAutomatically: Bool) {
    //    enqueuedDownlod.append(issue)
    self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated)")
    markStartDownload(feed: issue.feed, issue: issue, isAutomatically: isAutomatically) { (dlId, tstart) in
      issue.isDownloading = true
      self.dloader.downloadPayload(payload: issue.payload as! StoredPayload,
                                   onProgress: { (bytesLoaded,totalBytes) in
        Notification.send("issueProgress", content: (bytesLoaded,totalBytes),
                          sender: issue)
      }) {[weak self] err in
        issue.isDownloading = false
        var res: Result<StoredIssue,Error>
        if err == nil {
          res = .success(issue)
          issue.isComplete = true
          ArticleDB.save()
          self?.didDownload(issue)
          //inform DownloadStatusButton: download finished
          Notification.send("issueProgress", content: (Int64(1),Int64(1)), sender: issue)
        }
        else { res = .failure(err!) }
        self?.markStopDownload(dlId: dlId, tstart: tstart)
        //        self.enqueuedDownlod.removeAll{ $0.date == issue.date}
        Notification.send("issue", result: res, sender: issue)
      }
    }
  }
  
  /**
   Get an Issue from Server or local DB
   
   This method retrieves a complete Issue (ie downloaded Issue with complete structural
   data) from the database. If necessary all files are downloaded from the server.
   */
  public func getCompleteIssue(issue: StoredIssue, 
                               isPages: Bool = false,
                               isAutomatically: Bool,
                               force: Bool = false,
                               withAudio: Bool = false) {
    self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated) issueDate:  \(issue.date.short)")
    if issue.isDownloading {
      Notification.receiveOnce("issue", from: issue) { [weak self] notif in
        self?.getCompleteIssue(issue: issue, isPages: isPages, isAutomatically: isAutomatically)
      }
      return
    }
    let loadPages = isPages || autoloadPdf
    guard needsUpdate(issue: issue, toShowPdf: loadPages) || force == true else {
      Notification.send("issue", result: .success(issue), sender: issue)
      return
    }
    if self.isConnected {
      gqlFeeder.issues(feed: issue.feed, 
                       date: issue.date,
                       count: 1,
                       isPages: loadPages, 
                       withAudio: withAudio) { res in
        if let issues = res.value(), issues.count == 1 {
          let dissue = issues[0]
          #warning("Not needed, not used currently")
          //Notification.send("gqlIssue", result: .success(dissue), sender: issue)
          if issue.date != dissue.date {
            self.error("Cannot Update issue \(issue.date.short)/\(issue.isWeekend ? "weekend" : "weekday") with issue \(dissue.date.short)/\(dissue.isWeekend ? "weekend" : "weekday") feeders cycle: \(self.gqlFeeder.feeds.first?.cycle.toString() ?? "-")")
            let unexpectedResult : Result<[Issue], Error>
              = .failure(DownloadError(message: "Weekend Login cannot load weekday issues", handled: true))
            Notification.send("issueStructure", result: unexpectedResult, sender: issue)
            TazAppEnvironment.sharedInstance.resetApp(.wrongCycleDownloadError)
            return
          }
          issue.update(from: dissue)
          issue.isAudioComplete = withAudio && res.error() == nil
          ArticleDB.save()
          Notification.receiveOnce("resourcesReady") { _ in
            Notification.send("issueStructure", result: .success(issue), sender: issue)
          }
          self.downloadIssue(issue: issue, isComplete: true, isAutomatically: isAutomatically)
        }
        else if let err = res.error() {
          let errorResult : Result<[Issue], Error>
            = .failure(DownloadError(handled: false, enclosedError: err))
          Notification.send("issueStructure",
                            result: errorResult,
                            sender: issue)
        }
        else {
          //prevent ui deadlock
          let unexpectedResult : Result<[Issue], Error>
            = .failure(DownloadError(message: "Unexpected Behaviour", handled: false))
          Notification.send("issueStructure", result: unexpectedResult, sender: issue)
        }
      }
    }
    else {
      #warning("ToDO AddRetry here its easily possible!")
      OfflineAlert.show(type: .issueDownload)
      let res : Result<Any, Error>
        = .failure(DownloadError(message: "no connection", handled: true))
      Notification.send("issueStructure", result: res, sender: issue)
    }
  }
  
  /// Tell server we are starting to download
  func markStartDownload(feed: Feed, issue: Issue, isAutomatically: Bool, closure: @escaping (String?, UsTime)->()) {
    let isPush = pushToken != nil
    debug("Sending start of download to server")
    self.gqlFeeder.startDownload(feed: feed, issue: issue, isPush: isPush, pushToken: self.pushToken, isAutomatically: isAutomatically) { res in
      closure(res.value(), UsTime.now)
    }
  }
  
  /// Tell server we stopped downloading
  func markStopDownload(dlId: String?, tstart: UsTime) {
    if let dlId = dlId {
      let nsec = UsTime.now.timeInterval - tstart.timeInterval
      debug("Sending stop of download to server")
      self.gqlFeeder.stopDownload(dlId: dlId, seconds: nsec){_ in}
    }
  }
  
  func didDownload(_ issue: Issue){
    guard issue.date == self.defaultFeed.lastIssue else { return }
    guard let momentPublicationDate = issue.moment.files.first?.moTime else { return }
    ///momentPublicationDate is in UTC timeIntervalSinceNow calculates also with utc, so timeZone calculation needed!
    //is called multiple times!
    //debug("New Issue:\n  issue Date: \(issue.date)\n  defaultFeed.lastIssue: \(self.defaultFeed.lastIssue)\n  defaultFeed.lastUpdated: \(self.defaultFeed.lastUpdated)\n  defaultFeed.lastIssueRead: \(self.defaultFeed.lastIssueRead)")
    NotificationBusiness
      .sharedInstance
      .showPopupIfNeeded(newIssueAvailableSince: -momentPublicationDate.timeIntervalSinceNow)
    
  }
  
  
  /// Download Issue files and resources if necessary
  private func downloadIssue(issue: StoredIssue, isComplete: Bool = false, isAutomatically: Bool) {
    self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated)\(Defaults.expiredAccount ? " Expired!" : "") isComplete: \(isComplete) issueDate: \(issue.date.short)")
    Notification.receiveOnce("resourcesReady") { [weak self] err in
      guard let self = self else { return }
      self.dloader.createIssueDir(issue: issue)
      if self.isConnected {
        if isComplete { self.downloadCompleteIssue(issue: issue, isAutomatically: isAutomatically) }
        else { self.downloadPartialIssue(issue: issue) }
      }
      else {
        OfflineAlert.show(type: .issueDownload)
      }
    }
    updateResources(toVersion: issue.minResourceVersion)
  }
  
}
