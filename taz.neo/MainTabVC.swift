//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import NorthLib

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
    home.tabBarItem.image = UIImage(named: "home")
    home.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let homeNc = NavigationController(rootViewController: home)
    homeNc.isNavigationBarHidden = true
    
    let bookmarks = UIViewController()
    bookmarks.title = "Leseliste"
    bookmarks.tabBarItem.image = UIImage(named: "star")
    bookmarks.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let search = SearchController(feederContext: feederContext )
    search.title = "Suche"
    search.tabBarItem.image = UIImage(named: "search-magnifier")
    search.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    
    let searchNc = NavigationController(rootViewController: search)
//    let searchNc = NavigationController(rootViewController: SearchSettingsVC())
    
    let settings = SettingsVC(feederContext: feederContext)
    settings.title = "Einstellungen"
    settings.tabBarItem.image = UIImage(named: "settings")
    settings.tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
    if gt_iOS13 == false {
      ///iOS 12 and lower forget insets on select
      ///@see: https://stackoverflow.com/a/22549516
      ///set them to zero
      home.tabBarItem.imageInsets = .zero
      bookmarks.tabBarItem.imageInsets = .zero
      search.tabBarItem.imageInsets = .zero
      settings.tabBarItem.imageInsets = .zero
      ///...and use resized images
      home.tabBarItem.image = home.tabBarItem.image?.resized(targetSize: CGSize(width: 32, height: 32), scale: UIScreen.main.scale)
      bookmarks.tabBarItem.image = bookmarks.tabBarItem.image?.resized(targetSize: CGSize(width: 32, height: 32), scale: UIScreen.main.scale)
      search.tabBarItem.image = search.tabBarItem.image?.resized(targetSize: CGSize(width: 32, height: 32), scale: UIScreen.main.scale)
      settings.tabBarItem.image = settings.tabBarItem.image?.resized(targetSize: CGSize(width: 32, height: 32), scale: UIScreen.main.scale)

    }
    
    self.viewControllers = [ homeNc, bookmarks, searchNc, settings]
    self.selectedIndex = 2
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
