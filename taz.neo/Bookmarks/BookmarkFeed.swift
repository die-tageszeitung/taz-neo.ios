//
//  BookmarkFeed.swift
//  taz.neo
//
//  Created by Norbert Thies on 16.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/**
 
 
 HACKS:
 po (shared.bookmarkSection?.articles as? [StoredArticle])?.flatMap{$0.serverId}
 
 Status
 * Bookmark Feed is depreciated
 * lost Section's html after restart
 StoredFileEntry.fileNameExists(inDir:) Info:
   * Warning: File Leseliste.html exists but mtime and/or size are wrong 2024-08-29 08:24:41 +0000 !=? 2024-08-29 08:24:37 +0000 || 377 !=? 14
 ...datei muss generiert und bei appear neu geladen werden!
 tap auf Artikel geht nicht in Artikel
 * löschen Ausgabe
 * neu laden ausgabe?
 * Migration
 * wieso verschwinden artikel aus ihrem eigentlichen issue? ...und wann?
 
 * aktuelle Probleme?
 LADEFEHLER => DONE
 * entfernen aus Leseliste auf Artikelebene klappt nicht
 falscher bookmarks ordner wird noch vom bookmarks feed angelegt
 wenn ein Artikel in Section gebookmarkt ist, erscheint nach neustart der Stern nicht und er lässt sich nicht toggln
 */


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
  public var dir: Dir { Dir("\(feeder.dir.path)/bookmarks") }
