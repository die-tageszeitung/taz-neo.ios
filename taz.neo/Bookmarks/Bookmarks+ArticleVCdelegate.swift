//
//  Bookmarks+ArticleVCdelegate.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

typealias ArticleLinkOpen = (articleUrl:URL, issueDate:Date)

fileprivate extension URL {
  var tazMediaSyncId: Int? {
    let tazMsidBase = "https://www.taz.de/!"
    guard self.absoluteString.hasPrefix(tazMsidBase),
          self.pathComponents.count == 2 else {
           return nil
    }
    return Int(self.lastPathComponent.replacingOccurrences(of: "!", with: ""))
  }
}

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
    if let fromFilename = from?.lastPathComponent,
       let sourceArticle = sections.first?.articles?.first(where: { article in
         article.files.contains(where: { $0.fileName == fromFilename })
       }),
       let issueDate = sourceArticle.issueDate {
      if to.isFileURL {
        let data = ArticleLinkOpen(articleUrl: to, issueDate: issueDate)
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
        return
      }
      ///MSID is correct but issue Date is wrong!
      ///2nd Warning; Some Media Sync Id's did not have an Article in an issue
      ///e.g.:   getArticlesByMediaSyncId(mediaSyncIds: "6059218,6059401") , 6059218 did not exist for app
      ///Async call is not usefull for the app, so open online version
      /*
      else if let msid = to.tazMediaSyncId {
        let data = PushNotification.Payload.ArticlePushData(msid, nil, nil ,UsTime(iso: "2024-12-28T11:59:59+01:00").date, [:])
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
        return
      }*/
    }
    
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
