//
//  MarketingContainerView.swift
//  taz.neo
//
//  Created by Ringo Müller on 18.06.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class MarketingContainerView: Padded.View {
  
  var imageLeftAligned: Bool
  
  var button: Padded.Button
  var titleLabel = UILabel()
  var textLabel = UILabel()
  var imageView = UIImageView()
  
  var firstWrapper = UIView()
  var secondWrapper = UIView()
  
  var first2sv_constrains: tblrConstrains?
  var second2sv_constrains: tblrConstrains?
  
  var first2second_verticalConstraint: NSLayoutConstraint?
  var firstHalf_widthConstraint: NSLayoutConstraint?
  var secondHalf_widthConstraint: NSLayoutConstraint?
  
  var imageAspectConstraint: NSLayoutConstraint?
  
  func setup(){
    if imageLeftAligned {
      secondWrapper.addSubview(titleLabel)
      secondWrapper.addSubview(textLabel)
      firstWrapper.addSubview(imageView)
    }
    else {
      firstWrapper.addSubview(titleLabel)
      firstWrapper.addSubview(textLabel)
      secondWrapper.addSubview(imageView)
    }
    
    let imgSv = imageLeftAligned ? firstWrapper : secondWrapper
    let lblSv = imageLeftAligned ? secondWrapper : firstWrapper
    
//    firstWrapper.addBorder(.yellow)
//    secondWrapper.addBorder(.green)
//    
//    self.addBorder(.red)
//    
//    titleLabel.addBorder(.blue)
//    textLabel.addBorder(.systemPink)
//    imageView.addBorder(.purple)
//    button.addBorder(.magenta)
    
    self.addSubview(firstWrapper)
    self.addSubview(secondWrapper)
    self.addSubview(button)
    
    pin(titleLabel, to: lblSv, exclude: .bottom)
    pin(textLabel, to: lblSv, exclude: .top)
    pin(textLabel.top, to: titleLabel.bottom, dist: Const.Dist2.s5)
    
    pin(imageView, to: imgSv)
    imageView.contentMode = .scaleAspectFit
    if let img = imageView.image,
       img.size.width > 0,
       img.size.height > 0 {
      imageView.pinAspect(ratio: img.size.width/img.size.height, priority: .defaultHigh)
    }
    
    first2sv_constrains = pin(firstWrapper, to: self)
    first2sv_constrains?.bottom?.isActive = false
    first2sv_constrains?.right?.isActive = false
    first2sv_constrains?.bottom?.constant = -80 //dist for button
    
    second2sv_constrains = pin(secondWrapper, to: self)
    second2sv_constrains?.top?.isActive = false
    second2sv_constrains?.left?.isActive = false
    second2sv_constrains?.bottom?.constant = -80 //dist for button
    
    firstHalf_widthConstraint = firstWrapper.pinWidth(to: self.width, dist: -Const.Size.DefaultPadding, factor: 0.5)
    secondHalf_widthConstraint = secondWrapper.pinWidth(to: self.width, dist: -Const.Size.DefaultPadding, factor: 0.5)
    firstHalf_widthConstraint?.isActive = false
    secondHalf_widthConstraint?.isActive = false
    first2second_verticalConstraint = pin(secondWrapper.top,
                                          to: firstWrapper.bottom,
                                          dist: Const.Dist2.m15)
    
    titleLabel.numberOfLines = 0
    titleLabel.textAlignment = .left
    titleLabel.marketingHead()
    
    textLabel.numberOfLines = 0
    textLabel.textAlignment = .left
    textLabel.contentFont()
    
    self.backgroundColor = Const.SetColor.HBackground.color
    
    pin(button.bottom, to: self.bottom)
    pin(button.width, to: firstWrapper.width)
    _ = imageLeftAligned ? pin(button.right, to: self.right) : pin(button.left, to: self.left)
  }
  
  
  func updateCustomConstraints(isTabletLayout: Bool){
    first2sv_constrains?.bottom?.isActive = false
    first2sv_constrains?.right?.isActive = false

    second2sv_constrains?.top?.isActive = false
    second2sv_constrains?.left?.isActive = false

    firstHalf_widthConstraint?.isActive = false
    secondHalf_widthConstraint?.isActive = false
    first2second_verticalConstraint?.isActive = false
    imageAspectConstraint?.isActive = false
    
    if isTabletLayout {
      first2sv_constrains?.bottom?.isActive = true
      second2sv_constrains?.top?.isActive = true
      firstHalf_widthConstraint?.isActive = true
      secondHalf_widthConstraint?.isActive = true
    }
    else {
      first2sv_constrains?.right?.isActive = true
      second2sv_constrains?.left?.isActive = true
      first2second_verticalConstraint?.isActive = true
      imageAspectConstraint?.isActive = true
    }
  }
  
  
  /// Creates Marketing Container View with given Layout
  /// - Parameters:
  ///   - button: Button for Action
  ///   - title: Title for MarketingContainer
  ///   - text: Text for MarketingContainer
  ///   - imageName: image to use
  ///   - imageLeftAligned: true if image left and Text/Button right; false otherwise
  init(button: Padded.Button,
       title: String,
       text:String,
       imageName:String?,
       imageLeftAligned: Bool = false
  ) {
    self.imageLeftAligned = imageLeftAligned
    self.button = button
    self.titleLabel.text = title
    self.textLabel.attributedText = text.attributedStringWith(lineHeightMultiplier: 1.25)
    if let img = imageName {
        self.imageView.image = UIImage(named: img)
    }
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
