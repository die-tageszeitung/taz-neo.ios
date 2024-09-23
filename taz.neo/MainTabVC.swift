//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

class MainTabVC: UITabBarController, UIStyleChangeDelegate {

  var feederContext: FeederContext
  var service: IssueOverviewService
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    TazAppEnvironment.sharedInstance.nextWindowSize = size
    Notification.send(Const.NotificationNames.viewSizeTransition,
                      content: size,
                      error: nil,
                      sender: nil)
  }
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    Notification.send(Const.NotificationNames.traitCollectionDidChange,
                      content: self.traitCollection,
                      error: nil,
                      sender: nil)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard let data = TazAppEnvironment.openedFromNotificationCenter else { return }
    TazAppEnvironment.openedFromNotificationCenter = nil
    gotoArticleInIssue(with: data)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupTabbar()
    self.navigationController?.isNavigationBarHidden = true
    registerForStyleUpdates()
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { [weak self] notif in
      self?.authenticationSucceededCheckReload(alertMessage: (notif.content as? String))
    }
    
    Notification.receive(Const.NotificationNames.searchSelectedText) { [weak self] notif in
      guard let searchString = notif.content as? String,
      let searchCtrl
              = ((self?.viewControllers?.valueAt(2) as? UINavigationController)?
        .viewControllers.first as? SearchController) else { return }
      self?.selectedIndex = 2
      searchCtrl.searchFor(searchString: searchString)
    }

    Notification.receive(Const.NotificationNames.gotoSettings) { [weak self] notif in
      self?.selectedIndex = 3
    }
    
    Notification.receive(Const.NotificationNames.gotoIssue) { [weak self] notif in
      self?.gotoIssue(at: notif.content as? Date)
    }
    
    Notification.receive(Const.NotificationNames.gotoArticleInIssue) { [weak self] notif in
      self?.selectedIndex = 0
      if let data = notif.content as? PushNotification.Payload.ArticlePushData {
        self?.gotoArticleInIssue(with: data)
        return 
      }
      guard let article = notif.content as? Article else { return }
      self?.gotoArticleInIssue(article: article)
    }
    
    Notification.receive("issue") { [weak self] notification in
      self?.handleIssueDownloadNotification(notification: notification)
    }
    Notification.receive(Const.NotificationNames.issueUpdate) { [weak self] notification in
      self?.handleIssueDownloadNotification(notification: notification)
    }
  } // viewDidLoad
  
  var searchArticleToOpen: SearchArticle?
  
  func handleIssueDownloadNotification(notification: Notification){
    guard let art = searchArticleToOpen,
          art.originalIssueDate != nil,
          let issue = (notification.content as? Issue)
                    ?? (notification.content as? IssueCellData)?.issue,
          art.originalIssueDate?.issueKey == issue.date.issueKey else { return }
    openArticleFromSearch(article: art)
  }
  
  func gotoArticleInIssue(with data: PushNotification.Payload.ArticlePushData){
    log("open issue with date: \(data.articleDate) and Article: \(data.articleTitle ?? "\(data.articleMsId)")")
    guard let issue = self.service.issue(at: data.articleDate) else {
      Notification.receiveOnce(Const.NotificationNames.issueUpdate) { [weak self] _ in self?.gotoArticleInIssue(with: data)}
      service.download(issueAt: data.articleDate, withAudio: false)
      gotoIssue(at: data.articleDate)
      return
    }
    if feederContext.needsUpdate(issue: issue, toShowPdf: self.service.isFacsimile) {
      Notification.receiveOnce("issue") { [weak self] _ in self?.gotoArticleInIssue(with: data)}
      service.download(issueAt: data.articleDate, withAudio: false)
      gotoIssue(at: data.articleDate)
      return
    }
    
    guard let issueArtIndex = issue.indexOfArticle(with: data.articleMsId),
          let artInTargetIssue = issue.allArticles.valueAt(issueArtIndex) else {
      gotoIssue(at: data.articleDate)
      return
    }
    gotoArticleInIssue(article: artInTargetIssue)
  }
  
  func gotoArticleInIssue(article: Article){
    if let art = article as? SearchArticle {
      self.openArticleFromSearch(article: art)
      return
    }
    self.searchArticleToOpen = nil
    guard let issue = article.primaryIssue as? StoredIssue,
          let home = ((self.selectedViewController as? UINavigationController)?
            .viewControllers.first as? HomeTVC) else { return }
    if let sectVc = home.navigationController?.viewControllers.valueAt(1) as? SectionVC,
       let sectIssue = sectVc.issue as? StoredIssue,
       issue == sectIssue {
      sectVc.showArticle(article, animated: true)
      home.togglePdfButton.isHidden = true
    }
    else {
      home.navigationController?.popToRootViewController(animated: false)
      home.openIssue(issue, atArticle: issue.indexOf(article: article), atPage: issue.pageIndexOf(article: article))
      home.togglePdfButton.isHidden = true
    }
  }
  
  func openArticleFromSearch(article: SearchArticle){
    guard let date = article.originalIssueDate else {
      gotoIssue(at: nil)
      return
    }
    searchArticleToOpen = article
    guard let issue = self.service.issue(at: date) else {
      service.download(issueAt: date, withAudio: false)
      gotoIssue(at: date)
      return
    }
    if feederContext.needsUpdate(issue: issue, toShowPdf: self.service.isFacsimile) {
      service.download(issueAt: date, withAudio: false)
      gotoIssue(at: date)
      return
    }
    
    guard let issueArtIndex = issue.indexOf(article: article),
          let artInTargetIssue = issue.allArticles.valueAt(issueArtIndex) else {
      gotoIssue(at: date)
      return
    }
    gotoArticleInIssue(article: artInTargetIssue)
  }
  
  func gotoIssue(at date: Date?){
    self.selectedIndex = 0
    (self.selectedViewController as? UINavigationController)?.popToRootViewController(animated: false)
    guard let date = date,
        let home = ((self.selectedViewController as? UINavigationController)?
              .viewControllers.first as? HomeTVC) else { return }
    home.scroll(up: true)
    let idx = home.carouselController.service.nextIndex(for: date)
    home.carouselController.scrollTo(idx, animated: true)
  }
  
  func setupTabbar() {
    self.tabBar.barTintColor = Const.Colors.iOSDark.secondarySystemBackground
    self.tabBar.backgroundColor = Const.Colors.iOSDark.secondarySystemBackground
    self.tabBar.isTranslucent = false
    self.tabBar.tintColor = .white
    
    let home = HomeTVC(service: service, feederContext: feederContext)
    home.title = "Home"
    home.tabBarItem.image = UIImage(named: "home")
    home.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let homeNc = NavigationController(rootViewController: home)
    homeNc.isNavigationBarHidden = true
    
    let bookmarksNc = BookmarkNC(feederContext: feederContext)
    bookmarksNc.title = "Leseliste"
    bookmarksNc.tabBarItem.image = UIImage(named: "star")
    bookmarksNc.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    bookmarksNc.isNavigationBarHidden = true
    
    let search = SearchController(feederContext: feederContext )
    search.title = "Suche"
    search.tabBarItem.image = UIImage(named: "search-magnifier")
    search.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let searchNc = NavigationController(rootViewController: search)
    searchNc.isNavigationBarHidden = true
    
    let settings = SettingsVC(feederContext: feederContext)
    settings.title = "Einstellungen"
    settings.tabBarItem.image = UIImage(named: "settings")
    settings.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    self.viewControllers = [homeNc, bookmarksNc, searchNc, settings]
    self.selectedIndex = 0
  }
  
  override var viewControllers: [UIViewController]? {
    didSet {
      setupTracking()
    }
  }
  
  func setupTracking(){
//    if Usage.sharedInstance.usageTrackingAllowed == false { return }
    for case let nc as UINavigationController in viewControllers ?? [] {
      nc.delegate = Usage.shared
      (nc as? NavigationController)?.navigationDelegate = Usage.shared
    }
  }
  
  func applyStyles() {
    self.view.backgroundColor = .clear
    setNeedsStatusBarAppearanceUpdate()
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return Defaults.darkMode ?  .lightContent : .default
  }
  
  required init(feederContext: FeederContext, service: IssueOverviewService) {
    self.feederContext = feederContext
    self.service = service
    super.init(nibName: nil, bundle: nil)
    delegate = self
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
} // MainTabVC

