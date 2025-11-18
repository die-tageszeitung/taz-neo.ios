//
//  HelpBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 13.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import NorthLib
import UIKit

protocol HelpProviding {
  /// called when the global help button is tapped
  var helpItems: [HelpItem] { get }
  var newItemsCount: Int { get }
}

extension HelpProviding {
  var newItemsCount: Int { helpItems.count - (lastIndex ?? 0)  }
  
  /// The concrete type name of the conforming object
  var typeName: String {
    String(describing: type(of: self))
  }
  func isSameType(as other: HelpProviding) -> Bool {
    self.typeName == other.typeName
  }
  
  var lastIndex: Int? {
    switch self {
      case is HomeVC:
        return HelpBusiness.shared.lastHomeHelpIndex
      case is SectionVC:
        return HelpBusiness.shared.lastSectionHelpIndex
      case is ArticleVC:
        return HelpBusiness.shared.lastArticleHelpIndex
      case is TazPdfPagesViewController:
        return HelpBusiness.shared.lastPdfHelpIndex
      case is ArticlePlayer:
        return HelpBusiness.shared.lastPlayerHelpIndex
      case is NewContentTableVC:
        return HelpBusiness.shared.lastSliderHelpIndex
      default:
        return nil
    }
  }
  
  var doNotShowHelpInThisAreaAnymore: Bool {
    get { lastIndex ?? 0  < 0 }
    set {
      guard newValue == true else { return }
      switch self {
        case is HomeVC:
          HelpBusiness.shared.lastHomeHelpIndex = -1
        case is SectionVC:
          return HelpBusiness.shared.lastSectionHelpIndex = -1
        case is ArticleVC:
          return HelpBusiness.shared.lastArticleHelpIndex = -1
        case is ArticlePlayer:
          return HelpBusiness.shared.lastPlayerHelpIndex = -1
        case is TazPdfPagesViewController:
          return HelpBusiness.shared.lastPdfHelpIndex  = -1
        case is NewContentTableVC:
          return HelpBusiness.shared.lastSliderHelpIndex = -1
        default:
          break
      }
    }
  }
  
  func showHelpButton(){
    guard doNotShowHelpInThisAreaAnymore == false else { return }
    (TazAppEnvironment.sharedInstance.rootViewController
            as? MainTabVC)?.helpButton.showAnimated()
  }
  
  func hideHelpButton(){
    (TazAppEnvironment.sharedInstance.rootViewController
            as? MainTabVC)?.helpButton.hideAnimated()
  }
}

class HelpBusiness {
  
  
  @Default("showHelp")
  public var showHelp: Bool
  
  @Default("lastHomeHelpIndex")
  public var lastHomeHelpIndex: Int
  @Default("lastSectionHelpIndex")
  public var lastSectionHelpIndex: Int
  @Default("lastArticleHelpIndex")
  public var lastArticleHelpIndex: Int
  @Default("lastPlayerHelpIndex")
  public var lastPlayerHelpIndex: Int
  @Default("lastSliderHelpIndex")
  public var lastSliderHelpIndex: Int
  @Default("lastPdfHelpIndex")
  public var lastPdfHelpIndex: Int
  @Default("helpUsedOnce")
  public var helpUsedOnce: Bool
  
  func resetHelp(){
    helpUsedOnce = false
    lastHomeHelpIndex = 0
    lastSectionHelpIndex = 0
    lastArticleHelpIndex = 0
    lastPlayerHelpIndex = 0
    lastSliderHelpIndex = 0
    lastPdfHelpIndex = 0
  }
  
  
  func openHelp(){
    guard let window = UIApplication.shared.delegate?.window,
          let mainTabVc = TazAppEnvironment.sharedInstance.rootViewController as? MainTabVC,
    var helpProvider = mainTabVc.currentHelpProvider else { return }
    let helpItemsCount = helpProvider.helpItems.count
    
    if let cvc = helpProvider as? ContentVC {
      cvc.toolBar.show(show: true, animated: false)
    }
    
    ///show layer
    let helpView = HelpView()
    if helpProvider is ArticlePlayer {
      helpView.pageControllBottomOffset = -250
    }
    
    let close = {
      Notification.send(Const.NotificationNames.helpProviderChanged)
      UIView.animate(withDuration: 0.5,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
        helpView.alpha = 0.0
      }, completion: {(_) in
        helpView.removeFromSuperview()
      })
    }
    
