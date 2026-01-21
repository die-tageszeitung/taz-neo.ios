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
    lbl.textColor = .black
    lbl.textAlignment = .center
    lbl.backgroundColor = Const.Colors.appIconGrey
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
  
 
  lazy var helpIconImageWrapper: UIView = {
    let wrapper = UIView()
    wrapper.pinSize(CGSize(width: 50, height: 50))
    wrapper.backgroundColor = Const.Colors.fabBackground.withAlphaComponent(0.8)
    let iv = UIImageView(image: UIImage(named: "tooltip"))
    iv.pinSize(CGSize(width: 28, height: 28))
    iv.layer.cornerRadius = 14.0
    iv.contentMode = .scaleAspectFill
    iv.tintColor = Const.Colors.appIconGrey
    wrapper.addSubview(iv)
    wrapper.layer.cornerRadius = 25.0
    iv.centerAxis()
    wrapper.onTapping { [weak self] _ in self?.handleTap() }
    buttonContextMenu = ContextMenu(view: wrapper, title: "Hilfe ausblenden\nDie Hilfe kann jederzeit in den Einstellungen wieder aktiviert werden.")
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
    lbl.contentFont(size: 9.5)
    lbl.textColor = Const.Colors.appIconGrey
    lbl.textAlignment = .center
    return lbl
  }()
  
  func setupIfNeeded() {
    guard helpIconImageWrapper.superview == nil else { return }
    self.addSubview(helpIconImageWrapper)
    self.addSubview(badgeLabel)
    
    badgeLabel.isAccessibilityElement = false
    helpLabel.isAccessibilityElement = false
    helpIconImageWrapper.isAccessibilityElement = true
    helpIconImageWrapper.accessibilityLabel = "Hilfe anzeigen"
    helpIconImageWrapper.accessibilityTraits = .button
    
    pin(helpIconImageWrapper, to: self)
    
    if helpUsedOnce == false {
      self.addSubview(helpLabel)
      helpLabel.centerX()
      pin(helpLabel.bottom, to: helpIconImageWrapper.bottom, dist: -0.5)
      onMainAfter(2.0) {[weak self] in
        self?.helpIconImageWrapper.animateFocus()
      }
      onMainAfter(8.0) {[weak self] in
        guard self?.helpUsedOnce == false else { return }
        self?.helpIconImageWrapper.animateFocus()
      }
    }
    pin(badgeLabel.top, to: self.top, dist: 1.0)
    pin(badgeLabel.right, to: self.right, dist: -1.0)
  }
  
  override func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)
    setupIfNeeded()
  }
}
