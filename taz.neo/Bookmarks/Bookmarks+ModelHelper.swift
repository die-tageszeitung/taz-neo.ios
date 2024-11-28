//
//  Bookmarks+ModelHelper.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation

extension Bookmarks {
  static func toggle(article: Article, in list: StoredSection? = nil){
    shared.set(article: article, active: !article.hasBookmark, in: list)
  }
  static func set(article: Article, bookmarked:Bool, in list: StoredSection? = nil){
    shared.set(article: article, active: bookmarked, in: list)
  }
}

extension Article {
  var isReducedArticle:Bool {
    baseURL?.lastPathComponent.hasSuffix(".public") == true
    && authors?.isEmpty == true
    && onlineLink == nil
  }
}

extension Article {
  public var hasBookmark: Bool {
    get { return Bookmarks.shared.has(article: self)}
    set { Bookmarks.shared.set(article: self, active: newValue)}
  }
}

extension StoredArticle {
  public var hasBookmark: Bool {
    get { return Bookmarks.shared.has(article: self)}
    set { Bookmarks.shared.set(article: self, active: newValue)}
  }
}

extension Issue {
  public var isBookmarkIssue: Bool {
    return self is StoredIssue && baseUrl == Bookmarks.bookmarkUrl
  }
}

extension PersistentIssue: PersistentObject {
  var isBookmarkIssue: Bool { baseUrl == Bookmarks.bookmarkUrl }
}
