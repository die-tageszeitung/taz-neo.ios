//
//  GQLFeeder+BookmarksSync.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import Foundation
import NorthLib

/// One Bookmark entry from customerDataList (category == "bookmarks")
class GqlBookmarkCustomerData: GQLObject {
  var sTime: String        // raw timestamp string from server (e.g. "1760541336")
  var date: Date { return UsTime(iso: sTime, tz: GqlFeeder.tz).date }
  var category: String          // should be "bookmarks"
  var mediaSyncId: String       // "name" field in GQL (ID of the bookmarked media)
  var issueDate: Date           // parsed from val JSON ({"date":"2025-10-15"})


  enum CodingKeys: String, CodingKey {
    case sTime
    case category
    case mediaSyncId
    case val
  }

  enum DecodeError: Error, LocalizedError {
    case invalidValJSON
    case missingDateField
    case invalidDateFormat(String)

    var errorDescription: String? {
      switch self {
      case .invalidValJSON:
        return "val field is not valid JSON."
      case .missingDateField:
        return "val JSON missing required 'date' field."
      case .invalidDateFormat(let str):
        return "Invalid date format in val JSON: \(str)"
      }
    }
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    sTime = try container.decode(String.self, forKey: .sTime)
    category = try container.decode(String.self, forKey: .category)
    mediaSyncId = try container.decode(String.self, forKey: .mediaSyncId)

    // Parse issueDate from val JSON string
    let valString = try container.decode(String.self, forKey: .val)

    guard let data = valString.data(using: .utf8) else {
      throw DecodeError.invalidValJSON
    }
    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else {
      throw DecodeError.invalidValJSON
    }
    guard let dateStr = json["date"] else {
      throw DecodeError.missingDateField
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let parsedDate = formatter.date(from: dateStr) else {
      throw DecodeError.invalidDateFormat(dateStr)
    }
    issueDate = parsedDate
  }

  static var fields = """
    sTime: time
    category
    mediaSyncId: name
    val
  """

  func toString() -> String {
    """
      [Bookmark]
      mediaSyncId: \(mediaSyncId)
      issueDate:   \(issueDate)
      bookmarketTime:  \(date.dateAndTime)
      category:    \(category)
    """
  }
}

extension GqlFeeder {
  func loadBookmarks() async throws -> [GqlBookmarkCustomerData] {
   
    // MARK: - GQL Response Structs
    struct BookmarkResponse: Decodable {
      var error: String?
      var customerDataList: [GqlBookmarkCustomerData]?
      var authInfo: GqlAuthInfo
    }
//    // MARK: - GQL Response Structs
//    struct BookmarkResponseData: Decodable {
//      var data: BookmarkResponse
//    }
//    
//    // MARK: - GQL Response Structs
//    struct BookmarkResponse: Decodable {
//      var getCustomerData: BookmarkLoading
//    }
//    
//    struct BookmarkLoading: Decodable {
//      var error: String?
//      var customerDataList: [GqlBookmarkCustomerData]?
//      var authInfo: GqlAuthInfo
//    }

    // MARK: - Request Builder
    let request = """
      bookmarks:getCustomerData(category: "bookmarks", name: "*") {
          error
          customerDataList { \(GqlBookmarkCustomerData.fields) }
          authInfo { \(GqlAuthInfo.fields) }
        }
    """

    // MARK: - Session Check
    guard let gqlSession = self.gqlSession else {
      throw fatal("Not connected")
    }

    // MARK: - Await GraphQL Query
    let responseDict = try await gqlSession.query(
      graphql: request,
      type: [String: BookmarkResponse].self
    )

    // MARK: - Extract Response
    guard let response = responseDict["bookmarks"] else {
      throw fatal("Missing 'data' node in GraphQL response")
    }

    if let err = response.error, !err.isEmpty {
      throw fatal("Server error: \(err)")
    }

    return response.customerDataList ?? []
  }
}

extension GqlFeeder {
  
  

  func loadBookmarksOLD(finished: @escaping (Result<[GqlBookmarkCustomerData], Error>) -> ()) {
    
    // MARK: - GQL Response Structs
    struct BookmarkResponse: Decodable {
      var error: String?
      var customerDataList: [GqlBookmarkCustomerData]?
      var authInfo: GqlAuthInfo
    }
    
    struct BookmarkLoading: Decodable {
      var error: String?
      var customerDataList: [GqlBookmarkCustomerData]?
      var authInfo: GqlAuthInfo
    }

    // MARK: - Request Builder
    let request = """
        getCustomerData(category: "bookmarks", name: "*") {
          error
          customerDataList { \(GqlBookmarkCustomerData.fields) }
          authInfo { \(GqlAuthInfo.fields) }
        }
    """

    // MARK: - GraphQL Session Check
    guard let gqlSession = self.gqlSession else {
      finished(.failure(fatal("Not connected")))
      return
    }

    // MARK: - Perform Query
    gqlSession.query(graphql: request, type: [String: BookmarkResponse].self) {[weak self] (result, _) in
      guard let self = self else { return }
      switch result {
      case .success(let response):
        // GraphQL responses are typically keyed under "data"
        guard let res = response["getCustomerData"] else {
          finished(.failure(fatal("Missing 'data' node in GraphQL response")))
          return
        }

        if let err = res.error, !err.isEmpty {
          finished(.failure(fatal("Server error: \(err)")))
        } else {
          finished(.success(res.customerDataList ?? []))
        }

      case .failure(let error):
        finished(.failure(error))
      }
    }
  }
}
