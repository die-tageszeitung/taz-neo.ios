//
//  MainTabVC+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.09.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

/// every VC that wants to offer help implements this protocol
protocol HelpProviding where Self: UIViewController {
  /// called when the global help button is tapped
  func openHelp()
  var items: [CoachmarkItem] { get }
}

/// MARK: - extension to provide Base functionality for Help
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
    button.backgroundColor = Const.Colors.darkPrimaryBG
    return button
  }
  
  @objc private func helpTapped() {
    if let helpVC = currentVisibleHelpController() {
      helpVC.openHelp()
      highlightHelpButton = false
    }
  }
}

fileprivate extension MainTabVC {
  func currentVisibleHelpController() -> HelpProviding? {
      if let nav = selectedViewController as? UINavigationController {
          return nav.visibleViewController as? HelpProviding
      } else {
          return selectedViewController as? HelpProviding
      }
  }
}
