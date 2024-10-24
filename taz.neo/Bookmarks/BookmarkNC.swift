//
//  BookmarkNC.swift
//  taz.neo
//
//  Created by Ringo Müller on 12.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

fileprivate class PlaceholderVC: UIViewController{
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view
    = PlaceholderView("Sie haben noch keine Artikel in Ihrer Leseliste.\n\nSpeichern Sie Artikel zum weiterlesen, hören oder erinnern in Ihrer persönlichen Leseliste. Einfach das Sternchen bei den Artikeln aktivieren.",
                      image: UIImage(named: "star"))
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.view.backgroundColor = Const.SetColor.CTBackground.color
  }
}

extension PlaceholderVC: DefaultScreenTracking {
  public var defaultScreen: Usage.DefaultScreen? { .BookmarksEmpty }
}

class BookmarkNC: NavigationController {
  private var placeholderVC = PlaceholderVC()
  
  public var feederContext: FeederContext
  public lazy var bookmarkFeed = BookmarkFeed.allBookmarks(feeder: feeder)
  public var issue: Issue { bookmarkFeed.issues![0] }
  var isShowingAlert = false
  
  public lazy var sectionVC: BookmarkSectionVC = {
    return createSectionVC()
  }()
  
  func createSectionVC(openArticleAtIndex: Int? = nil) -> BookmarkSectionVC{
    let svc = BookmarkSectionVC(feederContext: feederContext,
                               atSection: nil,
                               atArticle: openArticleAtIndex)
    svc.delegate = self
    svc.toolBar.show(show:false, animated: true)
    svc.isStaticHeader = true
    svc.header.titletype = .bigLeft
    svc.header.title = App.isTAZ ? "leseliste" : "Leseliste"
    svc.hidesBottomBarWhenPushed = false
    return svc
  }
  
