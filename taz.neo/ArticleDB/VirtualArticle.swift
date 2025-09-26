//
//  VirtualObjects.swift
//  taz.neo
//
//  Created by Ringo Müller on 03.03.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// used for temporary search results and tom
public class VirtualArticle: Article {
  public var authors: [Author]?
  
  public var teaser: String?
  
  public var onlineLink: String?
  
  public var pageNames: [String]?
  
  public var articleType: ArticleType?
  
  public var serverId: Int?
  
  public var readingDuration: Int?
  
  public var html: FileEntry?
  
  public var pdf: FileEntry?
  
  public var title: String?
  
  public var images: [ImageEntry]?
  
  public var audioItem: Audio?
  
  public var primaryIssue: Issue?
  
  public var dir: Dir { Dir.tomsDir }
  
  /// Overrides `StoredArticle`'s `baseURL` getter.
  /// The base implementation falls back to `primaryIssue?.baseUrl` if the DB value is not set,
  /// which can lead to loading a local file and exposing the server file path,
  /// causing a crash on iOS 26.
  public var baseURL: String? { nil }
}
