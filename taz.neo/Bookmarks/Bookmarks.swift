//
//  Bookmarks.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

///new issue independent bookmarks implementation
///uses persisted issue to store all bookmarks
///default "Leseliste" Bookmarks are stored in the section named "Leseliste"
///
///currently the implementation is not ready for multiple bookmark lists but its prepared
public class Bookmarks: DoesLog {
  
  ///**DO not Change** stored in Database
  static let bookmarkUrl = "bookmark.issue.local"
  
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
  
  var bookmarkIssue: StoredIssue?
  
  ///default bookmark section
  var bookmarkSection: StoredSection? {
    didSet {
      bookmarkedArticles
      = bookmarkSection?.articles as? [StoredArticle] ?? []
    }
  }
  var feederContext: FeederContext?
  
  var bookmarkedArticles: [StoredArticle] = []
  
  private var _issueInfo: BookmarksIssueInfo?
  var issueInfo: BookmarksIssueInfo? {
    return _issueInfo ?? {
      let ii = BookmarksIssueInfo(feederContext: self.feederContext,
                                  issue: self.bookmarkIssue)
      _issueInfo = ii
      return ii
    }()
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

// MARK: - Logig GET|SET ... REMOVE Helper

extension Bookmarks {
  
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
  
  func has(article: Article) -> Bool {
    return bookmarkedArticles.contains{$0.serverId == article.serverId }
  }
    
  /// Prepares for managing bookmarks across multiple lists
  func set(article: Article, active: Bool, in list: StoredSection? = nil) {
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
  
  fileprivate func setBookmark11(for article: Article, in list: StoredSection? = nil, active: Bool) {
    set(article: article, active: active, in: list)
  }
  
}

// MARK: - Persistence Helper

extension Bookmarks {
  
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
      f.copyResourceWT(to: issueDir.path + "/" + fileEntry.fileName)
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
          Toast.show(Localized("error_download"))
          self.log("download finished with err: \(err)")
        }
      })
    }
    
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
}

// MARK: - Initialisation Helper

extension Bookmarks {
  fileprivate func bookmarkIssue(in feed: Feed) -> StoredIssue {
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
  
  @discardableResult
  fileprivate func addBookmarkSection(with name: String = "Leseliste") -> StoredSection? {
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
  
}

// MARK: - Migration Helper

extension Bookmarks {
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
}
