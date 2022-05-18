//
//  SearchFeed.swift
//  taz.neo
//
//  Created by Ringo Müller on 16.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//
import Foundation
import NorthLib


/// A Feed for Search Articles
public class SearchFeed: Feed {
  public var name: String
  public var feeder: Feeder
  public var cycle: PublicationCycle { .unknown }
  public var momentRatio: Float { 1 }
  public var issueCnt: Int { 1 }
  public var lastIssue: Date
  public var firstIssue: Date
  public var issues: [Issue]?
  
  public init(feeder: Feeder) {
    self.feeder = feeder
    self.name = "Bookmarks(\(feeder.title))"
    self.lastIssue = Date()
    self.firstIssue = self.lastIssue
  }
  
  deinit {
    /// Remove temporary files
    guard let issues = self.issues else { return }
    for issue in issues {
      if let sections = issue.sections {
        for section in sections {
          if let tmpFile = section.html as? TmpFileEntry {
            tmpFile.content = nil // removes file
          }
        }
      }
    }
    
  } // SearchFeed
}

/// An Issue of Sections of bookmarked Articles
public class SearchIssue: BookmarkIssue {}

/// A Section of bookmarked Articles
public class SearchSection: BookmarkSection {}


/// A temporary file entry
public class TmpFileEntry: FileEntry {
  public var name: String
  public var storageType: FileStorageType { .unknown }
  public var moTime: Date
  public var size: Int64 { 0 }
  public var sha256: String { "" }
  public var path: String
  
  /// Read/write access to contents of file
  public var content: String? {
    get { File(path).string }
    set {
      if let content = newValue { File(path).string = content }
      else { File(path).remove() }
    }
  }
  
  public init(name: String) {
    self.name = name
    self.path = "\(Dir.tmpPath)/\(name)"
    self.moTime = Date()
  }
}

