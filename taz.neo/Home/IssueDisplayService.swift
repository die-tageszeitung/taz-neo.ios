//
//  IssueDisplayService.swift
//  taz.neo
//
//  Created by Ringo Müller on 03.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import UIKit
import NorthLib

class IssueDisplayService: NSObject, IssueInfo, DoesLog {
  var issue: Issue {
    return sissue
  }
  
  
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  var feederContext: FeederContext
  var sissue: StoredIssue
  
  /// Initialize with FeederContext
  public init(feederContext: FeederContext, issue: StoredIssue) {
    self.feederContext = feederContext
    self.sissue = issue
  }
}
 

// MARK: - Open Issue Helper
extension IssueDisplayService {
  private func openIssue(issue:StoredIssue,
                         atSection: Int? = nil,
                         atArticle: Int? = nil,
                         atPage: Int? = nil,
                         pushDelegate: PushIssueDelegate) {
    #warning("DO prevent multiple pushes!")
    //prevent multiple pushes!
    //      if self.navigationController?.topViewController != self { return }
    let authenticatePDF = { [weak self] in
      guard let self = self else { return }
      if self.feederContext.isAuthenticated && self.feederContext.gqlFeeder.isExpiredAccount {
        //shows expired form
        self.feederContext.authenticate()
        return
      }
      let loginAction = UIAlertAction(title: Localized("login_button"),
                                      style: .default) { _ in
        self.feederContext.authenticate()
      }
      let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel)
      let msg = "Um das ePaper zu lesen, müssen Sie sich anmelden."
      Alert.message(title: "Fehler", message: msg, actions: [loginAction, cancelAction])
    }
    
