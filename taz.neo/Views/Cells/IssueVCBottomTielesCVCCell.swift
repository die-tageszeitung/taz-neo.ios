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
  
  public var observer : NSObjectProtocol?
 
  public override func prepareForReuse() {
    self.momentView.image = nil
    self.observer = nil
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
  }
  
  public var text : String? {
    didSet {
      button.setTitle(text, for: .normal)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

