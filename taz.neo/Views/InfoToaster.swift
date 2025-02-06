//
//  InfoToaster.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.05.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//


/**
 ***Ideas:**
 * any UIView can become a Toast with Info Toaster while implement its Protocoll
 * on show it appears as Popup/Popover on Topmost in current Apps Window
 
 ***UI/Size**
 * like PDF Lottie Toast
 * comes from Bottom, leaves to bottom
 * on mobile (compact ui) as full width
  otherwise as Popover with a max width of? 320px
 * centered vertically (optional pinned to bottom)
 * max height is windows height minus vertical insets
 * on rotation it adjusts
 * if content is larger a vertical Scroll view is used
 * close x has fixed pos
 *
 ***Lifecycle**
 * KISS ...as usual as possible
 *  Caller v = ToasterToastView() ... v.show...
 ** check if already displayed or layouted otherwise skip
 ** try not to request var or function implementation in implementing/using class!
 ** implementing cvlass just cares about its components/UI not the popup
 ** => dismiss is protocoll extension!
 *
 ***Difficult Implementation**
 * KISS ...use not a protocoll use a parent class
 * ToasterToastView > InfoToasterView > UIView
 ***Pro**
 *much simpler implementation
 ***Con**
 *not any UIView can be extended
 *
 *...so UI is Different to PDF Lottie
 */

import UIKit
import NorthLib

/// Helper to "toast" any view
/// will display view on top of current window with animation from bottom
class InfoToasterView: UIView{
  /// Closure will be called when dismissed
  fileprivate var dismissHandler: (()->())? = nil
  fileprivate var xButtonHandler: (()->())? = nil
  
  var hasCloseX: Bool = true { didSet { xButton.isHidden = !hasCloseX }}
  fileprivate var pinBottom: Bool = false { didSet { setPosition() }}
  
  // MARK: - Default Params
  var maxWidth: CGFloat
  = UIWindow.keyWindow?.traitCollection.horizontalSizeClass == .compact
  ? UIWindow.keyWindow?.frame.size.width ?? 380
  : 380

  // MARK: - LayoutConstrains
  fileprivate var scrollViewWidthConstraint : NSLayoutConstraint?
  fileprivate var scrollViewMaxHeightConstraint : NSLayoutConstraint?
  fileprivate var scrollViewYConstraint : NSLayoutConstraint?
  fileprivate var contentWidthConstraint : NSLayoutConstraint?
  
  // MARK: - UI Components
  fileprivate lazy var xButton: Button<ImageView> = {
    let xButton = Button<ImageView>()
    xButton.tazX()
    xButton.backgroundColor
    = Const.SetColor.ios_opaque(.closeXcircleBackground).color.withAlphaComponent(0.9)
    return xButton
  }()
  
  fileprivate lazy var wrapper: UIView = UIView()

  fileprivate lazy var shadeView: UIView = {
    var view = UIView()
    view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    return view
  }()
  
  
  fileprivate lazy var scrollView: UIScrollView  = {
    var view = UIScrollView()
    view.backgroundColor = Const.SetColor.CTBackground.color
    view.layer.cornerRadius = 12.0
    return view
  }()
  
  override func didMoveToWindow() {
    handleLayoutChange(newAppSize: wrapper.window?.frame.size ?? .zero)
    super.didMoveToWindow()
  }
  
  
  // MARK: - Init
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}

extension InfoToasterView {
  func show() {
    guard wrapper.superview == nil else {
      error("cannot show, already shown")
      return
    }
    ensureMain { [weak self] in
      guard let self = self,
            let delegate = UIApplication.shared.delegate,
            let window = delegate.window as? UIWindow else {
        self?.error("cannot show, either no app \(String(describing: UIApplication.shared.delegate)) or self already gone: \(String(describing: self))")
        return
      }
      shadeView.alpha = 0.0
      wrapper.isHidden = true
      window.addSubview(wrapper)
      pin(wrapper, to: window)
      scrollViewYConstraint?.constant = window.frame.size.height
      wrapper.doLayout()
      wrapper.isHidden = false
      showAnimated()
    }
  }
  
