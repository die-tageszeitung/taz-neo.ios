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
  
  public let imageView = UIImageView()
  public let button = UIButton()
  let buttonHeight:CGFloat = 30.0
  let buttonOffset:CGFloat = 3.0
  
  var menu:ContextMenu?
 
  public override func prepareForReuse() {
    self.imageView.image = nil
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
    imageView.backgroundColor = .black
    imageView.contentMode = .scaleAspectFit
    menu = ContextMenu(view: imageView)
    
    contentView.addSubview(imageView)
    pin(imageView, to: contentView, exclude: .bottom)
    pin(imageView.bottom,
        to: contentView.bottom,
        dist: -buttonHeight-buttonOffset,
        priority: .defaultHigh)
    
    contentView.addSubview(button)
    pin(button, to: contentView, exclude: .top)
    button.pinHeight(buttonHeight)
    pin(button.topGuide(), to: imageView.bottomGuide(), dist: buttonOffset, priority: .fittingSizeLevel)
    
    button.imageEdgeInsets = UIEdgeInsets(top: 2, left: 8, bottom: -2, right: -8)
    button.semanticContentAttribute = UIApplication.shared
      .userInterfaceLayoutDirection == .rightToLeft ? .forceLeftToRight : .forceRightToLeft
    button.imageView?.tintColor = .white
    
    self.addBorder(.green, 0.5)
    self.contentView.addBorder(.yellow, 1.0)
    self.imageView.addBorder(.blue, 1.5)
    self.button.addBorder(.red, 0.5)
  }
  
  public var text : String? {
    didSet {
      button.setTitle(text, for: .normal)
    }
  }
  
  public var cloudHidden : Bool = false {
    didSet {
      if cloudHidden {
        button.setImage(nil, for: .normal)
      }
      else {
        button.setImage(UIImage(name: "icloud.and.arrow.down"), for: .normal)
      }
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

