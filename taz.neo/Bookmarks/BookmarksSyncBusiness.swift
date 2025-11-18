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
  
  /// Synchronizes bookmarks between local and server using tombstones (local deletion timestamps).
  /// Returns true if something changed (new remote articles persisted, local deletions applied, uploads/deletes executed).
  static func sync(localBookmarks: [StoredArticle]) async throws -> Bool {
    guard let gqlFeeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      throw "No GQL feeder available"
    }
    
    // 1) Pull remote bookmarks
    let remoteBookmarks = try await gqlFeeder.loadBookmarks()
    Log.log("✅ Retrieved \(remoteBookmarks.count) bookmarks from server")
    
    // Snapshot common values to avoid capturing mutable variables across awaits
    let lastSync = Self.lastBookmarkSyncDate
    let deletedMap = Self.localDeletedBookmarks // [Int: TimeInterval] persisted tombstones
    // Convenience sets/maps
    let remoteById: [String: GqlBookmarkCustomerData] = Dictionary(uniqueKeysWithValues: remoteBookmarks.map { ($0.mediaSyncId, $0) })
    let remoteIdsSet = Set(remoteBookmarks.map { $0.mediaSyncId })
    
    let localById: [String: StoredArticle] = Dictionary(
      uniqueKeysWithValues: localBookmarks.compactMap { local in
        guard let sid = local.serverId else { return nil }
        return (String(sid), local)
      }
    )
    let localIdsSet = Set(localById.keys)
    
    // 2) Decide which remote-only IDs to pull:
    //    - remote-only (not present locally)
    //    - not blocked by a local tombstone (deleted AFTER lastSync)
    //    - and remote.time > lastSync (or if lastSync == nil: first sync -> pull everything)
    let remoteOnlyToPull: [String] = remoteBookmarks.compactMap { remote in
      let id = remote.mediaSyncId
      
      // Skip if already present locally
      if localById[id] != nil { return nil }
      
      // If a tombstone exists and was recorded after lastSync => the user deleted locally after last sync.
      // In that case we must NOT pull the remote item (we intend to delete remote).
      if let last = lastSync, let deletedAt = deletedMap[Int(id) ?? -1] {
        let deletedAtDate = Date(timeIntervalSince1970: deletedAt)
        if deletedAtDate > last {
          return nil
        }
      }
      
      // If we have a lastSync, only pull if remote is newer than lastSync
      if let last = lastSync, let t = TimeInterval(remote.sTime) {
        let remoteDate = Date(timeIntervalSince1970: t)
        return remoteDate > last ? id : nil
      }
      
      // No lastSync => first sync -> pull everything remote-only
      return id
    }
    
    Log.log("ℹ️ remoteOnlyToPull: \(remoteOnlyToPull.count)")
    
    // 3) Fetch remote articles for those to pull
    var pulledArticles: [GqlSingleArticle] = []
    if !remoteOnlyToPull.isEmpty {
      pulledArticles = try await gqlFeeder.loadArticles(withMediaSyncIds: remoteOnlyToPull)
      Log.log("✅ Pulled \(pulledArticles.count) remote articles")
    }
    
    // 4) Decide uploads (local-only and created after lastSync or first sync),
    //    local deletes to apply (server removed items that local didn't change since lastSync),
    //    and tombstone-based remote deletes (local deleted after lastSync -> delete remote)
    var toUpload: [StoredArticle] = []
    var localDeletesToApply: [StoredArticle] = []
    var tombstoneDeletesToRemoteIds: [String] = []
    
    // 4a) For each local item that is NOT on remote:
    for (id, local) in localById {
      if remoteIdsSet.contains(id) { continue } // remote still has it -> no upload decision here
      
      // If no lastSync -> first sync -> upload local to remote to preserve user's data
      guard let last = lastSync else {
        toUpload.append(local)
        continue
      }
      
      let localDate = local.bookmarkedDate ?? .distantPast
      if localDate > last {
        // local created/changed after last sync -> upload
        toUpload.append(local)
      } else {
        // local existed before last sync but remote now lacks it -> server removed it -> delete local
        localDeletesToApply.append(local)
      }
    }
    
    // 4b) For tombstones: delete on server if tombstone was recorded after lastSync and server still has the id
    if let last = lastSync {
      for (idInt, deletedAt) in deletedMap {
        let deletedAtDate = Date(timeIntervalSince1970: deletedAt)
        if deletedAtDate > last {
          let idStr = String(idInt)
          if remoteIdsSet.contains(idStr) {
            tombstoneDeletesToRemoteIds.append(idStr)
          }
        }
      }
    } else {
      // first sync: do not issue server deletes for local deletions before first sync
    }
    
    Log.log("⬆️ toUpload: \(toUpload.count)  ⬇️ tombstoneDeletesToRemote: \(tombstoneDeletesToRemoteIds.count)  localDeletesToApply: \(localDeletesToApply.count)")
    
    // 5) Persist pulled remote articles (MainActor) — copy arrays first to avoid captures
    let pulledCopy = pulledArticles
    let remoteBookmarksCopy = remoteBookmarks
    let persistedPulled: [StoredArticle] = try await MainActor.run {
      try persistRemoteBookmarks(articles: pulledCopy, bookmarks: remoteBookmarksCopy)
    }
    
    // 6) Prepare server operations: convert StoredArticle -> SimpleArticle for API   
    let uploadArticles: [SimpleArticle] = toUpload.map { local in
      SimpleArticle(issueDate: local.bookmarkedDate, serverId: local.serverId)
    }
    let deleteArticlesForServer: [SimpleArticle] = tombstoneDeletesToRemoteIds.compactMap { idStr in
      guard let sid = Int(idStr) else { return nil }
      return SimpleArticle(issueDate: nil, serverId: sid)
    }
    
    // 7) Call updateRemoteBookmarks (uploads + deletes)
    // Note: your updateRemoteBookmarks signature expects SimpleArticle arrays now
    let updateResults = try await gqlFeeder.updateRemoteBookmarks(
      newBookmarked: uploadArticles,
      deletedBookmarks: deleteArticlesForServer
    )
    Log.log("ℹ️ Bookmark update results: \(updateResults.count) entries processed")
    
    // 8) Process server results: remove successful tombstones from persistent store
    // Collect succeeded delete ids (serverId ints -> Strings)
    let succeededDeleteIds: [String] = updateResults
      .filter { $0.operation == .delete && $0.error == nil }
      .compactMap { $0.article.serverId }
      .map { String($0) }
    
    if !succeededDeleteIds.isEmpty {
      var tombstones = Self.localDeletedBookmarks // [Int: TimeInterval]
      for idStr in succeededDeleteIds {
        if let id = Int(idStr) { tombstones.removeValue(forKey: id) }
      }
      Self.localDeletedBookmarks = tombstones
    }
    
    // 9) Single MainActor.run for all local DB changes & notifications
    let persistedPulledCopy = persistedPulled
    let localDeletesToApplyCopy = localDeletesToApply
    // Note: toUpload are local items we uploaded; nothing to change locally for success case here.
    
    await MainActor.run {
      var changed: [StoredArticle] = []
      
      // a) Add persisted pulled articles
      changed.append(contentsOf: persistedPulledCopy)
      
      // b) Apply local deletes (server removed these)
      for local in localDeletesToApplyCopy {
        Log.log("Deleting local bookmark \(local.title ?? "-") MediaSyncID: \(local.serverId ?? -1) because server removed it.")
        local.delete() // implement actual CoreData deletion / bookmark removal
        changed.append(local)
      }
      
      // c) Save & notify if anything changed
      if !changed.isEmpty {
        ArticleDB.save()
        for art in changed {
          Notification.send(Const.NotificationNames.bookmarkChanged, sender: art)
        }
      }
    }
    
    // 10) Update last sync timestamp
    Self.lastBookmarkSyncDate = Date()
    
    // 11) Return whether anything changed
    let didChange = !persistedPulled.isEmpty || !toUpload.isEmpty || !localDeletesToApply.isEmpty || !succeededDeleteIds.isEmpty
    Log.log("✅ Bookmark sync finished. Changes: \(didChange ? "YES" : "NO")")
    return didChange
  }
  
  /// WARNING: DB INTERACTION – must run on Main Thread
  @MainActor
  private static func persistRemoteBookmarks(
    articles: [GqlSingleArticle],
    bookmarks: [GqlBookmarkCustomerData]
  ) throws -> [StoredArticle] {
    
    guard let bookmarkSection = Bookmarks.shared.bookmarkSection else {
      throw "No Bookmark Section!"
    }
    
    var persistedArticles: [StoredArticle] = []
    
    for article in articles {
      // Fetches or creates CoreData entity
      guard let storedArticle = article.getOrCreateStoredBookmarkArticle() else { continue }
      
      // Add relations
      storedArticle.pr.addToSections(bookmarkSection.pr)
      bookmarkSection.pr.addToArticles(storedArticle.pr)
      
      // Set bookmarked date (from remote timestamp)
      if storedArticle.bookmarkedDate == nil,
         let remote = bookmarks.first(where: { $0.mediaSyncId == String(article.gqlArticle.serverId ?? 0) }),
         let time = TimeInterval(remote.sTime) {
        storedArticle.bookmarkedDate = Date(timeIntervalSince1970: time)
      }
      persistedArticles.append(storedArticle)
    }
    return persistedArticles
  }
}

struct SimpleArticle {
  var issueDate: Date?
  var serverId: Int?
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
