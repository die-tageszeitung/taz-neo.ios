//
//  Bookmarks.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

class BookmarksIssueInfo: IssueInfo {
  var feederContext: FeederContext
  var issue: Issue
  
  init?(feederContext: FeederContext?, issue: Issue?){
    guard let fc = feederContext, let i = issue else { return nil }
    self.feederContext = fc
    self.issue = i
  }
}

public class Bookmarks: DoesLog {
  
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
  var feederContext: FeederContext?

  private var _issueInfo: BookmarksIssueInfo?
  var issueInfo: BookmarksIssueInfo? {
    return _issueInfo ?? {
      let ii = BookmarksIssueInfo(feederContext: self.feederContext,
                                  issue: self.bookmarkIssue)
      _issueInfo = ii
      return ii
    }()
  }
  
  /// returns true if value changed
  /// prepared for multiple bookmark lists
  fileprivate static func set(article: StoredArticle, active: Bool, in list: StoredSection? = nil) {
    guard has(article: article, in: list) != active else { return }//No Change nothing to do
    guard let bookmarkSection = list ?? shared.bookmarkSection else {
      Log.log("Fail to set Bookmark, usually unreachable code")
      return
    }
    if active {
      article.pr.addToSections(bookmarkSection.pr)
      bookmarkSection.pr.addToArticles(article.pr)
      //only this, is not working due originalMoment is not set yet
      //article.pr.originalMoment?.addToBookmarkedArticles(article.pr)
      //addTo...is only available for ...to n relation in a to 1 relation its just asign
      article.pr.originalMoment = (article.primaryIssue as? StoredIssue)?.pr.moment
      
//      AHH WIRD VERMUTLICH BEIM ISSUE LÖSCHEN GELÖSCHT ÜBERPRÜFE IN MODEL UND AM BEISPIEL!
      
      ///or the opposite direction:
//      (article.primaryIssue as? StoredIssue)?.pr.moment?.addToBookmarkedArticles(article.pr)
      addMomentToPublicationDate(for: article)
    }
    else {
      article.pr.removeFromSections(bookmarkSection.pr)
      bookmarkSection.pr.removeFromArticles(article.pr)
      if article.pr.sections?.count == 0 {
        article.delete()
      }
      if article.pr.originalMoment?.bookmarkedArticles?.count == 1
          && article.pr.originalMoment?.issue == nil {
        article.pr.originalMoment?.delete()
      }
//      article.pr.removeFromIssues(bookmarkIssue.pr)
//      bookmarkIssue.pr.removeFromArticles(article.pr)//??
    }
    Notification.send(Const.NotificationNames.bookmarkChanged,
                      content: article.sections,
                      sender: article)
  }
  
  fileprivate static func addMomentToPublicationDate(for article: StoredArticle){
    guard let iDate = article.primaryIssue?.date,
          let moment = article.primaryIssue?.moment as? StoredMoment
    else { return }
    
    let pDate = article.primaryIssue?.feed.publicationDates?
      .first{$0.date.issueKey == iDate.issueKey}
    guard let pDate = pDate as? StoredPublicationDate else { return }
    pDate.pr.moment = moment.pr
    article.pr.originalMoment = moment.pr
  }
  
  /// returns true if is in given list
  /// prepared for multiple bookmark lists, uses default list if none given
  fileprivate static func has(article: StoredArticle, in list: StoredSection? = nil) -> Bool {
    return (list ?? shared.bookmarkSection)?
      .articles?.contains{$0.serverId == article.serverId } ?? false
  }
  
  static func has(article: PersistentArticle, in list: StoredSection? = nil) -> Bool {
    guard article.serverId != -1 else { return false }
    return (list ?? shared.bookmarkSection)?
      .articles?.contains{$0.serverId ?? -1 == article.serverId } ?? false
  }
  
