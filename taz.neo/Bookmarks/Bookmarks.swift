//
//  Bookmarks.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

class BookmarksIssueInfo: ArticleVCdelegate, DoesLog {
  var section: (any Section)?
  
  var sections: [any Section] = []///required for header
  
  var article: (any Article)?
  
  var article2section: [String : [any Section]] = [:]///required for header
  
  func displaySection(index: Int) {}
  
  public func linkPressed(from: URL?, to: URL?) {
    guard let to = to else { return }
    self.debug("Calling application for: \(to.absoluteString)")
    if UIApplication.shared.canOpenURL(to) {
      UIApplication.shared.open(to, options: [:], completionHandler: nil)
    }
    else {
      error("No application or no permission for: \(to.absoluteString)")
    }
  }
  
  func closeIssue() {}
  
  var feederContext: FeederContext
  var issue: Issue
  
  func updateData(){
    article2section = issue.article2section
    sections = issue.sections ?? []
  }
  
  init?(feederContext: FeederContext?, issue: Issue?){
    guard let fc = feederContext, let i = issue else { return nil }
    self.feederContext = fc
    self.issue = i
    updateData()
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
  
  ///DO not Change stored in Database
  static let bookmarkUrl = "bookmark.issue.local"
  
  var bookmarkIssue: StoredIssue?
  var bookmarkSection: StoredSection? {
    didSet {
      bookmarkedArticles
      = bookmarkSection?.articles as? [StoredArticle] ?? []
    }
  }
  var feederContext: FeederContext?
  
  var bookmarkedArticles: [StoredArticle] = []
  ///probably not different "list" save
//  private var pendingDeletedArticleServerIds: [Int] = []
  
  private var _issueInfo: BookmarksIssueInfo?
  var issueInfo: BookmarksIssueInfo? {
    return _issueInfo ?? {
      let ii = BookmarksIssueInfo(feederContext: self.feederContext,
                                  issue: self.bookmarkIssue)
      _issueInfo = ii
      return ii
    }()
  }
  
  /// Prepares for managing bookmarks across multiple lists
  fileprivate func set(article: Article, active: Bool, in list: StoredSection? = nil) {
    // Retrieve the existing bookmarked article, if any
    let bookmarkedArticle = bookmarkArticle(for: article, in: list)
    
    // If the desired state matches the current state, exit early
    if (bookmarkedArticle == nil && !active) || (bookmarkedArticle != nil && active) {
      return
    }
    
    // Determine the target bookmark section
    guard let bookmarkSection = list ?? bookmarkSection else {
      Log.log("Failed to set bookmark. This code should typically not be reachable.")
      return
    }
    
    if active {
      // Activate the bookmark
      guard let storedArticle = bookmarkableArticle(from: article) else { return }
      
      storedArticle.pr.addToSections(bookmarkSection.pr)
      bookmarkSection.pr.addToArticles(storedArticle.pr)
      
      bookmarkedArticles.append(storedArticle)
      ArticleDB.save()
      Notification.send(Const.NotificationNames.bookmarkChanged, sender: storedArticle)
      
      let msg = "Der Artikel wurde in ihrer Leseliste gespeichert."
      Toast.show("<h3>\(article.title ?? "")</h3>\(msg)")
    } else if let storedArticle = bookmarkedArticle {
      removeBookmarked(article: storedArticle, from: bookmarkSection)
    } else {
      error("something went wrong: the article which should be un-bookmarked is not bookmarked. RaceCondition?")
    }
  }
  
  private func removeBookmarked(article: StoredArticle, from section: StoredSection){
    guard let serverId = article.serverId else { return }
    bookmarkedArticles.removeAll{ $0.serverId == serverId }
    
    let completion = { [weak self] wasTapped in
      if wasTapped {///do not delete
        self?.bookmarkedArticles.append(article)
        Notification.send(Const.NotificationNames.bookmarkChanged, sender: article)
        return
      }
      // Deactivate the bookmark
      article.pr.removeFromSections(section.pr)
      section.pr.removeFromArticles(article.pr)
      // Remove the stored article if it no longer belongs to any section
      if article.pr.sections?.count == 0 {
        article.delete()
      }
      ArticleDB.save()
    }
    let msg = "Der Artikel wurde aus ihrer Leseliste entfernt.<br/>Löschen rückgängig durch Antippen"
    Toast.show("<h3>\(article.title ?? "")</h3>\(msg)",
               minDuration: 0,
               completion: completion)
    Notification.send(Const.NotificationNames.bookmarkChanged, sender: article)
  }
  
  fileprivate func setBookmark(for article: Article, in list: StoredSection? = nil, active: Bool) {
    set(article: article, active: active, in: list)
  }
    
  fileprivate func has(article: Article) -> Bool {
    return bookmarkedArticles.contains{$0.serverId == article.serverId }
//    }
//    // Check if the article exists in the specified or default bookmark list
//    return bookmarkArticle(for: article, in: list) != nil
  }
  
  ///ignoring pending deletions
  private func bookmarkArticle(for article: Article, in list: Section? = nil) -> StoredArticle? {
    guard let serverId = article.serverId else { return nil }
    return bookmarkArticle(forArticleWith: serverId, in: list)
  }
  
  ///ignoring pending deletions
  private func bookmarkArticle(forArticleWith serverId: Int, in list: Section? = nil) -> StoredArticle? {
    // Retrieve the specified section or the shared bookmark section
    let section = list as? StoredSection ?? bookmarkSection
    // Find the matching article by its server ID
    return section?.articles?.first { $0.serverId == serverId } as? StoredArticle
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
    for article in StoredArticle.get(request: request) { 
      set(article: article, active: true)
    }
  }
  
  //IS STatic required?
  @discardableResult
  private func addBookmarkSection(with name: String = "Leseliste") -> StoredSection? {
    guard let issue = bookmarkIssue else {
      log("Failed to add BookmarkSection with name: \(name), bookmarkIssue is missing.")
      return nil
    }
    let sect = StoredSection.new()
    sect.name = "Leseliste"
    sect.type = .unknown
    
    let bmDir = issue.feed.bookmarksDir
    if bmDir.exists == false { bmDir.create() }
    let bmFilePath = "\(bmDir.path)/\(sect.name).html"
    File(bmFilePath).string = "initial, empty: Only for Compatibility Reasons due a Section(Content) required html"
    let tmpFile = StoredFileEntry.new(path: bmFilePath)
    sect.html = tmpFile
    issue.pr.addToSections(sect.pr)
    sect.pr.issue = issue.pr
    migrateBookmarks()
    
    return sect
  }

  func commonIssueDir(for issueDate: Date) -> Dir? {
    guard let feeder = feederContext?.storedFeeder,
    let feed = bookmarkIssue?.feed else { return nil }
    return feeder.issueDir(feed: feed.name, issue: feeder.date2a(issueDate))
  }
  
  private func commonIssueDir(fromSearchArticle searchArticle: SearchArticle) -> Dir? {
    guard let issueDate = searchArticle.originalIssueDate else { return nil }
    return commonIssueDir(for: issueDate)
  }
  /// ensures storedArticle properies are set as expected
  /// * creates target dir in default issue dir format e.g. /taz/taz/YYYY-mm-dd
  /// * link ressources to this folder
  /// * copies serach article files to this folder
  /// * sets StoredFileEntry.subdir property to the new target dir for all article.files
  private func bookmarkableArticle(from article: Article) -> StoredArticle? {
    if let storedArticle = article as? StoredArticle {
      ///bookmark from downloaded issue; just set some properties
      if let issue = storedArticle.primaryIssue as? StoredIssue {
        if storedArticle.pr.issueDate == nil {
          storedArticle.pr.issueDate = issue.date
        }
        storedArticle.baseURL = issue.baseUrl
      }
      return storedArticle
    }
    
    guard let searchArticle = article as? SearchArticle else {
      error("something went wrong: \(article) is not a StoredArticle or a SearchArticle")
      return nil
    }
    
    
    guard let issueDir = commonIssueDir(fromSearchArticle: searchArticle) else {
      error("something went wrong, did not found commonIssueDir for: \(article)")
      return nil
    }
    guard let feeder = feederContext?.storedFeeder else {
      error("something went wrong, did not found feeder")
      return nil
    }
    
    ///link Ressources (js/css/author images) if needed
    if issueDir.exists == false {
      issueDir.create()
    }
    let rlink = File(dir: issueDir.path, fname: "resources")
    let glink = File(dir: issueDir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: feeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: feeder.globalDir.path) }
    
    var dlFiles: [FileEntry]  = []
    
    ///copy serach content to target issue dir
    for fileEntry in searchArticle.files {
      let f = File(dir: Dir.searchResults.path, fname: fileEntry.fileName)
      if !f.exists { dlFiles.append(fileEntry); continue }
      f.copyResource(to: issueDir.path + "/" + fileEntry.fileName)
    }
    
    ///copy serach content to target issue dir
    for author in searchArticle.authors ?? [] {
      guard let fileEntry = author.photo else { continue }
      let f = File(dir: feeder.globalDir.path, fname: fileEntry.fileName)
      if !f.exists { dlFiles.append(fileEntry) }
    }
    
    if let searchArticleBaseUrl = searchArticle.baseURL, dlFiles.count > 0 {
      ///try to download not yet downloaded files
      feederContext?.dloader.downloadSearchHitFiles(files: dlFiles, baseUrl: searchArticleBaseUrl, closure: { err in
        for file in dlFiles {
          if file.storageType == .global { continue }///prevent move author images from global to issue folder
          let f = File(dir: Dir.searchResults.path, fname: file.fileName)
          if !f.exists { continue }
          f.copy(to: issueDir.path + "/" + file.fileName)
        }
        if let err = err {
          Toast.show("Fehler beim Download von Dateien")
          self.log("download finished with err: \(err)")
        }
      })
    }
    
    #warning("FIX ERROR DOWNLOAD => LATER LOAD ON OPEN ARTICLE")
    
    ///it is ensured, that article is not already a StoredArticle
    let storedArticle = StoredArticle.persist(object: article)
    
    ///set default properties, wich are not set correctly in
    storedArticle.pr.issueDate = searchArticle.originalIssueDate
    storedArticle.baseURL = searchArticle.baseURL
    storedArticle.sectionTitle = searchArticle.sectionTitle
    for au in searchArticle.authors ?? [] {
      let sau = StoredAuthor.persist(object: au)
      sau.pr.addToArticles(storedArticle.pr)
      storedArticle.pr.addToAuthors(sau.pr)
    }
    
    ///add subdir info to StoredArticle files
    let subdir = String(issueDir.path.dropFirst(Database.appDir.count + 1))
    for case let f as StoredFileEntry in storedArticle.files {
      f.subdir = subdir
    }
    
    /* NOT ONLY:
     (storedArticle.html as? StoredFileEntry)?.subdir
     = String(targetDir.path.dropFirst(Database.appDir.count + 1))
     */
    return storedArticle
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

extension Bookmarks {
  static func toggle(article: Article, in list: StoredSection? = nil){
    shared.set(article: article, active: !article.hasBookmark, in: list)
  }
  static func set(article: Article, bookmarked:Bool, in list: StoredSection? = nil){
    shared.set(article: article, active: bookmarked, in: list)
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

/* IDEAS**/
import UIKit
class XViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  
  private var articles: [Article] = []
  private var groupedArticles: [String: [Article]] = [:]
  private var sortedSectionKeys: [String] = []
  
  private let tableView = UITableView()
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd" // Gruppierung nach Tag
    return formatter
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    
    // Beispielartikel erstellen
    articles = [
      
    ]
    
    // Artikel gruppieren
    groupArticlesByDate()
    
    // UITableView einrichten
    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    tableView.frame = view.bounds
    view.addSubview(tableView)
  }
  
  private func groupArticlesByDate() {
    
    
    // Sections sortieren (nach Datum aufsteigend)
    sortedSectionKeys = groupedArticles.keys.sorted()
  }
  
  // MARK: - UITableViewDataSource
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return sortedSectionKeys.count
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return sortedSectionKeys[section]
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionKey = sortedSectionKeys[section]
    return groupedArticles[sectionKey]?.count ?? 0
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    
    let sectionKey = sortedSectionKeys[indexPath.section]
    if let articlesForSection = groupedArticles[sectionKey] {
      let article = articlesForSection[indexPath.row]
      cell.textLabel?.text = article.title
    }
    
    return cell
  }
  
  // MARK: - UITableViewDelegate (optional, für Benutzerinteraktion)
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let sectionKey = sortedSectionKeys[indexPath.section]
    if let articlesForSection = groupedArticles[sectionKey] {
      let article = articlesForSection[indexPath.row]
      print("Ausgewählt: \(article.title)")
    }
  }
}
