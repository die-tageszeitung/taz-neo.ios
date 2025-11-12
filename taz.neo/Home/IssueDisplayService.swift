//
//  IssueDisplayService.swift
//  taz.neo
//
//  Created by Ringo Müller on 03.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class IssueDisplayService: NSObject, IssueInfo, DoesLog {
  var issue: Issue {
    return sissue
  }
  
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  @Default("resumeReadAccepted")
  public var resumeReadAccepted: Int
  
  @Default("resumeReadDismissed")
  public var resumeReadDismissed: Int
  
  @Default("resumeReadSettingsChangeDiscard")
  public var resumeReadSettingsChangeDiscard: Bool
  
  @Default("reopenHintSetting")
  public var reopenHintSetting: Bool
  
  @Default("reopenAutomaticSetting")
  public var reopenAutomaticSetting: Bool
  
  var resumeReadHandled = false
  
  var continueReadingCtrl: ContinueReadingController?
  
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
  private func pushIssueVC(issue:StoredIssue,
                         atSection: Int? = nil,
                         atArticle: Int? = nil,
                         atArticleScrollPos: CGFloat? = nil,
                         atPage: Int? = nil,
                         pushDelegate: PushIssueDelegate) {
    if isFacsimile {
      self.pushPdfVC(issue: issue,
                     atPage: atPage,
                     atArticle: atArticle,
                     pushDelegate: pushDelegate)
    }
    else {
      self.pushSectionVC(issue: issue,
                         atSection: atSection,
                         atArticle: atArticle,
                         atArticleScrollPos: atArticleScrollPos,
                         pushDelegate: pushDelegate)
    }
  }
  
  func showIssue(pushDelegate: PushIssueDelegate, atArticle: Int? = nil, atArticleScrollPos: CGFloat? = nil, atSection: Int?, atPage: Int? = nil) {
    let issue = self.sissue
    
    if issue.sections?.count ?? 0 == 0 || issue.allArticles.count == 0 {
      debug("Issue: \(issue.date.short) has \(issue.sections?.count ?? 0) Ressorts and \(issue.allArticles.count) articles.")
    }
    var issueStatus = "status: \(issue.status), isComplete: \(issue.isComplete), isAudioComplete: \(issue.isAudioComplete), isReduced: \(issue.isReduced), needUpdateAudio: \(issue.needUpdateAudio), isDownloading: \(issue.isDownloading), isAutodownloading: \(issue.isAutodownloading), isOvwComplete: \(issue.isOvwComplete) articleCount: \(issue.allArticles.count), pageCount: \(issue.pages?.count ?? 0)"
    let path = issue.feed.feeder.issueDir(issue: issue).path
    if let protection = try? URL(fileURLWithPath: path)
      .resourceValues(forKeys: [.fileProtectionKey]), protection.allValues.isEmpty == false {
      var issueDirProtection = ""
      for (key, value) in protection.allValues {
        issueDirProtection += "\n  \(key): \(value)"
      }
      log("file protection info for path: \(path) \nis:\(issueDirProtection)")
    }
    else {
      log("No file protection info for path: \(path)")
    }
    
    
    feederContext.openedIssue = issue //remember opened issue to not delete if
    debug("*** Action: Entering \(issue.feed.name)-" +
          "\(issue.date.isoDate(tz: feederContext.storedFeeder.timeZone))")
    /* Dieser Code verhindert, wenn sich der feeder aufgehangen hat, dass eine andere bereits heruntergeladene Ausgabe geöffnet wird
     ...weil isDownloading == true => das wars!
     ein open issue in dem Fall wäre praktisch,
     ...würde dann den >>>Notification.receiveOnce("issueStructure"<<<" raus nehmen
     */
    
    let dfl = Defaults.singleton
    dfl["appCrashedLastDate"] = "\(Date())"
    dfl["appCrashedLastType"] = "fake crash..."
    
    guard feederContext.needsUpdate(issue: issue,
                                    toShowPdf: isFacsimile) else {
      log("No update needed to show issue in \(isFacsimile ? "facsimileView" : "appView")\n\(issueStatus)")
      pushIssueVC(issue: issue,
                atSection: atSection,
                atArticle: atArticle,
                atArticleScrollPos: atArticleScrollPos,
                atPage: atPage,
                pushDelegate: pushDelegate)
      if feederContext.isAuthenticated,
         feederContext.gqlFeeder.isExpiredAccount == false,
         issue.needUpdateAudio == true {
        self.feederContext.getCompleteIssue(issue: sissue, isPages: false, isAutomatically: false, force: true)
      }
      return
    }
    log("Update needed to show issue in \(isFacsimile ? "facsimileView" : "appView")\n\(issueStatus)")
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
        self.debug("open issue with issueStructure error: \(err) isIssueWatchable: \(issue.status.watchable)")
        ///if offline or download error, Page 1 could be displayed; section 1 is not available => just show Page 1
        if issue.status.watchable && self.isFacsimile {
          self.pushIssueVC(issue: issue,
                         atSection: atSection,
                         atArticle: atArticle,
                         atPage: atPage,
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
          ///if offline or download error, Page 1 could be displayed; section 1 is not available => just show Page 1
          if issue.status.watchable && self.isFacsimile {
            self.pushIssueVC(issue: issue,
                           atSection: atSection,
                           atArticle: atArticle,
                           atPage: atPage,
                           pushDelegate: pushDelegate)  }
          return
        }
        self.pushIssueVC(issue: issue,
                  atSection: atSection,
                  atArticle: atArticle,
                  atPage: atPage,
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
    
    let preventOpenDirect
    = issue.isReduced
    && feederContext.isAuthenticated
    && feederContext.gqlFeeder.isExpiredAccount == false
    
    if issue.status.watchable
        && preventOpenDirect == false
        && issue.sections?.isEmpty == false {
      self.pushIssueVC(issue: issue,
                atSection: atSection,
                atArticle: atArticle,
                atPage: atPage,
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

extension Issue {
  func indexOfArticle(with id: Int) -> Int? {
    return allArticles.firstIndex(where: { art in art.serverId == id })
  }
  
  func indexOfArticle(with url: URL) -> Int? {
    return allArticles.firstIndex(where: { art in art.html?.fileName == url.lastPathComponent })
  }
  
  func indexOf(article: Article?) -> Int? {
    guard let article = article else { return nil }
    return allArticles.firstIndex(where: { art in art.isEqualTo(otherArticle: article) })
  }
  func pageIndexOf(article: Article?) -> Int? {
    return pages?.firstIndex(where: { page in
      return article?.pageNames?.contains{ $0 == page.pdf?.name } ?? false
    })
  }
}