    ///addSubview changes index, save it before
    let lastIndex = lastHelpItemIndex(for: helpProvider)
    helpView.onDisplay {[weak self] idx in
      self?.display(idx: idx, for: helpProvider)
      if idx + 1 >= helpItemsCount {
        helpView.doNotShowHelpInThisAreaAnymore.showAnimated()
        helpView.doNotShowHelpInThisAreaAnymore.onTapping { _ in
          helpProvider.doNotShowHelpInThisAreaAnymore = true
          close()
          Notification.send(Const.NotificationNames.helpProviderChanged)
        }
      }
    }
    
    helpView.items = helpProvider.helpItems
    helpView.frame = window?.bounds ?? .zero // oder mit Auto Layout Constraints
    helpView.alpha = 0.0
    window?.addSubview(helpView)
    helpView.setLastMaxIndex(idx: lastIndex)
    UIView.animate(withDuration: 0.2,
                   delay: 0,
                   options: UIView.AnimationOptions.curveEaseIn,
                   animations: {
      helpView.alpha = 1.0
    }, completion: { (_) in
      if helpView.isTopmost == false {
        window?.bringSubviewToFront(helpView)
      }
    })
    helpView.onClose { close() }
  }
  
  private func lastHelpItemIndex(for helpProvider: HelpProviding) -> Int?{
    switch helpProvider {
      case is HomeVC:
        return lastHomeHelpIndex
      case is SectionVC:
        return lastSectionHelpIndex
      case is ContentVC:
        return lastArticleHelpIndex
      case is ArticlePlayer:
        return lastPlayerHelpIndex
      case is TazPdfPagesViewController:
        return lastPdfHelpIndex
      case is NewContentTableVC:
        return lastSliderHelpIndex
      default:
        return nil
    }
  }
  
  private func display(idx:Int, for helpProvider: HelpProviding){
    switch helpProvider {
      case is HomeVC:
        lastHomeHelpIndex = max(idx+1, lastHomeHelpIndex)
      case is SectionVC:
        lastSectionHelpIndex = max(idx+1, lastSectionHelpIndex)
      case is ArticleVC:
        lastArticleHelpIndex = max(idx+1, lastArticleHelpIndex)
      case is TazPdfPagesViewController:
        lastPdfHelpIndex = max(idx+1, lastPdfHelpIndex)
      case is ArticlePlayer:
        lastPlayerHelpIndex = max(idx+1, lastPlayerHelpIndex)
      case is NewContentTableVC:
        lastSliderHelpIndex = max(idx+1, lastSliderHelpIndex)
      default:
        break
    }
  }
  
  static let shared = HelpBusiness()
}

/// MARK: Access Helper
extension HelpBusiness {
  private static var mainTabVc: MainTabVC? {
    TazAppEnvironment.sharedInstance.rootViewController
     as? MainTabVC
  }
  
  static var helpButtonPlayerOffset: Double? {
    get { mainTabVc?.helpButtonPlayerOffset }
    set { if let newValue = newValue { mainTabVc?.helpButtonPlayerOffset = newValue } }
  }
  static var helpButtonToolbarOffset: Double? {
    get { mainTabVc?.helpButtonToolbarOffset }
    set { if let newValue = newValue { mainTabVc?.helpButtonToolbarOffset = newValue } }
  }
  static var helpButtonAdditionalSheetOffset: Double? {
    get { mainTabVc?.helpButtonAdditionalSheetOffset }
    set { if let newValue = newValue { mainTabVc?.helpButtonAdditionalSheetOffset = newValue } }
  }
}

