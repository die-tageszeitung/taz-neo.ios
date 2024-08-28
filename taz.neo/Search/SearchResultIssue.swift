//
//  SearchResultIssue.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.04.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

public class SearchResultIssue: VirtualIssue {
  
  public override var isComplete: Bool {
    get{
      for sect in sections ?? [] {
        for case let art as SearchArticle in sect.articles ?? [] {
          if art.isDownloaded == false { return false }
        }
      }
      return true
    }
    set{}
  }
  
  public override var dir: Dir { Dir.searchResults }
  
  public var search:SearchItem?
  
  func createDirsIfNeeded(){
    dir.create()
    let rlink = File(dir: dir.path, fname: "resources")
    let glink = File(dir: dir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: _feederContext.gqlFeeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: _feederContext.gqlFeeder.globalDir.path) }
  }
  private var _feederContext: FeederContext
  static let shared = SearchResultIssue(TazAppEnvironment.sharedInstance.feederContext!)
  private init(_ feederContext: FeederContext){
    _feederContext = feederContext
    super.init(feed: feederContext.defaultFeed)
    createDirsIfNeeded()
  }
}

class SearchArticle:GqlArticle{
  var isDownloaded = false
  
  /// every Article from a search can have a own issue
  /// every issue has a own base url
  /// use this field to transfer the issue base url from serachHit to downloader
  var originalIssueBaseURL: String?
  
  var originalIssueDate: Date?
  
  override var primaryIssue: Issue? {
    get{ SearchResultIssue.shared }
    set{}
  }
}

/// A Section of searched  Articles
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


