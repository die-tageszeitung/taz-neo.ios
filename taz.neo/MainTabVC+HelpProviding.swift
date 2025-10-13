//
//  MainTabVC+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.09.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

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
    HelpBusiness.shared.openHelp()
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
