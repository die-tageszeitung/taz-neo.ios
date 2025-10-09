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
  var items: [HelpItem] { get }
  func onDisplay(idx: Int, isClosing: Bool)
}

extension HelpProviding {
  
  func onDisplay(idx: Int, isClosing: Bool){}
  
  func openHelp(){
    guard let window = UIApplication.shared.delegate?.window else { return }
    
    ///show layer
      let helpView = HelpView()
    helpView.onDisplay {[weak self] idx in
      self?.onDisplay(idx: idx, isClosing: false)
    }
      helpView.items = self.items
      helpView.frame = window?.bounds ?? .zero // oder mit Auto Layout Constraints
      
      helpView.alpha = 0.0
      window?.addSubview(helpView)
      
      UIView.animate(withDuration: 0.7,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
        helpView.alpha = 1.0
                     }, completion: { [weak self] (_) in
                      if helpView.isTopmost == false {
                        window?.bringSubviewToFront(helpView)
                      }
                     })
      helpView.onClose {[weak self]  in
        UIView.animate(withDuration: 0.7,
                       delay: 0,
                       options: UIView.AnimationOptions.curveEaseInOut,
                       animations: {
          helpView.alpha = 0.0
                       }, completion: {(_) in
//                         helpView.targetView = nil
                         helpView.removeFromSuperview()
                
                        })
      }
  }
  
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

public class HelpItem {
  var title: String
  var text: String
  var isCircleCutout: Bool
  var circleCutoutInsetAdjustment: CGFloat?
  var targetView: UIView?
  var contentView: UIView?
  var topImageView: UIImageView?

  
  init(title: String, text: String, isCircleCutout: Bool = false, circleCutoutInsetAdjustment:CGFloat? = nil, targetView: UIView? = nil) {
    self.title = title
    self.text = text
    self.isCircleCutout = isCircleCutout
    self.circleCutoutInsetAdjustment = circleCutoutInsetAdjustment
    self.targetView = targetView
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
/**
 
 Todo
 
 header.extendedSearchButton
 
 
 Coachmarks.Section {
 //      switch item {
 //        case .slider:
 //          return slider?.button
 //        case .swipe:
 //          return currentView as? UIView

 ArticleVC
 case .audio:
//        return playButton.buttonView
//      case .share:
//        return shareButton.buttonView
//      case .font:
//        return textSettingsButton.buttonView
 
 
 
 */
