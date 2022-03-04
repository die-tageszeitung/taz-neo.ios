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
    
//    pushViewController(StartupVC(), animated: false)
//    MainTabVC.singleton = self
//    isNavigationBarHidden = true
//    isForeground = true
//    // Disallow leaving view controllers IssueVC and IntroVC by edge swipe
//    onPopViewController { vc in
//      if vc is IssueVC || vc is IntroVC {
//        return false
//      }
//      return true
//    }
    
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
    
    self.viewControllers
    = [ UINavigationController(rootViewController: home),
        bookmarks,
        search,
        settings]
    self.selectedIndex = 3
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
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
} // MainNC
