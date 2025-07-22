//
//  LastReadBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 08.05.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib


public class LastReadBusiness: NSObject, DoesLog {
  
  private static let maxEntries = 5
  private static let userDefaultsKey = "lastReadPositions"
  
  struct LastReadEntry: Codable {
    var issueKey: String
    var lastArticleServerId: Int
    var lastPage: Int
    var changed: String
    var scrollProgress: Float // 0.0 ... 1.0
  }
  
  private static let sharedInstance = LastReadBusiness()
  
  private var lastReadPositions: [LastReadEntry] {
    get {
      guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else { return [] }
      let decoded = try? JSONDecoder().decode([LastReadEntry].self, from: data)
      return decoded ?? []
    }
    set {
      if let data = try? JSONEncoder().encode(newValue) {
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
      }
    }
  }
  
  static func persist(lastArticle: Article, page: Int?, scrollProgress: Float?, in issue: Issue) {
    guard let serverId = lastArticle.serverId else { return }
    var positions = sharedInstance.lastReadPositions
    
    
    let entry = LastReadEntry(
      issueKey: issue.date.issueKey,
      lastArticleServerId: serverId,
      lastPage: page ?? -1,
      changed: UsTime.now.toString(),
      scrollProgress: scrollProgress ?? 0.0
    )
    print(">>> persist scrollProgress \(scrollProgress)")
    positions.removeAll { $0.issueKey == issue.date.issueKey }
    positions.insert(entry, at: 0)
    
    if positions.count > Self.maxEntries {
      positions = Array(positions.prefix(Self.maxEntries))
    }
    
    sharedInstance.lastReadPositions = positions
  }
  
  static func resetFor(issue: Issue?) {
    var positions = sharedInstance.lastReadPositions
    
    if let key = issue?.date.issueKey {
      positions.removeAll { $0.issueKey == key }
    } else {
      positions.removeAll()
    }
    
    sharedInstance.lastReadPositions = positions
  }
  
  static func getLast(for issue: Issue) -> (lastArticleServerId: Int?, page: Int?, changed: UsTime?, scrollProgress: Float?) {
    let key = issue.date.issueKey
    guard let entry = sharedInstance.lastReadPositions.first(where: { $0.issueKey == key }) else {
      return (nil, nil, nil, nil)
    }
      
    let page = entry.lastPage >= 0 ? entry.lastPage : nil
    let changed = UsTime(entry.changed)
    let progress = entry.scrollProgress
    print(">>> getLast scrollProgress \(progress)")
    return (entry.lastArticleServerId, page, changed, progress)
  }
  
  static func getAll() -> [(issueKey: String, lastArticleServerId: Int?, page: Int?, changed: UsTime, scrollProgress: Float)] {
    return sharedInstance.lastReadPositions.map { entry in
      let lastPage = entry.lastPage >= 0 ? entry.lastPage : nil
      return (entry.issueKey, entry.lastArticleServerId, lastPage, UsTime(entry.changed), entry.scrollProgress)
    }
  }
  
  func sync() {
    // Placeholder for sync logic
  }
}
