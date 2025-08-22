//
//  LastReadBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 08.05.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib


struct LastRead: Codable {
  var issueKey: String
  var lastArticleServerId: Int
  var lastPage: Int
  var changed: String
  var scrollProgress: Float // 0.0 ... 1.0
}
import Foundation

/// Business-Logik für die Speicherung der letzten Lesepositionen.
/// - Speichert bis zu `maxEntries` Positionen.
/// - Hält die Werte lokal im Speicher und schreibt nur auf App-Lifecycle-Events in UserDefaults.
final class LastReadBusiness {
  
  static let shared = LastReadBusiness()
  
  private let userDefaultsKey = "lastRead"
  private let maxEntries = 5
  
  /// Lokale Kopie im Speicher
  private var cachedLastReads: [LastRead] = []
  
  private init() {
    loadFromDefaults()
  }
  
  // MARK: - Öffentliche API
  
  /// Liefert alle gespeicherten Lesepositionen (neueste zuerst).
  func getAll() -> [LastRead] {
    return cachedLastReads
  }
  
  /// Liefert die zuletzt gespeicherte Position (falls vorhanden).
  func get(for issue: Issue) -> LastRead? {
    return cachedLastReads.first { $0.issueKey == issue.date.issueKey }
  }
  
  static func getLast(for issue: Issue) -> (lastArticleIndex: Int?,
                                            page: Int?,
                                            changed: UsTime?,
                                            articleScrollPos: CGFloat?)? {
    guard let entry = shared.get(for: issue) else {
      return nil
    }
    
    let page = entry.lastPage >= 0 ? entry.lastPage : nil
    let changed = UsTime(entry.changed)
    let progress = entry.scrollProgress
    print(">>> get scrollProgress \(progress) forArtWithServerId: \(entry.lastArticleServerId)")
    
    let artIdx = issue.allArticles.firstIndex(where: { $0.serverId == entry.lastArticleServerId })
    
    let articleScrollPos: CGFloat? = progress > 0.01 ? CGFloat(progress) : nil
    return (artIdx, page, changed, articleScrollPos)
  }
  
  ///Persisting Page overwrites Article and article overwrites page
  static func persist(lastArticle: Article?, page: Int?, scrollProgress: Float?, in issue: Issue) {
    let entry = LastRead(
      issueKey: issue.date.issueKey,
      lastArticleServerId: lastArticle?.serverId  ?? -1,
      lastPage: page ?? -1,
      changed: UsTime.now.toString(),
      scrollProgress: scrollProgress ?? 0.0
    )
    shared.setLastRead(entry)
  }
  
  
  /// Speichert eine neue Leseposition.
  /// - Wenn diese bereits existiert, wird sie nach vorne verschoben.
  /// - Bei Überschreitung von `maxEntries` wird der älteste Eintrag verworfen.
  private func setLastRead(_ entry: LastRead) {
    // falls bereits enthalten → entfernen
    cachedLastReads.removeAll { $0.issueKey == entry.issueKey }
    
    // neuen Eintrag nach vorne setzen
    cachedLastReads.insert(entry, at: 0)
    
    // bei Bedarf beschneiden
    if cachedLastReads.count > maxEntries {
      cachedLastReads = Array(cachedLastReads.prefix(maxEntries))
    }
  }
  
  /// Entfernt eine bestimmte Leseposition.
  func remove(for issue: Issue) {
    cachedLastReads.removeAll { $0.issueKey == issue.date.issueKey }
    persistToDefaults()
  }
  
  /// Entfernt alle Lesepositionen.
  func clearAll() {
    cachedLastReads.removeAll()
    persistToDefaults()
  }
  
  // MARK: - Persistierung
  
  /// Lädt die Daten einmalig aus UserDefaults.
  private func loadFromDefaults() {
    guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
          let decoded = try? JSONDecoder().decode([LastRead].self, from: data) else {
      cachedLastReads = []
      return
    }
    cachedLastReads = decoded
  }
  
  /// Persistiert den aktuellen Stand in UserDefaults (z. B. bei App Enter Background).
  func persistToDefaults() {
    guard let data = try? JSONEncoder().encode(cachedLastReads) else {
      return
    }
    UserDefaults.standard.set(data, forKey: userDefaultsKey)
  }
}
