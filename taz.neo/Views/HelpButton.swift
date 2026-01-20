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
      badgeLabel.isHidden = badgeValue <= 0
    }
  }
  
  private var onTapHelpHandler: (() -> ())?
  
  // MARK: - onClose/onCloseHandler
  public func onTapHelp(closure: (() -> ())?) {
    self.onTapHelpHandler = closure
  }
  
  private var onDisableCurrentHelpClosure: (() -> ())?
  
  // MARK: - onClose/onCloseHandler
  public func onDisableCurrentHelp(closure: (() -> ())?) {
    self.onDisableCurrentHelpClosure = closure
  }
  
  func handleTap() {
    helpUsedOnce = true
    onTapHelpHandler?()
  }
  
  var buttonContextMenu: ContextMenu?
  
  lazy var helpIconImageView: UIView = {
    let wrapper = UIView()
    wrapper.pinSize(CGSize(width: 48, height: 48))
    wrapper.layer.cornerRadius = 24.0
    wrapper.backgroundColor = Const.Colors.fabBackground
    let iv = UIImageView(image: UIImage(named: "tooltip2"))
    iv.pinSize(CGSize(width: 17, height: 17))
    iv.contentMode = .scaleAspectFit
    iv.tintColor = Const.Colors.appIconGrey

    wrapper.addSubview(iv)
    iv.centerX()
    iv.centerY(dist: -4.0)
    wrapper.onTapping { [weak self] _ in self?.handleTap() }
    buttonContextMenu = ContextMenu(view: iv, title: "Hilfe ausblenden\nDie Hilfe kann jederzeit in den Einstellungen wieder aktiviert werden.")
    buttonContextMenu?.addMenuItem(title: "Hilfe in diesem Bereich ausblenden", icon: "", closure: {[weak self] _ in
      self?.onDisableCurrentHelpClosure?()
    })
    buttonContextMenu?.addMenuItem(title: "Hilfe überall ausblenden", icon: "", closure: { [weak self] _ in
      self?.showHelp = false
      Notification.send(Const.NotificationNames.helpProviderChanged)
    })
    return wrapper
  }()
  
  private lazy var helpLabel: UIView = {
    let lbl = UILabel("Hilfe")
    lbl.isAccessibilityElement = false
    lbl.contentFont(size: 10.5)
    lbl.textColor = Const.Colors.appIconGrey
    lbl.textAlignment = .center
    return lbl
  }()
  
  func setupIfNeeded() {
    guard helpIconImageView.superview == nil else { return }
    self.addSubview(helpIconImageView)
    self.addSubview(badgeLabel)
    
    badgeLabel.isAccessibilityElement = false
    helpLabel.isAccessibilityElement = false
    helpIconImageView.isAccessibilityElement = true
    helpIconImageView.accessibilityLabel = "Hilfe anzeigen"
    helpIconImageView.accessibilityTraits = .button
    
    let bottomConstraint = pin(helpIconImageView, to: self).bottom
    
    if helpUsedOnce == false {
      bottomConstraint.constant = -20.0//helpLabelWrapperHeight+dist
      self.addSubview(helpLabel)
      helpLabel.centerX()
      pin(helpLabel.bottom, to: helpIconImageView.bottom, dist: -3.0)
      onMainAfter(2.0) {[weak self] in
        self?.helpIconImageView.animateFocus()
      }
      onMainAfter(8.0) {[weak self] in
        guard self?.helpUsedOnce == false else { return }
        self?.helpIconImageView.animateFocus()
      }
    }
    pin(badgeLabel.top, to: self.top, dist: 0.0)
    pin(badgeLabel.right, to: self.right, dist: -0.0)
  }
  
  override func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)
    setupIfNeeded()
  }
}
