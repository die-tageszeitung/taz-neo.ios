//
//  ArticlePlayerUI.swift
//  taz.neo
//
//  Created by Ringo Müller on 23.06.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

enum ArticlePlayerUIStates { case mini, maxi, tracklist}

class ArticlePlayerUI: UIView {
      
  var acticeTargetView: UIView? {
    didSet {
      if self.superview == nil { return }
      if acticeTargetView == oldValue { return }
      minimize()
      if acticeTargetView == nil {
        self.removeFromSuperview()
        onMainAfter {[weak self] in self?.addAndShow(animated: true) }
      } else {
        addAndShow(animated: true)
      }
    }
  }
    
  var bottomConstraint: NSLayoutConstraint?
  var rightConstraint: NSLayoutConstraint?
  
  
  func updateWidth(doLayout: Bool = true){
    
    let noGap = traitCollection.horizontalSizeClass == .compact && state == .maxi
    
    let w
    = noGap
    ? viewSize.width
    : min(375, viewSize.width - 2*Const.Size.DefaultPadding)
    if widthConstraint == nil {
      widthConstraint = self.pinWidth(w)
    }
    else {
      widthConstraint?.constant = w
    }
    
    if noGap {
      self.layer.cornerRadius = 0.0
    }
    
    rightConstraint?.constant
    = noGap
    ? 0
    : -Const.Size.DefaultPadding
    if acticeTargetView != nil {
      ///probably tollbar
      bottomConstraint?.constant = noGap ? -0.5 : -10
    }
    else {
      //probably tabbar => pinned to window
      bottomConstraint?.constant = noGap ? 5.0 : -60
    }

    if doLayout { self.superview?.layoutIfNeeded() }
  }
  
