//
//  LinkBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.12.25.
//  Copyright © 2025 taz. All rights reserved.
//
import UIKit
import NorthLib

class LinkBusiness {
  static func handleLinkPressed(from: URL?, to: URL?, with adelegate: ArticleVCdelegate?) {
    if UIApplication.shared.applicationState != .active { return }
    
    guard Defaults.singleton["openLinksInApp"]?.bool == true else {
      adelegate?.linkPressed(from: from, to: to)
      return
    }
    
    guard let msid = to?.absoluteString.tazMediaSyncId else {
      adelegate?.linkPressed(from: from, to: to)
      return
    }
    
    if let sameIssueArticle = adelegate?.issue.allArticles.first(where: { $0.serverId == msid }) {
      // targetArticle is in current issue; show article without Question
      if let sectVc = adelegate as? SectionVC {
        sectVc.showArticle(sameIssueArticle, animated: true)
      }
      else {
        adelegate?.linkPressed(from: from, to: sameIssueArticle.fileUrl)
      }
      return
    }
    else if let localArticle = StoredArticle.get(byMediaSyncId: msid),
            let issueDate = localArticle.issueDate,
            let url = localArticle.fileUrl {
      let issueText = localArticle.primaryIssue?.issueDateAccessibilityText ?? issueDate.accessibilityLabelText(prefix: "Ausgabe vom")
      let message = "Artikel \"\(localArticle.title ?? "")\" in der \(issueText) oder auf taz.de im Browser öffnen?"
      let openInIssueAction = Alert.action("In Ausgabe") {_ in
        let data = ArticleLinkOpen(articleUrl: url, issueDate: issueDate)
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data)
      }
      let openInBrowserAction = Alert.action("Im Browser") {_ in
        adelegate?.linkPressed(from: from, to: to)
      }
      Alert.actionSheet(message: message, actions: [openInIssueAction, openInBrowserAction])
      return
    }
    adelegate?.linkPressed(from: from, to: to)
    /*ToDo handle Issue/article lot locally, fetch article then popup load issue ...or just show article
//    else if let fc = TazAppEnvironment.sharedInstance.feederContext,
//            let gqlFeeder = fc.gqlFeeder,
//            let _ = try? gqlFeeder.loadArticles(withMediaSyncIds: ["\(msid)"]).first
//    {
//      Toast.show("taz.de > different not available Issue")
//    }
    else {
      adelegate?.linkPressed(from: from, to: to)
    }
     */
    ///in database => popup Artikel Titel in Ausgabe öffnen , auf taz.de anzeigen
    ///on server Artikel Titel in Suche öffnen , auf taz.de anzeigen
  }
}

fileprivate extension Article {
  var fileUrl : URL? {
    return dir.url.absoluteURL.appendingPathComponent(html?.name ?? "")
  }
}

fileprivate extension String {
  var tazMediaSyncId: Int64? {
    // Regex: ^https://www\.taz\.de/!(\d{6,8})(/)?$
    let pattern = #"^https://www\.taz\.de/!(\d{6,8})(/)?$"#
    
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return nil
    }
    
    let range = NSRange(location: 0, length: self.utf16.count)
    
    if let match = regex.firstMatch(in: self, options: [], range: range),
       let numberRange = Range(match.range(at: 1), in: self) {
      return Int64(self[numberRange])
    }
    
    return nil
  }
}
