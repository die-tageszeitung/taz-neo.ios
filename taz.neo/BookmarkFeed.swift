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
  public var dir: Dir { Dir("\(feeder.baseDir.path)/bookmarks") }
  /// total number of bookmarks
  public var count: Int = 0
  
  public init(feeder: Feeder) {
    self.feeder = feeder
    self.name = "Bookmarks(\(feeder.title))"
    self.lastIssue = Date()
    self.firstIssue = self.lastIssue
    dir.create()
    let rlink = File(dir: dir.path, fname: "resources")
    let glink = File(dir: dir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: feeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: feeder.globalDir.path) }
    // Copy resources to bookmark folder
    if let path = Bundle.main.path(forResource: "Trash.svg", ofType: nil) {
      let base = File.basename(path)
      let src = File(path)
      src.copy(to: "\(dir.path)/\(base)")
    }
  }
  
  deinit {
    /// Remove temporary files
    guard let issues = self.issues else { return }
    for issue in issues {
      if let sections = issue.sections {
        for section in sections {
          if let tmpFile = section.html as? BookmarkFileEntry {
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
    <link rel="stylesheet" type="text/css" href="resources/base.css">
    <link rel="stylesheet" type="text/css" href="resources/base2017.css">
    <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0"/>
    <link rel="stylesheet" type="text/css" href="resources/platform.css">
    <script src="resources/jquery-3.min.js" type="text/javascript" charset="utf-8" language="javascript"></script>
    <script src="resources/tazApi.js" type="text/javascript" charset="utf-8" language="javascript"></script>
    <script src="resources/setupApp.js" type="text/javascript" charset="utf-8" language="javascript"></script>
    <link rel="stylesheet" type="text/css" href="resources/ressort.css">
    <link rel="stylesheet" type="text/css" href="resources/tazApi.css">
    <link rel="stylesheet" type="text/css" href="resources/tazApiSection.css">
    
    <style>
      div.collapse {
        height: 0px;
        transition: height 1s ease;
      }
      p.issueDate {
        float: left;
        font-family           : AktivGrotesk, taz;
        font-weight           : normal;
        text-transform        : none;
        margin-bottom         : 0.556rem;     /*10bx*/
        font-size             : 0.861rem;     /* 15.5 bx */
      }
      img.trash {
        float: right;
        margin: -20px 0 0 15px;
        width: 50px
      }
      img.picture {
        float: right;
        margin: 0 0 10px 10px;
        width: 65px;
        height: 65px;
        object-fit: cover;
      }
    </style>
  
    <script>
      /*
      $('.trash').click(function(e) {
      })
      */
      function deleteBookmark(aname) {
        tazApi.setBookmark(aname, false);
      }
    </script>
  
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
    return "<p class=\"VerzeichnisAutor\">\(ret.xmlEscaped())</p>"
  }
  
  /// Get image of first picture (if available) with markup
  public func getImage(art: Article) -> String {
    if let imgs = art.images, imgs.count > 0 {
      let fn = imgs[0].name
      return "<img class=\"picture\" src=\"\(art.dir.path)/\(fn)\">"
    }
    else { return "" }
  }
  
  /// Generate HTML for given Section
  public func genHtml(section: BookmarkSection) {
    if let articles = section.articles as? [StoredArticle] {
      var html = """
      \(BookmarkFeed.htmlHeader)
      <body>
      <div id="content">\n
      """
      for art in articles {
        let issues = art.issues
        if issues.count > 0 {
          let title = art.title ?? art.html.name
          let teaser = art.teaser ?? ""
          let sdate = art.issueDate.gDateString(tz: self.feeder.timeZone)
          html += """
          <div class="VerzeichnisArtikel eptPolitik">
            <a href="\(art.path)" class="RessortDiv">
              \(getImage(art: art))
              <h2 class="Titel">\(title.xmlEscaped())</h2>
              <h4 class="Unterzeile">\(teaser.xmlEscaped())</h4>
              \(getAuthors(art: art))
            </a>
            <img class="trash" src="Trash.svg" 
              onClick='deleteBookmark("\(art.html.name)")'>
            <p class="issueDate">\(sdate)</p>
            <div class="VerzeichnisArtikelEnde"></div>
          </div>
          """
        }
      }
      html += "</div>\n</body>\n</html>\n"
      let tmpFile = section.html as! BookmarkFileEntry
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
    let bmSection = BookmarkSection(name: "leseliste", issue: bmIssue,
        html: BookmarkFileEntry(feed: bm, name: "allBookmarks.html"))
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
  public var primaryIssue: Issue?
  
  public init(name: String, issue: Issue, html: FileEntry) {
    self.name = name
    self.primaryIssue = issue
    self.html = html
  }
}

/// A temporary file entry
public class BookmarkFileEntry: FileEntry {
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
