//
//  BookmarksCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

///extendeds NewContentTableVcCell to have a share button
class BookmarksCell: NewContentTableVcCell {
  
  func onShare(closure:  ((Article, UIView)->())?) { _shareClosure = closure }
  private var _shareClosure: ((
    Article , UIView)->())?
  
  let shareButton = UIImageView(image: UIImage(named: "share"))
    
  override func updateStyles(){
    super.updateStyles()
    self.contentView.backgroundColor = Const.SetColor.ios(.systemBackground).color
  }
  
  override func setup() {
    super.setup()
    pin(dottedLine.bottom, to: self.contentView.bottom)
    shareButton.tintColor = Const.Colors.appIconGrey
    content.addSubview(shareButton)
    shareButton.pinSize(CGSize(width: 26, height: 26))
    pin(shareButton.right, to: bookmarkButton.left, dist: -10)
    pin(shareButton.centerY, to: bookmarkButton.centerY)
    shareButton.isHidden = true
    shareButton.onTapping {[weak self] _ in
      onMainAfter(0.1){[weak self] in ///prevent additional  cell tap due async call
        if let article = self?.article, let self = self {
          self._shareClosure?(article, self.shareButton)
        }
      }
    }
  }
  
}
