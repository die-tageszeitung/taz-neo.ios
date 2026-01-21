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
        dist: -7.0) //Const.Dist2.s5 m15???
    helpButton.onTapHelp { HelpBusiness.shared.openHelp()}
    helpButton.onDisableCurrentHelp { HelpBusiness.shared.disableCurrentHelp()}
    Notification.receive(Const.NotificationNames.helpProviderChanged, closure: {[weak self] _ in
      self?.helpProviderChanged()
    })
  }
  
  func helpProviderChanged(){
    guard let helpProvider = currentHelpProvider,
          helpProvider.doNotShowHelpInThisAreaAnymore == false,
          showHelp == true
    else {
      if helpButton.isVoiceOverFocusedElement {
        UIAccessibility.post(notification: .layoutChanged, argument: self.view)
      }
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
}

/// A model representing a single help  (coach mark) item displayed in the app.
/// Each `HelpItem` defines the textual content, accessibility information,
/// visual configuration, and the UI element it refers to.
public class HelpItem {
    
    /// The main title displayed for this help item.
    var title: String
    
    /// An optional alternative title used for VoiceOver accessibility.
    /// If provided, this will be read instead of `title`.
    var accessibilityTitle: String?
    
    /// The descriptive text explaining the help item.
    var text: String
    
    /// An optional alternative text label for VoiceOver accessibility.
    /// If provided, this overrides the spoken version of `text`.
    var accessibilityLabelText: String?
    
    /// Indicates whether the highlighted target area should be displayed
    /// as a circular cutout rather than the default rectangular shape.
    var isCircleCutout: Bool
    
    /// Optional adjustment applied to the circular cutout inset.
    /// A positive value enlarges the cutout; a negative value reduces it.
    var circleCutoutInsetAdjustment: CGFloat?
    
    /// The view this help item refers to or highlights.
    /// If `nil`, the help item will be shown without a specific target area.
    var targetView: UIView?
    
    /// An optional custom content view shown instead of the default text label.
    /// Use this to display more complex or styled content.
    var contentView: UIView?
    
    /// An optional image displayed above the title and text.
    var topImageView: UIImageView?
    
    
    /// Creates a new help item that can be used to configure coach marks.
    ///
    /// - Parameters:
    ///   - title: The visible title of the help item.
    ///   - accessibilityTitle: An optional alternative title for VoiceOver.
    ///   - text: The descriptive text shown below the title.
    ///   - accessibilityLabelText: An optional alternative accessibility label for the text.
    ///   - isCircleCutout: Determines whether the target highlight is circular.
    ///   - circleCutoutInsetAdjustment: Optional inset modification for the circular highlight.
    ///   - targetView: The UI element this help item highlights.
    init(
        title: String,
        accessibilityTitle: String? = nil,
        text: String,
        accessibilityLabelText: String? = nil,
        isCircleCutout: Bool = false,
        circleCutoutInsetAdjustment: CGFloat? = nil,
        targetView: UIView? = nil
    ) {
        self.title = title
        self.text = text
        self.accessibilityTitle = accessibilityTitle
        self.accessibilityLabelText = accessibilityLabelText
        self.isCircleCutout = isCircleCutout
        self.circleCutoutInsetAdjustment = circleCutoutInsetAdjustment
        self.targetView = targetView
    }
}
