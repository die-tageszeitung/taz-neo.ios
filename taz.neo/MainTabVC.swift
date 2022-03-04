//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import NorthLib

class MainTabVC: UITabBarController, UIStyleChangeDelegate {

//  static let singleton = TazAppEnvironment.sharedInstance
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
    home.tabBarItem.image = UIImage(named: "home")
    home.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let homeNc = NavigationController(rootViewController: home)
    homeNc.isNavigationBarHidden = true
    
    let bookmarks = UIViewController()
    bookmarks.title = "Leseliste"
    bookmarks.tabBarItem.image = UIImage(named: "star")
    bookmarks.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let search = UIViewController()
    search.title = "Suche"
    search.tabBarItem.image = UIImage(named: "search-magnifier")
    search.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let settings = SettingsVC()
    settings.title = "Einstellungen"
    settings.tabBarItem.image = UIImage(named: "settings")
    settings.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    self.viewControllers = [ homeNc, bookmarks, search, settings]
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
    else if let tvc = viewController as? UITableViewController
    {
      tvc.tableView.scrollRectToVisible(CGRect(x: 1, y: 1, width: 1, height: 1), animated: true)
    }
    return true
  }
}
