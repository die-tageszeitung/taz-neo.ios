//
//  HelpBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.09.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

/// every VC that wants to offer help implements this protocol
protocol HelpPresentable where Self: UIViewController {
  /// called when the global help button is tapped
  func openHelp()
  var items: [CoachmarkItem] { get }
}

extension MainTabVC {
  func setupHelpButton(){
    view.addSubview(helpButton)
    pin(helpButton.bottom, to: view.bottomGuide(), dist: -9.0 - tabBar.frame.height)
    pin(helpButton.right, to: view.rightGuide(), dist: -Const.Dist2.m15)
  }
  
  func createHelpButton() -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(named: "tooltip"), for: .normal)
    button.setTitle("Hilfe", for: .normal)

    // Optional: Tintfarbe (Standard ist systemBlue)
    button.tintColor = Const.Colors.appIconGrey

    // Optional: Zugriffshilfe
    button.accessibilityLabel = "Hilfe anzeigen"
    button.layoutVertically()
    button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    button.pinHeight(54.0)
    button.pinWidth(54.0)
    button.layer.cornerRadius = 27.0
    
    button.alpha = 0.0
    button.addTarget(self, action: #selector(helpTapped), for: .touchUpInside)
    
    return button
  }
  
  @objc private func helpTapped() {
        if let helpVC = currentVisibleHelpController() {
            helpVC.openHelp()
        }
    }
}

extension MainTabVC {
//  // MARK: - Sichtbarkeits-Logik
  private func currentVisibleHelpController() -> HelpPresentable? {
      if let nav = selectedViewController as? UINavigationController {
          return nav.visibleViewController as? HelpPresentable
      } else {
          return selectedViewController as? HelpPresentable
      }
  }
//  
//  private func updateHelpButtonVisibility(animated: Bool) {
//      let shouldShow = currentVisibleHelpController() != nil
//
//    
//    let targetAlpha: CGFloat = shouldShow ? 1.0 : 0.0
//
//      if animated {
//        self.helpButton.toogleAnimation(to: targetAlpha)
//          UIView.animate(withDuration: 0.25) {
//              self.helpButton.alpha = targetAlpha
//          }
//      } else {
//          helpButton.alpha = targetAlpha
//      }
//  }
//  
//  // MARK: - UITabBarControllerDelegate
//  func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
//      attachNavDelegateIfNeeded()
//      updateHelpButtonVisibility(animated: true)
//  }
//  private func attachNavDelegateIfNeeded() {
//      if let nav = selectedViewController as? UINavigationController {
//          nav.delegate = self
//      }
//  }
//
//  // MARK: - UINavigationControllerDelegate
//  func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
//      updateHelpButtonVisibility(animated: true)
//  }
//  
  
}


extension HomeVC: HelpPresentable, CoachmarkVC{
  var viewName: String {
    return "Home"
  }
  
  func targetView(for item: CoachmarkItem) -> UIView? {
    return nil
  }
  
  func target(for item: CoachmarkItem) -> (UIImage, [UIView], [CGPoint])? {
    return nil
  }
  
  func openHelp() {
    CoachmarksBusiness.shared.showHelp(sender: self)
  }
  
  var tabbarItems: [UIView] {
    var views: [UIView] = []
    if let tabBar = self.tabBarController?.tabBar {
      for (index, view) in tabBar.subviews.enumerated() {
        if let control = view as? UIControl {
          views.append(control)
        }
      }
    }
    return views
  }
  
  var items: [CoachmarkItem] {
    get {
      let tabbarItems = self.tabbarItems
      let itm = CoachmarkItem(title:"Willkommen in der taz neo App!",
                              text: "Hier finden Sie die neuesten Nachrichten und Artikel.",
                              isCircleCutout: true,
                              targetView: self.viewModeButton)
      let itm2 = CoachmarkItem(title:"Willkommen in der taz neo App!",
                               text: "Hier finden Sie die neuesten Nachrichten und Artikel.",
                               isCircleCutout: false,
                               targetView: self.collectionView)
      let itm3 = CoachmarkItem(title:"Home",
                               text: "Hier finden Sie die Ausgaben",
                               isCircleCutout: true,
                               targetView: tabbarItems.valueAt(0))
      let itm4 = CoachmarkItem(title:"Leseliste",
                               text: "Hier finden Sie Ihre Lesezeichen",
                               isCircleCutout: true,
                               targetView: tabbarItems.valueAt(1))
      let itm5 = CoachmarkItem(title:"Suche",
                               text: "Hier finden Sie die Suche",
                               isCircleCutout: true,
                               targetView: tabbarItems.valueAt(2))
      let itm6 = CoachmarkItem(title:"Einstellungen",
                               text: "Hier finden Sie die Einstellungen",
                               isCircleCutout: true,
                               targetView: tabbarItems.valueAt(3))
      
      let itm8 = CoachmarkItem(title:"Ende",
                               text: "Hier gibts nichts mehr zu sehen!",
                               isCircleCutout: false,
                               targetView: self.collectionView)
      return [itm, itm2, itm3, itm4, itm5, itm6, itm8]
    }
    
  }
}


extension ArticleVC: HelpPresentable, CoachmarkVC{
  public var viewName: String {
    return "Home"
  }
  
  public func targetView(for item: CoachmarkItem) -> UIView? {
    return nil
  }
  
  public func target(for item: CoachmarkItem) -> (UIImage, [UIView], [CGPoint])? {
    return nil
  }
  
  public func openHelp() {
    CoachmarksBusiness.shared.showHelp(sender: self)
  }
  var items: [CoachmarkItem] {
    get {
      let itm = CoachmarkItem(title:"Willkommen in der taz neo App!",
                              text: "Hier finden Sie die neuesten Nachrichten und Artikel.",
                              isCircleCutout: true,
                              targetView: self.backButton)
      return [itm, itm]
    }
    
  }
}
