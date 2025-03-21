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

class BackgroundDownloadGqlFeeder: GqlFeeder, IssueDownloaderDelegate {
  func didFinishAllDownloads(error: (any Error)?) {
    log("...didFinishAllDownloads")
  }
  
  @discardableResult
  public func updateStatus() async throws -> Feeder {
    let sess = self.gqlSession
    if let sess =  sess {
      log("...updateStatus with \(sess.isBackground ? "BG" : "FG") session")
    }
    else {
      log("...updateStatus with currently no session")
    }
    
    return try await withCheckedThrowingContinuation { continuation in
      self.log("....do updateStatus with await")
      updateStatus(loadAllPublicationDates: false) { [weak self] result in
        self?.log("...updateStatus done with result: \(result)")
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

extension BackgroundDownloadGqlFeeder {
  func markStartDownloadAsync(feed: Feed, issue: Issue, isAutomatically: Bool, returnOnMain: Bool) async throws -> (String?, UsTime) {
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
}
