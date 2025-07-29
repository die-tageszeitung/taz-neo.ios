//
//  IssueDisplayService+ContinueReading.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.07.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

extension IssueDisplayService {
  
  func handleContinueReading(with sectionVC: SectionVC) {
    resumeReadHandled = false
    let lastPos = LastReadBusiness.getLast(for: issue)
    guard let id = lastPos.lastArticleServerId,
          let lastArticle = issue.allArticles.first(where: { $0.serverId == id }),
          let scrollProgress = lastPos.scrollProgress else { return }
    if reopenAutomaticSetting == true {
      sectionVC.reopenArticleDocName = lastArticle.html?.name
      sectionVC.reopenArticleScrollPos = CGFloat(scrollProgress)
      sectionVC.whenLoaded {
        sectionVC.showArticle(lastArticle)
        Usage.track(Usage.event.dialog.OpenLastArticleAgain, name: "OpenAutomatic")
        Notification.send(Const.NotificationNames.articleLoaded)
      }
    }
    else if reopenHintSetting == true {
      sectionVC.whenLoaded { [weak self] in
        guard self?.resumeReadHandled == false else {
          ///close if Tabbar TextSetting used, due its not covered by activeVc handlers
          self?.continueReadingCtrl?.handleDismiss()
          return
        }///prevent multiple open
        sectionVC.reopenArticleDocName = lastArticle.html?.name
        sectionVC.reopenArticleScrollPos = CGFloat(scrollProgress)
        self?.resumeReadHandled = true
        self?.continueReadingCtrl = ContinueReadingController(article: lastArticle, targetVc: sectionVC) {[weak self] doContinue in
          if doContinue == true {
            sectionVC.showArticle(lastArticle)
            Usage.track(Usage.event.dialog.OpenLastArticleAgain, name: "Open")
            Notification.send(Const.NotificationNames.articleLoaded)
            self?.resumeReadDidAccepted(sectionVC.articleVC)
          }
          else {
            Usage.track(Usage.event.dialog.OpenLastArticleAgain, name: "Cancel")
            onMainAfter(1.0) {[weak self] in
              self?.resumeReadDidDismissed(sectionVC)
            }
          }
          self?.continueReadingCtrl = nil
        }
      }
    }
    else {//both false
      Usage.track(Usage.event.dialog.OpenLastArticleAgain, name: "Disabled")
    }
  }
  
  private func resumeReadDidDismissed(_ sectionVC: SectionVC){
    resumeReadDismissed += 1
    resumeReadAccepted = 0
    if resumeReadDismissed < 5 { return }
    ///Show also if user tapped on an article
    let target = sectionVC.navigationController?.viewControllers.last ?? sectionVC
    ContinueReadingController(title: "\"Weiterlesen\" weiterhin anzeigen?",
                              text: "Sie haben \"Weiterlesen\" bisher nicht genutzt. Möchten Sie den Hinweis weiterhin anzeigen lassen?",
                              confirmText: "Ja, Hinweis behalten",
                              declineText: "Nein, nicht mehr anzeigen",
                              targetVc: target) { [weak self] userChoice in
      guard let userChoice = userChoice else {
        self?.resumeReadDismissed = 0
        return
      }
      if userChoice {
        self?.resumeReadDismissed = -20
      }
      else {
        self?.resumeReadDismissed = 0
        self?.reopenHintSetting = false
      }
    }
  }
  
  private func resumeReadDidAccepted(_ articleVC: ArticleVC?){
    resumeReadAccepted += 1
    resumeReadDismissed = 0
    if resumeReadAccepted < 3 { return }
    guard let articleVC = articleVC else { return }
    var didShow = false
    articleVC.whenLoaded {
      if didShow { return }
      didShow = true
      ContinueReadingController(title: "Automatisch \"Weiterlesen\"?",
                                text: "Sie verwenden \"Weiterlesen\" regelmäßig.\nMöchten Sie künftig automatisch dort weiterlesen, wo Sie aufgehört haben?",
                                confirmText: "Ja, automatisch weiterlesen",
                                declineText: "Nein, Hinweis behalten",
                                targetVc: articleVC) { [weak self] userChoice in
        guard let userChoice = userChoice else {
          self?.resumeReadAccepted = 0
          return
        }
        if userChoice {
          self?.resumeReadAccepted = 0
          self?.reopenAutomaticSetting = true
        }
        else {
          self?.resumeReadAccepted = -20
        }
      }
    }
  }
}
