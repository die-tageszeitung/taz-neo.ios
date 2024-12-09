//
//  Bookmarks.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// Manages user bookmarks for articles.
/// Bookmarks are stored persistently, with a default section named "Leseliste".
/// Currently, the implementation is limited to a single list (section) but is designed for future extensibility.
public class Bookmarks: DoesLog {
  
  /// Database key for bookmark storage. **DO not Change**
  static let bookmarkURL = "bookmark.issue.local"
  
  static let defaultBookmarkSectionTitle = "Leseliste"
  
  /// Singleton instance for managing bookmarks.
  private static let sharedInstance = Bookmarks()
  
  /// Persistent issue for bookmark storage.
  var bookmarkIssue: StoredIssue?
  
  /// Default section for storing bookmarks.
  var bookmarkSection: StoredSection? {
    didSet {
      bookmarkedArticles
      = bookmarkSection?.articles as? [StoredArticle] ?? []
    }
  }
  
  /// Feeder context to manage the environment and data fetching.
  var feederContext: FeederContext?
  
  /// List of articles currently bookmarked in default list
  var bookmarkedArticles: [StoredArticle] = []
  
  ///currently downloading articles
  var loadingArticles: [StoredArticle] = []
  
  /// Cached issue information for ArticleVC @see: ArticleVCdelegate
  private var _issueInfo: BookmarksIssueInfo?
  
  /// Accessor for BookmarksIssueInfo lazily initialized if feederContext and bookmarkIssue is already set
  var issueInfo: BookmarksIssueInfo? {
    return _issueInfo ?? {
      _issueInfo = BookmarksIssueInfo(feederContext: self.feederContext,
                                      issue: self.bookmarkIssue)
      return _issueInfo
    }()
  }
  
  /// Shared accessor for the singleton instance.
  /// initialize environment if default StoredFeed and FeederContext is available
  /// dev/null if not; means no database no bookmark functionallity,
  /// no worry initial Popup "Server not reachable" block every user interaction
  static var shared: Bookmarks {
    get {
      if sharedInstance.bookmarkSection == nil {
        ///initialize if needed
        sharedInstance.setup()
      }
      return sharedInstance
    }
  }
  
  private func setup(){
    ///check if required environment is available; otherwise bookmarks would not work and cannot be initialized
    guard let feederContext = TazAppEnvironment.sharedInstance.feederContext,
          let feed = feederContext.defaultFeed else {
      return
    }
    
    ///solves access to bookmarks without inited feeder
    ///if no stored feeder:
    /// - no bookmark can be set: OK
    /// - no bookmark can be fetch from Database, list is empty: OK
    self.feederContext = feederContext
    let bookmarkIssue = self.loadOrCreateBookmarkIssue(in: feed)
    self.bookmarkIssue = bookmarkIssue
    ///as long as default bookmarkSection is unset bookmarks did not work;
    self.bookmarkSection
    = bookmarkIssue.sections?.first as? StoredSection
    ?? self.createBookmarkSection(in: bookmarkIssue,
                                            sectionName: Bookmarks.defaultBookmarkSectionTitle)
    loadFullArticlesIfNeeded()
  }
}

// MARK: - Logic: GET|SET ... REMOVE Helper

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

