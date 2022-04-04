//
//  SearchResultIssue.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.04.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import Foundation

public class SearchResultIssue: BookmarkIssue {
  public func baseUrlForFiles(_ files: [FileEntry]) -> String {
    guard let s = search,
          let f = files.first,
          let hits = s.searchHitList else { return "" }
    for hit in hits {
      for file in hit.article.files {
        if file.fileName == f.fileName {
          hit.writeToDisk()//TOO LATE
          return hit.baseUrl
        }
      }
    }
    return ""
  }
  public var search:SearchItem?
}
