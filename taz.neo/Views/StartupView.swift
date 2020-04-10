//
//  StartupView.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

let TazRot = UIColor.rgb(0xd50d2e)

class StartupView: UIView {
  
  private var startupLogo: UIImage?
  private var imageView: UIImageView?
  
  private var widthConstraint: NSLayoutConstraint?
  private var heightConstraint: NSLayoutConstraint?
  
  private var animationTimer: Timer?
  public var isAnimating: Bool = false {
    didSet { 
      if isAnimating { animate() } 
      else { animationTimer?.invalidate() }
    }
  }
  public var showLogo: Bool = true {
    didSet {
      if showLogo { imageView?.isHidden = false }
      else {
        isAnimating = false
        imageView?.isHidden = true
      }
    }
  }
  
  private func setup() {
    startupLogo = UIImage(named: "StartupLogo")
    imageView = UIImageView(image: startupLogo)
    backgroundColor = TazRot
    if let iv = imageView {
      addSubview(iv)
      pin(iv.centerX, to: self.centerX)
      pin(iv.centerY, to: self.centerY)
      pinSize(factor: 0.3)
    }
  }
  
  func pinSize(factor: CGFloat = 1) {
    if let size = startupLogo?.size, let iv = self.imageView {
      if let con = widthConstraint { con.isActive = false }
      if let con = heightConstraint { con.isActive = false }
      widthConstraint = iv.pinWidth(size.width*factor)
      heightConstraint = iv.pinHeight(size.height*factor)
    }
  }
  
  func animateSize(seconds: Double, to: CGFloat, atEnd: (()->())? = nil) {
    UIView.animate(withDuration: seconds, delay: 0, options: .curveEaseOut, 
      animations: { [weak self] in
      guard let this = self else { return }
      this.pinSize(factor: to)
      this.layoutIfNeeded()
    }) { _ in if let closure = atEnd { closure() } }
  }
  
  func animateOnce(seconds: Double) {
    animateSize(seconds: seconds, to: 1) { [weak self] in
      self?.animateSize(seconds: seconds, to: 0.3)
    }
  }
  
  func animate(seconds: Double = 1) {
    animationTimer = Timer.scheduledTimer(withTimeInterval: 2*seconds + 0.001, repeats: true) 
    { [weak self] timer in
      if let self = self, self.isAnimating {
        onMain { self.animateOnce(seconds: seconds) }
        return
      }
      timer.invalidate()
    }
    delay(seconds: 0.1) { self.animateOnce(seconds: seconds - 0.1) }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
}
