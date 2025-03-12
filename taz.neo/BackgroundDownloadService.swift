//
//  BackgroundDownloadService.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.03.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

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
  
//  var dlCallback: (Error?)->()
//  static var dlCallback: (Error?)->() {
//    get { return (UIApplication.shared.delegate as! AppDelegate).dlCallback }
//    set { (UIApplication.shared.delegate as! AppDelegate).dlCallback = newValue }
//  }
  
  static func dlCallback(err: Error?) {
    if let err { Self.shared.log("Error in download: \(err)") }
    else { Self.shared.log("Download successful") }
  }
  
//  private func dlCallback(err: Error?) {
//    if let err { log("Error in download: \(err)") }
//    else { log("Download successful") }
//  }
  
  
  fileprivate var currentFeederData : (name: String, url: String, feed: String)
  //  = Defaults.currentFeeder
  = (name: "taz-test", url: "https://dl.taz.de/appGraphQl", feed: "taz")
  
  fileprivate var feeder: BakgroundDownloadGqlFeeder?
  
  fileprivate var downloadingIssues: [Issue] = []
  
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
  func dlCallback(err: Error?) {
    log("dlCallback called...")
    if let err = err {
      log("Failed to Download with err: \(err)")
      return
    }
    
#warning("Use the right one!")
    guard let issue = downloadingIssues.pop() else {
      log("Download succeed but no issue to persist!")
      return
    }
    
    onMain {
      if ArticleDB.singleton == nil {
        //self.currentFeeder.name
        ArticleDB(name: "taz-test") { [weak self] _ in
          self?.persist(issue: issue)
        }
      }
      else {
        self.persist(issue: issue)
      }
    }
  }
  
  public static func checkForNewIssue() {
    print("...static checkForNewIssue requested")
    let semaphore = DispatchSemaphore(value: 0)
    
    Task {
      print("...static checkForNewIssue  do")
      await BackgroundDownloadService.shared.checkForNewIssue()
      print("...static checkForNewIssue done")
      semaphore.signal()
    }
    semaphore.wait()
  }
  
  private func checkForNewIssue() async {
    do {
      log("...checkForNewIssue")
      let token = SimpleAuthenticator.getUserData().token
      
      guard (token?.length ?? 0) > 10 else {
        throw BackgroundDownloadError("No token available! Token: \(token ?? "N/A")")
      }
      
      if feeder == nil {
        log("...create feeder")
        feeder = BakgroundDownloadGqlFeeder(title: currentFeederData.name,
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
      let date = Date(timeIntervalSinceNow: -60*60*24*1)
      log("...fetch latest issue")
      let issueData = try await feeder.issues(feed: feed,
                                              date: date,
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
      
      downloadingIssues.append(issue)
      let issueDir = issue.dir
      if !issueDir.exists {
        issueDir.create()
        let rlink = File(dir: issueDir.path, fname: "resources")
        let glink = File(dir: issueDir.path, fname: "global")
        if !rlink.isLink { rlink.link(to: feeder.resourcesDir.path) }
        if !glink.isLink { glink.link(to: feeder.globalDir.path) }
      }
      
      let bgSession = try BackgroundSession(zipUrl) {[weak self] err in
        self?.dlCallback(err: err)
      }
      
      self.log("downloading to: \(issueDir.path)")
      bgSession.downloadZip(toDir: issueDir.path)
      
      try issue.moment.carouselFiles.forEach {
        let url = issue.baseUrl.appending("/\($0.fileName)")
        let bgSession = try BackgroundSession(url) {[weak self] err in
          self?.dlCallback(err: err)
        }
        self.log("downloading \($0.fileName) from: \(url) to: \(issueDir.path)")
        bgSession.download(toDir: issueDir.path)
      }
    }
    catch {
      log("downloadIssueData error: \(error)")
      feeder = nil
    }
  }
  
  func persist(issue: Issue) {
    ///just for testing
    guard let storedFeeder =  StoredFeeder.get(name: self.currentFeederData.name).first else {
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

fileprivate extension BakgroundDownloadGqlFeeder {
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
