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
  var date: Date { return UsTime(Int64(sTime) ?? 0).date }
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

struct BookmarkArticle {
  var issueDate: Date?
  var serverId: Int?
}

extension GqlFeeder {

  enum BookmarkOperation: String {
    case upload = "Upload"
    case delete = "Delete"
  }

  struct BookmarkSyncResult {
    let article: BookmarkArticle
    let operation: BookmarkOperation
    let error: String?
  }

  /// post new bookmarks and deleted to server
  /// - Returns: array of results (articles, operations, error messages if any)
  func updateRemoteBookmarks(
    newBookmarked: [BookmarkArticle],
    deletedBookmarks: [BookmarkArticle]
  ) async throws -> [BookmarkSyncResult] {

    // MARK: - Check Session
    guard let gqlSession = self.gqlSession else {
      throw fatal("Not connected")
    }

    // MARK: - Build Mutation Parts
    var mutationParts: [String] = []
    var resultMap: [(alias: String, article: BookmarkArticle, op: BookmarkOperation)] = []
    var aliasCounter = 1

    // Upload new bookmarks
    for art in newBookmarked {
      guard let sid = art.serverId else {
        log("Skip upload — article has no serverId (\(art))")
        continue
      }
      guard let issueDate = art.issueDate else {
        log("Skip upload article \(sid) — missing issueDate (cannot build bookmark payload).")
        continue
      }

      let valJson = "{\"date\": \"\(issueDate.ISO8601)\"}".quote()
      let alias = "s\(aliasCounter)"
      aliasCounter += 1

      mutationParts.append("""
        \(alias): saveCustomerData(category: "bookmarks", name: "\(sid)", val: \(valJson)) {
          error
          ok
        }
      """)
      resultMap.append((alias, art, .upload))
    }

    // post removed bookmarks
    for art in deletedBookmarks {
      guard let sid = art.serverId else {
        log("Skip delete — article has no serverId (\(art))", logLevel: .Error)
        continue
      }

      let alias = "d\(aliasCounter)"
      aliasCounter += 1

      mutationParts.append("""
        \(alias): deleteCustomerData(category: "bookmarks", name: "\(sid)") {
          error
          ok
        }
      """)
      resultMap.append((alias, art, .delete))
    }

    // if no changes do not post anything
    if mutationParts.isEmpty {
      log("No bookmark changes to sync (no uploads or deletes).", logLevel: .Error)
      return []
    }

    // MARK: - Build full GraphQL mutation
    let request = """
      \(mutationParts.joined(separator: "\n"))
    """

    // MARK: - Define generic response type
    struct MutationResponse: Decodable {
      var error: String?
      var ok: Bool?
    }

    // MARK: - Execute request
    let responseDict = try await gqlSession.mutation(
      graphql: request,
      type: [String: MutationResponse].self
    )

    // MARK: - Collect results
    var results: [BookmarkSyncResult] = []

    for entry in resultMap {
      let alias = entry.alias
      let article = entry.article
      let operation = entry.op

      if let res = responseDict[alias] {
        if let err = res.error, !err.isEmpty {
          results.append(.init(article: article, operation: operation, error: err))
        } else if res.ok != true {
          results.append(.init(article: article, operation: operation, error: "Unknown server failure"))
        } else {
          results.append(.init(article: article, operation: operation, error: nil))
        }
      } else {
        results.append(.init(article: article, operation: operation, error: "Missing response for alias \(alias)"))
      }
    }
    return results
  }
}
