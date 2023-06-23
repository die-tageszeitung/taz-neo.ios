//
//  ArticlePlayerUI.swift
//  taz.neo
//
//  Created by Ringo Müller on 23.06.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class ArticlePlayerUI: UIView {
  
  var image: UIImage? {
    didSet {
      bgImageView.image = image
      imageView.image = image
      if image == nil {
        imageAspectConstraint?.isActive = false
        imageWidthConstraint?.isActive = true
        imageLeftConstraint?.constant = 0.0
      }
      else {
        imageWidthConstraint?.isActive = false
        imageAspectConstraint?.isActive = false
//        imageAspectConstraint = imageView.pinAspect(ratio: 1.0)
        imageLeftConstraint?.constant = Const.Size.DefaultPadding
      }
      UIView.animate(withDuration: 0.3) {[weak self] in
        self?.layoutIfNeeded()
      }
    }
  }
  
  private var backClosure: (()->())?
  private var forwardClosure: (()->())?
  private var toggleClosure: (()->())?
  private var closeClosure: (()->())?
  
  func onBack(closure: @escaping ()->()) {
    backClosure = closure
  }
  
  func onForward(closure: @escaping ()->()){
    forwardClosure = closure
  }
  
  func onToggle(closure: @escaping ()->()){
    toggleClosure = closure
  }
  
  func onClose(closure: @escaping ()->()){
    closeClosure = closure
  }
  
  private lazy var imageView: UIImageView = {
    let v = UIImageView()
    v.clipsToBounds = true
    v.onTapping(closure: { [weak self] _ in self?.maximize() })
    return v
  }()
  
  private lazy var bgImageView: UIImageView = UIImageView()
  private let blurredEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
  
  lazy var titleLabel: UILabel = {
    let lbl = UILabel()
    lbl.numberOfLines = 0
    lbl.boldContentFont().white()
    lbl.onTapping(closure: { [weak self] _ in self?.maximize() })
    return lbl
  }()
  
  lazy var authorLabel: UILabel = {
    let lbl = UILabel()
    lbl.contentFont(size: Const.Size.SmallerFontSize).white()
    lbl.numberOfLines = 0
    lbl.onTapping(closure: { [weak self] _ in self?.maximize() })
    return lbl
  }()
  
  lazy var elapsedTimeLabel: UILabel
  = UILabel().contentFont(size: 9.0).white()
  
  lazy var remainingTimeLabel: UILabel
  = UILabel().contentFont(size: 9.0).white()
  
  lazy var closeButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in
      self?.removeFromSuperview()
      self?.closeClosure?()
    }
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "xmark"
    return btn
  }()
  
  lazy var slider: UISlider = {
    let slider = UISlider()
    let thumb = UIImage.circle(diam: 8.0, color: .white)
    slider.setThumbImage(thumb, for: .normal)
    slider.setThumbImage(thumb, for: .highlighted)
    slider.minimumTrackTintColor = .white
    return slider
  }()
  
  
  lazy var minimizeButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.minimize() }
    btn.pinSize(CGSize(width: 38, height: 38))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "chevron.down"
    return btn
  }()
  
  lazy var toggleButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.toggleClosure?() }
    btn.pinSize(CGSize(width: 36, height: 36))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "pause.fill"
    return btn
  }()
  
  var isPlaying: Bool = false {
    didSet {
      toggleButton.buttonView.symbol = isPlaying ? "pause.fill" : "play.fill"
    }
  }
  
  lazy var backButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.backClosure?() }
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "backward.fill"
    //btn.buttonView.symbol = "gobackward.15"
    return btn
  }()
  
  var backButtonEnabled = true {
    didSet {
      backButton.isEnabled = backButtonEnabled
      backButton.alpha = backButtonEnabled ? 1.0 : 0.5
    }
  }
  var forwardButtonEnabled = true {
    didSet {
      forwardButton.isEnabled = forwardButtonEnabled
      forwardButton.alpha = forwardButtonEnabled ? 1.0 : 0.5
    }
  }
  
  lazy var forwardButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.forwardClosure?() }
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "forward.fill"
    //btn.buttonView.symbol = "goforward.15"
    return btn
  }()
  
  func show(){
    if self.superview != nil {
      error("already displayed")
      return
    }
    guard let window = UIWindow.keyWindow else {
      error("No Key Window")
      return
    }
    window.addSubview(self)
    pin(self.right, to: window.rightGuide(), dist: -Const.Size.DefaultPadding)
    pin(self.bottom, to: window.bottomGuide(), dist: -60.0)
  }
  
  
  func minimize(){
    ///ignore if min not needed
  }
  
  func maximize(){
    ///ignore if max
    print("maximize...")
  }
  
  func setup2(){
    self.addSubview(bgImageView)
    self.addSubview(imageView)
    self.addSubview(titleLabel)
    self.addSubview(authorLabel)
    self.addSubview(closeButton)
    self.addSubview(minimizeButton)
    self.addSubview(slider)
    self.addSubview(imageView)
    self.addSubview(toggleButton)
    
    slider.isHidden = true
    minimizeButton.isHidden = true
    
    self.layer.cornerRadius = 5.0 //max: 13.0
    
    pin(bgImageView, to: imageView)
    
    let cSet = pin(imageView, to: self, dist: Const.Size.DefaultPadding, exclude: .right)
    imageLeftConstraint = cSet.left
    
    imageWidthConstraint = imageView.pinWidth(1)
    imageWidthConstraint?.isActive = false
    
    imageAspectConstraint = imageView.pinAspect(ratio: 0.0, pinWidth: true)
    imageView.contentMode = .scaleAspectFill
    
    pin(titleLabel.top, to: imageView.top, dist: -1.0)
    pin(authorLabel.bottom, to: imageView.bottom)
    
    pin(titleLabel.left, to: imageView.right, dist: Const.Size.DefaultPadding)
    pin(authorLabel.left, to: imageView.right, dist: Const.Size.DefaultPadding)
    
    pin(closeButton, to: self, dist: 14.0, exclude: .left)
    closeButton.pinAspect(ratio: 1.0)
    
    pin(toggleButton.centerY, to: closeButton.centerY)
    pin(toggleButton.right, to: closeButton.left, dist: -22.0)
    
    pin(titleLabel.right, to: toggleButton.left, dist: -22.0)
    pin(authorLabel.right, to: toggleButton.left, dist: -22.0)
    
    titleLabel.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    authorLabel.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    
    self.backgroundColor = Const.Colors.darkSecondaryBG
    self.pinHeight(50)
    widthConstraint = self.pinWidth(200)
    self.updateWidth()
    
    Notification.receive(Const.NotificationNames.viewSizeTransition) {   [weak self] notification in
      guard let newSize = notification.content as? CGSize else { return }
      self?.updateWidth(width: newSize.width)
    }
    
    /**
     backward.fill
     forward.fill
     
     list.bullet   mit 5px padding corner radius ca 5px if list open
     
     
     */
    
  }
  
  func setup(){
    self.addSubview(bgImageView)
    self.addSubview(blurredEffectView)
    self.addSubview(imageView)
    self.addSubview(titleLabel)
    self.addSubview(authorLabel)
    self.addSubview(closeButton)
    self.addSubview(minimizeButton)
    self.addSubview(slider)
    self.addSubview(remainingTimeLabel)
    self.addSubview(elapsedTimeLabel)
    self.addSubview(imageView)
    self.addSubview(toggleButton)
    self.addSubview(backButton)
    self.addSubview(forwardButton)
    
    self.layer.cornerRadius = 13.0
    
    let padding = Const.Size.DefaultPadding
    
    pin(minimizeButton.top, to: self.top, dist: 1.0)
    pin(minimizeButton.right, to: self.right, dist: -padding + 8.0)
    
    pin(imageView.left, to: self.left, dist: padding)
    pin(imageView.right, to: self.right, dist: -padding)
    pin(imageView.top, to: minimizeButton.bottom, dist: 1.0)

    //Aspect and hight is critical e.g. tv tower vs panorama
    imageView.pinAspect(ratio: 1.5, pinWidth: false)
    imageView.contentMode = .scaleAspectFit
    bgImageView.contentMode = .scaleToFill
    
    pin(bgImageView, to: imageView)
    pin(blurredEffectView, to: imageView)
    
    pin(titleLabel.left, to: self.left, dist: padding)
    pin(titleLabel.right, to: self.right, dist: -padding)
    pin(titleLabel.top, to: imageView.bottom, dist: padding)

    pin(authorLabel.left, to: self.left, dist: padding)
    pin(authorLabel.right, to: self.right, dist: -padding)
    pin(authorLabel.top, to: titleLabel.bottom, dist: 2.0)
    
    pin(slider.left, to: self.left, dist: padding)
    pin(slider.right, to: self.right, dist: -padding)
    pin(slider.top, to: authorLabel.bottom, dist: padding)
    
    pin(elapsedTimeLabel.top, to: slider.bottom, dist: 4.0)
    pin(remainingTimeLabel.top, to: slider.bottom, dist: 4.0)
    pin(elapsedTimeLabel.left, to: self.left, dist: padding)
    pin(remainingTimeLabel.right, to: self.right, dist: -padding)
    pin(remainingTimeLabel.left, to: elapsedTimeLabel.right, dist: padding, priority: .defaultLow)
    
    remainingTimeLabel.textAlignment = .right
    
    elapsedTimeLabel.text = "2:30"
    remainingTimeLabel.text = "-2:30"
    
    toggleButton.centerX()
    pin(toggleButton.top, to: slider.bottom, dist: padding + 5.0)
    pin(toggleButton.bottom, to: self.bottom, dist: -padding)

    pin(backButton.right, to: toggleButton.left, dist: -30.0)
    pin(forwardButton.left, to: toggleButton.right, dist: 30.0)
    
    pin(backButton.centerY, to: toggleButton.centerY)
    pin(forwardButton.centerY, to: toggleButton.centerY)
    
    self.backgroundColor = Const.Colors.darkSecondaryBG
    widthConstraint = self.pinWidth(200)
    self.updateWidth()
    
    Notification.receive(Const.NotificationNames.viewSizeTransition) {   [weak self] notification in
      guard let newSize = notification.content as? CGSize else { return }
      self?.updateWidth(width: newSize.width)
    }
    
    /**

     
     list.bullet   mit 5px padding corner radius ca 5px if list open
     
     
     */
    
  }
  
  
  var widthConstraint: NSLayoutConstraint?
  var imageWidthConstraint: NSLayoutConstraint?
  var imageLeftConstraint: NSLayoutConstraint?
  var imageAspectConstraint: NSLayoutConstraint?
  
  func updateWidth(width:CGFloat = UIWindow.keyWindow?.bounds.size.width ?? UIScreen.shortSide){
    widthConstraint?.constant = min(300, width - 2*Const.Size.DefaultPadding)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

