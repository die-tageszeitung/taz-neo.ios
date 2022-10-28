//
//  IssueVCBottomTielesCVCCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 26.02.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public class IssueVCBottomTielesCVCCell : UICollectionViewCell {
  
  public let momentView = MomentView()
  public let button = DownloadStatusButton()
  let buttonHeight:CGFloat = 30.0
  let buttonOffset:CGFloat = 3.0
  
  var menu:ContextMenu?
  
  public var issue : Issue? {  didSet { update() } }
  
  public override func prepareForReuse() {
    self.momentView.image = nil
    self.button.label.text = nil
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    /**
     Bugfix after Merge
     set ImageViews BG Color to same color like Collection Views BG fix white layer on focus
     UIColor.clear or UIColor(white: 0, alpha: 0) did not work
     Issue is not in last Build before Merge 0.4.18-2021011501 ...but flickering is there on appearing so its half of the bug
     - was also build with same xcode version/ios sdk
     issue did not disappear if deployment target is set back to 11.4
     */
//    momentView.backgroundColor = .black
//    momentView.contentMode = .scaleAspectFit
    menu = ContextMenu(view: momentView)
    
    contentView.addSubview(momentView)
    pin(momentView, to: contentView, exclude: .bottom)
    pin(momentView.bottom,
        to: contentView.bottom,
        dist: -buttonHeight-buttonOffset,
        priority: .defaultHigh)
    
    contentView.addSubview(button)
    pin(button, to: contentView, exclude: .top)
    button.pinHeight(buttonHeight)
    pin(button.topGuide(), to: momentView.bottomGuide(), dist: buttonOffset, priority: .fittingSizeLevel)
    button.tintColor = Const.Colors.appIconGrey
    //not use cloud image from assets due huge padding
    //button.cloudImage = UIImage(named: "download")
    button.label.textColor = Const.Colors.appIconGrey
    button.label.font = Const.Fonts.contentFont(size: 15.0)
    
    Notification.receive("issueProgress", closure: {   [weak self] notif in
      guard let self = self else { return }
      if (notif.object as? Issue)?.date != self.issue?.date { return }
      if let (loaded,total) = notif.content as? (Int64,Int64) {
        let percent = Float(loaded)/Float(total)
        if percent > 0.05 {
          self.button.indicator.downloadState = .process
          self.button.indicator.percent = percent
        }
        if percent == 1.0 {  self.momentView.isActivity = false }
      }
    })
  }
  
  
  /// Update (or just set) Label Text
  /// on **iPhone** no Changes, fixes **Text depending Screen Resolution**
  /// on **iPad horizontalSizeClass changes are handled**, unfortunately resolution checks result here in
  /// strange behaviour that some cells not get updated and still show e.g. 22.10.22 and the next 23.10.2022
  private func updateLabel(){
    guard let issue = issue else { return }

//    let smaller = self.frame.size.width < 160
    let shorter
    = Device.isIpad
    ? traitCollection.horizontalSizeClass == .compact
    : UIWindow.size.width <= 375 //Iphone 6-iPhone 13mini
    
    ///iPhone 12 has 390 @see: https://www.ios-resolution.com
    ///or iPad Pro * 1/3 @see: https://developer.apple.com/design/human-interface-guidelines/foundations/layout
    
    button.label.text
    = issue.validityDateText(timeZone: GqlFeeder.tz,
                             short: true,
                             shorter: shorter,
                             leadingText: "")
  }
  
  public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if !Device.isIpad { return }
    if previousTraitCollection?.horizontalSizeClass == traitCollection.horizontalSizeClass { return }
    updateLabel()
  }
  
  private func update(){
    guard let issue = issue else { return }
    updateLabel()
    
    momentView.isActivity = issue.isDownloading
    
    if issue.isDownloading {
      button.indicator.downloadState = .waiting
    }
    else if issue.status.watchable {
      button.indicator.downloadState = .done
    }
    else {
      button.indicator.downloadState = .notStarted
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

