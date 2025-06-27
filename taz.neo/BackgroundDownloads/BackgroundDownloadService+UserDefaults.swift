//
//  BackgroundDownloadService+UserDefaults.swift
//  taz.neo
//
//  Created by Ringo Müller on 15.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation

/// Data Structure to persist background download data using UserDefaults.
struct DownloadData: Codable {
  static let ressourcesDownloadID = "RessourcesDownloadID"
  
  let isoDateKey: String           // z.B. "2025-05-15"
  var downloadId: String      // Eindeutige ID
  var startTime: Int64       // Unix-Timestamp
  
  var isDownloaded: Bool { startTime < 0 || downloadId.isEmpty }
  var isRessourcesDownload: Bool { downloadId == Self.ressourcesDownloadID }
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

/// Helper to save and retrieve DownloadData in UserDefaults.
/// `saveDownloadData` is called ONLY in doCheckForNewIssue currently after enqueuing the zip download of the issue
/// `setDownloadFinished` is only called in `dlCallback` (successful  zip download of the issue) also if database is not saved yet.
///  `getDownloadData` is called in getDownloadData and `applicationRestarted` to set the download finished for the issue, if it was not saved yet.
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
  
  /// Returns an array of ISO date keys for all completed issue downloads stored in UserDefaults,
  /// excluding resource-only downloads.
  ///
  /// Used on app launch to detect any finished downloads (e.g., ZIP files)
  /// that haven't yet been persisted to the database, so they can be saved now.
  var downloadDateKeys: [String] {
    let dict = UserDefaults.standard.getDownloadDict()
    return dict.values
      .filter { $0.downloadId != DownloadData.ressourcesDownloadID }
      .map { $0.isoDateKey }
  }
  
  ///called after download finished to get the DownloadData for the given download URL, to set the download finished
  ///also called from `applicationRestarted`
  func getDownloadData(forDownloadUrl url: String) -> DownloadData? {
    UserDefaults.standard.getDownloadDict()[url]
  }
  
  /// Returns the `DownloadData` associated with the given ISO date key (e.g., "2025-05-15").
  ///
  /// This method is used to retrieve the download data for a specific issue date, typically
  /// to check download progress or metadata related to that date.
  ///
  /// - Parameter key: The ISO-formatted date string used as the lookup key.
  /// - Returns: The `DownloadData` associated with the given date key, or `nil` if not found.
  func getDownloadData(forDateKey key: String) -> DownloadData? {
      let dict = UserDefaults.standard.getDownloadDict()
      return dict.first { $0.value.isoDateKey == key }?.value
  }
  
  /// Retrieves the download URL key for a given ISO-formatted date key.
  ///
  /// This method searches the stored background download dictionary for the first entry
  /// where the associated `DownloadData` has a matching `isoDateKey`, and returns the
  /// corresponding dictionary key (typically a download URL).
  ///
  /// - Parameter key: The ISO date key (e.g., "2025-06-27") to search for.
  /// - Returns: The download URL string associated with the date key, or `nil` if not found.
  func getUrl(forDateKey key: String) -> String? {
      let dict = UserDefaults.standard.getDownloadDict()
      return dict.first { $0.value.isoDateKey == key }?.key
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
