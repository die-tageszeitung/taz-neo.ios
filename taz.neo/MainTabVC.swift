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
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    Notification.send(Const.NotificationNames.viewSizeTransition,
                      content: size,
                      error: nil,
                      sender: nil)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupTabbar()
    self.navigationController?.isNavigationBarHidden = true
    registerForStyleUpdates()
  } // viewDidLoad
  
  func setupTabbar() {
    self.tabBar.barTintColor = Const.Colors.iOSDark.secondarySystemBackground
    self.tabBar.backgroundColor = Const.Colors.iOSDark.secondarySystemBackground
    self.tabBar.isTranslucent = false
    self.tabBar.tintColor = .white
    
    let home = IssueVC(feederContext: feederContext)
    home.title = "Home"
    home.updateToolbarHomeIcon()
    home.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let homeNc = NavigationController(rootViewController: home)
    homeNc.isNavigationBarHidden = true
    
    let bookmarksNc = BookmarksNC(feederContext: feederContext)
    bookmarksNc.title = "Leseliste"
    bookmarksNc.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    bookmarksNc.isNavigationBarHidden = true
    bookmarksNc.updateTabbarImage()
    
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

extension MainTabVC : UITabBarControllerDelegate {
  func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
    
    if tabBarController.selectedViewController != viewController { return true }
    
    if let firstVc = (viewController as? NavigationController)?.viewControllers.first,
       let issueVC = firstVc as? IssueVcWithBottomTiles //IssueVC also works
    {
      issueVC.onHome()
    }
    else if let firstVc = (viewController as? NavigationController)?.viewControllers.first,
       let searchController = firstVc as? SearchController //IssueVC also works
    {
      searchController.restoreInitialState()
    }
    else if let tvc = viewController as? UITableViewController
    {
      tvc.tableView.scrollRectToVisible(CGRect(x: 1, y: 1, width: 1, height: 1), animated: true)
    }
    return true
  }
}

