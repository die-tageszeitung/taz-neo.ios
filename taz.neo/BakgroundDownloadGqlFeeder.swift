//
//  BakgroundDownloadGqlFeeder.swift
//  taz.neo
//
//  Created by Ringo Müller on 03.03.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//


import Foundation
import NorthLib
import UIKit

struct BackgroundDownloadError: Error {
  let message: String
  
  init(_ parts: String...) {
    self.message = parts.joined(separator: " ")
  }
  
  var localizedDescription: String {
    return message
  }
}

class BakgroundDownloadGqlFeeder: GqlFeeder, IssueDownloaderDelegate {
  func didFinishAllDownloads(error: (any Error)?) {
    log("didFinishAllDownloads")
  }
  
  @discardableResult
  public func updateStatus() async throws -> Feeder {
    let sess = self.gqlSession
    if let sess =  sess {
      log ("updateStatus with \(sess.isBackground ? "BG" : "FG") session")
    }
    else {
      log ("updateStatus with currently no session")
    }
    
    return try await withCheckedThrowingContinuation { continuation in
      updateStatus(loadAllPublicationDates: false) { [weak self] result in
        self?.log ("updateStatus done with result: \(result)")
        switch result {
          case .success(let feeder):
            continuation.resume(returning: feeder)
          case .failure(let error):
            continuation.resume(throwing: error)
        }
      }
    }
  }
  
  /// backing var for backgroundSession
  private var _backgroundSession: URLSession?
  /// backing var for downloader
  private var _dloader: IssueDownloader?
  
  private var fetchCompletionHandler: FetchCompletionHandler?
  /// the Downloader to use
  var downloader: IssueDownloader?
  
  /// Initilialize with name/title and URL of GraphQL server
  required public init(title: String,
                       url: String,
                       token: String?) {
    super.init(title: title, url: url, token: token)
    gqlSession?.isBackground = true
    gqlSession?._session = nil
  }
}

extension BakgroundDownloadGqlFeeder {
  
  private func doDownloadIssueData(issue: Issue)  async throws -> URL {
    guard let zipName = issue.requiredZipName else {
      throw BackgroundDownloadError("No zipName found for issue", issue.date.short)
    }
    guard let zipUrl = URL(string: issue.baseUrl.appending("/\(zipName)")) else {
      throw BackgroundDownloadError("No valid Zip URL for: ", issue.baseUrl+"/"+zipName)
    }
    let authKey = SimpleAuthenticator.getUserData().token ?? ""///No errr
    ///
    debug("Try to Download: \(zipUrl) \nwith:\n\(authKey)")
    if downloader == nil {
      downloader = IssueDownloader(authKey: authKey, isBackground: false)
      downloader?.delegate = self
    }
    let issueDir = issue.dir
    downloader?.download(files: [], toDir: issueDir)
#warning("Placeholder toDo!")
    return URL(fileURLWithPath: "")
  }
  
  
  func downloadIssueData(issue: Issue) async throws {
    let feed = issue.feed
    log("download issue zip for date: \(issue.date.short)")
    let (dlId, tstart) = try await markStartDownloadAsync(feed: feed, issue: issue, isAutomatically: true, returnOnMain: false)
    let tmpZipUrl = try await doDownloadIssueData(issue:issue)
    await markStopDownloadAsync(dlId: dlId, tstart: tstart, returnOnMain: false)
    try extractDownloadedZip(zipURL: tmpZipUrl, issueDir: issue.dir)
  }
  
#warning("Wo packe ich es hin? ins issue verzeichniss oder in ein DownloadTempVerzeichniss")
  private func extractDownloadedZip(zipURL: URL, issueDir: Dir) throws {
    debug("extracting zip to \(issueDir.path)")
    if true || !issueDir.exists {
      issueDir.create()
      let rlink = File(dir: issueDir.path, fname: "resources")
      let glink = File(dir: issueDir.path, fname: "global")
      if !rlink.isLink { rlink.link(to: self.resourcesDir.path) }
      if !glink.isLink { glink.link(to: self.globalDir.path) }
    }
    
    let zfile = ZipFile(path: zipURL.path)
    try zfile.unpack(toDir: issueDir.path)
  }
  
