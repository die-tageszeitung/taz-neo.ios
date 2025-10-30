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
  
  static func sync(localBookmarks: [StoredArticle]) async throws {
    guard let gqlFeeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      throw "No GQL feeder available"
    }
    
    // MARK: - 1️⃣ Lade Bookmarks vom Server
    let remoteBookmarks = try await gqlFeeder.loadBookmarks()
    print("✅ Retrieved \(remoteBookmarks.count) bookmarks from server")
    
    // MARK: - 2️⃣ Lade die Artikel der Bookmarks (nur die mediaSyncIds)
    let mediaSyncIds = remoteBookmarks.map { $0.mediaSyncId }
    let articles = try await gqlFeeder.loadArticles(withMediaSyncIds: mediaSyncIds)
    print("✅ Retrieved \(articles.count) bookmarked articles")
    
    // MARK: - 3️⃣ Synchronisationslogik (Beispielplatzhalter)
    // Hier würdest du:
    //  - lokale Bookmarks mit remoteBookmarks mergen
    //  - neue/entfernte Bookmarks erkennen
    //  - ggf. Änderungen pushen
    
    // Beispiel:
    //      for local in localBookmarks {
    //        if let remote = remoteBookmarks.first(where: { $0.mediaSyncId == local.mediaSyncId }) {
    //          // Bookmark existiert auch auf Server → ggf. aktualisieren
    //          print("Found remote match for \(local.mediaSyncId)")
    //        } else {
    //          // Lokal, aber nicht remote → evtl. hochladen
    //          print("Local-only bookmark \(local.mediaSyncId), might push to server")
    //        }
    //      }
    
    // MARK: - 4️⃣ Fertig
    print("✅ Bookmark sync finished.")
    Self.lastBookmarkSyncDate = Date()
  }
}
