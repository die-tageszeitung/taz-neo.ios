//
//  BackgroundDownloadService.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.03.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

class BackgroundDownloadService: DoesLog {
  
  private var currentFeeder : (name: String, url: String, feed: String)
//  = Defaults.currentFeeder
  = (name: "taz-test", url: "https://dl.taz.de/appGraphQl", feed: "taz")
  
  var feeder: BakgroundDownloadGqlFeeder
  static let shared = BackgroundDownloadService()
  
  private init() {
    let token = SimpleAuthenticator.getUserData().token
    feeder = BakgroundDownloadGqlFeeder(title: currentFeeder.name,
                         url: currentFeeder.url,
                         token: token)
  }
}

extension BackgroundDownloadService {
  
  var feed: Feed? {
    return feeder.feeds.first { $0.name == currentFeeder.feed }
  }
  
  func checkForNewIssue() async {
    do {
      guard let feed = feed else {
        throw BackgroundDownloadError("No Feed. Is BackgroundDownloadService feeder initialized?")
      }
      let issueData = await fetchLatestIssues(feed)
      guard let issue = issueData?.issues.first else {
        throw BackgroundDownloadError("Fetch Issue failed!")
      }
      ///maybe not required & if killed, do it with a task! own subclass of task, maybe persist db at first then just copy/add files
      storeResponseToTemp(data: issueData?.data)
      try await feeder.downloadIssueData(issue: issue)
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
        
        

//        let defaultFeed = StoredFeed.get(name: self.currentFeeder.name, inFeeder: storedFeeder).first
//        storedFeeder.is
//        defaultFeed?.lastIssue = issue.date
      }
    }
    catch {
      log("downloadIssueData error: \(error)")
    }
  }
  
  func persist(issue: Issue) {
    ///just for testing
    guard let storedFeeder =  StoredFeeder.get(name: self.currentFeeder.name).first else {
      self.log("no storedFeeder found for \(self.currentFeeder.name)")
      return
    }
    
    let si = StoredIssue.persist(object: issue)
    let pd = StoredPublicationDate.new()
    pd.date = issue.date
    pd.validityDate = issue.validityDate
    si.isComplete = true
    ArticleDB.save()
    self.log("issue persisted \(si.date)")
  }
    
  
}

fileprivate extension BackgroundDownloadService {
  
  func fetchLatestIssues(_ feed: Feed) async -> BakgroundDownloadGqlFeeder.IssueData? {
    do {
      let withPages = false
      let withAudio = false
      let date = Date(timeIntervalSinceNow: -60*60*24*1)
      return try await feeder.issues(feed: feed,
                                     date: date,
                                     count: 1,
                                     isPages: withPages,
                                     withAudio: withAudio, returnOnMain: false)
    }
    catch {
      log("checkForNewIssue error: \(error)")
      return nil
    }
  }
  
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