  func setup() {
    Notification.receive(Const.NotificationNames.expiredAccountDateChanged) { [weak self] notif in
      guard TazAppEnvironment.hasValidAuth else { return }
      self?.reloadOpened()
    }
    #warning("ToDo after refactor and issue independent bookmarks")
    /*
     there was a (particullary not) reproduceable bug:
     logged out > load demo issue > bookmark demo article > view in bookmark list
     > login in issue-overview
     1. > move to article in bookmarks > showed demo Article OR! full Article (depend on what?) AND showed Login Form
     2. > article in bookmark list was not clickable (list did not refreshed!)
     
     to load all articles fully is maybe too much because currently its needed to load all issues
     later with issue independent bookmark articles we can load all articles
     
     another bug: bookmark css was also after a few restarts not available.
     from testflight alpha > alpha
     not solved by various restarts @see error report by mail
     solved by start debug
     */
    
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { [weak self] notif in
      guard TazAppEnvironment.hasValidAuth else { return }
      self?.reloadOpened()
    }
    
    Notification.receive("updatedDemoIssue") { [weak self] notif in
      guard let self = self else { return }
      self.bookmarkFeed
      = BookmarkFeed.allBookmarks(feeder: self.feeder)
      self.sectionVC.delegate = nil
      self.sectionVC.delegate = self///trigger SectionVC.setup()
    }
    
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      // regenerate all bookmark sections
      guard let emptyRoot = self?.placeholderVC,
            let self = self else { return }
      if let art = msg.sender as? StoredArticle {
        self.bookmarkFeed.loadAllBookmarks()
        self.bookmarkFeed.genAllHtml()
        if art.hasBookmark {
          self.sectionVC.insertArticle(art)
          self.sectionVC.reload()
          self.ensureBookmarkListVisibleIfNeeded(animated: false)
        }
        else {
          self.sectionVC.deleteArticle(art)
          if !self.sectionVC.isVisible { self.sectionVC.reload() }
          self.sectionVC.updateAudioButton()
        }
        if self.bookmarkFeed.count <= 0 {
          self.viewControllers[0] = emptyRoot
          self.popToRootViewController(animated: true)
        }
      }
      else {
        self.bookmarkFeed.genAllHtml()
        self.sectionVC.reload()
      }
    }
  }
  
  func ensureBookmarkListVisibleIfNeeded(animated: Bool = true){
    if bookmarkFeed.count > 0 && self.viewControllers.first != sectionVC  {
      setViewControllers([sectionVC], animated: animated)
    }
  }
   
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    ensureBookmarkListVisibleIfNeeded()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  init(feederContext: FeederContext) {
    self.feederContext = feederContext
    super.init(rootViewController: placeholderVC)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension BookmarkNC: IssueInfo {
  public func resetIssueList() {}
}


extension BookmarkNC: ReloadAfterAuthChanged {
  public func reloadOpened(){
    /// UseCase: app reseted, unauth, bookmark demo Article
    /// view demo article in bookmark list, scroll down login
    guard TazAppEnvironment.hasValidAuth else { return }
    
    let lastIndex: Int? = (self.viewControllers.last as? ArticleVC)?.index
    var issuesToDownload:[StoredIssue] = []
    for art in bookmarkFeed.issues?.first?.allArticles ?? [] {
      if let sissue = art.primaryIssue as? StoredIssue,
         sissue.status == .reduced,
         issuesToDownload.contains(sissue) == false {
        issuesToDownload.append(sissue)
      }
    }
        
    func downloadNextIfNeeded(){
      if let nextIssue = issuesToDownload.first {
        self.feederContext.getCompleteIssue(issue: nextIssue,
                                             isPages: false,
                                             isAutomatically: false)
      } else if let idx = lastIndex {
        reopenArticleAtIndex(idx: idx)
      } else {
        self.bookmarkFeed
        = BookmarkFeed.allBookmarks(feeder: self.feeder)
        self.sectionVC.reload()
        Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
      }
    }
    
    Notification.receive("issue"){ notif in
      ///ensure the issue download comes from here!
      guard let issue = notif.object as? Issue else { return }
      guard let issueIdx = issuesToDownload.firstIndex(where: {$0.date == issue.date})
      else { return /* Issue Download from somewhere else */ }
      issuesToDownload.remove(at: issueIdx)
      downloadNextIfNeeded()
    }
    downloadNextIfNeeded()
  }
  
  private func reopenArticleAtIndex(idx: Int?){
    self.bookmarkFeed
    = BookmarkFeed.allBookmarks(feeder: self.feeder)
    self.sectionVC.releaseOnDisappear()
    self.sectionVC
    = createSectionVC(openArticleAtIndex: idx)
    self.viewControllers[0] = self.sectionVC
    self.popToRootViewController(animated: true)
    Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
  }
  
  public func reloadIfNeeded(article: Article?){
    guard let article = article,
          let reloadIssue = article.primaryIssue as? StoredIssue else { return }

    if article.html?.exists(inDir: article.dir.path) == false {
      loadReload(reloadIssue: reloadIssue)
    }
    else if reloadIssue.isReduced && TazAppEnvironment.hasValidAuth {
      loadReload(reloadIssue: reloadIssue)
    }
  }
  
  private func loadReload(reloadIssue: StoredIssue){
    let lastIndex: Int? = (self.viewControllers.last as? ArticleVC)?.index
    let snap = UIWindow.keyWindow?.snapshotView(afterScreenUpdates: false)
    WaitingAppOverlay.show(alpha: 1.0,
                           backbround: snap,
                           showSpinner: true,
                           titleMessage: "Aktualisiere Daten",
                           bottomMessage: "Bitte haben Sie einen Moment Geduld!",
                           dismissNotification: Const.NotificationNames.removeLoginRefreshDataOverlay)
    Notification.receive("issue"){[weak self] notif in
      ///ensure the issue download comes from here!
      guard let issue = notif.object as? Issue else { return }
      guard reloadIssue.date.issueKey == issue.date.issueKey else { return }
      self?.reopenArticleAtIndex(idx: lastIndex)
    }
    reloadOpened()
    onMainAfter {[weak self] in
      self?.popToRootViewController(animated: false)//there is a overlay
    }
  }
}