extension MainTabVC {
  /// Check whether it's necessary to reload the current Issue
  /// - Parameter alertMessage: optional alert message e.g. shown if reactivated subscription
  public func authenticationSucceededCheckReload(alertMessage: String? = nil) {
    feederContext.updateAuthIfNeeded()
    
    var reloadTargets: [ReloadAfterAuthChanged] = []
        
    for case let tabNav as UINavigationController in self.viewControllers ?? [] {
      let firstVc = tabNav.viewControllers.first
      let vcCount = tabNav.viewControllers.count
      if let home = firstVc as? HomeTVC {
        if vcCount > 1 { reloadTargets.append(home)}
      }
      else if let search = firstVc as? SearchController{
        if search.currentState == .result { reloadTargets.append(search)}
      }
      else if let target = firstVc as? ReloadAfterAuthChanged {
        reloadTargets.append(target)
      }
      else if let settings = firstVc as? SettingsVC {
        settings.refreshAndReload()
      }
    }
    if reloadTargets.count == 0 {
      if let alertMessage = alertMessage {
        Alert.message(message: alertMessage)
      }
      return
    }
    if Defaults.expiredAccount {
      //DemoIssue only will be exchanged with DemoIssue
      log("not refresh if expired account")
      return
    }
    
    let snap = UIWindow.keyWindow?.snapshotView(afterScreenUpdates: false)
    
    WaitingAppOverlay.show(alpha: 1.0,
                           backbround: snap,
                           showSpinner: true,
                           titleMessage: "\(alertMessage ?? "")\nAktualisiere Daten",
                           bottomMessage: "Bitte haben Sie einen Moment Geduld!",
                           dismissNotification: Const.NotificationNames.removeLoginRefreshDataOverlay)
    Notification.receiveOnce(Const.NotificationNames.articleLoaded) { _ in
      Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
    }
    Notification.receiveOnce(Const.NotificationNames.feederUnreachable) { _ in
      /// popToRootViewController is no more needed here due its done by reloadTarget.reloadOpened
      Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
      Toast.show(Localized("error"))
    }
    onMainAfter(1.0) {
      for reloadTarget in reloadTargets {
        reloadTarget.reloadOpened()
      }
    }
    onMainAfter(15.0) {
      //dirty hack sometimes reload opened did not work
      //had it unreproduceable in debug, and sendt the following notification enter foreground hock/Breakpoint
      Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
    }
  }
}

extension MainTabVC : UITabBarControllerDelegate {
  func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
    if tabBarController.selectedViewController != viewController { return true }
    
    if let firstVc = (viewController as? NavigationController)?.viewControllers.first,
       let home = firstVc as? HomeTVC
    {
      home.onHome()
    }
    else if let firstVc = (viewController as? NavigationController)?.viewControllers.first,
       let searchController = firstVc as? SearchController
    {
      _ = searchController.restoreInitialState()
    }
    else if let firstVc = (viewController as? NavigationController)?.viewControllers.first,
       let content = firstVc as? ContentVC
    {
      content.currentWebView?.scrollView.setContentOffset(CGPoint(x:0, y:0), animated: true)
    }
    else if let tvc = viewController as? UITableViewController
    {
      tvc.tableView.scrollRectToVisible(CGRect(x: 1, y: 1, width: 1, height: 1), animated: true)
    }
    return true
  }
}

public protocol ReloadAfterAuthChanged {
  func reloadOpened()
}
