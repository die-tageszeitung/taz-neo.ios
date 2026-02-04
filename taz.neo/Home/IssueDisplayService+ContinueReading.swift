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
                     atArticleScrollPos: CGFloat? = nil,
                     pushDelegate: PushIssueDelegate) {
    let sectionVC = SectionVC(feederContext: feederContext,
                              atSection: atSection,
                              atArticle: atSection == nil ? atArticle : nil)
    sectionVC.delegate = self
    if atSection == nil,
       let idx = atArticle,
       let lastArticle = issue.allArticles.valueAt(idx) {
      sectionVC.reopenArticleScrollPos = atArticleScrollPos
      sectionVC.reopenArticleDocName = lastArticle.html?.name
    }
    if atArticle == nil && atSection == nil {
      requestContinueReading(with: sectionVC)
    }
    pushDelegate.push(sectionVC, issueInfo: self)
  }
  
  ///displays sheet to request continue reading if applyable
  private func requestContinueReading(with sectionVC: SectionVC) {
    if reopenHintSetting == false && reopenAutomaticSetting == false {
      Usage.track(Usage.event.dialog.OpenLastRead, name: "Disabled")
      return
    }
    guard reopenHintSetting == true && reopenAutomaticSetting == false else { return }

    var lastSectionIndex: Int?
    var lastSection: Section?
    var lastArticle: Article?
    if let idx = issue.lastSection,
       let lastSect = issue.sections?.valueAt(idx) {
      lastSectionIndex = idx
      lastSection = lastSect
    }
    else if let idx = issue.lastArticle,
       let lastArt = issue.allArticles.valueAt(idx) {
      lastArticle = lastArt
    }
    
    guard lastSectionIndex ?? 0 > 0 || lastArticle != nil else { return }
    resumeReadHandled = false
    
    sectionVC.whenLoaded { [weak self] in
      guard self?.resumeReadHandled == false else {
        ///close if Tabbar TextSetting used, due its not covered by activeVc handlers
        self?.continueReadingCtrl?.handleDismiss()
        return
      }///prevent multiple open
      sectionVC.reopenArticleDocName = lastArticle?.html?.name
      if let lastPos = self?.issue.lastArticleScrollPos {
        sectionVC.reopenArticleScrollPos = CGFloat(lastPos)
      }
      self?.resumeReadHandled = true
      self?.continueReadingCtrl = ContinueReadingController(lastContent: lastSection ?? lastArticle, targetVc: sectionVC) {[weak self] resume in
        if resume == true {
          if let lastArticle = lastArticle {
            sectionVC.showArticle(lastArticle)
            Notification.send(Const.NotificationNames.articleLoaded)
          }
          else if let idx = lastSectionIndex{
            ///This is the way to scroll to certain index in WebCollection VC whitout artefacts,
            ///but it still looks ugly for jumps > 4 indices
            ///every index would be handled e.g. the sliderButton disappears and re-appears on 'anzeigen'
            /// sectionVC.suppressLinkPressedNotification = true
            /// sectionVC.collectionView?.scrollto(idx, animated: true)
            /// onMainAfter(1.0) { sectionVC.suppressLinkPressedNotification = false }
            sectionVC.index = idx
          }
          Usage.track(Usage.event.dialog.OpenLastRead, name: "OpenFromDialog")
          self?.resumeReadDidAccepted(sectionVC.articleVC ?? sectionVC)
        }
        else {
          Usage.track(Usage.event.dialog.OpenLastRead, name: "Cancel")
          onMainAfter(1.0) {[weak self] in
            self?.resumeReadDidDismissed(sectionVC)
          }
        }
        self?.continueReadingCtrl = nil
      }
    }
  }
  
  private func resumeReadDidDismissed(_ vc: UIViewController){
    
    guard resumeReadSettingsChangeDiscard == false else { return }
    
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
        Usage.track(Usage.event.dialog.OpenLastReadDisable, name: "Dismissed")
        return
      }
      self?.resumeReadSettingsChangeDiscard = true
      if userChoice {
        self?.resumeReadDismissed = -20
        Usage.track(Usage.event.dialog.OpenLastReadDisable, name: "Stay Enabled")
      }
      else {
        self?.resumeReadDismissed = 0
        self?.reopenHintSetting = false
        Usage.track(Usage.event.dialog.OpenLastReadDisable, name: "Disable")
      }
    }
  }
  
  private func resumeReadDidAccepted(_ vc: UIViewController){
    
    guard resumeReadSettingsChangeDiscard == false else { return }
    
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
          Usage.track(Usage.event.dialog.OpenLastReadAutomatic, name: "Dismissed")
          return
        }
        self?.resumeReadSettingsChangeDiscard = true
        if userChoice {
          self?.resumeReadAccepted = 0
          self?.reopenAutomaticSetting = true
          Usage.track(Usage.event.dialog.OpenLastReadAutomatic, name: "Enabled")
        }
        else {
          self?.resumeReadAccepted = -20
          Usage.track(Usage.event.dialog.OpenLastReadAutomatic, name: "Keep Notification")
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
                      atSection: Int? = nil,
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
    
    let pdfVC = TazPdfPagesViewController(issueInfo: self)
    pushDelegate.push(pdfVC, issueInfo: self)
    
    if issue.status == .reduced && issue.pages?.count ?? 0 < 5 {
      authenticate()
      return
    }
    
    var targetArticle: Article?
    if let artIdx = atArticle {
      targetArticle = issue.allArticles.valueAt(artIdx)
    }
    
    if reopenAutomaticSetting || atPage != nil || atArticle != nil {
      reOpen(vc: pdfVC,
             atPage: atPage,
             atArticle: targetArticle,
             atArticleScrollPos: issue.lastArticleScrollPos)
      if reopenAutomaticSetting {
        Usage.track(Usage.event.dialog.OpenLastRead, name: "OpenAutomatic")
      }
    }
    else {
      requestContinueReading(with: pdfVC, issue: issue)
    }
  }
  
  private func requestContinueReading(with pdfVC: TazPdfPagesViewController, issue:StoredIssue) {
    if reopenHintSetting == false && reopenAutomaticSetting == false {
      Usage.track(Usage.event.dialog.OpenLastRead, name: "Disabled")
      return
    }
    guard reopenHintSetting == true && reopenAutomaticSetting == false else { return }
    
    var img: UIImage?
    var txt: String?
    var title: String?
    var targetArticle: Article?
    
    if let idx = issue.lastArticleIndexForCurrentMode,
       let lastArt = issue.allArticles.valueAt(idx) {
      img = lastArt.firstImage
      title = "Weiterlesen:"
      txt = lastArt.title ?? "(kein Titel angegeben)"
      targetArticle = lastArt
    } else if let page = issue.lastPage, page != 0 {
      img = issue.pages?.valueAt(page)?.facsimile?.image(dir: issue.dir)
      title = "Weiterlesen:"
      txt = "Seite \(page+1)"
    } else {
      return
    }
    
    guard let title = title, let txt = txt else { return }
    
    continueReadingCtrl
    = ContinueReadingController(title: title,
                                text: txt,
                                image: img,
                                targetVc: pdfVC,
                                bottomOffset: pdfVC.toolBar.yOffset,
                                finishHandler: {[weak self] resume in
      if resume == true {
        self?.reOpen(vc: pdfVC,
                     atPage: issue.lastPage,
                     pageAnimated: true,
                     atArticle: targetArticle,
                     atArticleScrollPos: issue.lastArticleScrollPos)
        self?.resumeReadDidAccepted(pdfVC)
        Usage.track(Usage.event.dialog.OpenLastRead, name: "OpenFromDialog")
      } else {
        self?.resumeReadDidDismissed(pdfVC)
        Usage.track(Usage.event.dialog.OpenLastRead, name: "Cancel")
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
