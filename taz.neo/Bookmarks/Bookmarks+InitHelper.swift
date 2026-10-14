//
//  Bookmarks+InitHelper.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthBase

// MARK: - Bookmarks Initialisation Helper

extension Bookmarks {
  
  /// Loads an existing bookmark issue or creates a new one if it does not exist.
  ///
  /// - Returns: A `StoredIssue` object representing the bookmark issue.
  func loadOrCreateBookmarkIssue(in feeder: StoredFeeder) -> StoredIssue {
    var bookmarksFeed: StoredFeed
    if let dbFeed = StoredFeed.get(name: "BookmarkFeed", inFeeder: feeder).first {
      bookmarksFeed = dbFeed
    } else {
      bookmarksFeed = StoredFeed.new()
      bookmarksFeed.name = "BookmarkFeed"
      bookmarksFeed.feeder = feeder
      bookmarksFeed.type = .bookmarkFeed
      bookmarksFeed.cycle = .unknown
      bookmarksFeed.feedId = 0
      bookmarksFeed.firstIssue = Date()
      bookmarksFeed.lastIssue = Date()
      bookmarksFeed.pr.order = 0
      bookmarksFeed.issueCnt = 1
    }
    
    /// current way: use bookmarksFeed to find its only bookmarkIssue
    if let existingBookmarkIssue = (bookmarksFeed.issues ?? []).first as? StoredIssue {
      return existingBookmarkIssue
    }
    
    // Old Way, need to migrate: Attempt to find an existing bookmark issue in the database
    let request = StoredIssue.fetchRequest
    request.predicate = NSPredicate(format: "(baseUrl = %@)", Self.bookmarkURL)
    if let existingBookmarkIssue = StoredIssue.get(request: request).first {
      log("Migrate prev bookmarks")
      ///Migration from none multiFeed App Version
      for case let feed as StoredFeed in existingBookmarkIssue.pr.feeds ?? [] {
        feed.pr.removeFromIssues(existingBookmarkIssue.pr)
      }
      existingBookmarkIssue.pr.addToFeeds(bookmarksFeed.pr)
      ArticleDB.save()
      return existingBookmarkIssue
    }
    log("create new bookmark issue")
    // Create a new bookmark issue if none exists and set Default Properties
    let newBookmarkIssue = StoredIssue.new()
    newBookmarkIssue.baseUrl = Self.bookmarkURL
    newBookmarkIssue.date = Date(timeIntervalSince1970: 0)///long time before first taz 78/79
    newBookmarkIssue.moTime = Date()
    newBookmarkIssue.minResourceVersion = 0
    newBookmarkIssue.status = .unknown
    newBookmarkIssue.isWeekend = false
    newBookmarkIssue.isDownloading = false
    newBookmarkIssue.isComplete = false
    newBookmarkIssue.pr.addToFeeds(bookmarksFeed.pr)
    ///result is fetched in setup/singleton getter
    createBookmarkSection(in: newBookmarkIssue,
                          sectionName: Bookmarks.defaultBookmarkSectionTitle)
    // Save the newly created bookmark issue to the database
    ArticleDB.save()
    return newBookmarkIssue
  }
    
  /// Creates a new bookmark section within a bookmark issue.
  ///
  /// - Parameters:
  ///   - issue: The `StoredIssue` object to which the bookmark section will be added.
  ///   - title: The title of the new bookmark section.
  /// - Returns: A `StoredSection` object representing the newly created section.
  @discardableResult
  func createBookmarkSection(in issue: StoredIssue, sectionName: String) -> StoredSection {
    
    let newSection = StoredSection.new()
    newSection.name = sectionName
    newSection.type = .unknown
    
    ///create not used/ legacy fileentry for html property
    newSection.html = fileEntry(for: newSection, in:  TazAppEnvironment.masterFeed!.bookmarksDir)
    
    issue.pr.addToSections(newSection.pr)
    
    bookmarkSection = newSection
    migrateBookmarks()
    ArticleDB.save()
    return newSection
  }
  
  fileprivate func fileEntry(for section: StoredSection, in dir: Dir) -> FileEntry? {
    if dir.exists == false { dir.create() }
    let filePath = "\(dir.path)/\(section.name).html"
    File(filePath).string = "initial, empty: Only for Compatibility Reasons due a Section(Content) required html"
    return StoredFileEntry.new(path: filePath)
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
    let oldBookmarks =  StoredArticle.get(request: request)
    for article in oldBookmarks {
      set(article: article, active: true)
    }
    log("migrated: \(bookmarkedArticles.count)/\(oldBookmarks.count) Bookmarks")
  }
}
