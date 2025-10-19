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
    guard helpButton.superview == nil else { return }
    view.addSubview(helpButton)
    helpButtonDefaultBottomDistance
    = tabBar.frame.height + 9.0
    helpButtonBottomConstraint
    = pin(helpButton.bottom,
          to: view.bottomGuide(isMargin: true),
          dist: -helpButtonDefaultBottomDistance)
    pin(helpButton.right,
        to: view.rightGuide(),
        dist: -Const.Dist2.m15)
    helpButton.onTapHelp {[weak self] in self?.helpTapped()}
    Notification.receive(Const.NotificationNames.helpProviderChanged, closure: {[weak self] _ in
      self?.helpProviderChanged()
    })
  }
  
  func helpProviderChanged(){
    guard let helpProvider = currentHelpProvider,
          helpProvider.doNotShowHelpInThisAreaAnymore == false,
          showHelp == true
    else {
      helpButton.hideAnimated()
      return
    }
    helpButton.badgeValue = helpProvider.newItemsCount
    helpButton.showAnimated()
  }
  
  func updateHelpButtonBottomConstraint(){
    UIView.animate(withDuration: 0.4) {[weak self] in
      guard let self = self else { return }
      //      self.view.superview?.layoutSubviews()//n
      helpButtonBottomConstraint?.constant
      = -self.helpButtonDefaultBottomDistance
      - self.helpButtonPlayerOffset
      - self.helpButtonToolbarOffset
      - self.helpButtonAdditionalSheetOffset
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
