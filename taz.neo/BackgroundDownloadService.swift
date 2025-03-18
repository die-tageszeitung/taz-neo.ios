//
//  BackgroundDownloadService.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.03.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import UIKit

/**
 
 Testplan:
 - live/release branch, Testflight Testbuild
 ***benutzt TestServer!**
 - push Notification/dowload nach Zeit Issue Tap kommt und
 ***läd neue Ausgabe vom Live Server!**
 
 Checklisten
 * sind alle BackgroundSession sachen implementiert?
 ** korrekt implementiert? Fortsetzen unterschiedliche Downloads...
 * richtiger Feeder
 * Background/FG States korrekt
 * USer Feedback?
 
 
 - ForeGround/Background
 - Push
 - fetch data ...X no Feeder => no Download
 - Push
 - fetchData => Feeder + Issue => Download1
 ...Download1Fail
 - Push fetchData => Feeder + Issue => Download2
 ...Download1 Success => persist Issue 1
 ...Download2 Success => persist Issue 2
 
 ===
 
 - strukturdaten
 - download start
 - bg session
 ....
 ...appdelegate...mit 1. NAmen, 2. Callback/CompleetionHandler
 - bgsession wieder herstellen mit Namen
 - callbackCompleetionHandler aufrufen
 - URLSessionDelegate Protocol urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)
 - URLSessionTaskDelegate Protocol +2
 
 
 - mehrere Downloads ++ appdelegate aufgerufen...wenn app beendet...sonnst kein
 
 */


class BackgroundDownloadService: DoesLog {
  
  @Default("autoloadNewIssues")
  var autoloadNewIssues: Bool
  
  @Default("autoloadPdf")
  var autoloadPdf: Bool
  
  @Default("autoloadAudio")
  var autoloadAudio: Bool
  
  @Default("autoloadOnlyInWLAN")
  var autoloadOnlyInWLAN: Bool
  
  @Default("autoDownloadedIssuesSinceLastAppUse")
  var autoDownloadedIssuesSinceLastAppUse: Int

  static let maxUnreadIssuesToDownload: Int = 3
  
  var fetchCompletionHandler: FetchCompletionHandler?
    
  static func dlCallback(err: Error?) { Self.shared.dlCallback(err: err) }
  
  fileprivate var currentFeederData = Defaults.currentFeeder
  
  fileprivate var feeder: BackgroundDownloadGqlFeeder?

  fileprivate var downloadId: String?
  fileprivate var downloadStart: UsTime?
  
  fileprivate static let shared = BackgroundDownloadService()
  private init() {}
}

fileprivate extension Issue {
  var zipUrl: String? {
    guard let zipName = Defaults.autoloadPdf ? zipNamePdf : zipName else { return nil }
    return baseUrl.appending("/\(zipName)")
  }
}

extension BackgroundDownloadService {
  func dlCallback(err: Error?, downloadUrl: String? = nil) {
    log("dlCallback called...for URL: \(downloadUrl ?? "-")")
    if let err = err {
      log("Failed to Download with err: \(err)")
      return
    }
    
    if downloadUrl?.lastPathComponent.hasSuffix(".zip") == false {
      self.log("Do not update Database for file \(downloadUrl?.lastPathComponent ?? "-")")
      return
    }
    
    guard let issueDate = Defaults.backgroundDownloadIssueDate else {
      self.log("No Issue Date found to update")
      return
    }
    
    if let downloadStart = downloadStart, let downloadId = downloadId {
      let nsec = UsTime.now.timeInterval - downloadStart.timeInterval
      feeder?.stopDownload(dlId: downloadId, seconds: nsec, returnOnMain: false) { [weak self] err in
        self?.log("send stop to server for dlId: \(downloadId) with err: \(err)")
        self?.downloadId = nil
        self?.downloadStart = nil
      }
    }
    else {
      log("cannot send stop to server missing downloadStart or downloadId")
    }
    
    updateDatabase {[weak self] in
      self?.setIssueCompleete(for: issueDate)
    }
  }
  
  private func updateDatabase(handler: @escaping()-> Void) {
    onMain {
      if ArticleDB.singleton == nil {
        let dbName = Defaults.currentFeeder.name
        ArticleDB(name: dbName) {[weak self] err in
          if let err = err {
            self?.log("failed open database \(err)")
            self?.log("try update anyway ...may crash?")
          }
          handler()
        }
      }
      else {
        handler()
      }
    }
  }
  