    if isFacsimile {
      ///the positive use case
      let pushPdf = { [weak self] in
        guard let self = self else { return }
        let vc = TazPdfPagesViewController(issueInfo: self)
        pushDelegate.push(vc, issueInfo: self)
        if issue.status == .reduced {
          authenticatePDF()
        }
        
      }
      ///in case of errors
      let handleError = {
        Toast.show(Localized("error"))
        Notification.send(Const.NotificationNames.articleLoaded)
      }
      
      if feederContext.storedFeeder.momentPdfFile(issue: issue) != nil {
        pushPdf()
      }
      else if let page1pdf = issue.pages?.first?.pdf {
        feederContext.dloader.downloadIssueData(issue: issue, files: [page1pdf]) { err in
          if err != nil { handleError() }
          else { pushPdf() }
        }
      } else {
        handleError()
      }
    }
    else {
      self.pushSectionVC(issue: issue,
                         atSection: atSection,
                         atArticle: atArticle,
                         pushDelegate: pushDelegate)
    }
  }
  
  /// Setup SectionVC and push it onto the VC stack
  private func pushSectionVC(issue:StoredIssue,
                             atSection: Int? = nil,
                             atArticle: Int? = nil,
                             pushDelegate: PushIssueDelegate) {
    let sectionVC = SectionVC(feederContext: feederContext,
                              atSection: atSection,
                              atArticle: atArticle)
    sectionVC.delegate = self
    
    if atArticle == nil {
      sectionVC.whenLoaded {
        Notification.send(Const.NotificationNames.articleLoaded)
      }
    }
    pushDelegate.push(sectionVC, issueInfo: self)
  }
  
  
  func showIssue(pushDelegate: PushIssueDelegate, at targetArticle: Article? = nil, isReloadOpened: Bool = false){
    let issue = self.sissue
    
    if issue.sections?.count ?? 0 == 0 || issue.allArticles.count == 0 {
      debug("Issue: \(issue.date.short ?? "-") has \(issue.sections?.count ?? 0) Ressorts and \(issue.allArticles.count) articles.")
      debug("This may fail!")
    }
      
    
    feederContext.openedIssue = issue //remember opened issue to not delete if
    debug("*** Action: Entering \(issue.feed.name)-" +
          "\(issue.date.isoDate(tz: feederContext.storedFeeder.timeZone))")
    /* Dieser Code verhindert, wenn sich der feeder aufgehangen hat, dass eine andere bereits heruntergeladene Ausgabe geöffnet wird
     ...weil isDownloading == true => das wars!
     ein open issue in dem Fall wäre praktisch,
     ...würde dann den >>>Notification.receiveOnce("issueStructure"<<<" raus nehmen
     */
    
    guard feederContext.needsUpdate(issue: issue,
                                    toShowPdf: isFacsimile) else {
      openIssue(issue: issue,
                atSection: issue.lastSection,
                atArticle: targetArticle?.index ?? issue.lastArticle,
                atPage: issue.lastPage,
                pushDelegate: pushDelegate)
      if feederContext.isAuthenticated,
         feederContext.gqlFeeder.isExpiredAccount == false,
         issue.needUpdateAudio == true {
        self.feederContext.getCompleteIssue(issue: sissue, isPages: false, isAutomatically: false, force: true)
      }
      return
    }
    //      if isDownloading {
    //        statusHeader.currentStatus = .loadIssue
    //        return
    //      }
    //      isDownloading = true
    //      issueCarousel.index = index
    //      issueCarousel.setActivity(idx: index, isActivity: true)
    Notification.receiveOnce("issueStructure", from: issue) { [weak self] notif in
      guard let self = self else { return }
      let issue = self.sissue
      if let err = notif.error {
        if issue.status.watchable && self.isFacsimile {
          self.openIssue(issue: issue,
                    atSection: issue.lastSection,
                    atArticle: targetArticle?.index ?? issue.lastArticle,
                    atPage: issue.lastPage,
                    pushDelegate: pushDelegate) }
        return
      }
      guard let sect0 = issue.sections?.first else {
        self.handleDownloadError(error: DefaultError(message: "data not available yet"))
        return
      }
      self.downloadSection(issue: issue, section: sect0) { [weak self] err in
        guard let self = self else { return }
        guard err == nil else {
          if issue.status.watchable && self.isFacsimile { self.openIssue(issue: issue,
                                                                    atSection: issue.lastSection,
                                                                    atArticle: targetArticle?.index ?? issue.lastArticle,
                                                                    atPage: issue.lastPage,
                                                                    pushDelegate: pushDelegate)  }
          return
        }
        self.openIssue(issue: issue,
                  atSection: issue.lastSection,
                  atArticle: targetArticle?.index ?? issue.lastArticle,
                  atPage: issue.lastPage,
                  pushDelegate: pushDelegate)
        Notification.receiveOnce("issue", from: issue) { [weak self] notif in
          guard let self = self else { return }
          if let err = notif.error {
            self.handleDownloadError(error: err)
            self.error("Issue \(issue.date.isoDate()) DL Errors: last = \(err)")
          }
          else {
            self.debug("Issue \(issue.date.isoDate()) DL complete")
//            self.setLabel(idx: index)
          }
//          self.issueCarousel.setActivity(idx: index, isActivity: false)
        }
      }
    }
    if issue.status.watchable
        && issue.sections?.isEmpty == false
        && isReloadOpened == false {
      self.openIssue(issue: issue,
                atSection: issue.lastSection,
                atArticle: targetArticle?.index ?? issue.lastArticle,
                atPage: issue.lastPage,
                pushDelegate: pushDelegate)
    }
    self.feederContext.getCompleteIssue(issue: sissue, isPages: isFacsimile, isAutomatically: false)
  }
  
  /// Download one section
  private func downloadSection(issue:StoredIssue, section: Section, closure: @escaping (Error?)->()) {
    feederContext.dloader.downloadSection(issue: issue, section: section) { [weak self] err in
      if err != nil { self?.debug("Section \(section.html?.name ?? "-") DL Errors: last = \(err!)") }
      else { self?.debug("Section \(section.html?.name ?? "-") DL complete") }
      closure(err)
    }
  }
  
  /// Inspect download Error and show it to user
  func handleDownloadError(error: Error?) {
    self.debug("Err: \(error?.description ?? "-")")
    func showDownloadErrorAlert() {
      OfflineAlert.show(type: .issueDownload)
    }
    
    if let err = error as? FeederError {
      err.handle()
    }
    else if let err = error as? DownloadError, let err2 = err.enclosedError as? FeederError {
      err2.handle()
    }
    else if let err = error as? DownloadError {
      if err.handled == false {  showDownloadErrorAlert() }
      self.debug(err.enclosedError?.description ?? err.description)
    }
    else if let err = error {
      self.debug(err.description)
      showDownloadErrorAlert()
    }
    else {
      self.debug("unspecified download error")
      showDownloadErrorAlert()
    }
//    self.isDownloading = false
  }

}

extension Article {
  var index: Int? {
    return self.primaryIssue?.allArticles.firstIndex(where: { art in art.isEqualTo(otherArticle: self) })
  }
  
}
