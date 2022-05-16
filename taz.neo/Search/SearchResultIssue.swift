//
//  SearchResultIssue.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.04.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

public class SearchResultIssue: BookmarkIssue {
  
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
  
  public func baseUrlForFiles(_ files: [FileEntry]) -> String {
    guard let s = search,
          let f = files.first,
          let hits = s.searchHitList else { return "" }
    for hit in hits {
      for file in hit.article.files {
        if file.fileName == f.fileName {
          hit.writeToDisk()//TOO LATE
          hit.article.isDownloaded = true
          return hit.baseUrl
        }
      }
    }
    return ""
  }
  
  public override var dir: Dir { Dir.searchResults }
  
  public var search:SearchItem? 
  
  static let shared = SearchResultIssue()
  private init(){
    super.init(feed: TazAppEnvironment.sharedInstance.feederContext!.defaultFeed)
  }

}


class SearchArticle:GqlArticle{
  
  var isDownloaded = false
  
  override var primaryIssue: Issue {
    get{ SearchResultIssue.shared }
    set{}
  }
}
