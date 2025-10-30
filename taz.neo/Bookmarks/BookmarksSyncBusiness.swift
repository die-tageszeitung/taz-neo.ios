//
//  BookmarksSyncBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import NorthLib
import Foundation

final class BookmarksSyncBusiness {
  
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
  
  static func sync(localBookmarks: [StoredArticle]) async throws -> Bool {
    guard let gqlFeeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      throw "No GQL feeder available"
    }
    
    // MARK: - 1️⃣ Lade Bookmarks vom Server
    let remoteBookmarks = try await gqlFeeder.loadBookmarks()
    print("✅ Retrieved \(remoteBookmarks.count) bookmarks from server")
    
    // MARK: - 2️⃣ Berechne MediaSyncIDs, die noch lokal fehlen
    let localIds = Set(localBookmarks.compactMap { $0.serverId }.map { String($0) })
    let missingRemoteIds = remoteBookmarks
      .map { $0.mediaSyncId }
      .filter { !localIds.contains($0) }
    
    print("ℹ️ \(missingRemoteIds.count) remote bookmarks missing locally")
    
    // MARK: - 3️⃣ Lade die fehlenden Artikel
    let missingArticles = try await gqlFeeder.loadArticles(withMediaSyncIds: missingRemoteIds)
    print("✅ Retrieved \(missingArticles.count) missing bookmarked articles")
    
    // MARK: - 4️⃣ Mergen: Setze bookmarkedDate bei lokalen Artikeln
    // RemoteBookmarks enthalten `time` (UNIX Timestamp)
    
    var mergedArticles: [StoredArticle] = []
    
    // 4a - Update vorhandene lokale Artikel, falls sie remote gebookmarkt sind
    for local in localBookmarks {
      if let remote = remoteBookmarks.first(where: { String(local.serverId ?? 0) == $0.mediaSyncId }) {
        local.bookmarkedDate = Date(timeIntervalSince1970: TimeInterval(remote.sTime) ?? Date().timeIntervalSince1970)
        mergedArticles.append(local)
      }
    }
    ///MAIN!!!
    // 4b - Füge die fehlenden Artikel als neue StoredArticle hinzu
    let newStoredArticles: [StoredArticle] = try await MainActor.run {
      try persistRemoteBookmarks(articles: missingArticles, bookmarks: remoteBookmarks)
    }
    mergedArticles.append(contentsOf: newStoredArticles)
    
    // MARK: - 5️⃣ Optional: Entfernte Bookmarks erkennen
    // z.B. alle lokalen Artikel, die nicht mehr auf remoteBookmarks sind
    let remoteIdsSet = Set(remoteBookmarks.map { $0.mediaSyncId })
    let removedLocal = mergedArticles.filter { !remoteIdsSet.contains(String($0.serverId ?? 0)) }
    if !removedLocal.isEmpty {
      #warning("TODO!!!!")
      print("⚠️ \(removedLocal.count) bookmarks removed on server")
      // Optional: löschen oder markieren
    }
    
    // MARK: - 6️⃣ Fertig
    print("✅ Bookmark sync finished. Total merged: \(mergedArticles.count)")
    Self.lastBookmarkSyncDate = Date()
    
    guard newStoredArticles.count > 0 else { return removedLocal.count > 0 }
    await MainActor.run {
      ArticleDB.save()
      for article in newStoredArticles {
        Notification.send(Const.NotificationNames.bookmarkChanged, sender: article)
      }
    }
    return true
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



fileprivate extension GqlSingleArticle {
  func getOrCreateStoredBookmarkArticle() -> StoredArticle? {
    if let storedArticle = StoredArticle.get(object: gqlArticle){
        return storedArticle
    }
    
    guard let issueDir = Bookmarks.shared.commonIssueDir(for: date) else {
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
    
    var dlFiles: [FileEntry]  = []
    
    ///copy serach content to target issue dir
    for fileEntry in gqlArticle.files {
      let f = File(dir: Dir.searchResults.path, fname: fileEntry.fileName)
      if !f.exists { dlFiles.append(fileEntry); continue }
      f.copyResourceWT(to: issueDir.path + "/" + fileEntry.fileName)
    }
    
    ///copy serach content to target issue dir
    for author in gqlArticle.authors ?? [] {
      guard let fileEntry = author.photo else { continue }
      let f = File(dir: feeder.globalDir.path, fname: fileEntry.fileName)
      if !f.exists { dlFiles.append(fileEntry) }
    }
    
    if dlFiles.count > 0 {
      ///try to download not yet downloaded files
      feederContext.dloader.downloadSearchHitFiles(files: dlFiles, baseUrl: baseUrl, closure: { err in
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
    storedArticle.pr.issueDate = date
    storedArticle.baseURL = baseUrl
    storedArticle.sectionTitle = sectionTitle
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
