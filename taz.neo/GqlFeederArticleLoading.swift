//
//  GqlFeederArticleLoading.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// One Article of an Issue
class GqlSingleArticle: GQLObject, DoesLog {
  var gqlArticle: GqlArticle
  /// Name of section
  var sectionTitle: String?
  /// date of original issue
  var sIssueDate: String
  var issueDate: Date { return UsTime(iso: sIssueDate, tz: GqlFeeder.tz).date }
  var baseUrl: String
  
  enum CodingKeys: String, CodingKey {
    case gqlArticle
    case sectionTitle
    case sIssueDate
    case baseUrl
  }
  
  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    gqlArticle = try container.decode(GqlArticle.self, forKey: .gqlArticle)
    sectionTitle = try container.decodeIfPresent(String.self, forKey: .sectionTitle)
    baseUrl = try container.decode(String.self, forKey: .baseUrl)
    sIssueDate = try container.decode(String.self, forKey: .sIssueDate)
  }
  
  static var fields = """
    gqlArticle:article { \(GqlArticle.fieldsMinimum) }
    sectionTitle
    sIssueDate: date
    baseUrl
  """
  
  func toString() -> String {
    """
      gqlArticle:  \(gqlArticle.toString())
      sectionTitle:  \(sectionTitle ?? "-")
      date: \(issueDate.short)
      baseUrl:   \(baseUrl)
    """
  }
}


extension GqlFeeder {
  func loadArticles(_ articles: [Article],
                    finished: @escaping (Result<[GqlSingleArticle], Error>) -> ()) {
    
    struct ArticleLoading: Decodable {
      var authInfo: GqlAuthInfo
      var articleList: [GqlSingleArticle]?
      
      static func request(_ articles: [Article]) -> String{
        let mediaSyncIds = articles
          .compactMap { $0.serverId }
          .map { String($0) }
          .joined(separator: ", ")
        // GraphQL Query
        return """
              articleLoading: getArticlesByMediaSyncId(mediaSyncIds: "\(mediaSyncIds)") {
                authInfo { \(GqlAuthInfo.fields) }
                articleList { \(GqlSingleArticle.fields) }
              }
            """
      }
    }
    
    // GraphQL Session
    guard let gqlSession = self.gqlSession else {
      finished(.failure(fatal("Not connected"))); return
    }
    
    let request = ArticleLoading.request(articles)
    
    gqlSession.query(graphql: request, type: [String:ArticleLoading].self) { (result, _) in
      switch result {
        case .success(let response):
          finished(.success((response["articleLoading"])?.articleList ?? []))
        case .failure(let error):
          finished(.failure(error))
      }
    }
  }
}


extension GqlFeeder {
  func loadArticles(withMediaSyncIds mediaSyncIds: [String]) async throws -> [GqlSingleArticle] {
    
    struct ArticleLoading: Decodable {
      var authInfo: GqlAuthInfo
      var articleList: [GqlSingleArticle]?
      
      static func request(mediaSyncIds: [String]) -> String {
        """
        articleLoading: getArticlesByMediaSyncId(mediaSyncIds: "\(mediaSyncIds.joined(separator: ", "))") {
          authInfo { \(GqlAuthInfo.fields) }
          articleList { \(GqlSingleArticle.fields) }
        }
        """
      }
    }
    
    // MARK: - GraphQL Session Check
    guard let gqlSession = self.gqlSession else {
      throw fatal("Not connected")
    }
    
    // MARK: - Request Build
    let request = ArticleLoading.request(mediaSyncIds: mediaSyncIds)
    
    // MARK: - Await Query
    let responseDict = try await gqlSession.query(
      graphql: request,
      type: [String: ArticleLoading].self
    )
    
    // MARK: - Extract Results
    guard let articleLoading = responseDict["articleLoading"] else {
      throw fatal("Missing 'articleLoading' in GraphQL response")
    }
    
    return articleLoading.articleList ?? []
  }
}