extension MainTabVC {
  var currentHelpProvider: HelpProviding? {
    if ArticlePlayer.singleton.isMaxiPlayer {
      return ArticlePlayer.singleton
    }
    if let nav = selectedViewController as? UINavigationController {
      if let cvc = nav.visibleViewController as? ContentVC,
         cvc.slider?.isOpen == true {
        return cvc.slider?.slider as? HelpProviding
      }
      else if let cvc = nav.visibleViewController as? TazPdfPagesViewController,
         cvc.slider?.isOpen == true {
        return cvc.slider?.slider as? HelpProviding
      }
      return nav.visibleViewController as? HelpProviding
    } else {
      return selectedViewController as? HelpProviding
    }
  }
}
/*
fileprivate extension BookmarksSyncBusiness {
  /** ** END - END ** END ** END ** END ** END ** END ** END ** END ** END ** END ** END - END **/
  
  /// Synchronisiert lokale und entfernte Bookmarks bidirektional.
   /// Gibt `true` zurück, wenn sich etwas geändert hat (neue oder entfernte Bookmarks).
   static func sync44(localBookmarks: [StoredArticle]) async throws -> Bool {
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

     // 4) Merge vorhandene lokale Artikel (wenn auch remote vorhanden, aktualisiere bookmarkedDate)
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
     let newStoredArticles: [StoredArticle] = try await MainActor.run {
       try persistRemoteBookmarks(articles: articlesCopy, bookmarks: bookmarksCopy)
     }

     // 7) Server-Update (nur Uploads)
     let updateResults = try await gqlFeeder.updateRemoteBookmarks(
       newBookmarked: toUpload,
       deletedBookmarks: []
     )
     print("ℹ️ Bookmark update results: \(updateResults.count) entries processed")

     // 8) Abschluss: DB-Änderungen und Notifications (nur ein MainActor.run!)
     let toDeleteLocalCopy = toDeleteLocal
     
     await MainActor.run {
       var changedArticles: [StoredArticle] = []

       // Neue vom Server persistierte Artikel
       changedArticles.append(contentsOf: newStoredArticles)

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
     let didChange = !newStoredArticles.isEmpty || !toUpload.isEmpty || !toDeleteLocal.isEmpty
     print("✅ Bookmark sync finished. Changes: \(didChange ? "YES" : "NO")")

     return didChange
   }
  
  // Synchronisiert lokale und entfernte Bookmarks bidirektional.
    /// Gibt `true` zurück, wenn sich etwas geändert hat (neue oder entfernte Bookmarks).
    static func sync3bnevertested(localBookmarks: [StoredArticle]) async throws -> Bool {
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
          // remote not present locally
          guard localById[remote.mediaSyncId] == nil else { return false }
          // if we have a lastSync, only consider remote items newer than lastSync
          if let last = lastSync, let t = TimeInterval(remote.sTime) {
            let remoteDate = Date(timeIntervalSince1970: t)
            return remoteDate > last
          }
          // no last sync -> bring everything
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
          } else {
            // falls parse fehlschlägt, belasse vorhandenes bookmarkedDate
          }
          mergedArticles.append(local)
        }
      }

      // 5) Persistiere die neu vom Server kommenden Artikel (MainActor)
      let articlesCopy = missingArticles
      let bookmarksCopy = remoteBookmarks
      let newStoredArticles: [StoredArticle] = try await MainActor.run {
        try persistRemoteBookmarks(articles: articlesCopy, bookmarks: bookmarksCopy)
      }
      mergedArticles.append(contentsOf: newStoredArticles)

      // 6) Entscheide Upload vs. Local-Delete für alle lokalen Bookmarks, die remote NICHT vorhanden sind
      var toUpload: [StoredArticle] = []
      var toDeleteLocal: [StoredArticle] = []

      for (_, local) in localById {
        let idStr = String(local.serverId ?? 0)
        // remote has it -> skip (already handled above)
        if remoteIdsSet.contains(idStr) {
          continue
        }

        // remote does not have it
        // if no lastSync -> conservative: treat as new local -> upload
        guard let last = lastSync else {
          toUpload.append(local)
          continue
        }

        // we have lastSync -> use local.bookmarkedDate to decide
        let localDate = local.bookmarkedDate ?? Date.distantPast
        if localDate > last {
          // local was created/modified AFTER last sync -> upload
          toUpload.append(local)
        } else {
          // local was not changed since last sync -> server must have deleted it -> delete local
          toDeleteLocal.append(local)
        }
      }

      print("⬆️ toUpload: \(toUpload.count)  ⬇️ toDeleteLocal: \(toDeleteLocal.count)")

      // 7) Führe Uploads/Deletes am Server aus (Uploads = neue lokale bookmarks, Deletes = remote deletions? no: toDeleteLocal are local deletes we should not delete remotely)
      // NOTE: For deletes on server we need to decide the case "locally deleted -> server delete".
      // Here: toUpload = send saveCustomerData; toDeleteRemote = local deletions (local removed since last sync) -> compute:
      let localDeletedSinceLastSync: [StoredArticle] = localBookmarks
        .filter { local in
          let idStr = String(local.serverId ?? 0)
          // server still has it but local no longer bookmarked -> hard to detect here; this would require tracking bookmark removal explicitly.
          return false // placeholder; depends on how you model "deleted locally" (e.g., mark or remove)
        }

      // In your described scenario (remote cleared everything), toDeleteLocal contains the items to remove locally.
      // We will upload the toUpload list, and we will NOT issue server deletes for items that are local-only but older than lastSync (they were likely removed on server).
      let updateResults = try await gqlFeeder.updateRemoteBookmarks(
        newBookmarked: toUpload,
        deletedBookmarks: [] // we only send deletes-to-server when we detect "local deletions" (not implemented here)
      )

      // 8) Perform local deletions (MainActor)
      if !toDeleteLocal.isEmpty {
        await MainActor.run {
          for local in toDeleteLocal {
            Log.log("Deleting local bookmark \(local.title ?? "-") MediaSyncID: \(local.serverId ?? -1) because server removed it.")
            local.delete()
          }
          // Save if needed
          ArticleDB.save()
        }
      }

      // 9) Update last sync timestamp
      Self.lastBookmarkSyncDate = Date()

      // 10) Notify and final logging
      if !newStoredArticles.isEmpty {
        await MainActor.run {
          for article in newStoredArticles {
            Notification.send(Const.NotificationNames.bookmarkChanged, sender: article)
          }
        }
      }

      let didChange = !newStoredArticles.isEmpty || !toUpload.isEmpty || !toDeleteLocal.isEmpty
      print("✅ Bookmark sync finished. Changes: \(didChange ? "YES" : "NO")")
      return didChange
    }
  
  static func sync3(localBookmarks: [StoredArticle]) async throws -> Bool {
    guard let gqlFeeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      throw "No GQL feeder available"
    }

    // MARK: 1️⃣ Remote abrufen
    let remoteBookmarks = try await gqlFeeder.loadBookmarks()
    print("✅ Retrieved \(remoteBookmarks.count) bookmarks from server")

    let localIds = Set(localBookmarks.compactMap { $0.serverId }.map(String.init))
    let remoteIds = Set(remoteBookmarks.map(\.mediaSyncId))

    // MARK: 2️⃣ Neue Remote-Bookmarks (seit letztem Sync)
    let missingRemoteIds = remoteBookmarks
      .filter { !localIds.contains($0.mediaSyncId) }
      .filter {
        guard let lastSync = Self.lastBookmarkSyncDate else { return true }
        let remoteDate = Date(timeIntervalSince1970: TimeInterval($0.sTime) ?? 0)
        return remoteDate > lastSync
      }
      .map(\.mediaSyncId)

    print("ℹ️ \(missingRemoteIds.count) new remote bookmarks (since last sync)")

    // MARK: 3️⃣ Lade neue Remote-Artikel (nur falls nötig)
    var missingArticles: [GqlSingleArticle] = []
    if !missingRemoteIds.isEmpty {
      missingArticles = try await gqlFeeder.loadArticles(withMediaSyncIds: missingRemoteIds)
      print("✅ Retrieved \(missingArticles.count) missing bookmarked articles")
    }

    // MARK: 4️⃣ Update vorhandene lokale Artikel
    var mergedArticles: [StoredArticle] = []
    for local in localBookmarks {
      if let remote = remoteBookmarks.first(where: { String(local.serverId ?? 0) == $0.mediaSyncId }) {
        local.bookmarkedDate = Date(timeIntervalSince1970: TimeInterval(remote.sTime) ?? Date().timeIntervalSince1970)
        mergedArticles.append(local)
      }
    }

    // MARK: 5️⃣ Neue Remote-Artikel persistieren
    let articlesCopy = missingArticles
    let bookmarksCopy = remoteBookmarks
    let newStoredArticles: [StoredArticle] = try await MainActor.run {
      try persistRemoteBookmarks(articles: articlesCopy, bookmarks: bookmarksCopy)
    }
    mergedArticles.append(contentsOf: newStoredArticles)

    // MARK: 6️⃣ Bestimme Uploads & Deletes
    let remoteIdsSet = Set(remoteBookmarks.map(\.mediaSyncId))
    let localIdsSet = Set(localBookmarks.compactMap { $0.serverId }.map(String.init))

    // 👉 Hochladen: lokal markiert, aber nicht remote vorhanden
    let toUpload = localBookmarks.filter { !remoteIdsSet.contains(String($0.serverId ?? 0)) }

    // 👉 Löschen: remote noch da, aber lokal gelöscht (nicht mehr bookmarked)
    let toDelete = remoteBookmarks
      .filter { !localIdsSet.contains($0.mediaSyncId) }
      .compactMap { remote in
        // Wir brauchen ein Article-Objekt für deleteCustomerData
        localBookmarks.first(where: { String($0.serverId ?? 0) == remote.mediaSyncId })
      }

    print("⬆️ Upload \(toUpload.count) new bookmarks, ⬇️ Delete \(toDelete.count) remote bookmarks")

    // MARK: 7️⃣ Änderungen an Server senden
    let uploadResults = try await gqlFeeder.updateRemoteBookmarks(
      newBookmarked: toUpload,
      deletedBookmarks: toDelete
    )

    if !uploadResults.isEmpty {
      print("ℹ️ Bookmark update results: \(uploadResults.count) entries processed")
    }

    // MARK: 8️⃣ Abschluss
    print("✅ Bookmark sync finished. Total merged: \(mergedArticles.count)")
    Self.lastBookmarkSyncDate = Date()

    // Speichern, nur wenn sich wirklich etwas geändert hat
    let didChange = !newStoredArticles.isEmpty || !toUpload.isEmpty || !toDelete.isEmpty
    if didChange {
      await MainActor.run {
        ArticleDB.save()
        for article in newStoredArticles {
          Notification.send(Const.NotificationNames.bookmarkChanged, sender: article)
        }
      }
    }

    return didChange
  }
  
  
  /// Synchronisiert lokale und entfernte Bookmarks bidirektional.
  /// Gibt `true` zurück, wenn sich etwas geändert hat (neue oder entfernte Bookmarks).
  static func sync2(localBookmarks: [StoredArticle]) async throws -> Bool {

    guard let gqlFeeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      throw "No GQL feeder available"
    }

    // MARK: - 1️⃣ Lade Bookmarks vom Server
    let remoteBookmarks = try await gqlFeeder.loadBookmarks()
    print("✅ Retrieved \(remoteBookmarks.count) bookmarks from server")

    // MARK: - 2️⃣ Lokale & entfernte IDs ermitteln
    let localIds = Set(localBookmarks.compactMap { $0.serverId }.map(String.init))
    let remoteIds = Set(remoteBookmarks.map { $0.mediaSyncId })

    // MARK: - 3️⃣ Prüfe, ob Remote-Bookmarks lokal fehlen
    // -> aber NUR, wenn sie neuer sind als der letzte Sync
    let missingRemoteIds = remoteBookmarks
      .filter { !localIds.contains($0.mediaSyncId) }
      .filter { bookmark in
        guard let lastSync = Self.lastBookmarkSyncDate else { return true }
        let remoteDate = Date(timeIntervalSince1970: TimeInterval(bookmark.sTime) ?? 0)
        return remoteDate > lastSync
      }
      .map(\.mediaSyncId)

    print("ℹ️ \(missingRemoteIds.count) new remote bookmarks (since last sync)")

    // MARK: - 4️⃣ Lade die fehlenden Artikel (nur die neuen)
    var missingArticles: [GqlSingleArticle] = []
    if !missingRemoteIds.isEmpty {
      missingArticles = try await gqlFeeder.loadArticles(withMediaSyncIds: missingRemoteIds)
      print("✅ Retrieved \(missingArticles.count) missing bookmarked articles")
    }

    // MARK: - 5️⃣ Mergen & Update vorhandene Artikel
    var mergedArticles: [StoredArticle] = []

    for local in localBookmarks {
      if let remote = remoteBookmarks.first(where: { String(local.serverId ?? 0) == $0.mediaSyncId }) {
        local.bookmarkedDate = Date(timeIntervalSince1970: TimeInterval(remote.sTime) ?? Date().timeIntervalSince1970)
        mergedArticles.append(local)
      }
    }
    ///Fix: Reference to captured var 'missingArticles' in concurrently-executing code; this is an error in the Swift 6 language mode
    let missingArticlesCopy = missingArticles

    // MARK: - 6️⃣ Neue Remote-Artikel persistieren
    let newStoredArticles: [StoredArticle] = try await MainActor.run {
      try persistRemoteBookmarks(articles: missingArticlesCopy, bookmarks: remoteBookmarks)
    }
    mergedArticles.append(contentsOf: newStoredArticles)

    // MARK: - 7️⃣ Prüfe, ob lokale Bookmarks auf Remote gelöscht wurden
    let removedLocal = localBookmarks.filter { !remoteIds.contains(String($0.serverId ?? 0)) }
    if !removedLocal.isEmpty {
      print("⚠️ \(removedLocal.count) bookmarks were deleted remotely")
      // TODO: Optional -> lokal löschen oder kennzeichnen
    }

    // MARK: - 8️⃣ Prüfe lokale Änderungen für Upload/Delete
    // Uploads: lokal gebookmarkt, aber remote nicht vorhanden
    let localOnly = localBookmarks.filter { !remoteIds.contains(String($0.serverId ?? 0)) }

    // Deletes: lokal gelöscht (nicht mehr gebookmarkt), aber noch auf remote vorhanden
    // MARK: - 9️⃣ Uploads & Deletes an Server senden
    let uploadResults = try await gqlFeeder.updateRemoteBookmarks(
      newBookmarked: localOnly,
      deletedBookmarks: removedLocal
    )

    // MARK: - 🔟 Log Sync-Ergebnisse
    let errors = uploadResults.filter { $0.error != nil }
    if errors.isEmpty {
      print("✅ Remote sync successful (\(uploadResults.count) operations)")
    } else {
      for e in errors {
        print("⚠️ \(e.operation.rawValue) failed for article \(e.article.serverId ?? -1): \(e.error ?? "-")")
      }
    }

    // MARK: - 11️⃣ Finalize
    Self.lastBookmarkSyncDate = Date()

    await MainActor.run {
      if !newStoredArticles.isEmpty {
        ArticleDB.save()
        for article in newStoredArticles {
          Notification.send(Const.NotificationNames.bookmarkChanged, sender: article)
        }
      }
    }

    let hasChanges = !newStoredArticles.isEmpty || !removedLocal.isEmpty || !localOnly.isEmpty
    print("✅ Bookmark sync finished. Changes: \(hasChanges ? "YES" : "NO")")
    return hasChanges
  }
  
  static func syncOLD(localBookmarks: [StoredArticle]) async throws -> Bool {
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
    let response = try await gqlFeeder.updateRemoteBookmarks(newBookmarked: [], deletedBookmarks: [])
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
}
  
*/