//  public var dir: Dir { Dir("\(feeder.baseDir.path)/bookmarks") }
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
    let resources = ["bookmarks-ios.js", "Star.svg", "StarFilled.svg",
                     "Share.svg", "dot-night.svg", "dot-day.svg"]
    for f in resources {
      if let path = Bundle.main.path(forResource: f, ofType: nil) {
        let base = File.basename(path)
        let src = File(path)
        let dest = "\(dir.path)/resources/\(base)"
        src.copyResource(to: dest)
      }
    }
    let css = App.isTAZ ? "bookmarks-taz.css" : "bookmarks-lmd.css"
    if let path = Bundle.main.path(forResource: css, ofType: nil) {
      let src = File(path)
      let dest = "\(dir.path)/resources/bookmarks-ios.css"
      let targetFile1 = File(dest)
      log("bookmarks-ios.css before copy exist: \(targetFile1.exists) size: \(targetFile1.size) content: \(targetFile1.string.prefix(42))")
      let status = src.copyResourceWithStatusReturn(to: dest)
      let targetFile = File(dest)
      log("copied bookmarks-ios.css with status: \(status) targetExist: \(targetFile.exists) size: \(targetFile.size) content: \(targetFile.string.prefix(42))")
    }
    else {
      log("cannot copy bookmarks-ios.css due dest not found")
    }
  }
  
  deinit {
    /// Remove temporary files
    guard let issues = self.issues else { return }
    for issue in issues {
      if let sections = issue.sections {
        for section in sections {
          if let tmpFile = section.html as? StoredFileEntry {
            #warning("ToDO")
//            tmpFile.conten = nil // removes file
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
  
  // A dotted line using SVG
  //static var htmlDottedLine = "<div class='dottedline'></div>"
  static var htmlDottedLine = "<hr class='dotted'/>"
  
  func dottedLine(inSection: Bool) -> String {
    return (App.isTAZ ? !inSection : inSection) ?
      BookmarkFeed.htmlDottedLine : "";
  }
  
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
      ret = "<address>\(ret.authorsFormated)</address>&ensp;"
    }
    if let duration = art.readingDuration {
      ret += "<time>\(duration) min.</time>"
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
      \(dottedLine(inSection: false))
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
      let dateText = App.isLMD ? 
        "Ausgabe " + issue.date.gMonthYear(tz: GqlFeeder.tz, isNumeric: true) :
        issue.validityDateText(timeZone: GqlFeeder.tz, leadingText: "wochentaz, ")
      var html = """
      <section id="\(date.timeIntervalSince1970)">
        <header class="issue">
          <img class="moment" src="\(momentPath ?? "")">
          <h1>\(dateText)</h1>
        </header>\n
        \(dottedLine(inSection: true))
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
    let tmpFile = section.html
    #warning("ToDo writeFile!!!")
//    tmpFile.content = html
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
  /// @Norbert wieso bookmark feed? ...feed Bookmarks, feed audiohörliste, feed sonstwas
  /// NOPE ...now its same feed == taz /lmd Feed, wenn ich umschalte zwischen den feeds habe ich die anderen Feeds
  /// same behaviour like before where issue.articles hatten bookmark, waren also auch in feed "gefangen"
  /// ich brauche keinen bookmark feed, also weg damit und code gen in init oder bookmarks verlagern!
  public static func allBookmarks()  {
//    let bm = BookmarkFeed(feeder: feeder)
//    let bmIssue = Bookmarks.shared.bookmarkIssue
////    let bmSection = BookmarkSection(name: App.isTAZ ? "leseliste" : "Leseliste",
////        issue: bmIssue, html: BookmarkFileEntry(feed: bm, name: "allBookmarks.html"))
//    let bmSection = Bookmarks.shared.bookmarkSection
//    bm.issues = [bmIssue]
//    bmIssue.sections = [bmSection]
//    bm.loadAllBookmarks()
//    bm.genHtml(section: bmSection)
//    return bm
  }
}

public extension StoredArticle {
  
}

extension StoredArticle {
  public var hasBookmark: Bool {
    get {
      let has = Bookmarks.has(article: self)
      print("requested has Bookmark for: \(self.title ?? "-") id: \(self.serverId ?? -1) has: \(has)")
      return has
    }
    set {
      if Bookmarks.set(article: self, active: newValue) == false { return }///No change, no notification
      Notification.send(Const.NotificationNames.bookmarkChanged, content: sections, sender: self)
    }
  }
}

extension Issue {
  public var isBookmarkIssue: Bool {
    return self is StoredIssue && baseUrl == Bookmarks.bookmarkUrl
  }
  
//  public var dir: Dir? {
//    return nil
//  }
}

public class Bookmarks {
  ///Motivation: altes bookmark issue war virtuell und nicht in db, soll jetzt in db sein um ausgabenunabhängige lesezeichen zu haben
  ///Problem setze und entferne bookmark hat riesen overhead, sollte vielleicht nicht komplett im Model via Artikel gemacht werden, also hier ...halte dann hier auch das BookmarkIssue und die entsprechende Section vorrätig
  ///später mehrere Sections: Leseliste, archiv, hörliste....

  private static let sharedInstance = Bookmarks()
  static var shared: Bookmarks {
    get {
      if sharedInstance.bookmarkSection == nil {
        ///solves access to bookmarks without inited feeder
        ///if no stored feeder:
        /// - no bookmark can be set OK
        /// - no bookmark can be fetsch from DB list is empty OK
        sharedInstance.setup()
      }
      return sharedInstance
    }
  }
  
  fileprivate static let bookmarkUrl = "bookmark.issue.local"
  
  var bookmarkIssue: StoredIssue?
  var bookmarkSection: StoredSection?
  
  /// returns true if value changed
  /// prepared for multiple bookmark lists
  fileprivate static func set(article: StoredArticle, active: Bool, in list: StoredSection? = nil) -> Bool {
    guard has(article: article, in: list) != active else { return false }//No Change nothing to do
    guard let bookmarkIssue = shared.bookmarkIssue,
          let bookmarkSection = list ?? shared.bookmarkSection else {
      Log.log("Fail to set Bookmark, usually unreachable code")
      return false
    }
    if active {
      article.pr.addToSections(bookmarkSection.pr)
      bookmarkSection.pr.addToArticles(article.pr)
      article.pr.addToIssues(bookmarkIssue.pr)
      bookmarkIssue.pr.addToArticles(article.pr)
    }
    else {
      article.pr.removeFromSections(bookmarkSection.pr)
      bookmarkSection.pr.removeFromArticles(article.pr)
      article.pr.removeFromIssues(bookmarkIssue.pr)
      bookmarkIssue.pr.removeFromArticles(article.pr)
    }
    return true
  }
  
  /// returns true if is in given list
  /// prepared for multiple bookmark lists, uses default list if none given
  fileprivate static func has(article: Article, in list: StoredSection? = nil) -> Bool {
    return (list ?? shared.bookmarkSection)?
      .articles?.contains{$0.serverId == article.serverId } ?? false
  }
  
  private static func bookmarkIssue(in feed: Feed) -> StoredIssue {
    let request = StoredIssue.fetchRequest
    request.predicate = NSPredicate(format: "(baseUrl = %@)", bookmarkUrl)
    if let si = StoredIssue.get(request: request).first { return si }
    
    let si = StoredIssue.new()
    si.baseUrl = bookmarkUrl
    si.date = Date(timeIntervalSinceReferenceDate: 0)//1.1.2001
    si.moTime = Date()
    si.minResourceVersion = 0
    si.status = .unknown
    si.isWeekend = false
    
    si.isDownloading = false
    si.isComplete = false
    si.feed = feed
    si.moment =  DummyMoment()
    
    addBookmarkSection(to: si)
    return si
  }
  
  #warning("ToDo: migrate old bookmarks!")
  private static func migrateBookmarks(){
    
  }
  
  @discardableResult
  private static func addBookmarkSection(to issue: StoredIssue, with name: String = "Leseliste") -> StoredSection {
    let sect = StoredSection.new()
    sect.name = "Leseliste"
    sect.type = .unknown
//    sect.primaryIssue = issue
    
//    let bmPath = "\(issue.feed.dir.path)/bookmarks"
    let bmDir = issue.feed.bookmarksDir
    if !bmDir.exists {
      bmDir.create()
      let rlink = File(dir: bmDir.path, fname: "resources")
      let glink = File(dir: bmDir.path, fname: "global")
      if !rlink.isLink { rlink.link(to: issue.feed.feeder.resourcesDir.path) }
      if !glink.isLink { glink.link(to: issue.feed.feeder.globalDir.path) }
    }
    
    let bmFilePath = "\(bmDir.path)/\(sect.name).html"
    
    File(bmFilePath).string = "initial, empty"
    let tmpFile = StoredFileEntry.new(path: bmFilePath)
    print("Created Bookmarks at path: \(tmpFile?.path) in dir: \(tmpFile?.dir) subdir: \(tmpFile?.subdir)")
//    BookmarkFileEntry(feed: issue.feed, name: "\(sect.name).html")
//    print("tmp file path: \(tmpFile.path)")
    sect.html = tmpFile
//    sect.html?.exists(inDir: <#T##String#>)
    issue.pr.addToSections(sect.pr)
    sect.pr.issue = issue.pr
    migrateBookmarks()
    return sect
  }
  
  func setup(){
    guard let feed
    = TazAppEnvironment.sharedInstance.feederContext?.defaultFeed else {
      return
    }
    let bmIssue: StoredIssue = Self.bookmarkIssue(in: feed)
    self.bookmarkIssue = bmIssue
    self.bookmarkSection
    = bookmarkIssue?.sections?.first as? StoredSection
    ?? Self.addBookmarkSection(to: bmIssue)
    BookmarkFeed(feeder: feed.feeder)
  }
}

/// An Issue of Sections of bookmarked Articles
public class VirtualIssue: Issue {
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
  public var audioItem: Audio?
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

public class BookmarkFileEntry3: FileEntry {
  public var name: String
  
  public var storageType: FileStorageType { .issue }
  
  public var moTime: Date
  
  public var size: Int64
  
  public var sha256: String
  
  /// Read/write access to contents of file
  public var content: String? {
    get { File(path).string }
    set {
      if let content = newValue { File(path).string = content }
      else { File(path).remove() }
    }
  }
  
  private var path: String
  
  public init(feed: Feed, name: String) {
    self.name = name
    let bmPath = "\(feed.dir.path)/bookmarks/"
    let bmDir = Dir(bmPath)
    if !bmDir.exists {
      bmDir.create()
      let rlink = File(dir: bmDir.path, fname: "resources")
      let glink = File(dir: bmDir.path, fname: "global")
      if !rlink.isLink { rlink.link(to: feed.feeder.resourcesDir.path) }
      if !glink.isLink { glink.link(to: feed.feeder.globalDir.path) }
    }
    path = "\(bmDir.path)/\(name)"
    self.moTime = Date()
    self.size = 0
    self.sha256 = ""
  }
  
}

/// A temporary file entry
public class BookmarkFileEntry2: FileEntry {
  public var name: String
  public var storageType: FileStorageType { .issue }
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
  
  public init(feed: Feed, name: String) {
    self.name = name
    let bmPath = "\(feed.dir.path)/bookmarks/"
    let bmDir = Dir(bmPath)
    if !bmDir.exists {
      bmDir.create()
      let rlink = File(dir: bmDir.path, fname: "resources")
      let glink = File(dir: bmDir.path, fname: "global")
      if !rlink.isLink { rlink.link(to: feed.feeder.resourcesDir.path) }
      if !glink.isLink { glink.link(to: feed.feeder.globalDir.path) }
    }
    self.path = "\(bmDir.path)/\(name)"
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
  
  public func copyResourceWithStatusReturn(to: String) -> Int {
    var status = -123
    let dest = File(to)
    if dest.mtime != self.mtime {
      status = self.copy(to: to)
      dest.mtime = self.mtime
    }
    return status
  }
}

fileprivate extension String {
  var authorsFormated: String {
    #if LMD
    return self.length > 0 ? self.xmlEscaped().prepend("von ") : ""
    #else
    return self.xmlEscaped()
    #endif
  }
}
