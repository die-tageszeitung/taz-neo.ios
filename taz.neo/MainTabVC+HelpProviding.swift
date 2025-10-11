//
//  MainTabVC+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.09.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib


fileprivate class HelpState {
  @Default("lastSectionHelpIndex")
  var lastSectionHelpIndex: Int
  @Default("lastArticleHelpIndex")
  var lastArticleHelpIndex: Int
  @Default("lastPlayerHelpIndex")
  var lastPlayerHelpIndex: Int
  @Default("lastSliderHelpIndex")
  var lastSliderHelpIndex: Int
  @Default("lastHomeHelpIndex")
  var lastHomeHelpIndex: Int
  
  static let shared = HelpState()
}

#warning("Refactor HelpProviding")
/// every VC that wants to offer help implements this protocol
/// OHNE where Self: UIViewController ?????????
///
protocol HelpProviding where Self: UIViewController {
  /// called when the global help button is tapped
  var helpItems: [HelpItem] { get }
  var newItemsCount: Int { get }
  var lastHelpItemIndex: Int { get set }
  func onDisplay(idx: Int, isClosing: Bool)
}

extension HelpProviding {
  var newItemsCount: Int { helpItems.count - 1 - lastHelpItemIndex }
}

extension ArticleVC {
  var lastHelpItemIndex: Int {
    get { HelpState.shared.lastArticleHelpIndex }
    set { HelpState.shared.lastArticleHelpIndex = newValue }
  }
}

extension SectionVC {
  var lastHelpItemIndex: Int {
    get { HelpState.shared.lastSectionHelpIndex }
    set { HelpState.shared.lastSectionHelpIndex = newValue }
  }
}

extension HomeVC {
  var lastHelpItemIndex: Int {
    get { HelpState.shared.lastHomeHelpIndex }
    set { HelpState.shared.lastHomeHelpIndex = newValue }
  }
}

  

extension HelpProviding {
  
  func onDisplay(idx: Int, isClosing: Bool){
    lastHelpItemIndex = max(lastHelpItemIndex, idx)
  }
  
  func openHelp(){
    guard let window = UIApplication.shared.delegate?.window else { return }
    
    ///show layer
    let helpView = HelpView()
    helpView.onDisplay {[weak self] idx in
      self?.onDisplay(idx: idx, isClosing: false)
    }
    helpView.items = self.helpItems
//    helpView.setLastMaxIndex(idx: lastHelpItemIndex)//NOT WORKING
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
    helpButtonDefaultBottomDistance
    = tabBar.frame.height + 9.0
    helpButtonBottomConstraint
    = pin(helpButton.bottom,
          to: view.bottomGuide(),
          dist: -helpButtonDefaultBottomDistance)
    pin(helpButton.right,
        to: view.rightGuide(),
        dist: -Const.Dist2.m15)
    helpButton.onTapHelp {[weak self] in self?.helpTapped()}
  }
  
  func updateHelpButtonBottomConstraint(){
    UIView.animate(withDuration: 0.4) {[weak self] in
      guard let self = self else { return }
      //      self.view.superview?.layoutSubviews()//n
      helpButtonBottomConstraint?.constant
      = -self.helpButtonDefaultBottomDistance
      - self.helpButtonPlayerOffset
      - self.helpButtonToolbarOffset
    }
  }
  
  private func helpTapped() {
    currentVisibleHelpController()?.openHelp()
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
