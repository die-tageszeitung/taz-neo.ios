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
public class BookmarkFeed: Feed, DoesLog {
  public var name: String
  public var feeder: Feeder
  public var cycle: PublicationCycle { .unknown }
  public var momentRatio: Float { 1 }
  public var issueCnt: Int { 1 }
  public var lastIssue: Date
  public var firstIssue: Date
  public var issues: [Issue]?
  public var dir: Dir { feeder.baseDir }
  /// total number of bookmarks
  public var count: Int = 0
  
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
  }
  
  // HTML header
  static var htmlHeader = """
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE html>
  <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de" lang="de">
  <head>
  <meta name="generator" content="taz E-Book Generator Version 3.000"/>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <meta http-equiv="cache-control" content="no-cache"/>
  <meta http-equiv="expires" content="0"/>
  <meta http-equiv="pragma" content="no-cache"/>
  <title>section.277349.html</title>
    <link rel="stylesheet" type="text/css" href="resources/base.css"> </link>
    <link rel="stylesheet" type="text/css" href="resources/base2017.css"> </link>
  <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0"/>
    <link rel="stylesheet" type="text/css" href="resources/platform.css"> </link>
    <script src="resources/jquery-3.min.js" type="text/javascript" charset="utf-8" language="javascript"> </script>
    <script src="resources/tazApi.js" type="text/javascript" charset="utf-8" language="javascript"> </script>
    <script src="resources/setupApp.js" type="text/javascript" charset="utf-8" language="javascript"> </script>
    <link rel="stylesheet" type="text/css" href="resources/ressort.css"> </link>
    <link rel="stylesheet" type="text/css" href="resources/tazApi.css"> </link>
    <link rel="stylesheet" type="text/css" href="resources/tazApiSection.css"> </link>
  </head>
  """
  
  /// Get all authors as String with HTML markup
  public func getAuthors(art: Article) -> String {
    var ret = ""
    if let authors = art.authors {
      guard authors.count > 0 else { return "" }
      let n = authors.count - 1
      for i in 0...n {
        if let name = authors[i].name {
          ret += name
          if i != n { ret += ", " }
        }
      }
    }
    return "<p class=\"VerzeichnisAutor\">\(ret)</p>"
  }
  
  /// Generate HTML for given Section
  public func genHtml(section: BookmarkSection) {
    if let articles = section.articles as? [StoredArticle] {
      var html = """
      \(BookmarkFeed.htmlHeader)
      <body>
      """
      for art in articles {
        let issues = art.issues
        if issues.count > 0 {
          html += """
            <div id="content">
            <a href="\(art.path)" class="RessortDiv">
              <div class="VerzeichnisArtikel eptPolitik">
                <h2 class="Titel">\(art.title ?? art.html.name)</h2>
                <h4 class="Unterzeile">\(art.teaser ?? "")</h4>
                \(getAuthors(art: art))
                <div class="VerzeichnisArtikelEnde"/>
              </div>
            </a>
            </div>
          """
        }
      }
      html += "</body>\n</html>\n"
      let tmpFile = section.html as! TmpFileEntry
      tmpFile.content = html
    }
  }
  
  /// Generate HTML for all Sections
  public func genAllHtml() {
    if let issues = self.issues {
      for issue in issues {
        if let sections = issue.sections {
          for section in sections {
            if let section = section as? BookmarkSection
            { self.genHtml(section: section) }
          }
        }
      }
    }
  }
  
  /// Load all bookmarks into single Section
  public func loadAllBookmmarks() {
    if let issues = issues, issues.count > 0,
       let sections = issues[0].sections, sections.count > 0 {
      let section = sections[0] as! BookmarkSection
      let allArticles = StoredArticle.bookmarkedArticles()
      count = allArticles.count
      section.articles = allArticles
    }
  }
  
  /// Return BookmarkFeed consisting of one Section with all bookmarks
  public static func allBookmarks(feeder: Feeder) -> BookmarkFeed {
    let bm = BookmarkFeed(feeder: feeder)
    let bmIssue = BookmarkIssue(feed: bm)
    let bmSection = BookmarkSection(name: "Leseliste", issue: bmIssue,
        html: TmpFileEntry(feed: bm, name: "allBookmarks.html"))
    bm.issues = [bmIssue]
    bmIssue.sections = [bmSection]
    bm.loadAllBookmmarks()
    bm.genHtml(section: bmSection)
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
  public var dir: Dir { feed.dir }
  
  init(feed: Feed) {
    self.feed = feed
    self.date = Date()
    self.moTime = self.date 
  }
}

/// A Section of bookmarked Articles
public class BookmarkSection: Section {
  public var name: String
  public var extendedTitle: String? { name }
  public var type: SectionType { .articles }
  public var articles: [Article]?
  public var navButton: ImageEntry? { nil }
  public var html: FileEntry
  public var images: [ImageEntry]? { nil }
  public var authors: [Author]? { nil }
  public var primaryIssue: Issue
  
  public init(name: String, issue: Issue, html: FileEntry) {
    self.name = name
    self.primaryIssue = issue
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
  
  public init(feed: BookmarkFeed, name: String) {
    self.name = name
    self.path = "\(feed.dir.path)/\(name)"
    self.moTime = Date()
  }
}

public class DummyPayload: Payload {
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
