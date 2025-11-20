//
//  BookmarksSyncBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import NorthLib
import Foundation

final class BookmarksSyncBusiness: DoesLog {
  
  @Default("localDeletedBookmarks")
  static var localDeletedBookmarksString: String   // "id:ts,id:ts"

  static var localDeletedBookmarks: [Int: TimeInterval] {
      get {
          guard !localDeletedBookmarksString.isEmpty else { return [:] }

          let pairs = localDeletedBookmarksString.split(separator: ",")
          var map: [Int: TimeInterval] = [:]

          for pair in pairs {
              let parts = pair.split(separator: ":")
              if parts.count == 2,
                 let id = Int(parts[0]),
                 let ts = TimeInterval(parts[1]) {
                  map[id] = ts
              }
          }
          return map
      }
      set {
          let str = newValue
              .map { "\($0.key):\($0.value)" }
              .joined(separator: ",")
          localDeletedBookmarksString = str
      }
  }

  /// Merkt lokale Löschung eines Bookmarks
  static func appendLocalDeletedBookmarkMediaSyncId(_ mediaSyncId: Int?) {
      guard let id = mediaSyncId else { return }

      var map = localDeletedBookmarks

      // Wenn noch nicht markiert → aktuell lokale Löschzeit
      if map[id] == nil {
          map[id] = Date().timeIntervalSince1970
      }

      localDeletedBookmarks = map
  }
  
  @Default("lastBookmarkSyncDate")
  static var lastBookmarkSyncDateString: String
  static var lastBookmarkSyncDate: Date? {
    get {
      guard Self.lastBookmarkSyncDateString.length > 0 else { return nil }
      return Date.fromString(Self.lastBookmarkSyncDateString)
    }
    set {
      if let new = newValue {
        Self.lastBookmarkSyncDateString = Date.toString(new)}
      else {
        Self.lastBookmarkSyncDateString = ""
      }
    }
  }
  static var lastBookmarkSyncAgoString: String {
    guard let date = lastBookmarkSyncDate else {
      return "noch nicht ausgeführt"
    }
    
    let secondsAgo = Int(Date().timeIntervalSince(date))
    
    switch secondsAgo {
      case 0..<1:
        return "gerade eben"
      case 1..<60:
        return "vor \(secondsAgo) " + (secondsAgo == 1 ? "Sekunde" : "Sekunden")
      case 60..<3600:
        let minutes = secondsAgo / 60
        return "vor \(minutes) " + (minutes == 1 ? "Minute" : "Minuten")
      default:
        let hours = secondsAgo / 3600
        return "vor \(hours) " + (hours == 1 ? "Stunde" : "Stunden")
    }
  }
  