  func dismiss(){
    UIView.animate(withDuration: 0.7,
                   delay: 0,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.8,
                   options: UIView.AnimationOptions.curveEaseInOut,
                   animations: {
                    self.scrollViewYConstraint?.constant = UIWindow.size.height + 50
                    self.shadeView.alpha = 0.0
                    self.wrapper.layoutIfNeeded()
                   }, completion: { [weak self] _ in
                     self?.wrapper.removeFromSuperview()
                     self?.dismissHandler?()
                     self?.dismissHandler = nil
                     self?.xButtonHandler = nil
                     self?.scrollView.removeFromSuperview()
                     self?.removeFromSuperview()
                   })
  }
  
  /// define the closure to call when dismissed
  func onDismiss(closure: @escaping ()->()) { dismissHandler = closure }
  
  /// define the closure to call when x button tapped
  func onXButton(closure: @escaping ()->()) { xButtonHandler = closure }
}


fileprivate extension InfoToasterView {
  func showAnimated(){
    self.wrapper.bringToFront()
    
    UIView.animate(withDuration: 0.9,
                   delay: 0,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.8,
                   options: UIView.AnimationOptions.curveEaseInOut,
                   animations: {[weak self] in
      self?.shadeView.alpha = 1.0
      self?.updatePosition(toShow: true)
      self?.wrapper.layoutIfNeeded()
    }, completion: {[weak self] (_) in
      self?.wrapper.bringToFront()
    })
  }
  
  func setup(){
      setupUI()
      setupLayoutChange()
    xButton.onTapping {[weak self] _ in
      self?.xButtonHandler != nil
      ? self?.xButtonHandler?()
      : self?.dismiss()
    }
  }
  
  func setupUI(){
    guard self.superview == nil else { error("already a child!"); return }
    
    guard scrollViewMaxHeightConstraint == nil,
          scrollViewWidthConstraint == nil,
          scrollViewYConstraint == nil,
          contentWidthConstraint == nil else {
      error("already setup layout")
      return
    }

    wrapper.addSubview(shadeView)
    wrapper.addSubview(scrollView)
    scrollView.addSubview(self)
    scrollView.addSubview(xButton)
    
    pin(shadeView, to: wrapper)
    
    pin(xButton.right, to: scrollView.rightGuide(), dist: -Const.Size.DefaultPadding)
    pin(xButton.top, to: scrollView.topGuide(), dist: Const.Size.DefaultPadding)
    
    ///Layout Components
    let width = min(UIWindow.size.width, maxWidth)
    contentWidthConstraint = self.pinWidth(width)
    scrollViewWidthConstraint = scrollView.pinWidth(width)

    scrollViewMaxHeightConstraint = scrollView.pinHeight(0)
    pin(self, to: scrollView, priority: .fittingSizeLevel)
    
    setPosition()
    updatePosition(toShow: false)
  }
  func setPosition(){
    guard let sv = scrollView.superview else { return }
    self.scrollViewYConstraint?.isActive = false
    if pinBottom {
      self.scrollViewYConstraint = pin(scrollView.bottom, to: sv.bottom)
    }
    else {
      self.scrollViewYConstraint = scrollView.centerAxis().y
    }
  }
  func updatePosition(toShow:Bool){
    self.scrollViewYConstraint?.constant
    = toShow ? 0 : UIWindow.size.height + 50
  }
  
  
  func setupLayoutChange(){
    Notification.receive(Const.NotificationNames.viewSizeTransition) {   [weak self] notification in
      guard let self = self else { return }
      guard let newSize = notification.content as? CGSize else { return }
      handleLayoutChange(newAppSize: newSize)
    }
    Notification.receive(Const.NotificationNames.traitCollectionDidChange) {   [weak self] notification in
      guard let self = self else { return }
      guard let traitCollection = notification.content as? UITraitCollection else { return }
      self.pinBottom = traitCollection.horizontalSizeClass == .compact
      self.doLayout()
    }
    self.pinBottom = UIWindow.keyWindow?.traitCollection.horizontalSizeClass == .compact
  }

  
  func handleLayoutChange(newAppSize: CGSize){
    self.doLayout()
    self.scrollViewMaxHeightConstraint?.constant = min(newAppSize.height, self.frame.size.height)
    self.scrollViewWidthConstraint?.constant = min(newAppSize.width, maxWidth)
    self.contentWidthConstraint?.constant = min(newAppSize.width, maxWidth)
  }
  
  func resetConstraints() {
    
  }
}