  func setIssueCompleete(for issueDate: Date) {
    self.log("Update Issue for \(issueDate.short) after Download")
    ///just for testing
    guard let storedFeeder =  StoredFeeder.get(name: currentFeederData.name).first else {
      self.log("no storedFeeder found for \(currentFeederData.name)")
      return
    }
    
    guard let feed = storedFeeder.feeds.first as? StoredFeed else {
      self.log("no stored Feed found for \(currentFeederData.name)")
      return
    }
    
    guard let si = StoredIssue.get(date: issueDate, inFeed: feed).first else {
      self.log("no StoredIssue for date: \(issueDate.short) found in feed \(currentFeederData.name)")
      return
    }
    
#warning("May refactor to create this on Startup?")
    if autoloadPdf {
      log("create facsimile image for page with pagina: \(si.pages?.first?.pagina ?? "-")")
      _ = si.pages?.first?.facsimile//create facsimile image!
    }
    
    si.isComplete = true
    ArticleDB.save()
    self.log("Background Download & Update finished")
    
    if Defaults.newIssueSystemSetting {
      LocalNotifications.notify(message: "taz vom \(issueDate.short) heruntergeladen")
    }
  }
  
  public static func checkForNewIssue(_ fetchCompletionHandler: FetchCompletionHandler?) {
    Self.shared.log("...static checkForNewIssue requested, App State: \(UIApplication.shared.stateDescription)")
    let appState = UIApplication.shared.applicationState
    
    Task {
      Self.shared.log("...static checkForNewIssue  do")
      await BackgroundDownloadService.shared.checkForNewIssue(fetchCompletionHandler, currentAppState: appState)
      Self.shared.log("...static checkForNewIssue done")
    }
  }
  
  private func checkForNewIssue(_ fetchCompletionHandler: FetchCompletionHandler?, currentAppState: UIApplication.State) async {
    do {
      log("...checkForNewIssue")
      
      guard autoloadNewIssues else {
        throw BackgroundDownloadError("autoloadNewIssues disabled")
      }
      log("...checkForNewIssue #2")
      guard App.isAvailable(.AUTODOWNLOAD) else {
        log("...checkForNewIssue #2x")
        throw BackgroundDownloadError("autoload not available")
      }
      log("...checkForNewIssue #3")
      guard autoDownloadedIssuesSinceLastAppUse < Self.maxUnreadIssuesToDownload else {
        log("...checkForNewIssue #3x")
        throw BackgroundDownloadError("Do not download issues anymore due they are not read yet!")
      }
      
      if currentAppState == .active {
        log("...checkForNewIssue 4 > active!")
        guard let feederContext = TazAppEnvironment.sharedInstance.feederContext else {
          log("...checkForNewIssue # no feeder context")
          throw BackgroundDownloadError("Currently in active State bnut no feederContext!")
        }
        Notification.receiveOnce(Const.NotificationNames.publicationDatesChanged) {[weak self] _ in
          guard let lastIssueDate = TazAppEnvironment.sharedInstance.service?.lastIssueDate else {
            self?.log("No last IssueDate available")
            return
          }
          self?.log("Try to download issue withDate: \(lastIssueDate.short) in active State")
          TazAppEnvironment.sharedInstance.service?.download(issueAt: lastIssueDate,
                                                             withAudio: self?.autoloadAudio ?? false)
        }
        feederContext.checkForNewIssues(force: false)
        throw BackgroundDownloadError("prevent Background Download in Forground")
      }
      
      let token = SimpleAuthenticator.getUserData().token
      
      guard (token?.length ?? 0) > 10 else {
        throw BackgroundDownloadError("No token available! Token: \(token ?? "N/A")")
      }
      
      if feeder == nil {
        log("...create feeder")
        feeder = BackgroundDownloadGqlFeeder(title: currentFeederData.name,
                                            url: currentFeederData.url,
                                            token: token)
      }
      
      guard let feeder = feeder else {
        throw BackgroundDownloadError("No Feeder available!")
      }
      log("...update feeder status")
      try await feeder.updateStatus()
      
      let feed = feeder.feeds.first { $0.name == currentFeederData.feed }
      log("...use matching feeder")
      guard let feed = feed else {
        throw BackgroundDownloadError("Matching Feed not found! Feeder has \(feeder.feeds.count) feeds, required: \(currentFeederData.feed), first name: \(feeder.feeds.first?.name ?? "N/A")")
      }
      
      let withPages = false
      let withAudio = false
      let issueData = try await feeder.issues(feed: feed,
                                              date: nil,
                                              count: 1,
                                              isPages: withPages,
                                              withAudio: withAudio, returnOnMain: false)
      log("...fetch latest issue done")
      guard let issue = issueData.issues.first else {
        throw BackgroundDownloadError("Fetch Issue failed!")
      }
      ///maybe not required & if killed, do it with a task! own subclass of task, maybe persist db at first then just copy/add files
      //      storeResponseToTemp(data: issueData?.data)
      log("...load issue content zip")
      guard let zipUrl = issue.zipUrl else {
        throw BackgroundDownloadError("No Zip to Download!")
      }
      
      Defaults.backgroundDownloadIssueDate = issue.date

      let issueDir = issue.dir
      if !issueDir.exists {
        issueDir.create()
        let rlink = File(dir: issueDir.path, fname: "resources")
        let glink = File(dir: issueDir.path, fname: "global")
        if !rlink.isLink { rlink.link(to: feeder.resourcesDir.path) }
        if !glink.isLink { glink.link(to: feeder.globalDir.path) }
      }
      
      updateDatabase {[weak self] in
        self?.persist(issue: issue)
      }
      
      let bgSession = try BackgroundSession(zipUrl) {[weak self] err in
        self?.dlCallback(err: err, downloadUrl: zipUrl)
      }
      
      log("mark start download for issue in feed \(issue.feed.name)")
      let startDlResult = try await feeder.markStartDownloadAsync(feed: issue.feed,
                                                                  issue: issue,
                                                                  isAutomatically: true,
                                                                  returnOnMain: false)
      self.downloadId = startDlResult.0
      self.downloadStart = startDlResult.1
      
      self.log("downloading to: \(issueDir.path)")
      bgSession.allowMobile = !autoloadOnlyInWLAN
      bgSession.downloadZip(toDir: issueDir.path)
#warning("Change this if ZIPS contain everything!")
      var additionalFiles: [FileEntry] = issue.moment.carouselFiles
      let pages = true ? issue.pages ?? [] : []
#warning("Remove this if ZIPS contain everything!")
      for page in pages {
        if page.isProbablyNotInZip,
            let fileEntry = page.pdf {
          log("download additionalfile for page: \(page.title ?? "-") (\(page.pagina ?? "-")) page frames #: \(page.frames?.count ?? -1) firstFrameUrl: \(page.frames?.first?.link.map { String($0.prefix(8)) } ?? "-")")
          additionalFiles.append(fileEntry)
        }
      }
      
      if autoloadAudio {
        additionalFiles.append(contentsOf: issue.audioFiles)
      }
      
      try additionalFiles.forEach {
        let url = issue.baseUrl.appending("/\($0.fileName)")
        let bgSession = try BackgroundSession(url) {[weak self] err in
          self?.dlCallback(err: err, downloadUrl: zipUrl)
        }
        bgSession.allowMobile = !autoloadOnlyInWLAN
        self.log("downloading \($0.fileName) from: \(url) to: \(issueDir.path)")
        bgSession.download(toDir: issueDir.path)
      }
      autoDownloadedIssuesSinceLastAppUse += 1
      fetchCompletionHandler?(.newData)
    }
    catch {
      log("downloadIssueData error: \(error)")
      feeder = nil
      fetchCompletionHandler?(.noData)
    }
  }
  
