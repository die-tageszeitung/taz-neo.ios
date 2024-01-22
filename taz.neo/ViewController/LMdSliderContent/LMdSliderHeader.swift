//
//  LMdSliderHeader.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.01.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthUIKit

/// Header for lmd collectionview content table
class LMdSliderHeader: UIView {
  let imageView = UIImageView()
  let pageLabel = UILabel()
  let bottomBorder = UIView()
  let contentLabel = UILabel("Inhalt - ",
                             _numberOfLines: 1,
                             align: .left) 
  let issueLabel = UILabel("Ausgabe",
                             _numberOfLines: 1,
                             align: .right)
  
  var panoPageWidthConstraint: NSLayoutConstraint?
  var singlePageWidthConstraint: NSLayoutConstraint?  
  var panoPageAspectWidthConstraint: NSLayoutConstraint?
  var singlePageAspectWidthConstraint: NSLayoutConstraint?
  
  var image: UIImage? {
    didSet {
      panoPageWidthConstraint?.isActive = false
      panoPageAspectWidthConstraint?.isActive = false
      singlePageWidthConstraint?.isActive = false
      singlePageAspectWidthConstraint?.isActive = false
      if image?.size.width ?? 0.0 > image?.size.height ?? 1.0 {
        panoPageAspectWidthConstraint?.isActive = true
        panoPageWidthConstraint?.isActive = true
      }
      else {
        singlePageAspectWidthConstraint?.isActive = true
        singlePageWidthConstraint?.isActive = true
      }
      imageView.image = image
    }
  }
  
  func setup(){
    self.addSubview(imageView)
    self.addSubview(pageLabel)
    self.addSubview(contentLabel)
    self.addSubview(issueLabel)
    self.addSubview(bottomBorder)
    
    pageLabel.lmdBenton(size: 13.0).centerText()
    contentLabel.lmdArnhem()
    issueLabel.lmdArnhem(italic: true)
    
    imageView.shadow()
    imageView.contentMode = .scaleAspectFit
    
    bottomBorder.backgroundColor = .black
    bottomBorder.pinHeight(0.7)
    pin(bottomBorder.left, to: self.left, dist:  Const.Size.DefaultPadding)
    pin(bottomBorder.right, to: self.right, dist:  -Const.Size.DefaultPadding)
    pin(bottomBorder.bottom, to: self.bottom)
    
    pin(imageView.top, to: self.top, dist: 10)
    pin(imageView.left, to: self.leftGuide(), dist: Const.Size.DefaultPadding)
    
    pin(pageLabel.left, to: self.imageView.left)
    pageLabel.pinWidth(to: self.width, dist: -30, factor: 0.3)
    pin(issueLabel.left, to: contentLabel.right, dist: 0)
    pin(issueLabel.right, to: self.right, dist: -Const.Size.DefaultPadding)
    
    pin(contentLabel.bottom, to: self.bottom, dist: -10)
    pin(pageLabel.bottom, to: self.bottom, dist: -10)
    pin(issueLabel.bottom, to: self.bottom, dist: -10)
    
    pin(issueLabel.top, to: imageView.bottom, dist: 10, priority: .fittingSizeLevel)
    
    pin(contentLabel.right, to: issueLabel.left)
    /// layout.minimumInteritemSpacing == 12.0 + layout.sectionInset.left == 15 + ...right ==  15
    let dist = 30.0 //0.3*(width-dist)
    panoPageWidthConstraint = imageView.pinWidth(to: self.width,
                                                 factor: 0.6)
    panoPageWidthConstraint?.isActive = false
    singlePageWidthConstraint = imageView.pinWidth(to: self.width,
                                                   factor: 0.3)
    singlePageWidthConstraint?.isActive = false
    
    panoPageAspectWidthConstraint = imageView.pinAspect(ratio: 1.38,
                                                        pinWidth: false)
    panoPageAspectWidthConstraint?.isActive = false
    singlePageAspectWidthConstraint = imageView.pinAspect(ratio: 0.69,
                                                          pinWidth: false)
    
    singlePageAspectWidthConstraint?.isActive = false
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
