//
//  StartupView.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A StartupView simply shows some content and allows "some" animation
/// of this content
public protocol StartupView where Self: UIView {
  var isAnimating: Bool { get set }
}

/// A SpinnerView show a Spinner on a black (by default) background
public class SpinnerStartupView: UIView, StartupView {
  
  private var spinner = UIActivityIndicatorView()
  public var isAnimating: Bool {
    get { return spinner.isAnimating }
    set {
      if newValue { 
        self.isHidden = false
        spinner.startAnimating() 
      } 
      else { 
        spinner.stopAnimating() 
        self.isHidden = true
      }
    }
  }
  
  private func setup() {
    if #available(iOS 13, *) { 
      spinner.style = .large 
      spinner.color = .white
    }
    else { spinner.style = .whiteLarge }
    spinner.hidesWhenStopped = true
    addSubview(spinner)
    pin(spinner.centerX, to: self.centerX)
    pin(spinner.centerY, to: self.centerY)
    self.bringSubviewToFront(spinner)
    self.backgroundColor = .black
    self.isAnimating = false
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

} // SpinnerStartupView

/// This StatupView shows the taz logo which shrinks/expands when the animation
/// is switched on
class LogoStartupView: UIView, StartupView {
  
  private var startupLogo: UIImage?
  private var imageView: UIImageView?
  
  private var widthConstraint: NSLayoutConstraint?
  private var heightConstraint: NSLayoutConstraint?
  
  private var animationTimer: Timer?
  public var isAnimating: Bool = false {
    didSet { 
      if isAnimating { 
        self.isHidden = false
        animate() 
      } 
      else { 
        self.isHidden = true
        animationTimer?.invalidate() 
      }
    }
  }
  
  private func setup() {
    startupLogo = UIImage(named: "StartupLogo")
    imageView = UIImageView(image: startupLogo)
    backgroundColor = AppColors.tazRot
    if let iv = imageView {
      addSubview(iv)
      pin(iv.centerX, to: self.centerX)
      pin(iv.centerY, to: self.centerY)
      pinSize(factor: 0.3)
    }
    isAnimating = false
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