  //IS STatic required?
  private func bookmarkIssue(in feed: Feed) -> StoredIssue {
    let request = StoredIssue.fetchRequest
    request.predicate = NSPredicate(format: "(baseUrl = %@)", Self.bookmarkUrl)
    if let si = StoredIssue.get(request: request).first { return si }
    
    let si = StoredIssue.new()
    si.baseUrl = Self.bookmarkUrl
    si.date = Date(timeIntervalSinceReferenceDate: 0)//1.1.2001
    si.moTime = Date()
    si.minResourceVersion = 0
    si.status = .unknown
    si.isWeekend = false
    
    si.isDownloading = false
    si.isComplete = false
    si.feed = feed
    si.moment =  DummyMoment()
    
    addBookmarkSection()
    return si
  }
  
  /// Migrates bookmarks from previously implementation stored as flag of article to the new implementation.
  private func migrateBookmarks() {
      // Fetch previous bookmarks using previous implementation
      // Only articles with `hasBookmark` flag are retrieved.
      let request = StoredArticle.fetchRequest
      request.predicate = NSPredicate(format: "hasBookmark = true")
      // Migrate bookmarks by using self.hasBookmark logic to add them to the bookmark issue
      for article in StoredArticle.get(request: request) { article.hasBookmark = true }
  }
  
  //IS STatic required?
  @discardableResult
  private func addBookmarkSection(with name: String = "Leseliste") -> StoredSection? {
    guard let issue = bookmarkIssue else {
      log("Failed to add BookmarkSection with name: \(name), bookmarkIssue is missing.")
      return nil
    }
    copyRessourcesIfNeeded()
    let sect = StoredSection.new()
    sect.name = "Leseliste"
    sect.type = .unknown
//    sect.primaryIssue = issue
    
    let bmFilePath = "\(issue.feed.bookmarksDir.path)/\(sect.name).html"
    File(bmFilePath).string = "initial, empty"
    let tmpFile = StoredFileEntry.new(path: bmFilePath)
    sect.html = tmpFile
    issue.pr.addToSections(sect.pr)
    sect.pr.issue = issue.pr
    migrateBookmarks()

    return sect
  }
  
  //IS STatic required?
  private func copyRessourcesIfNeeded(){
    guard let issue = bookmarkIssue else {
      log("Failed to copy, bookmarkIssue is missing.")
      return
    }
    let bmDir = issue.feed.bookmarksDir
    if bmDir.exists { return }

    bmDir.create()
    let rlink = File(dir: bmDir.path, fname: "resources")
    let glink = File(dir: bmDir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: issue.feed.feeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: issue.feed.feeder.globalDir.path) }
    
    ///copy both taz and lmd bookmark css, and just use different ones! Switch would be easier
    ///@see old init BookmarkFeed for prev version
    var resources = ["bookmarks-ios.js", "Star.svg", "StarFilled.svg",
                     "Share.svg", "dot-night.svg", "dot-day.svg", "bookmarks-taz-ios.css", "bookmarks-lmd-ios.css"]
    for f in resources {
      if let path = Bundle.main.path(forResource: f, ofType: nil) {
        let base = File.basename(path)
        let src = File(path)
        let dest = "\(bmDir.path)/resources/\(base)"
        src.copyResource(to: dest)
      }
    }
  }
  
  func setup(){
    guard let fc = TazAppEnvironment.sharedInstance.feederContext,
          let feed = fc.defaultFeed else {
      return
    }
    let bmIssue: StoredIssue = bookmarkIssue(in: feed)
    self.feederContext = fc
    self.bookmarkIssue = bmIssue
    ///In case of Multiple Bookmark Lists, handle theese here and set 'the default' bookmark section
    self.bookmarkSection
    = bookmarkIssue?.sections?.first as? StoredSection ?? addBookmarkSection()
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

extension StoredArticle {
  public var hasBookmark: Bool {
    get { return Bookmarks.has(article: self)}
    set {Bookmarks.set(article: self, active: newValue)}
  }
}

extension Issue {
  public var isBookmarkIssue: Bool {
    return self is StoredIssue && baseUrl == Bookmarks.bookmarkUrl
  }
}