  var viewSize: CGSize = .zero {
    didSet {
      if oldValue.width == viewSize.width { return }
      updateWidth()
    }
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if self.traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
      updateWidth()
    }
  }
  
  private func addAndShow(animated:Bool){
    guard let targetSv
            = acticeTargetView?.superview
            ?? UIWindow.keyWindow else { return }
    self.removeFromSuperview()
    if let acticeTargetView = acticeTargetView, targetSv == acticeTargetView.superview {
      targetSv.insertSubview(self, belowSubview: acticeTargetView)
      bottomConstraint = pin(self.bottom, to: acticeTargetView.top, dist:  -10.0)
    }
    else {
      targetSv.addSubview(self)
      bottomConstraint = pin(self.bottom, to: targetSv.bottomGuide(), dist:  -60.0)
    }
    rightConstraint = pin(self.right, to: targetSv.rightGuide(), dist: -Const.Size.DefaultPadding)
    viewSize = targetSv.frame.size
    self.updateWidth()
    if animated == false  { return }
    UIView.animate(withDuration: 0.6) {
      targetSv.layoutIfNeeded()
    }
  }
  
  func show(){
    if self.superview != nil {
      error("already displayed")
      return
    }
    
    acticeTargetView
    = (((TazAppEnvironment.sharedInstance.rootViewController as? MainTabVC)?
      .selectedViewController as? UINavigationController)?
      .visibleViewController as? ContentVC)?.toolBar
    addAndShow(animated: false)
    updateUI()
  }
  
  var currentSeconds: Double? {
    didSet {
      if oldValue ?? 0.0 > currentSeconds ?? 0.0 {progressCircle.reset()}
      ///expect 60s als default, every 60s there is one round/graph fill ...like the default clock
      let total = (totalSeconds ?? 60) > 0 ? (totalSeconds ?? 60.0) : 60.0
      let current = currentSeconds ?? 0.0
      let percent = min(1.0, current/total)
      slider.value = Float(percent)
      progressCircle.progress = Float(percent)
      self.elapsedTimeLabel.text = TimeInterval(current).minuteSecondsString
      let remaining = total-current
      self.remainingTimeLabel.text = "-\(TimeInterval(remaining).minuteSecondsString ?? "")"
    }
  }
  var totalSeconds: Double?
  
  // MARK: - Closures
  private var toggleClosure: (()->())?
  private var closeClosure: (()->())?
    
  func onToggle(closure: @escaping ()->()){
    toggleClosure = closure
  }
  
  func onClose(closure: @escaping ()->()){
    closeClosure = closure
  }
  
  // MARK: - external accessible components
  
  // MARK: - Image/ImageView
  var image: UIImage? {
    didSet {
      if image == oldValue { return }
      bgImageView.image = image?.withRenderingMode(.alwaysTemplate).blurred
      imageView.image = image
      updateUI()
    }
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
    btn.pinSize(CGSize(width: 38, height: 38))
    btn.hinset = 0.1//20%
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.name = "close"
    return btn
  }()
  
  lazy var slider: UISlider = {
    let slider = UISlider()
    let thumb = UIImage.circle(diam: 12.0, color: .white)
    let thumbH = UIImage.circle(diam: 12.0, color: .lightGray)
    slider.setThumbImage(thumb, for: .normal)
    slider.setThumbImage(thumbH, for: .highlighted)
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
    toggleSizeConstrains = btn.pinSize(CGSize(width: 30, height: 30))
    btn.activeColor = .white
//    btn.hinset = 0.17
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.name = "pause"
    
    btn.layer.addSublayer(progressCircle)
    progressCircle.color = Const.Colors.appIconGreyActive
    progressCircle.isDownloadButtonItem = false
    progressCircle.frame = CGRect(x: -3, y: -3, width: 36, height: 36)
    return btn
  }()
  
  var isPlaying: Bool = false {
    didSet {
      toggleButton.buttonView.name = isPlaying ? "pause" : "play"
    }
  }
  
  /**
BULLET LIST BUTTON MISSING
   list.bullet   mit 5px padding corner radius ca 5px if list open
   */
  
  lazy var backButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.name = "backward"
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
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.name = "forward"
    return btn
  }()
  
  lazy var progressCircle = ProgressCircle()
  
  func minimize(){ state = .mini }
  
  func maximize(){ state = .maxi }
  
  var heightConstraint: NSLayoutConstraint?
  var widthConstraint: NSLayoutConstraint?//Only for viewSizeTransition not for state changes!

  var imageSizeConstrains: (width: NSLayoutConstraint,
                            height: NSLayoutConstraint)?
  
  var imageConstrains: (top: NSLayoutConstraint,
                        bottom: NSLayoutConstraint,
                        left: NSLayoutConstraint,
                        right: NSLayoutConstraint)?
  var toggleSizeConstrains: (width: NSLayoutConstraint,
                             height: NSLayoutConstraint)?
  
  var authorLabelBottomConstraint_Mini: NSLayoutConstraint?
  var authorLabelTopConstraint_Maxi: NSLayoutConstraint?
  var closeButtonLeftConstraint_Mini: NSLayoutConstraint?
  var imageAspectConstraint_Maxi: NSLayoutConstraint?
  var imageAspectConstraint_Mini: NSLayoutConstraint?
  var titleLabelLeftConstraint_Maxi: NSLayoutConstraint?
  var titleLabelLeftConstraint_Mini: NSLayoutConstraint?
  var titleLabelRightConstraint_Maxi: NSLayoutConstraint?
  var titleLabelRightConstraint_Mini: NSLayoutConstraint?
  var titleLabelTopConstraint_Maxi: NSLayoutConstraint?
  var titleLabelTopConstraint_Mini: NSLayoutConstraint?
  var toggleButtonBottomConstraint_Maxi: NSLayoutConstraint?
  var toggleButtonTopConstraint_Maxi: NSLayoutConstraint?
  var toggleButtonXConstraint_Maxi: NSLayoutConstraint?
  var toggleButtonYConstraint_Mini: NSLayoutConstraint?

  
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
    self.addSubview(toggleButton)
    self.addSubview(backButton)
    self.addSubview(forwardButton)
    
    //Mini Player Base UI
    pin(bgImageView, to: imageView)
    imageConstrains = pin(imageView, to: self, dist: Const.Size.DefaultPadding)
    
    imageConstrains?.top.isActive = false
    imageConstrains?.left.isActive = false
    imageConstrains?.right.isActive = false
    imageConstrains?.bottom.isActive = false
    imageSizeConstrains = imageView.pinSize(CGSize(width: 1, height: 1))
    imageSizeConstrains?.height.isActive = false
    imageSizeConstrains?.width.isActive = false
                
    imageAspectConstraint_Mini = imageView.pinAspect(ratio: 1.0)
    imageAspectConstraint_Mini?.isActive = false
    imageAspectConstraint_Maxi = imageView.pinAspect(ratio: 1.5, pinWidth: false)
    imageAspectConstraint_Maxi?.isActive = false
    
    bgImageView.contentMode = .scaleToFill
    pin(bgImageView, to: imageView)
    pin(blurredEffectView, to: imageView)
    blurredEffectView.alpha = 0.8

    titleLabelTopConstraint_Mini = pin(titleLabel.top, to: imageView.top, dist: -1.0)
    authorLabelBottomConstraint_Mini = pin(authorLabel.bottom, to: imageView.bottom)
    titleLabelLeftConstraint_Mini = pin(titleLabel.left, to: imageView.right, dist:10.0)
    titleLabelRightConstraint_Mini = pin(titleLabel.right, to: toggleButton.left, dist: -22.0, priority: .defaultLow)
    
    titleLabelTopConstraint_Mini?.isActive = false
    authorLabelBottomConstraint_Mini?.isActive = false
    titleLabelLeftConstraint_Mini?.isActive = false
    titleLabelRightConstraint_Mini?.isActive = false
    
    pin(authorLabel.left, to: titleLabel.left)
    pin(authorLabel.right, to: titleLabel.right)

    titleLabel.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    authorLabel.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)

    toggleButtonYConstraint_Mini = pin(toggleButton.centerY, to: self.centerY)
    closeButtonLeftConstraint_Mini = pin(closeButton.left, to: toggleButton.right, dist: 13.0)
    closeButtonLeftConstraint_Mini?.isActive = false
    
    pin(closeButton.centerY, to: toggleButton.centerY)
    pin(closeButton.right, to: self.right, dist: -8.0)
    
    //Maxi Player Base UI
    pin(minimizeButton.top, to: self.top, dist: 1.0)
    pin(minimizeButton.right, to: self.right, dist: -padding + 8.0)
    
    titleLabelLeftConstraint_Maxi = pin(titleLabel.left, to: self.left, dist: padding)
    titleLabelRightConstraint_Maxi = pin(titleLabel.right, to: self.right, dist: -padding)
    titleLabelTopConstraint_Maxi = pin(titleLabel.top, to: imageView.bottom, dist: padding)

    authorLabelTopConstraint_Maxi = pin(authorLabel.top, to: titleLabel.bottom, dist: 2.0)
    
    pin(slider.left, to: self.left, dist: padding)
    pin(slider.right, to: self.right, dist: -padding)
    pin(slider.top, to: authorLabel.bottom, dist: padding)
    
    pin(elapsedTimeLabel.top, to: slider.bottom, dist: 4.0)
    pin(remainingTimeLabel.top, to: slider.bottom, dist: 4.0)
    pin(elapsedTimeLabel.left, to: self.left, dist: padding)
    pin(remainingTimeLabel.right, to: self.right, dist: -padding)
    pin(remainingTimeLabel.left, to: elapsedTimeLabel.right, dist: padding, priority: .defaultLow)
    
    remainingTimeLabel.textAlignment = .right
    
    toggleButtonXConstraint_Maxi = toggleButton.centerX()
    toggleButtonXConstraint_Maxi?.isActive = false
    toggleButtonTopConstraint_Maxi = pin(toggleButton.top, to: slider.bottom, dist: padding + 5.0)
    toggleButtonTopConstraint_Maxi?.isActive = false
    toggleButtonBottomConstraint_Maxi = pin(toggleButton.bottom, to: self.bottom, dist: -padding)
    toggleButtonBottomConstraint_Maxi?.isActive = false

    pin(backButton.right, to: toggleButton.left, dist: -30.0)
    pin(forwardButton.left, to: toggleButton.right, dist: 30.0)
    
    pin(backButton.centerY, to: toggleButton.centerY)
    pin(forwardButton.centerY, to: toggleButton.centerY)
    
    self.backgroundColor = Const.Colors.darkSecondaryBG
    
    heightConstraint = self.pinHeight(50)
    heightConstraint?.isActive = false

    Notification.receive(Const.NotificationNames.viewSizeTransition) {   [weak self] notification in
      guard let newSize = notification.content as? CGSize else { return }
      self?.viewSize = newSize
    }
  }

  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  var state:ArticlePlayerUIStates = .mini {
    didSet { if oldValue != state {  updateUI() } }
  }
  
  let padding = Const.Size.DefaultPadding
  let miniPadding = 10.0
  
  private func updateUI(){
    if self.superview == nil { return }
    authorLabelBottomConstraint_Mini?.isActive = false
    authorLabelTopConstraint_Maxi?.isActive = false
    closeButtonLeftConstraint_Mini?.isActive = false
    imageAspectConstraint_Maxi?.isActive = false
    imageAspectConstraint_Mini?.isActive = false
    titleLabelLeftConstraint_Maxi?.isActive = false
    titleLabelLeftConstraint_Mini?.isActive = false
    titleLabelRightConstraint_Maxi?.isActive = false
    titleLabelRightConstraint_Mini?.isActive = false
    titleLabelTopConstraint_Maxi?.isActive = false
    titleLabelTopConstraint_Mini?.isActive = false
    toggleButtonBottomConstraint_Maxi?.isActive = false
    toggleButtonTopConstraint_Maxi?.isActive = false
    toggleButtonXConstraint_Maxi?.isActive = false
    toggleButtonYConstraint_Mini?.isActive = false
    heightConstraint?.isActive = false
    imageConstrains?.top.isActive = false
    imageConstrains?.left.isActive = false
    imageConstrains?.bottom.isActive = false
    imageConstrains?.right.isActive = false
    imageSizeConstrains?.height.isActive = false
    imageSizeConstrains?.width.isActive = false
    
    bgImageView.isHidden = true
    blurredEffectView.isHidden = true
    closeButton.isHidden = true
    minimizeButton.isHidden = true
    slider.isHidden = true
    remainingTimeLabel.isHidden = true
    elapsedTimeLabel.isHidden = true
    backButton.isHidden = true
    forwardButton.isHidden = true
    
    progressCircle.isHidden = true
    
    imageConstrains?.left.constant = Const.Size.DefaultPadding
    
    switch state {
      case .mini:
        if image == nil {
          imageConstrains?.left.constant = 0
          imageSizeConstrains?.width.isActive = true
        }
        else {
          imageConstrains?.left.constant = miniPadding
          imageAspectConstraint_Mini?.isActive = true
        }
        self.layer.cornerRadius = 5.0
        imageView.contentMode = .scaleAspectFill
        imageConstrains?.top.constant = miniPadding
        imageConstrains?.bottom.constant = -miniPadding
        imageConstrains?.top.isActive = true
        imageConstrains?.left.isActive = true
        imageConstrains?.bottom.isActive = true
        toggleSizeConstrains?.height.constant = 30
        toggleSizeConstrains?.width.constant = 30
        
        titleLabel.numberOfLines = 1
        authorLabel.numberOfLines = 1
        
        titleLabel.boldContentFont(size: 13)
        authorLabel.contentFont(size: 12)
        
        authorLabelBottomConstraint_Mini?.isActive = true
        closeButtonLeftConstraint_Mini?.isActive = true
        titleLabelLeftConstraint_Mini?.isActive = true
        titleLabelRightConstraint_Mini?.isActive = true
        titleLabelTopConstraint_Mini?.isActive = true
        toggleButtonYConstraint_Mini?.isActive = true
        heightConstraint?.isActive = true
        
        progressCircle.isHidden = false
        closeButton.isHidden = false
      case .maxi:
        imageConstrains?.top.constant = 38.0
        imageConstrains?.left.constant = padding
        imageConstrains?.right.constant = -padding
        imageConstrains?.top.isActive = true
        imageConstrains?.left.isActive = true
        imageConstrains?.right.isActive = true
        if image == nil {
          imageSizeConstrains?.height.isActive = true
        } else {
          imageAspectConstraint_Maxi?.isActive = true
          bgImageView.isHidden = false
          blurredEffectView.isHidden = false
        }
        
        toggleSizeConstrains?.height.constant = 52
        toggleSizeConstrains?.width.constant = 52
        
        authorLabelTopConstraint_Maxi?.isActive = true
        titleLabelLeftConstraint_Maxi?.isActive = true
        titleLabelRightConstraint_Maxi?.isActive = true
        titleLabelTopConstraint_Maxi?.isActive = true
        toggleButtonBottomConstraint_Maxi?.isActive = true
        toggleButtonTopConstraint_Maxi?.isActive = true
        toggleButtonXConstraint_Maxi?.isActive = true
        
        titleLabel.numberOfLines = 0
        authorLabel.numberOfLines = 0
        
        titleLabel.boldContentFont()
        authorLabel.contentFont(size: Const.Size.SmallerFontSize)
        
        slider.isHidden = false
        minimizeButton.isHidden = false
        remainingTimeLabel.isHidden = false
        elapsedTimeLabel.isHidden = false
        backButton.isHidden = false
        forwardButton.isHidden = false
        self.layer.cornerRadius = 13.0
        imageView.contentMode = .scaleAspectFit
      case .tracklist:
        slider.isHidden = false
        minimizeButton.isHidden = false
        self.layer.cornerRadius = 13.0
    }
    updateWidth(doLayout: false)
    UIView.animate(withDuration: 0.3) {[weak self] in
      self?.layoutIfNeeded()
    }
  }
}

extension UIImage {
  var blurred:UIImage {
    var ciImage: CIImage? = self.ciImage
    if ciImage == nil,
       let cgImage = self.cgImage {
      ciImage = CIImage(cgImage: cgImage)
    }
    guard let ciImage = ciImage else { return self }
    return UIImage(ciImage: ciImage.applyingGaussianBlur(sigma: 7.0))
  }
}