  private func markStartDownloadAsync(feed: Feed, issue: Issue, isAutomatically: Bool, returnOnMain: Bool) async throws -> (String?, UsTime) {
    let pushToken = Defaults.lastKnownPushToken
    let isPush = pushToken != nil
    debug("Sending start of download to server")
    
    return try await withCheckedThrowingContinuation { continuation in
      startDownload(feed: feed, issue: issue, isPush: isPush, pushToken: pushToken, isAutomatically: isAutomatically, returnOnMain: returnOnMain) { res in
        switch res {
          case .success(let value):
            continuation.resume(returning: (value, UsTime.now))
          case .failure(let error):
            continuation.resume(throwing: error) // Fehler wird weitergereicht
        }
      }
    }
  }
  
  private func markStopDownloadAsync(dlId: String?, tstart: UsTime, returnOnMain: Bool) async {
    guard let dlId = dlId else { return }
    return await withCheckedContinuation { [weak self] continuation in
      let nsec = UsTime.now.timeInterval - tstart.timeInterval
      self?.debug("Sending stop of download to server")
      self?.stopDownload(dlId: dlId, seconds: nsec, returnOnMain: returnOnMain) { _ in
        continuation.resume()
      }
    }
  }
}

class BGDownloadManager: DoesLog {
  
  var currentFeeder : (name: String, url: String, feed: String)
  = Defaults.currentFeeder
  
  var feeder: BakgroundDownloadGqlFeeder
  static let shared = BGDownloadManager()
  
  var latestIssue: Issue?
  
  var feed: Feed? {
    return feeder.feeds.first { $0.name == currentFeeder.feed }
  }
  
  private init() {
    feeder = BakgroundDownloadGqlFeeder(title: currentFeeder.name,
                                        url: currentFeeder.url,
                                        token: SimpleAuthenticator.getUserData().token)
    feeder.updateStatus { [weak self] res in
      self?.log("updateStatus done with \(res)")
    }
  }
  
  func fetchLatestIssue() {
    guard let feed = feed else {
      log("no matching feed found for \(currentFeeder.feed)")
      return
    }
    let withPages = false
    let withAudio = false
    feeder.issues(feed: feed,
                  count: 1,
                  isPages: withPages,
                  withAudio: withAudio,
                  returnOnMain: false) { [weak self] (res, data) in
      switch res {
        case .success(let issues):
          guard let issue = issues.first else {
            self?.log("no issue found")
            return
          }
          //          self?.saveIssueData(issue, data: data)
          ///save issue json to persist it to db later OR direct persist in db
          self?.persist(issue: issue)
          self?.latestIssue = issue
          //          self?.log("latestIssue: \(issue)")
          //          self?.dow
        case .failure(let error):
          self?.log("issueFetch done with \(error)")
      }
    }
  }
  
  ///save issue json to persist it to db later
  private func saveIssueData(_ issue: Issue, data: Data?) {
    guard let data = data else {
      log("no data for issue \(issue)")
      return
    }
    ///save issue json to persist it to db later
    let file = File(dir: issue.dir.path, fname: "issueData.json")
    file.data = data
  }
  
  ///or direct persist in db
  func persist(issue: Issue) {
    guard let feed = feed as? StoredFeed else {
      log("no matching feed found for \(currentFeeder.feed)")
      return
    }
    let si = StoredIssue.get(date: issue.date, inFeed: feed)
    if let sIssue = si.first {
      sIssue.update(from: issue)
    }
    else {
      StoredIssue.persist(object: issue)
    }
  }
}

fileprivate extension Issue {
  var requiredZipName: String? { Defaults.autoloadPdf ? zipNamePdf : zipName }
}
