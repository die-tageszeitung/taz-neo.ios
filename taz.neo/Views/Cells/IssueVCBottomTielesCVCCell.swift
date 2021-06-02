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
    self.button.startHandler = nil
    self.button.startHandler = nil
    self.button.setTitle("", for: .normal)
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
    button.tintColor = Const.Colors.darkSecondaryText
    //not use cloud image from assets due huge padding
    //button.cloudImage = UIImage(named: "download")
    button.setTitleColor(Const.Colors.darkSecondaryText, for: .normal)
    button.titleLabel?.font = Const.Fonts.contentFont(size: Const.ASize.DefaultFontSize)
    
    Notification.receive("issueProgress", closure: {   [weak self] notif in
      guard let self = self else { return }
      if (notif.object as? Issue)?.date != self.issue?.date { return }
      if let (loaded,total) = notif.content as? (Int64,Int64) {
        let percent = Float(loaded)/Float(total)
        if percent > 0.05 {
          self.button.downloadState = .process
          self.button.percent = percent
        }
        if percent == 1.0 {  self.momentView.isActivity = false }
      }
    })
  }
  
  private func update(){
    button.startHandler = nil
    button.stopHandler = nil
    
    guard let issue = issue else { return }
    
    let title = UIWindow.size.width < 370 ? issue.date.shortest : issue.date.shorter
    button.setTitle(title, for: .normal)
    
    momentView.isActivity = issue.isDownloading
    
    if issue.isDownloading {
      button.downloadState = .waiting
    }
    else if issue.isComplete {
      button.downloadState = .done
    }
    else {
      button.downloadState = .notStarted
    }
    
  }
  
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

