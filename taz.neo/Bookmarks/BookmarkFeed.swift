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
  @Default("bookmarksListTeaserEnabled")
  var bookmarksListTeaserEnabled: Bool
  
  public var name: String
  public var feeder: Feeder
  public var cycle: PublicationCycle { .unknown }
  public var momentRatio: Float { 1 }
  public var issueCnt: Int { 1 }
  public var lastIssue: Date
  public var firstIssue: Date
  public var issues: [Issue]?
  public var publicationDates: [PublicationDate]?
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
    let resources = ["bookmarks-ios.css", "bookmarks-ios.js",
                     "Star.svg", "StarFilled.svg", "Share.svg", "dot-night.svg", "dot-day.svg"]
    for f in resources {
      if let path = Bundle.main.path(forResource: f, ofType: nil) {
        let base = File.basename(path)
        let src = File(path)
        let dest = "\(dir.path)/resources/\(base)"
        src.copyResource(to: dest)
      }
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
  <!DOCTYPE html>
  <html lang="de">
  <head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0"/>
    <link rel="stylesheet" href="resources/bookmarks-ios.css"/>
    <script src="resources/tazApi.js"></script>
    <script src="resources/bookmarks-ios.js"></script>
    <title>Bookmarks</title>
  </head>
  """
  
  /// Get all authors as String with HTML markup
  public func getAuthors(art: Article) -> String {
    var ret = ""
    if let authors = art.authors, authors.count > 0 {
      let n = authors.count - 1
      for i in 0...n {
        if let name = authors[i].name {
          ret += name
          if i != n { ret += ", " }
        }
      }
      ret = "<address>\(ret.xmlEscaped())</address>&ensp;"
    }
    if let duration = art.readingDuration {
      ret += "<time>\(duration) min</time>"
    }
    return """
        <div class="author">
          \(ret)
        </div>\n
    """
  }
  
  /// Get image of first picture (if available) with markup
  public func getImage(art: Article) -> String {
    if let imgs = art.images, imgs.count > 0 {
      let fn = imgs[0].name
      return "<img class=\"photo\" src=\"\(art.dir.path)/\(fn)\">"
    }
    else { return "" }
  }
  
  /// Get the inner HTML of an article
  public func getInnerHtml(art: StoredArticle) -> String {
    let title = art.title ?? art.html?.name ?? ""
    let shareIcon
    = art.onlineLink == nil
    ? ""
    : """
        <img class="share" src="resources/Share.svg">
      """
    let teaser = bookmarksListTeaserEnabled
    ? "<p>\((art.teaser ?? "").xmlEscaped())</p>"
    : ""
    let html = """
      <div class="dottedline"></div>
      <a href="\(art.path)">
        \(getImage(art: art))
        <h2>\(title.xmlEscaped())</h2>
        \(teaser)
      </a>
      <div class = "foot">
        \(getAuthors(art: art))
        <div class="icons">
          \(shareIcon)
          <img class="bookmark" src="resources/StarFilled.svg">
        </div>
      </div>
    """
    return html
  }
  
  /// Generate HTML for given HTML Section
  public func genHtmlSection(date: Date, arts: [Article]) -> String {
    if let articles = arts as? [StoredArticle],
       articles.count > 0,
       let issue = articles[0].primaryIssue {
      let momentPath = feeder.smallMomentImageName(issue: issue)
      let dateText = issue.validityDateText(timeZone: GqlFeeder.tz,
                                            leadingText: "wochentaz, ")
      var html = """
      <section id="\(date.timeIntervalSince1970)">
        <header class="issue">
          <img class="moment" src="\(momentPath ?? "")">
          <h1>\(dateText)</h1>
        </header>\n
      """
      var order = 1;
      for art in articles {
        let issues = art.issues
        if issues.count > 0 {
          html += """
            <article id="\(File.progname(art.html?.name ?? ""))" style="order:\(order)">
            \(getInnerHtml(art: art))
            </article>\n
          """
        }
        order += 1
      }
      html += "</section>\n"
      return html
    }
    return ""
  }

  public func genHtmlSections(section: BookmarkSection) -> String {
    var html = ""
    for date in section.issueDates! {
      html += genHtmlSection(date: date, arts: section.groupedArticles![date]!)
    }
    return html
  }
  
  /// Generate HTML for given Section
  public func genHtml(section: BookmarkSection) {
    var html = """
      \(BookmarkFeed.htmlHeader)
      <body>\n
      """
    html += genHtmlSections(section: section)
    html += "</body>\n</html>\n"
    let tmpFile = section.html as! BookmarkFileEntry
    tmpFile.content = html
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
  public func loadAllBookmarks() {
    if let issues = issues, issues.count > 0,
       let sections = issues[0].sections, sections.count > 0 {
      let section = sections[0] as! BookmarkSection
      let allArticles = StoredArticle.bookmarkedArticles()
      count = allArticles.count
      section.articles = allArticles
      section.groupedArticles = [:]
      section.issueDates = []
      for art in allArticles {
        let sdate = art.issueDate
        if let _ = section.groupedArticles![sdate] {
          section.groupedArticles![sdate]!.append(art)
        }
        else { section.groupedArticles![sdate] = [art] }
      }
      section.issueDates = Array(section.groupedArticles!.keys).sorted
        { d1, d2 in d1 > d2 }
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
    bm.loadAllBookmarks()
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
  public var validityDate: Date?
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
  public var audio: Audio?
  public var name: String
  public var extendedTitle: String? { name }
  public var type: SectionType { .articles }
  public var articles: [Article]?
  public var groupedArticles: [Date:[Article]]?
  public var issueDates: [Date]?
  public var navButton: ImageEntry? { nil }
  public var html: FileEntry?
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

/// Small File extension to copy resource files
extension File {
  /**
   copies a file to a destination given by its pathname.

   self is only copied if it is either newer than the destination file
   (in this case it is an update of a new app version) or the destination
   file is newer than the source file (in this case it has been copied before
   but the mtime has not been set to that of the source file).
   After copying the destination file's mtime is set to that of the source
   file.
   */
  public func copyResource(to: String) {
    let dest = File(to)
    if dest.mtime != self.mtime {
      self.copy(to: to)
      dest.mtime = self.mtime
    }
  }
}

