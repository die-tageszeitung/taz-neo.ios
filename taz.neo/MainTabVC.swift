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
  
  private var popViewControllerClosure: ((UIViewController)->(Bool))
  = { vc in return !(vc is IntroVC) }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
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
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupTabbar()
    self.navigationController?.isNavigationBarHidden = true
    registerForStyleUpdates()
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { [weak self] notif in
      self?.authenticationSucceededCheckReload()
    }
    
    Notification.receive(Const.NotificationNames.searchSelectedText) { [weak self] notif in
      guard let searchString = notif.content as? String,
      let searchCtrl
              = ((self?.viewControllers?.valueAt(2) as? UINavigationController)?
        .viewControllers.first as? SearchController) else { return }
      self?.selectedIndex = 2
      searchCtrl.searchFor(searchString: searchString)
    }
    
    Notification.receive(Const.NotificationNames.gotoIssue) { [weak self] notif in
      self?.selectedIndex = 0
      (self?.selectedViewController as? UINavigationController)?.popToRootViewController(animated: false)
      guard let date = notif.content as? Date,
            let home = ((self?.selectedViewController as? UINavigationController)?
                .viewControllers.first as? HomeTVC) else { return }
      home.scroll(up: true)
      let idx = home.carouselController.service.nextIndex(for: date)
      ///todo reactivate smallJump but with better logic e.g. not load beetwen items!
      var smallJump = false
      if let i = home.carouselController.centerIndex, i.distance(to: idx) < 50 { smallJump = true }
      home.carouselController.scrollTo(idx, animated: smallJump, fromJumpToDate: true)
    }
    
    Notification.receive(Const.NotificationNames.gotoArticleInIssue) { [weak self] notif in
      self?.selectedIndex = 0
      guard let article = notif.content as? Article,
            let issue = article.primaryIssue as? StoredIssue,
            let home = ((self?.selectedViewController as? UINavigationController)?
                .viewControllers.first as? HomeTVC) else { return }
      /*
       
       (self?.selectedViewController as? UINavigationController)?.popToRootViewController(animated: false)
       
      home.scroll(up: true)
      let idx = home.carouselController.service.nextIndex(for: date)
      ///todo reactivate smallJump but with better logic e.g. not load beetwen items!
      var smallJump = false
      if let i = home.carouselController.centerIndex, i.distance(to: idx) < 50 { smallJump = true }
      home.carouselController.scrollTo(idx, animated: smallJump, fromJumpToDate: true)
       */
      
      if let sectVc = home.navigationController?.viewControllers.valueAt(1) as? SectionVC,
      let sectIssue = sectVc.issue as? StoredIssue,
          issue == sectIssue {
        sectVc.showArticle(article, animated: true)
        home.togglePdfButton.isHidden = true
      }
      else {
        home.navigationController?.popToRootViewController(animated: false)
        home.openIssue(issue, at: article)
        home.togglePdfButton.isHidden = true
      }
    }
    
  } // viewDidLoad
  
  func setupTabbar() {
    self.tabBar.barTintColor = Const.Colors.iOSDark.secondarySystemBackground
    self.tabBar.backgroundColor = Const.Colors.iOSDark.secondarySystemBackground
    self.tabBar.isTranslucent = false
    self.tabBar.tintColor = .white
    
    let service = IssueOverviewService(feederContext: feederContext)
    let home = HomeTVC(service: service, feederContext: feederContext)
    home.title = "Home"
    home.tabBarItem.image = UIImage(named: "home")
    home.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let homeNc = NavigationController(rootViewController: home)
    homeNc.onPopViewController(closure: popViewControllerClosure)
    homeNc.isNavigationBarHidden = true
    
    let bookmarksNc = BookmarkNC(feederContext: feederContext)
    bookmarksNc.onPopViewController(closure: popViewControllerClosure)
    bookmarksNc.title = "Leseliste"
    bookmarksNc.tabBarItem.image = UIImage(named: "star")
    bookmarksNc.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    bookmarksNc.isNavigationBarHidden = true
    
    let search = SearchController(feederContext: feederContext )
    search.title = "Suche"
    search.tabBarItem.image = UIImage(named: "search-magnifier")
    search.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let searchNc = NavigationController(rootViewController: search)
    searchNc.onPopViewController(closure: popViewControllerClosure)
    searchNc.isNavigationBarHidden = true
    
    let settings = SettingsVC(feederContext: feederContext)
    settings.title = "Einstellungen"
    settings.tabBarItem.image = UIImage(named: "settings")
    settings.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    self.viewControllers = [homeNc, bookmarksNc, searchNc, settings]
    self.selectedIndex = 0
  }
  
  func applyStyles() {
    self.view.backgroundColor = .clear
    setNeedsStatusBarAppearanceUpdate()
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return Defaults.darkMode ?  .lightContent : .default
  }
  
  required init(feederContext: FeederContext) {
    self.feederContext = feederContext
    super.init(nibName: nil, bundle: nil)
    delegate = self
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
} // MainTabVC

extension MainTabVC {
  /// Check whether it's necessary to reload the current Issue
  public func authenticationSucceededCheckReload() {
    feederContext.updateAuthIfNeeded()
    
    let selectedNc = selectedViewController as? UINavigationController
    var reloadTarget: ReloadAfterAuthChanged?
    
    if let home = selectedNc?.viewControllers.first as? HomeTVC,
       selectedNc?.topViewController != home {
      reloadTarget = home
    }
    else if let search = selectedNc?.viewControllers.first as? SearchController,
            selectedNc?.topViewController != search {
      reloadTarget = search
    }
    else if let target = selectedNc as? ReloadAfterAuthChanged {
      reloadTarget = target
    }
    
    ///Settings need to be reloaded no matter if selected!
    if let settings = selectedViewController as? SettingsVC {
      settings.refreshAndReload()
    } else  {
      for case let settings as SettingsVC in self.viewControllers ?? [] {
        settings.refreshAndReload()
      }
    }
              
    guard let reloadTarget = reloadTarget else { return }
    if Defaults.expiredAccount {
      //DemoIssue only will be exchanged with DemoIssue
      log("not refresh if expired account")
      return
    }
    
    let snap = UIWindow.keyWindow?.snapshotView(afterScreenUpdates: false)
    
    WaitingAppOverlay.show(alpha: 1.0,
                           backbround: snap,
                           showSpinner: true,
                           titleMessage: "Aktualisiere Daten",
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
      reloadTarget.reloadOpened()
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
