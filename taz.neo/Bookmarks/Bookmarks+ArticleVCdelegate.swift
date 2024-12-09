//
//  Bookmarks+ArticleVCdelegate.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

///Helper to handle Access from ArticleVC to Bookmark Issue
class BookmarksIssueInfo: ArticleVCdelegate, DoesLog {
  var section: (any Section)?
  
  var sections: [any Section] = []///required for header
  
  var article: (any Article)?
  
  var article2section: [String : [any Section]] = [:]///required for header
  
  func displaySection(index: Int) {}
  
  public func linkPressed(from: URL?, to: URL?) {
    guard let to = to else { return }
    self.debug("Calling application for: \(to.absoluteString)")
    if UIApplication.shared.canOpenURL(to) {
      UIApplication.shared.open(to, options: [:], completionHandler: nil)
    }
    else {
      error("No application or no permission for: \(to.absoluteString)")
    }
  }
  
  func closeIssue() {}
  
  var feederContext: FeederContext
  var issue: Issue
  
  func updateData(){
    article2section = issue.article2section
    sections = issue.sections ?? []
  }
  
  init?(feederContext: FeederContext?, issue: Issue?){
    guard let fc = feederContext, let i = issue else { return nil }
    self.feederContext = fc
    self.issue = i
    updateData()
  }
}