  func persist(issue: Issue) {
    ///just for testing
    guard StoredFeeder.get(name: self.currentFeederData.name).first != nil else {
      self.log("no storedFeeder found for \(self.currentFeederData.name)")
      return
    }
    
    let si = StoredIssue.persist(object: issue)
    
    let pd = StoredPublicationDate.new()
    pd.pr.feed = si.pr.feed//!requzired due set is not allowed due circular ref's
    pd.date = issue.date
    pd.validityDate = issue.validityDate
    si.isComplete = true
    ArticleDB.save()
    self.log("issue persisted \(si.date) issueDate in feed: \(pd.feed?.name ?? "-")")
  }
}

fileprivate extension BackgroundDownloadService {
  
  func storeResponseToTemp(data: Data?) {
    guard let data = data else { return }
    let file = File(dir: Dir.tmp.path, fname: "issueData.json")
    file.data = data
  }
}

fileprivate extension BackgroundDownloadGqlFeeder {
  typealias IssueData = (issues: [Issue], data: Data?)
  
  func issues(feed: Feed,
              date: Date? = nil,
              key: String? = nil,
              count: Int = 20,
              isOverview: Bool = false,
              isPages: Bool = false,
              withAudio: Bool = false,
              returnOnMain: Bool = true,
              isBackGround: Bool = false) async throws -> IssueData {
    return try await withCheckedThrowingContinuation { continuation in
      issues(feed: feed, date: date, key: key, count: count,
             isOverview: isOverview, isPages: isPages, withAudio: withAudio,
             returnOnMain: returnOnMain, isBackGround: isBackGround) { result, data in
        switch result {
          case .success(let issues):
            continuation.resume(returning: (issues, data))
          case .failure(let error):
            continuation.resume(throwing: error)
        }
      }
    }
  }
}

fileprivate extension Page {
  var isProbablyNotInZip: Bool {
    if title?.contains("anzeige") == true { return true }
    if title?.contains("bundestalk") == true { return true }
    return false
  }
}
    