  static func hasRemoteBookmarks() async throws -> Bool {
    guard let gqlFeeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      return false
    }
    return try await gqlFeeder.loadBookmarks().count > 0
  }
  
  /// Synchronizes bookmarks using a SINGLE-SOURCE-OF-TRUTH server model.
  /// Local tombstones are only used during *this* sync to avoid reviving deleted items.
  /// After a successful sync all tombstones are cleared.
  /// Returns true if something changed locally.
  static func sync(localBookmarks: [StoredArticle]) async throws -> Bool {
    guard let gqlFeeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      throw "No GQL feeder available"
    }
    
    //Log.log("Local bookmarks: \(localBookmarks.map { "\($0.serverId ?? -1)" }.joined(separator: ", "))")
    
    // --- 1) Pull remote bookmarks (THE authoritative list) ---
    let remoteBookmarks = try await gqlFeeder.loadBookmarks()
    //Log.log("✅ Retrieved \(remoteBookmarks.count) bookmarks: \(remoteBookmarks.map{"\($0.mediaSyncId)@\($0.date.dateAndTime)"}.joined(separator: ", ")) from server")
    
    // Lookups
    let remoteBookmarkDatesById: [String: Date] = Dictionary(
      uniqueKeysWithValues: remoteBookmarks.map { ($0.mediaSyncId, $0.date) }
    )
    let remoteIds = remoteBookmarkDatesById.keys
    let localMap: [String: StoredArticle] = Dictionary(
        uniqueKeysWithValues: localBookmarks.compactMap { l in
            guard let sid = l.serverId else { return nil }
            return (String(sid), l)
        }
    )
    
    // Tombstones (only relevant DURING current sync)
    let deletedMap = Self.localDeletedBookmarks
    
    // 1) Build initial list of remote-only ids (no CoreData access here)
    var remoteOnlyIdsToFetch: [String] = remoteBookmarks.compactMap { remote -> String? in
      let id = remote.mediaSyncId
      
      // Skip if tombstone says "deleted after last sync"
      if let last = Self.lastBookmarkSyncDate,
         let delTs = deletedMap[Int(id) ?? -1] {
        let deletedAt = Date(timeIntervalSince1970: delTs)
        if deletedAt > last { return nil }
      }
      
      // Skip if already present locally (fast in-memory map)
      return localMap[id] == nil ? id : nil
    }
    
    // 2) On MainActor: mark existing local articles as bookmarked and collect their ids to remove
    let candidateIds = remoteOnlyIdsToFetch // snapshot
    
    let idsRemovedFromFetchList: [String] = try await MainActor.run {
      var removed: [String] = []
      
      for id in candidateIds {
        guard let mediaSyncId = Int64(id) else { continue }
        guard let localArticle = StoredArticle.get(byMediaSyncId: mediaSyncId) else { continue }
        
        // If the article is already fully available locally, mark it bookmarked
        // and schedule its id to be removed from the fetch-list.
        if localArticle.html?.name != nil {
          try localArticle.activateBookmark(remoteBookmarkedDate: remoteBookmarkDatesById[id])
          removed.append(id)
        }
      }
      return removed
    }
    
    // 3) Remove those IDs from the fetch list (done outside the await)
    if !idsRemovedFromFetchList.isEmpty {
      remoteOnlyIdsToFetch.removeAll { idsRemovedFromFetchList.contains($0) }
    }
    
    // Now remoteOnlyIdsToFetch contains only IDs that truly need to be fetched from server.
    
    //Log.log("ℹ️ remoteOnly Article IDs to fetch: \(remoteOnlyIdsToFetch.count) \(remoteOnlyIdsToFetch.joined(separator: ", "))")
    
    // --- 3) Fetch missing remote articles ---
    var missingRemoteArticles: [GqlSingleArticle] = []
    if !remoteOnlyIdsToFetch.isEmpty {
      missingRemoteArticles = try await gqlFeeder.loadArticles(withMediaSyncIds: remoteOnlyIdsToFetch)
      Log.log("✅ Fetched \(missingRemoteArticles.count) remote articles")
      //Log.log("✅ Fetched \(missingRemoteArticles.count) remote articles \(missingRemoteArticles.map{$0.gqlArticle.serverId})")
    }
    
    // --- 4) Determine uploads & remote deletes ---
    // Upload = local exists but server does NOT have it, AND local was created after lastSync
    // Delete = local tombstone exists AND server still has it
    var toUpload: [StoredArticle] = []
    var remoteDeletes: [String] = []
    var localDeletes: [StoredArticle] = []
    
    let lastSync = Self.lastBookmarkSyncDate
    
    for (idStr, local) in localMap {
      if remoteIds.contains(idStr) { continue } // nothing to upload
      
      // First sync → always upload if server misses it
      guard let lastSync = lastSync else {
        toUpload.append(local)
        continue
      }
      
      let localDate = local.bookmarkedDate ?? .distantPast
      
      if localDate > lastSync {
        // Local create after last sync → upload
        toUpload.append(local)
      } else {
        // Server removed it → remove locally too
        localDeletes.append(local)
      }
    }
    
    // Remote deletes via tombstones
    if let last = lastSync {
      for (id, deletedAt) in deletedMap {
        if Date(timeIntervalSince1970: deletedAt) > last {
          let idStr = String(id)
          if remoteIds.contains(idStr) {
            remoteDeletes.append(idStr)
          }
        }
      }
    }
    
    Log.log("⬆️ toUpload: \(toUpload.count)  ⬇️ deleteRemote: \(remoteDeletes.count)  deleteLocal: \(localDeletes.count)")
