//
//  BackgroundDownloadService+JsonData.swift
//  taz.neo
//
//  Created by Ringo Müller on 16.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

extension BackgroundDownloadService {
  
  /// Loads feed from JSON file
  func loadFeedFromJsonFile(feederContext: FeederContext,
                            feedName: String,
                            issueDateKey: String) async throws -> Feed {
    let feedPath = feederContext.storedFeeder.feedDir(feedName).path
    let filePath = "\(feedPath)/\(issueDateKey)/\(BackgroundDownloadService.jsonDataFilename)"
    let file = File(filePath)
    log("Loading feed from JSON file: \(filePath)")
    guard file.exists else {
      throw BackgroundDownloadError("File \(filePath) does not exist.")
    }
    
    let response = try await feederContext.gqlFeeder.gqlSession?.query(
      graphql: "",
      type: [String: GqlFeeder.FeedRequest].self,
      fromData: file.data
    )
    
    guard let frqResponse = response?["feedRequest"] else {
      throw BackgroundDownloadError("FEHLER: 'feedRequest' not found in saved response.")
    }
    
    guard let feed = frqResponse.feeds.first else {
      throw BackgroundDownloadError("FEHLER: No feed found in saved response.")
    }
    
    // Set references like done in GqlFeeder.Feeder.feedWithIssues
    feed.gqlFeeder = feederContext.gqlFeeder
    
    for issue in feed.issues ?? [] {
      issue.feed = feederContext.defaultFeed
      (issue as? GqlIssue)?.setPayload(
        feeder: feederContext.gqlFeeder,
        isPages: Defaults.autoloadPdfOrFacsimile,
        withAudio: self.autoloadAudio
      )
      
      for section in (issue.sections as? [GqlSection]) ?? [] {
        section.primaryIssue = issue
        
        if let articles = section.articles as? [GqlArticle] {
          for article in articles {
            article.primaryIssue = issue
          }
        }
      }
    }
    log("Found \(feed.issues?.count ?? 0) issues and \(feed.publicationDates?.count ?? 0) publicationDates in JSON file.")
    return feed
  }
}

fileprivate extension GraphQlSession {
  /// Async wrapper for `query`, preserving generic decoding.
  func query<T: Decodable>(
    graphql: String,
    type: T.Type,
    fromData: Data? = nil,
    returnOnMain: Bool = true
  ) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      self.query(graphql: graphql, type: type, fromData: fromData, returnOnMain: returnOnMain) { result, _ in
        switch result {
          case .success(let value):
            continuation.resume(returning: value)
          case .failure(let error):
            continuation.resume(throwing: error)
        }
      }
    }
  }
}
