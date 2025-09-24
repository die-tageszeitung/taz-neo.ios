//
//  FloatingPanelContentView.swift
//  taz.neo
//
//  Created by Ringo Müller on 18.09.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

class FloatingPanelContentView: UIView {
  
  var confirmText: String?
  var declineText: String?
  
  var hasOptions: Bool {
    return confirmText != nil && declineText != nil
  }
  
  // MARK: - Layout
  var padding: CGFloat = 9.0
  var rightPadding: CGFloat = 9.0
  
  lazy var imageView: UIImageView = {
    let v = UIImageView()
    v.pinHeight(32.0, priority: .required)
    v.pinAspect(ratio: 1.0)
    v.clipsToBounds = true
    return v
  }()
  
  lazy var topLabel: UILabel = {
    let lbl = UILabel()
    lbl.contentFont(size: 13)
    lbl.text = "Weiterlesen:"
    return lbl
  }()
  
  lazy var bottomLabel: UILabel = {
    let lbl = UILabel()
    lbl.numberOfLines = 0
    lbl.boldContentFont(size: 13)
    return lbl
  }()
  
  lazy var confirmLabel: UILabel = {
    let lbl = UILabel()
    lbl.tazPrimaryButtonStyle()

    return lbl
  }()
  
  lazy var declineLabel: UILabel = {
    let lbl = UILabel()
    lbl.tazSecondaryButtonStyle()
    return lbl
  }()
  
  func setup() {
    addSubview(topLabel)
    addSubview(bottomLabel)
    addSubview(imageView)
    setupButtons()
    pin(imageView.top, to: top, dist: padding)
    pin(imageView.left, to: left, dist: padding)
    
    pin(topLabel.top, to: top, dist: padding)
    pin(bottomLabel.top, to: topLabel.bottom, dist: 2.0)
    
    let leftAnchor = imageView.image == nil ? left : imageView.right
    
    pin(topLabel.left, to: leftAnchor, dist: padding)
    pin(bottomLabel.left, to: leftAnchor, dist: padding)
    
    pin(topLabel.right, to: right, dist: -rightPadding )
    pin(bottomLabel.right, to: right, dist: -rightPadding)
    
    let bottomView = declineLabel.superview != nil ? declineLabel : bottomLabel
    pin(bottomView.bottom, to: bottom, dist: -padding)
  }
  
  func setupButtons(){
    guard let confirmText = confirmText,
          let declineText = declineText else { return }
    confirmLabel.text = confirmText
    declineLabel.text = declineText
    addSubview(confirmLabel)
    addSubview(declineLabel)
    pin(confirmLabel.top, to: bottomLabel.bottom, dist: padding)
    pin(declineLabel.top, to: confirmLabel.bottom, dist: padding)
    
    pin(confirmLabel.left, to: left, dist: padding)
    pin(declineLabel.left, to: left, dist: padding)
    
    pin(confirmLabel.right, to: right, dist: -padding)
    pin(declineLabel.right, to: right, dist: -padding)
  }
}


fileprivate extension UILabel {
  
  private static var btnHeight = 30.0
  
  func tazPrimaryButtonStyle() {
    self.boldContentFont(size: Const.Size.SmallerFontSize)
    self.textColor = .white
    self.textAlignment = .center
    self.numberOfLines = 1
    self.layer.cornerRadius = Self.btnHeight/2 + 1.0
    self.layer.masksToBounds = true
    self.layer.borderColor = UIColor.white.cgColor
    self.layer.borderWidth = 1
    self.backgroundColor = .black
    self.pinHeight(Self.btnHeight + 2.0)
  }
  
  func tazSecondaryButtonStyle() {
    self.contentFont(size: Const.Size.SmallerFontSize)
    self.textColor = .black
    self.textAlignment = .center
    self.numberOfLines = 1
    self.layer.cornerRadius = Self.btnHeight/2
    self.layer.masksToBounds = true
    self.layer.borderColor = UIColor.black.cgColor
    self.layer.borderWidth = 1
    self.backgroundColor = .white
    self.pinHeight(Self.btnHeight)
  }
}
