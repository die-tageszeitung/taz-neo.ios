//
//  IssueDisplayService+ContinueReading.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.07.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

//App-Section-Article
extension IssueDisplayService {
  
  func handleContinueReading(with sectionVC: SectionVC) {
    resumeReadHandled = false
    guard let lastPos = LastReadBusiness.getLast(for: issue),
          let idx = lastPos.lastArticleIndex,
          let lastArticle = issue.allArticles.valueAt(idx),
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
        self?.continueReadingCtrl = ContinueReadingController(article: lastArticle, targetVc: sectionVC) {[weak self] resume in
          if resume == true {
            sectionVC.showArticle(lastArticle)
            Usage.track(Usage.event.dialog.OpenLastArticleAgain, name: "Open")
            Notification.send(Const.NotificationNames.articleLoaded)
            self?.resumeReadDidAccepted(sectionVC.articleVC ?? sectionVC)
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
                              text: "Sie verwenden \"Weiterlesen\" nicht regelmäßig. Möchten Sie den Hinweis weiterhin anzeigen lassen?",
                              confirmText: "Ja, Hinweis behalten",
                              declineText: "Nein, nicht mehr anzeigen",
                              targetVc: target) { [weak self] userChoice in
      guard let userChoice = userChoice else {
        self?.resumeReadDismissed -= 2
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
  
  private func resumeReadDidAccepted(_ vc: UIViewController){
    resumeReadAccepted += 1
    resumeReadDismissed = 0
    if resumeReadAccepted < 3 { return }
    onMainAfter(1.0) {
      ContinueReadingController(title: "Automatisch \"Weiterlesen\"?",
                                text: "Sie verwenden \"Weiterlesen\" regelmäßig. Möchten Sie künftig automatisch dort weiterlesen, wo Sie aufgehört haben?",
                                confirmText: "Ja, automatisch weiterlesen",
                                declineText: "Nein, Hinweis behalten",
                                targetVc: vc) { [weak self] userChoice in
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

//PDF
extension IssueDisplayService {
  func pushPdfVC(issue:StoredIssue,
                         atPage: Int? = nil,
                         atArticle: Int? = nil,
                         pushDelegate: PushIssueDelegate){
    if feederContext.storedFeeder.momentPdfFile(issue: issue) != nil {
      pushPdf(issue: issue,
              atPage: atPage,
              atArticle: atArticle,
              pushDelegate: pushDelegate)
    }
    else if let page1pdf = issue.pages?.first?.pdf {
      feederContext.dloader.downloadIssueData(issue: issue, files: [page1pdf]) {[weak self] err in
        if err != nil {
          self?.handleError()
        }
        else {
          self?.pushPdf(issue: issue,
                        atPage: atPage,
                        atArticle: atArticle,
                        pushDelegate: pushDelegate) }
      }
    } else {
      handleError()
    }
  }
  
  private func handleError(){
    Toast.show(Localized("error"))
    Notification.send(Const.NotificationNames.articleLoaded)
  }
  
  private func pushPdf(issue:StoredIssue,
                       atPage: Int? = nil,
                       atArticle: Int? = nil,
                         pushDelegate: PushIssueDelegate,
                         requestReopen:Bool = false){
    
    let lastPos = LastReadBusiness.getLast(for: issue)
    
    let vc = TazPdfPagesViewController(issueInfo: self)
    pushDelegate.push(vc, issueInfo: self)
    
    if issue.status == .reduced {
      authenticate()
      #warning("DANGER TEST DELETE...")
      return
    }
    
    if reopenAutomaticSetting || atPage != nil || atArticle != nil {
      if let page = atPage ?? lastPos?.page {
        vc.index = page
      }
      
      if let artIdx = atArticle,
         let art = issue.allArticles.valueAt(artIdx) {
        vc.openArticle(name: art.html?.name,
                       path: issue.dir.path,
                       reopenArticleScrollPos: CGFloat(lastPos?.scrollProgress ?? 0.0))
      }
      return
    }
    
    var img: UIImage?
    var txt: String
    var title: String
    var article: Article?
    
    if let artIdx = lastPos?.lastArticleIndex {
      guard let art = issue.allArticles.valueAt(artIdx) else { return }
      article = art
      img = art.firstImage
      title = "Weiterlesen (Artikel):"
      txt = art.title ?? "(kein Titel angegeben)"
    } else if let page = lastPos?.page, page != 0 {
      img = issue.pages?.valueAt(page)?.facsimile?.image(dir: issue.dir)
      title = "Weiterlesen:"
      txt = "Seite \(page+1)"
    } else {
      return
    }
    continueReadingCtrl
    = ContinueReadingController(title: title,
                                text: txt,
                                image: img,
                                targetVc: vc,
                                bottomOffset: vc.toolBar.yOffset,
                                finishHandler: {[weak self] resume in
      if resume == true {
        if let page = lastPos?.page {
          vc.index = page
        }
        
        if let art = article {
          vc.openArticle(name: art.html?.name,
                         path: issue.dir.path,
                         reopenArticleScrollPos: CGFloat(lastPos?.scrollProgress ?? 0.0))
        }
        self?.resumeReadDidAccepted(vc.childArticleVC ?? vc)
      }

    })
  }
  
  private func authenticate(){
    if self.feederContext.isAuthenticated && self.feederContext.gqlFeeder.isExpiredAccount {
      //shows expired form
      self.feederContext.authenticate()
      return
    }
    //...not show login if logged in!
    if self.feederContext.isAuthenticated == true { return }
    /// ...show Login
    let loginAction = UIAlertAction(title: Localized("login_button"),
                                    style: .default) { _ in
      self.feederContext.authenticate()
    }
    let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel)
    let msg = "Um das ePaper zu lesen, müssen Sie sich anmelden."
    Usage.track(Usage.event.dialog.PDFModeLoginHint)
    Alert.message(title: "Fehler", message: msg, actions: [loginAction, cancelAction])
  }
  
}
