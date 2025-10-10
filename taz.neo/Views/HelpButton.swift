//
//  HelpButton.swift
//  taz.neo
//
//  Created by Ringo Müller on 10.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

class HelpButton: UIView {
  
  @Default("showHelp")
  public var showHelp: Bool
  
  @Default("helpUsedOnce")
  public var helpUsedOnce: Bool
  
  private var bottomConstraint: NSLayoutConstraint?
  
  private lazy var badgeLabel: UILabel = {
    let lbl = UILabel()
    lbl.pinSize(CGSize(width: 16, height: 16))
    lbl.layer.cornerRadius = 8.0
    lbl.clipsToBounds = true
    lbl.contentFont(size: 8.5)
    lbl.textColor = .white
    lbl.textAlignment = .center
    lbl.backgroundColor = .systemRed
    lbl.isHidden = true
    return lbl
  }()
  
  public var badgeValue: Int = 0 {
    didSet {
      badgeLabel.text = "\(badgeValue)"
      if badgeValue > 0 {
        badgeLabel.isHidden = false
        startAnimation()
      }
      else {
        badgeLabel.isHidden = true
        removeAnimation()
      }
    }
  }
  
  private var onTapHelpHandler: (() -> ())?
  
  // MARK: - onClose/onCloseHandler
  public func onTapHelp(closure: (() -> ())?) {
    self.onTapHelpHandler = closure
  }
  
  func handleTap() {
    if helpUsedOnce == false {
      helpLabel.removeFromSuperview()
      bottomConstraint?.constant = 0.0
    }
    onTapHelpHandler?()
  }
  
  private lazy var helpIconImageView: UIImageView = {
    let iv = UIImageView(image: UIImage(named: "tooltip"))
    iv.pinSize(CGSize(width: 32, height: 32))
    iv.contentMode = .scaleAspectFit
    iv.tintColor = Const.Colors.appIconGrey
    iv.backgroundColor = Const.Colors.darkPrimaryBG
    iv.layer.cornerRadius = 16.0
    iv.onTapping { [weak self] _ in self?.handleTap() }
    return iv
  }()
  
  private lazy var helpLabel: UIView = {
    let wrapper = UIView()
    let lbl = UILabel("Hilfe")
    lbl.contentFont(size: Const.Size.SmallerFontSize)
    lbl.textColor = Const.Colors.appIconGrey
    lbl.textAlignment = .center
    wrapper.backgroundColor = Const.Colors.darkPrimaryBG
    wrapper.layer.cornerRadius = 4.0
    wrapper.addSubview(lbl)
    pin(lbl.top, to: wrapper.top, dist: 0.0)
    pin(lbl.right, to: wrapper.right, dist: -4.0)
    pin(lbl.left, to: wrapper.left, dist: 4.0)
    pin(lbl.bottom, to: wrapper.bottom, dist: 0.0)
    wrapper.onTapping { [weak self] _ in self?.handleTap() }
    return wrapper
  }()
  
  func setupIfNeeded() {
    guard helpIconImageView.superview == nil else { return }
    self.accessibilityLabel = "Hilfe anzeigen"
    self.addSubview(helpIconImageView)
    self.addSubview(badgeLabel)
    
    bottomConstraint = pin(helpIconImageView, to: self).bottom
    
    if helpUsedOnce == false {
      bottomConstraint?.constant = -20.0//helpLabelWrapperHeight+dist
      self.addSubview(helpLabel)
      pin(helpLabel.top, to: helpIconImageView.bottom, dist: 2.0)
    }
    
    pin(badgeLabel.top, to: self.top, dist: -7.0)
    pin(badgeLabel.right, to: self.right, dist: 7.0)
  }
  
  private func removeAnimation() {
    helpIconImageView.layer.removeAllAnimations()
  }
  
  private func startAnimation() {
    if helpIconImageView.layer.animationKeys()?.count ?? 0 > 0 { return }
    UIView.animateKeyframes(withDuration: 7.0,
                            delay: 0,
                            options: [.repeat, .allowUserInteraction],
                            animations: {
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) {
        self.helpIconImageView.tintColor = .white.withAlphaComponent(0.9)
      }
      UIView.addKeyframe(withRelativeStartTime: 0.51, relativeDuration: 0.48) {
        self.helpIconImageView.tintColor = Const.Colors.appIconGrey
      }
    },
                            completion: nil)
  }
  
  override func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)
    setupIfNeeded()
  }
}
