//
//  BookmarkFeed.swift
//  taz.neo
//
//  Created by Norbert Thies on 16.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib


/// A Feed of bookmarked Articles
public class BookmarkFeed: Feed {
  public var name: String
  public var feeder: Feeder
  public var cycle: PublicationCycle { .unknown }
  public var momentRatio: Float { 1 }
  public var issueCnt: Int { 1 }
  public var lastIssue: Date
  public var firstIssue: Date
  public var issues: [Issue]?
  
  public init(feeder: Feeder) {
    self.feeder = feeder
    self.name = "Bookmarks(\(feeder.title))"
    self.lastIssue = Date()
    self.firstIssue = self.lastIssue
  }
  
  deinit {
    /// Remove temporary files
    guard let issues = self.issues else { return }
    for issue in issues {
      if let sections = issue.sections {
        for section in sections {
          if let tmpFile = section.html as? TmpFileEntry {
            tmpFile.content = nil // removes file
          }
        }
      }
    }
    
  } // BookmarkFeed
  
  public static func allBookmarks(feeder: Feeder) -> BookmarkFeed {
    let bm = BookmarkFeed(feeder: feeder)
    let bmIssue = BookmarkIssue(feed: bm)
    let bmSection = BookmarkSection(name: "Lesezeichen",
                                    html: TmpFileEntry(name: "allBookmarks"))
    bm.issues = [bmIssue]
    bmIssue.sections = [bmSection]
    bmSection.articles = StoredArticle.bookmarkedArticles()
    //#warning("ToDo: 0.9.4+ @Ringo: Build Section-HTML here")
    /// compute HTML and store it in html
    let html = "..."
    let tmpFile = bmSection.html as! TmpFileEntry
    tmpFile.content = html
    return bm
  }
}

/// An Issue of Sections of bookmarked Articles
public class BookmarkIssue: Issue {
  public var isDownloading: Bool { get { false } set {} }
  public var isComplete: Bool { get { false } set {} }
  public var feed: Feed
  public var date: Date
  public var moTime: Date
  public var isWeekend: Bool { false }
  public var moment: Moment { DummyMoment() }
  public var key: String? { nil }
  public var baseUrl: String { "" }
  public var status: IssueStatus { .unknown }
  public var minResourceVersion: Int { 0 }
  public var zipName: String? { nil }
  public var zipNamePdf: String? { nil }
  public var imprint: Article? { nil }
  public var sections: [Section]?
  public var pages: [Page]? { nil }
  public var lastSection: Int? { get { nil } set {} }
  public var lastArticle: Int? { get { nil } set {} }
  public var lastPage: Int? { get { nil } set {} }
  public var payload: Payload { DummyPayload() }
  
  init(feed: Feed) {
    self.feed = feed
    self.date = Date()
    self.moTime = self.date 
  }
}

/// A Section of bookmarked Articles
public class BookmarkSection: Section {
  public var name: String
  public var extendedTitle: String? { nil }
  public var type: SectionType { .articles }
  public var articles: [Article]?
  public var navButton: ImageEntry? { nil }
  public var html: FileEntry
  public var images: [ImageEntry]? { nil }
  public var authors: [Author]? { nil }
  
  public init(name: String, html: FileEntry) {
    self.name = name
    self.html = html
  }
}

/// A temporary file entry
public class TmpFileEntry: FileEntry {
  public var name: String
  public var storageType: FileStorageType { .unknown }
  public var moTime: Date
  public var size: Int64 { 0 }
  public var sha256: String { "" }
  public var path: String
  
  /// Read/write access to contents of file
  public var content: String? {
    get { File(path).string }
    set {
      if let content = newValue { File(path).string = content }
      else { File(path).remove() }
    }
  }
  
  public init(name: String) {
    self.name = name
    Dir.searchResults.create()
    self.path = "\(Dir.searchResultsPath)/\(name)"
    self.moTime = Date()
  }
}

open class DummyPayload: Payload {
  public var localDir: String { "" }
  public var remoteBaseUrl: String { "" }
  public var remoteZipName: String? { nil }
  public var files: [FileEntry] { [] }
  public var issue: Issue? { nil }
  public var resources: Resources? { nil }
}

public class DummyMoment: Moment {
  public var images: [ImageEntry] { [] }
  public var creditedImages: [ImageEntry] { [] }
  public var animation: [FileEntry] { [] }
}

public class DummyIssue: BookmarkIssue {
  public func baseUrlForFiles(_ files: [FileEntry]) -> String {
    guard let s = search,
          let f = files.first,
          let hits = s.searchHitList else { return "" }
    for hit in hits {
      for file in hit.article.files {
        if file.fileName == f.fileName {
          hit.writeToDisk()//TOO LATE
          return hit.baseUrl
        }
      }
    }
    return ""
  }
  public var search:SearchItem?
}
