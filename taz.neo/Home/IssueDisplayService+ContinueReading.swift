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
  
  /// Setup SectionVC and push it onto the VC stack
  func pushSectionVC(issue:StoredIssue,
                     atSection: Int? = nil,
                     atArticle: Int? = nil,
                     atArticlePercent: CGFloat? = nil,
                     pushDelegate: PushIssueDelegate) {
    let sectionVC = SectionVC(feederContext: feederContext,
                              atSection: atSection,
                              atArticle: atArticle)
    sectionVC.delegate = self
    
    pushDelegate.push(sectionVC, issueInfo: self)
    if atArticle == nil { handleContinueReading(with: sectionVC) }
  }
  
  private func handleContinueReading(with sectionVC: SectionVC) {
    resumeReadHandled = false
    guard let lastPos = LastReadBusiness.getLast(for: issue),
          let idx = lastPos.lastArticleIndex,
          let lastArticle = issue.allArticles.valueAt(idx) else { return }
    if reopenAutomaticSetting == true {
      sectionVC.reopenArticleDocName = lastArticle.html?.name
      sectionVC.reopenArticleScrollPos = lastPos.articleScrollPos
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
        sectionVC.reopenArticleScrollPos = lastPos.articleScrollPos
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
  
  private func resumeReadDidDismissed(_ vc: UIViewController){
    resumeReadDismissed += 1
    resumeReadAccepted = 0
    if resumeReadDismissed < 5 { return }
    ///Show also if user tapped on an article
    ContinueReadingController(title: "\"Weiterlesen\" weiterhin anzeigen?",
                              text: "Sie verwenden \"Weiterlesen\" nicht regelmäßig. Möchten Sie den Hinweis weiterhin anzeigen lassen?",
                              confirmText: "Ja, Hinweis behalten",
                              declineText: "Nein, nicht mehr anzeigen",
                              targetVc: vc.topVc) { [weak self] userChoice in
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
                                targetVc: vc.topVc) { [weak self] userChoice in
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

fileprivate extension UIViewController {
  var topVc : UIViewController { navigationController?.topViewController ?? self }
}

//PDF
extension IssueDisplayService {
  /// Opens an issue in PDF mode.
  ///
  /// This function performs the following steps:
  /// 1. Downloads the issue if necessary.
  /// 2. Opens the issue starting at the initial page.
  /// 3. Checks authentication and issue status:
  ///    - May present a login or subscription expiration screen and return early.
  /// 4. Determines whether to open a specific page or article:
  ///    - If `atPage` or `atArticle` is provided (e.g. from bookmarks, search, or push notification), or
  ///    - If `reopenAutomaticSetting` is `true`, or
  ///    - If `reopenHintSetting` is `true` (then shows a request sheet).
  ///
  /// - Note: If `atPage` or `atArticle` is provided, the "Continue Reading" setting will be ignored.
  /// These parameters are typically set when the user taps an element that leads directly to an article or page.
  ///
  /// - Parameters:
  ///   - issue: The stored issue to open.
  ///   - atPage: An optional page number to open directly.
  ///   - atArticle: An optional article identifier to open directly.
  ///   - pushDelegate: A delegate used to manage push behavior when opening the issue.
  func pushPdfVC(issue: StoredIssue,
                 atPage: Int? = nil,
                 atArticle: Int? = nil,
                 pushDelegate: PushIssueDelegate) {
    ///Download if needed
    if feederContext.storedFeeder.momentPdfFile(issue: issue) != nil {
      pushPdf(issue: issue,
              atPage: atPage,
              atArticle: atArticle,
              pushDelegate: pushDelegate)
    }
    else if let page1pdf = issue.pages?.first?.pdf {
      feederContext.dloader.downloadIssueData(issue: issue, files: [page1pdf]) {[weak self] err in
        if err != nil { self?.handleError(); return; }
        self?.pushPdf(issue: issue,
                      atPage: atPage,
                      atArticle: atArticle,
                      pushDelegate: pushDelegate)
        Notification.send(Const.NotificationNames.articleLoaded)
      }
    } else { handleError() }
  }
  
  private func handleError(msg: String = Localized("error")){ Toast.show(msg) }
  
  private func reOpen(vc: TazPdfPagesViewController,
                      atPage: Int? = nil,
                      pageAnimated: Bool = false,
                      atArticle: Article? = nil,
                      atArticleScrollPos: CGFloat? = nil){
    if let page = atPage {
      if pageAnimated {
        vc.collectionView?.scrollto(page, animated: pageAnimated)
      }
      else {
        vc.index = page
      }
    }
    
    if let art = atArticle {
      vc.openArticle(name: art.html?.name,
                     path: issue.dir.path,
                     reopenArticleScrollPos: CGFloat(atArticleScrollPos ?? 0.0))
    }
  }
  
  private func pushPdf(issue:StoredIssue,
                       atPage: Int? = nil,
                       atArticle: Int? = nil,
                       pushDelegate: PushIssueDelegate){
    
    let vc = TazPdfPagesViewController(issueInfo: self)
    pushDelegate.push(vc, issueInfo: self)
    
    if issue.status == .reduced {
      authenticate()
      return
    }
    
    let lastPos = LastReadBusiness.getLast(for: issue)
    var targetArticle: Article?
    if let artIdx = atArticle ?? lastPos?.lastArticleIndex {
      targetArticle = issue.allArticles.valueAt(artIdx)
    }
    let openPage: Int? = atPage ?? lastPos?.page
    guard targetArticle != nil || openPage != nil else { return }
    
    if reopenAutomaticSetting || atPage != nil || atArticle != nil {
      reOpen(vc: vc,
             atPage: openPage,
             atArticle: targetArticle,
             atArticleScrollPos: lastPos?.articleScrollPos)
      return
    }

    guard reopenHintSetting else { return }
    
    var img: UIImage?
    var txt: String
    var title: String
    
    if let targetArticle = targetArticle {
      img = targetArticle.firstImage
      title = "Weiterlesen (Artikel):"
      txt = targetArticle.title ?? "(kein Titel angegeben)"
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
        self?.reOpen(vc: vc,
                     atPage: openPage,
                     pageAnimated: true,
                     atArticle: targetArticle,
                     atArticleScrollPos: lastPos?.articleScrollPos)
        self?.resumeReadDidAccepted(vc)
      } else {
        self?.resumeReadDidDismissed(vc)
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
