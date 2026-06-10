//
//  Bookmarks+ModelExtensions.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit

extension Bookmarks {
  static func toggle(article: Article, in list: StoredSection? = nil){
    shared.set(article: article, active: !article.hasBookmark, in: list)
  }
  static func set(article: Article, bookmarked:Bool, in list: StoredSection? = nil){
    shared.set(article: article, active: bookmarked, in: list)
  }
}

extension Article {
  /// Determines if the article is a reduced version.
  var isReducedArticle:Bool {
    baseURL?.lastPathComponent.hasSuffix(".public") == true
    && authors?.isEmpty == true
    && onlineLink == nil
  }
}

extension Article {
  /// Bookmark status for the article.
  var hasBookmark: Bool {
    get { return Bookmarks.shared.has(article: self)}
    set { Bookmarks.shared.set(article: self, active: newValue)}
  }
 
  var bookmarkIconName: String? {
    if self.articleType == .podcast { return nil }
    return hasBookmark ? "star-fill" : "star"
  }
  
  var bookmarkIcon: UIImage? {
    guard let name = bookmarkIconName else { return nil }
    return UIImage(named: name)
  }
}

extension StoredArticle {
  ///Duplication required for hasBookmark.toggle in ContentVC
  var hasBookmark: Bool {
    get { return Bookmarks.shared.has(article: self)}
    set { Bookmarks.shared.set(article: self, active: newValue)}
  }
}

extension Issue {
  /// Checks if the issue is the bookmark issue.
  var isBookmarkIssue: Bool {
    guard let self = self as? StoredIssue else { return false }
    return self.pr.baseUrl == Bookmarks.bookmarkURL
  }
}

extension PersistentIssue: PersistentObject {
  var isBookmarkIssue: Bool { baseUrl == Bookmarks.bookmarkURL }
}

// MARK: - Sorting Helper

extension Array where Element == StoredArticle {
  
  /// Sorts articles based on issue dates, section orders and article order
  func bookmarkOrder() -> Self {
    self.sorted(by: {
      // 1st. issue dates
      if $0.issueDate?.issueKey != $1.issueDate?.issueKey {
        return $0.issueDate?.ISO8601 ?? "0" > $1.issueDate?.ISO8601 ?? "1"
      }
      // 2nd. sections order
      let section0MinOrder
      = $0.nonBookmarkSections.map { Int($0.pr.order) }.min() ?? Int.max
      let section1MinOrder
      = $1.nonBookmarkSections.map { Int($0.pr.order) }.min() ?? Int.max
      
      if section0MinOrder != section1MinOrder {
        return section0MinOrder < section1MinOrder
      }
      // 3rd. Article Order
      return $0.pr.order < $1.pr.order
    })
  }
}