//    Log.log("toUpload: \(toUpload.map { "\($0.serverId ?? -1)" }.joined(separator: ", "))")
//    Log.log("remoteDeletes: \(remoteDeletes.joined(separator: ", "))")
//    Log.log("localDeletes: \(localDeletes.map { "\($0.serverId ?? -1)" }.joined(separator: ", "))")
    
    let pulledArticlesCopy = missingRemoteArticles
    
    // --- 5) Persist pulled remote articles ---
    let persistedPulled = try await MainActor.run {
      try persistRemoteBookmarks(
        articles: pulledArticlesCopy,
        bookmarks: remoteBookmarks
      )
    }
    
    // --- 6) Prepare API update lists ---
    let uploadArticles = toUpload.map { local in
      BookmarkArticle(issueDate: local.bookmarkedDate, serverId: local.serverId)
    }
    let deleteArticlesForServer = remoteDeletes.compactMap { idStr -> BookmarkArticle? in
      guard let sid = Int(idStr) else { return nil }
      return BookmarkArticle(issueDate: nil, serverId: sid)
    }
    
    // --- 7) Apply remote updates ---
    let updateResults = try await gqlFeeder.updateRemoteBookmarks(
      newBookmarked: uploadArticles,
      deletedBookmarks: deleteArticlesForServer
    )
    
    if false {//enable/disable log and warning unused updateResults
      Log.log("ℹ️ Bookmark update results: \(updateResults.count) entries processed")
    }
    
    let localDeletesCopy = localDeletes
    
    // --- 8) Apply local deletes ---
    await MainActor.run {
      var changed: [StoredArticle] = []
      
      // Add remote-pulled
      changed.append(contentsOf: persistedPulled)
      
      // Local deletes from "server removed"
      for local in localDeletesCopy {
        Log.debug("Deleting local bookmark \(local.title ?? "-") MediaSyncID: \(local.serverId ?? -1) because server removed it.")
        local.delete()
        changed.append(local)
      }
      
      if !changed.isEmpty {
        ArticleDB.save()
        for art in changed {
          Notification.send(Const.NotificationNames.bookmarkChanged, sender: art)
        }
      }
    }
    
    // --- 9) Update sync timestamp ---
    Self.lastBookmarkSyncDate = Date()
    
    // --- 10) IMPORTANT: Clear ALL tombstones (SPOT model) ---
    Self.localDeletedBookmarks = [:]
    
    // --- 11) Result ---
    let didChange =
    !persistedPulled.isEmpty ||
    !toUpload.isEmpty ||
    !remoteDeletes.isEmpty ||
    !localDeletes.isEmpty
    
    Log.log("✅ Bookmark sync finished. Changes: \(didChange ? "YES" : "NO")")
    
    return didChange
  }

  /// WARNING: DB INTERACTION – must run on Main Thread
  @MainActor
  private static func persistRemoteBookmarks(
    articles: [GqlSingleArticle],
    bookmarks: [GqlBookmarkCustomerData]
  ) throws -> [StoredArticle] {
    
    var persistedArticles: [StoredArticle] = []
    
    for article in articles {
      // Fetches or creates CoreData entity
      guard let storedArticle = article.getOrCreateStoredBookmarkArticle() else { continue }
      
      var remoteDate: Date?
      if let remote = bookmarks.first(where: { $0.mediaSyncId == String(article.gqlArticle.serverId ?? 0) }),
         let time = TimeInterval(remote.sTime) {
        remoteDate = Date(timeIntervalSince1970: time)
      }
      try storedArticle.activateBookmark(remoteBookmarkedDate: remoteDate)
      persistedArticles.append(storedArticle)
    }
    return persistedArticles
  }
}

/// WARNING: DB INTERACTION – must run on Main Thread
fileprivate extension StoredArticle {
  @MainActor
  func activateBookmark(remoteBookmarkedDate:Date?) throws {
    guard let bookmarkSection = Bookmarks.shared.bookmarkSection else {
      throw "No Bookmark Section!"
    }
    // Add relations
    self.pr.addToSections(bookmarkSection.pr)
    bookmarkSection.pr.addToArticles(self.pr)
    
    if self.bookmarkedDate == nil {
      self.bookmarkedDate = remoteBookmarkedDate
    }
  }
}

fileprivate extension GqlSingleArticle {
  func getOrCreateStoredBookmarkArticle() -> StoredArticle? {
    if let storedArticle = StoredArticle.get(object: gqlArticle){
      return storedArticle
    }
    
    guard let issueDir = Bookmarks.shared.commonIssueDir(for: issueDate) else {
      error("something went wrong, did not found commonIssueDir for: \(self)")
      return nil
    }
    
    guard let feederContext = TazAppEnvironment.sharedInstance.feederContext else {
      error("something went wrong, feederContext not available")
      return nil
    }
    
    guard let feeder = feederContext.storedFeeder else {
      error("something went wrong, did not found feeder")
      return nil
    }
    
    ///link Resources (js/css/author images) if needed
    if issueDir.exists == false {
      issueDir.create()
    }
    let rlink = File(dir: issueDir.path, fname: "resources")
    let glink = File(dir: issueDir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: feeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: feeder.globalDir.path) }
    
    var dlFiles: [FileEntry]  = gqlArticle.files
    
    let momentFilename = issueDate.defaultMomentImageFilename
    dlFiles.append(TmpFileEntry(name: momentFilename))
    log("Download moment file: \(momentFilename)")
    
    if dlFiles.count > 0 {
      ///try to download not yet downloaded files
      feederContext.dloader.downloadSearchHitFiles(files: dlFiles, baseUrl: baseUrl, targetDir: issueDir, closure: { err in
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
    let storedArticle = StoredArticle.persist(object: gqlArticle)
    
    ///set default properties, wich are not set correctly in
    storedArticle.pr.issueDate = issueDate
    storedArticle.baseURL = baseUrl
    storedArticle.sectionTitle = sectionTitle ?? gqlArticle.sectionTitle
    for au in gqlArticle.authors ?? [] {
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
