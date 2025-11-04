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
  
  static func sync(localBookmarks: [StoredArticle]) async throws -> Bool {
    guard let gqlFeeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      throw "No GQL feeder available"
    }
    
    // 1) Remote abrufen
    let remoteBookmarks = try await gqlFeeder.loadBookmarks()
    print("✅ Retrieved \(remoteBookmarks.count) bookmarks from server")
    
    // Hilfsdaten
    let lastSync = Self.lastBookmarkSyncDate
    let remoteIdsSet = Set(remoteBookmarks.map { $0.mediaSyncId })
    let localById: [String: StoredArticle] = Dictionary(
      uniqueKeysWithValues: localBookmarks.compactMap { local in
        guard let sid = local.serverId else { return nil }
        return (String(sid), local)
      }
    )
    
    // 2) Neue remote-only IDs bestimmen (nur solche, die neuer sind als lastSync)
    let missingRemoteIds = remoteBookmarks
      .filter { remote in
        guard localById[remote.mediaSyncId] == nil else { return false }
        if let last = lastSync, let t = TimeInterval(remote.sTime) {
          return Date(timeIntervalSince1970: t) > last
        }
        return true
      }
      .map(\.mediaSyncId)
    
    print("ℹ️ \(missingRemoteIds.count) new remote bookmarks (since last sync)")
    
    // 3) Lade nur die wirklich neuen remote-Artikel
    var missingArticles: [GqlSingleArticle] = []
    if !missingRemoteIds.isEmpty {
      missingArticles = try await gqlFeeder.loadArticles(withMediaSyncIds: missingRemoteIds)
      print("✅ Retrieved \(missingArticles.count) missing bookmarked articles")
    }
    
    // 4) Merge vorhandener lokaler Artikel (wenn auch remote vorhanden, aktualisiere bookmarkedDate)
    var mergedArticles: [StoredArticle] = []
    for (_, local) in localById {
      if let remote = remoteBookmarks.first(where: { $0.mediaSyncId == String(local.serverId ?? 0) }) {
        if let t = TimeInterval(remote.sTime) {
          local.bookmarkedDate = Date(timeIntervalSince1970: t)
        }
        mergedArticles.append(local)
      }
    }
    
    // 5) Bestimme Uploads vs. lokale Löschungen
    var toUpload: [StoredArticle] = []
    var toDeleteLocal: [StoredArticle] = []
    
    for (_, local) in localById {
      let idStr = String(local.serverId ?? 0)
      if remoteIdsSet.contains(idStr) { continue }
      
      guard let last = lastSync else {
        // Erstsynchronisation → hochladen statt löschen
        toUpload.append(local)
        continue
      }
      
      let localDate = local.bookmarkedDate ?? .distantPast
      if localDate > last {
        toUpload.append(local)
      } else {
        toDeleteLocal.append(local)
      }
    }
    
    print("⬆️ toUpload: \(toUpload.count)  ⬇️ toDeleteLocal: \(toDeleteLocal.count)")
    
    // 6) Neue Remote-Artikel persistieren (Datenkopien zum Schutz)
    let articlesCopy = missingArticles
    let bookmarksCopy = remoteBookmarks
    // persistRemoteBookmarks selbst läuft bereits auf MainActor intern; wir rufen sie auf und erhalten result
    let newStoredArticles: [StoredArticle] = try await MainActor.run {
      try persistRemoteBookmarks(articles: articlesCopy, bookmarks: bookmarksCopy)
    }
    
    // 7) Server-Update (nur Uploads)
    let updateResults = try await gqlFeeder.updateRemoteBookmarks(
      newBookmarked: toUpload,
      deletedBookmarks: []
    )
    print("ℹ️ Bookmark update results: \(updateResults.count) entries processed")
    
    // ---------------------------
    // Wichtig: Erstelle hier unveränderliche Kopien aller Variablen,
    // die du im MainActor.run verwenden willst, um Swift-6-Capture-Fehler zu vermeiden.
    // ---------------------------
    let newStoredArticlesCopy = newStoredArticles
    let toDeleteLocalCopy = toDeleteLocal
    // Falls du weitere Collections brauchst, kopiere sie ebenfalls:
    // let toUploadCopy = toUpload
    
    // 8) Abschluss: DB-Änderungen und Notifications (nur ein MainActor.run!)
    await MainActor.run {
      var changedArticles: [StoredArticle] = []
      
      // Neue vom Server persistierte Artikel
      changedArticles.append(contentsOf: newStoredArticlesCopy)
      
      // Remote-gelöschte lokal entfernen
      for local in toDeleteLocalCopy {
        Log.log("Deleting local bookmark \(local.title ?? "-") MediaSyncID: \(local.serverId ?? -1) because server removed it.")
        local.delete()
        changedArticles.append(local)
      }
      
      // DB speichern, Notifications senden
      if !changedArticles.isEmpty {
        ArticleDB.save()
        for article in changedArticles {
          Notification.send(Const.NotificationNames.bookmarkChanged, sender: article)
        }
      }
    }
    
    // 9) Letzten Sync-Zeitpunkt aktualisieren
    Self.lastBookmarkSyncDate = Date()
    
    // 10) Rückgabe: hat sich was geändert?
    let didChange = !newStoredArticlesCopy.isEmpty || !toUpload.isEmpty || !toDeleteLocalCopy.isEmpty
    print("✅ Bookmark sync finished. Changes: \(didChange ? "YES" : "NO")")
    
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
