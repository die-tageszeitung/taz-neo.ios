//
//  BackgroundDownloadService+UserDefaults.swift
//  taz.neo
//
//  Created by Ringo Müller on 15.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation

struct DownloadData: Codable {
  let isoDateKey: String           // z.B. "2025-05-15"
  var downloadId: String      // Eindeutige ID
  var startTime: Int64       // Unix-Timestamp
  
  var isDownloaded: Bool { startTime < 0 || downloadId.isEmpty }
  mutating func setDownloaded(){ downloadId = "";  startTime = -1 }
  
  // Optional: Initializer mit Default-Werten oder Convenience-Logik
  init(isoDateKey: String, downloadId: String, startTime: Int64) {
    self.isoDateKey = isoDateKey
    self.downloadId = downloadId
    self.startTime = startTime
  }
}

// MARK: - UserDefaults Erweiterung für Codable Dictionary
private extension UserDefaults {
  private static let backgroundDownloadsKey = "BackgroundDownloadsDictionaryKey"
  
  func getDownloadDict() -> [String: DownloadData] {
    guard let data = data(forKey: Self.backgroundDownloadsKey),
          let decoded = try? JSONDecoder().decode([String: DownloadData].self, from: data) else {
      return [:]
    }
    return decoded
  }
  
  func setDownloadDict(_ dict: [String: DownloadData]) {
    if let encoded = try? JSONEncoder().encode(dict) {
      set(encoded, forKey: Self.backgroundDownloadsKey)
    }
  }
}

extension BackgroundDownloadService {
  func saveDownloadData(forDownloadUrl url: String, date: Date, downloadId: String, startTime: Int64) {
    let data = DownloadData(isoDateKey: date.ISO8601, downloadId: downloadId, startTime: startTime)
    var current = UserDefaults.standard.getDownloadDict()
    current[url] = data
    UserDefaults.standard.setDownloadDict(current)
  }
  
  func setDownloadFinished(forDownloadUrl url: String) {
    var dict = UserDefaults.standard.getDownloadDict()
    guard var data = dict[url] else {
      log("No data found for: \(url)")
      return
    }
    
    data.setDownloaded()
    dict[url] = data
    UserDefaults.standard.setDownloadDict(dict)
    log("Set Download finished for issue with date: \(data.isoDateKey)")
  }
  
  var downloadDateKeys: [String] {
    let dict = UserDefaults.standard.getDownloadDict()
    return dict.values.map { $0.isoDateKey }
  }
  
  
  func getDownloadData(forDownloadUrl url: String) -> DownloadData? {
    UserDefaults.standard.getDownloadDict()[url]
  }
  
  func removeDownloadData(forDownloadUrl url: String) {
    var current = UserDefaults.standard.getDownloadDict()
    current.removeValue(forKey: url)
    UserDefaults.standard.setDownloadDict(current)
  }
  
  /// Removes the download data entry from UserDefaults for the given issue key.
  ///
  /// This method retrieves the stored download dictionary and searches for the first entry
  /// whose value has a matching `isoDateKey`. If found, the entry is removed and the updated
  /// dictionary is saved back to UserDefaults. If no matching entry is found, a log message is printed.
  ///
  /// - Parameter key: The `isoDateKey` of the download item to be removed.
  func removeDownloadData(forIssueKey key: String) {
    var dict = UserDefaults.standard.getDownloadDict()
    
    // Find the first key in the dictionary where the value matches the issue key
    if let matchingKey = dict.first(where: { $0.value.isoDateKey == key })?.key {
      dict.removeValue(forKey: matchingKey)
      UserDefaults.standard.setDownloadDict(dict)
    } else {
      log("No data found for: \(key)")
    }
  }
}
