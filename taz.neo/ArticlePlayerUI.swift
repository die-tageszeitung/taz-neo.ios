//
//  ArticlePlayerUI.swift
//  taz.neo
//
//  Created by Ringo Müller on 23.06.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

enum ArticlePlayerUIStates { case mini, maxi}

class ArticlePlayerUI: UIView {
  
  @Default("playbackRate")
  public var playbackRate: Double
    
  @Default("autoPlayNext")
  var autoPlayNext: Bool
  
  var rateMenuItms: [menuAction] = []
  
  func updateWidth(doLayout: Bool = true){
    
    let noGap = traitCollection.horizontalSizeClass == .compact && state == .maxi
    
    let w
    = noGap
    ? viewSize.width
    : min(375, viewSize.width - 2*miniPadding)
    if widthConstraint == nil {
      widthConstraint = self.pinWidth(w)
    }
    else {
      widthConstraint?.constant = w
    }
    parentRightConstraint?.constant
    = noGap
    ? 0
    : -miniPadding
    
    if doLayout { self.superview?.layoutIfNeeded() }
    fixBottomPosition()
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
  
  private func addAndShow(){
    guard self.superview == nil else { return }
    guard let view
            = (TazAppEnvironment.sharedInstance.rootViewController
               as? UITabBarController)?.view  else { return }
    view.addSubview(self)
    self.isHidden = true
    parentBottomConstraint = pin(self.bottom, to: view.bottomGuide(), dist: -64.0)
    parentRightConstraint = pin(self.right, to: view.rightGuide(), dist: -miniPadding)
    viewSize = view.frame.size
  }
  
  func show(){
    if self.superview != nil { return }
    addAndShow()
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
  private var maxiItemTapClosure: (()->())?
  
  func onToggle(closure: @escaping ()->()){
    toggleClosure = closure
  }
  
  func onClose(closure: @escaping ()->()){
    closeClosure = closure
  }
  
  func onMaxiItemTap(closure: @escaping ()->()){
    maxiItemTapClosure = closure
  }
  
  // MARK: - external accessible components
  
  // MARK: - Image/ImageView
  var image: UIImage? {
    didSet {
      if image == oldValue { return }
      bgImageView.image = image?.withRenderingMode(.alwaysTemplate).blurred
      imageView.image = image
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
    return lbl
  }()
  
  lazy var authorLabel: UILabel = {
    let lbl = UILabel()
    lbl.contentFont().white()
    lbl.numberOfLines = 0
    return lbl
  }()
  
  func updateUI(){
    updateLayout()
  }
  
  func setRate(_ rate: Double, isInitial: Bool = false){
    rateMenuItms = rateMenuItms.map{
      var itm = $0
      if $0.title == "\(rate)" {
        itm.icon = "checkmark"
      }
      else {
        itm.icon = nil
      }
      return itm
    }
    
    let menu = MenuActions()
    menu.actions = rateMenuItms
    
    if #available(iOS 14.0, *) {
      rateButton.menu = menu.contextMenu
    }
    playbackRate = rate
    rateButton.setTitle("\(rate)x", for: .normal)
    isInitial
    ? Usage.xtrack.audio.setInitialPlaySpeed(ratio: rate)
    : Usage.xtrack.audio.changePlaySpeed(ratio: rate)
  }
  
  lazy var rateButton: UIButton = {
    let btn = UIButton()
    btn.titleLabel?.contentFont()
    btn.setTitleColor(Const.Colors.appIconGrey, for: .normal)
    if #available(iOS 14.0, *) {
      btn.showsMenuAsPrimaryAction = true
    }
    
    let values: [Double] = [0.5, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.5, 2.0]
    var itms: [menuAction] = []
    for val in values {
      itms += (title: "\(val)",
               icon: nil,
               group: 0,
               closure: {[weak self] _ in self?.setRate(val)})
    }
    rateMenuItms = itms
    btn.contentEdgeInsets = .zero
    if #available(iOS 14.0, *) {
      btn.iosHigher14?.showsMenuAsPrimaryAction = true
    }
    return btn
  }()
  
  lazy var elapsedTimeLabel: UILabel
  = UILabel().contentFont(size: 9.0).color(Const.Colors.appIconGrey)
  
  lazy var remainingTimeLabel: UILabel
  = UILabel().contentFont(size: 9.0).color(Const.Colors.appIconGrey)
  
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
  
  var seekBackButtonEnabled = true {
    didSet {
      seekBackwardButton.isEnabled = seekBackButtonEnabled
      seekBackwardButton.alpha = seekBackButtonEnabled ? 1.0 : 0.5
    }
  }
  var seekFrwardButtonEnabled = true {
    didSet {
      seekForwardButton.isEnabled = seekFrwardButtonEnabled
      seekForwardButton.alpha = seekFrwardButtonEnabled ? 1.0 : 0.5
    }
  }
  
  var skipToAudioBreaks: Bool = false {
    didSet {
      if oldValue == skipToAudioBreaks { return }
      seekForwardButton.buttonView.name = skipToAudioBreaks ? "goforward" : "goforward.15"
      seekBackwardButton.buttonView.name = skipToAudioBreaks ? "gobackward" : "gobackward.15"
    }
  }
  
  lazy var seekForwardButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.hinset = 0.05
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.name = "goforward.15"
    return btn
  }()
  
  lazy var seekBackwardButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.hinset = 0.05
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.name = "gobackward.15"
    return btn
  }()
  
  lazy var playNextLabel: UILabel = {
    let lbl =  UILabel()
    lbl.contentFont().color(Const.Colors.appIconGrey)
    lbl.text = "Nächsten Artikel abspielen"
    return lbl
  }()
  
  lazy var playNextSwitch = {
    let sw = UISwitch()
    sw.isOn = autoPlayNext
    sw.addTarget(self,
                 action: #selector(handlePlayNextSwitch(sender:)),
                 for: .valueChanged)
    return sw
  }()
  
  @objc public func handlePlayNextSwitch(sender: UISwitch) {
    autoPlayNext = sender.isOn
    Usage.xtrack.audio.autoPlayNext(enable: autoPlayNext, initial: false)
  }
  
  lazy var progressCircle = ProgressCircle()
  
  private let wrapper = CustomWrapper()
  
  func minimize(){
    Usage.xtrack.audio.minimize()
    state = .mini
  }
  
  func maximize(){
    if state == .maxi {
      maxiItemTapClosure?()
    }
    else {
      state = .maxi
      Usage.xtrack.audio.maximize()
    }
  }
  
  var parentRightConstraint: NSLayoutConstraint?//Global not for state changes!
  var parentBottomConstraint: NSLayoutConstraint?//Global not for state changes!
  
  var widthConstraint: NSLayoutConstraint?//Only for viewSizeTransition not for state changes!

  var imageSizeConstrains_Mini: (width: NSLayoutConstraint,///active if mini
                            height: NSLayoutConstraint)?///mini? 32:0 active: mini || maxi+img==nil
  
  var imageAspectConstraint_Maxi: NSLayoutConstraint?///active only in maxi if img!=nil
  var imageConstrains: (top: NSLayoutConstraint,///fix
                        bottom: NSLayoutConstraint,///mini only
                        left: NSLayoutConstraint,///fix
                        right: NSLayoutConstraint)?///maxi only
  var wrapperConstrains: (top: NSLayoutConstraint,///mini defaultPadding else 38.0
                        bottom: NSLayoutConstraint,///mini defaultPadding else 68.0?
                        left: NSLayoutConstraint,///mini defaultPadding else maxiPadding
                        right: NSLayoutConstraint)?///mini 104 else maxiPadding
  var toggleSizeConstrains: (width: NSLayoutConstraint,///mini 30 maxi 52
                            height: NSLayoutConstraint)?///
  var titleLabelRightConstraint: NSLayoutConstraint?///maxi+NoAuthor -15 else 0
  var authorLabelRightConstraint: NSLayoutConstraint?///maxi -15 else 0
  var authorLabelBottomConstraint: NSLayoutConstraint?///maxi+NoAuthor: -4 else 0
  var titleLabelLeftConstraint: NSLayoutConstraint?///mini+image: 32+padding else 0
  var titleLabelTopConstraint_Maxi: NSLayoutConstraint?///active only in maxi
  var titleLabelTopConstraint_Mini: NSLayoutConstraint?///active only in mini
  var toggleButtonTopConstraint_Maxi: NSLayoutConstraint?///active only in maxi
  var toggleButtonBottomConstraint_Maxi: NSLayoutConstraint?///active only in maxi
  var toggleButtonXConstraint_Maxi: NSLayoutConstraint?///active only in maxi
  var toggleButtonYConstraint_Mini: NSLayoutConstraint?///active only in mini
  var toggleButtonRightConstraint_Mini: NSLayoutConstraint?///active only in mini
  
  func setup(){
    wrapper.addSubview(bgImageView)
    wrapper.addSubview(blurredEffectView)
    wrapper.addSubview(imageView)
    wrapper.addSubview(titleLabel)///1line mini 2 maxi
    wrapper.addSubview(authorLabel)///1line mini 2 maxi
    wrapper.addSubview(rateButton)
    self.addSubview(closeButton)
    self.addSubview(minimizeButton)
    self.addSubview(slider)
    self.addSubview(remainingTimeLabel)
    self.addSubview(elapsedTimeLabel)
    self.addSubview(toggleButton)
    self.addSubview(backButton)
    self.addSubview(forwardButton)
    self.addSubview(seekForwardButton)
    self.addSubview(seekBackwardButton)
    self.addSubview(playNextLabel)
    self.addSubview(playNextSwitch)
    self.addSubview(wrapper)
    wrapper.onTapping(closure: { [weak self] _ in self?.maximize() })
    setRate(playbackRate, isInitial: true)
    //Mini Player Base UI
    pin(bgImageView, to: imageView)
    imageConstrains = pin(imageView, to: wrapper)
    imageConstrains?.right.isActive = false
    imageConstrains?.bottom.isActive = false
    
    imageSizeConstrains_Mini = imageView.pinSize(CGSize(width: 32, height: 32))
    imageSizeConstrains_Mini?.height.isActive = false
    imageSizeConstrains_Mini?.width.isActive = false
                
    imageAspectConstraint_Maxi = imageView.pinAspect(ratio: 1.5, pinWidth: false)
    imageAspectConstraint_Maxi?.isActive = false
    
    bgImageView.contentMode = .scaleToFill
    pin(bgImageView, to: imageView)
    pin(blurredEffectView, to: imageView)
    blurredEffectView.alpha = 0.8
    
    pin(authorLabel.left, to: titleLabel.left)
    titleLabelLeftConstraint = pin(titleLabel.left, to: wrapper.left)
    
    pin(rateButton.right, to: wrapper.right)
    titleLabelRightConstraint = pin(titleLabel.right, to: wrapper.right)
    authorLabelRightConstraint = pin(authorLabel.right, to: wrapper.right)
    authorLabelBottomConstraint = pin(authorLabel.bottom, to: wrapper.bottom)
    
    titleLabelTopConstraint_Mini = pin(titleLabel.top, to: imageView.top, dist: -1.0)
    titleLabelTopConstraint_Mini?.isActive = false
    titleLabelTopConstraint_Maxi = pin(titleLabel.top, to: imageView.bottom, dist: maxiPadding)
    titleLabelTopConstraint_Maxi?.isActive = false
    
    pin(authorLabel.top, to: titleLabel.bottom, dist: 2.0)
    pin(rateButton.bottom, to: wrapper.bottom, dist: 6.0)
  
    titleLabel.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    authorLabel.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)

    toggleButtonYConstraint_Mini = toggleButton.centerY()
    toggleButtonYConstraint_Mini?.isActive = false
    toggleButtonXConstraint_Maxi = toggleButton.centerX()
    toggleButtonXConstraint_Maxi?.isActive = false
    
    toggleButtonRightConstraint_Mini =  pin(toggleButton.right, to: self.right, dist: -60.0)
    toggleButtonRightConstraint_Mini?.isActive = false
    
    toggleButtonTopConstraint_Maxi = pin(toggleButton.top, to: slider.bottom, dist: padding + 5.0)
    toggleButtonTopConstraint_Maxi?.isActive = false
    
    pin(closeButton.right, to: self.right, dist: -8.0)
    closeButton.centerY()
    
    wrapperConstrains = pin(wrapper, to: self)
    
    pin(minimizeButton.top, to: self.top, dist: 1.0)
    pin(minimizeButton.right, to: self.right, dist: -padding + 8.0)
    
    pin(slider.left, to: self.left, dist: maxiPadding)
    pin(slider.right, to: self.right, dist: -maxiPadding)
    pin(slider.top, to: wrapper.bottom, dist: padding)
    
    pin(elapsedTimeLabel.top, to: slider.bottom, dist: 4.0)
    pin(remainingTimeLabel.top, to: slider.bottom, dist: 4.0)
    pin(elapsedTimeLabel.left, to: self.left, dist: padding)
    pin(remainingTimeLabel.right, to: self.right, dist: -padding)
    pin(remainingTimeLabel.left, to: elapsedTimeLabel.right, dist: padding, priority: .defaultLow)
    
    remainingTimeLabel.textAlignment = .right
    
    pin(playNextLabel.left, to: self.left, dist: maxiPadding)
    pin(playNextSwitch.right, to: self.right, dist: -maxiPadding)
    pin(playNextSwitch.top, to: toggleButton.bottom, dist: maxiPadding + 5.0)
    pin(playNextLabel.top, to: toggleButton.bottom, dist: maxiPadding + 7.0)

    pin(backButton.right, to: toggleButton.left, dist: -90.0)
    pin(forwardButton.left, to: toggleButton.right, dist: 90.0)
    
    pin(seekBackwardButton.right, to: toggleButton.left, dist: -30.0)
    pin(seekForwardButton.left, to: toggleButton.right, dist: 30.0)
    
    pin(backButton.centerY, to: toggleButton.centerY)
    pin(forwardButton.centerY, to: toggleButton.centerY)
    pin(seekBackwardButton.centerY, to: toggleButton.centerY)
    pin(seekForwardButton.centerY, to: toggleButton.centerY)
    
    self.backgroundColor = Const.Colors.darkSecondaryBG
    self.layer.shadowOpacity = 0.40
    self.layer.shadowOffset = CGSize(width: 2, height: 2)
    self.layer.shadowRadius = 5
    self.layer.shadowColor = UIColor.black.cgColor
    
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
    didSet { if oldValue != state {
      self.bringToFront()
      updateLayout(stateChange: true) }
    }
  }
  
  let padding = Const.Size.DefaultPadding
  let miniPadding = 9.0
  let maxiPadding = 18.0
  
  func fixBottomPosition(){
    if self.state == .mini || traitCollection.horizontalSizeClass != .compact {
      parentBottomConstraint?.constant = -64.0
    }
    else {
      parentBottomConstraint?.constant = 0.0 + UIWindow.safeInsets.bottom
    }
  }
  
  private func updateLayout(stateChange: Bool = false){
    if self.superview == nil { return }
    fixBottomPosition()
    switch state {
      case .mini:
        rateButton.isHidden = true
        closeButton.isHidden = false
        minimizeButton.isHidden = true
        slider.isHidden = true
        remainingTimeLabel.isHidden = true
        elapsedTimeLabel.isHidden = true
        backButton.isHidden = true
        forwardButton.isHidden = true
        seekForwardButton.isHidden = true
        seekBackwardButton.isHidden = true
        playNextLabel.isHidden = true
        playNextSwitch.isHidden = true
        progressCircle.isHidden = false
        
        toggleButtonTopConstraint_Maxi?.isActive = false///active only in maxi
        toggleButtonBottomConstraint_Maxi?.isActive = false///active only in maxi
        toggleButtonXConstraint_Maxi?.isActive = false///active only in maxi
        titleLabelTopConstraint_Maxi?.isActive = false///active only in maxi
        imageAspectConstraint_Maxi?.isActive = false///active only in maxi if img!=nil
        
        imageView.isHidden = image == nil
        bgImageView.isHidden = image == nil
        blurredEffectView.isHidden = image == nil
        
        imageConstrains?.bottom.isActive = true ///mini only
        imageConstrains?.right.isActive = false///maxi only
        
        imageSizeConstrains_Mini?.width.isActive = true
        imageSizeConstrains_Mini?.height.isActive = true
        imageSizeConstrains_Mini?.height.constant = 32.0

        wrapperConstrains?.top.constant = miniPadding ///mini defaultPadding else 38.0
        wrapperConstrains?.bottom.constant = -miniPadding ///mini defaultPadding else 68.0?
        wrapperConstrains?.left.constant = miniPadding///mini defaultPadding else maxiPadding
        wrapperConstrains?.right.constant = -101///mini 101 else maxiPadding
        
        toggleSizeConstrains?.width.constant = 30///mini 30 maxi 52
        toggleSizeConstrains?.height.constant = 30///mini 30 maxi 52

        titleLabelRightConstraint?.constant = 0
        authorLabelRightConstraint?.constant = 0///maxi -15 else 0
        titleLabelLeftConstraint?.constant = image == nil ? 0 : 32 + padding///mini+image: 32+padding else 0

        titleLabelTopConstraint_Mini?.isActive = true///active only in mini

        toggleButtonYConstraint_Mini?.isActive = true///active only in mini
        toggleButtonRightConstraint_Mini?.isActive = true///active only in mini
                
        self.layer.cornerRadius = 5.0
        imageView.contentMode = .scaleAspectFill
        
        titleLabel.numberOfLines = 1
        authorLabel.numberOfLines = 1
        
        titleLabel.boldContentFont(size: 13)
        authorLabel.contentFont(size: 13)
        authorLabelBottomConstraint?.constant = 0
      case .maxi:
        authorLabelBottomConstraint?.constant
        = authorLabel.text?.length ?? 0 == 0 ? 4.0 : 0.0
        imageConstrains?.bottom.isActive = false ///mini only
        titleLabelTopConstraint_Mini?.isActive = false///active only in mini
        toggleButtonYConstraint_Mini?.isActive = false///active only in mini
        toggleButtonRightConstraint_Mini?.isActive = false///active only in mini
        if image == nil {
          imageAspectConstraint_Maxi?.isActive = false
          imageSizeConstrains_Mini?.height.isActive = true
        }
        else {
          imageSizeConstrains_Mini?.height.isActive = false
          imageAspectConstraint_Maxi?.isActive = true
        }
        imageSizeConstrains_Mini?.width.isActive = false
 
        ///ContextMenu is only available for iOS 14, no fallback in Player due nearly no users on iOS 13
        ///active Devices iOS 13.x 1 of 2.000 in last 30 Days opt in => 0.05%
        if #available(iOS 14.0, *) { rateButton.isHidden = false }
        closeButton.isHidden = true
        minimizeButton.isHidden = false
        slider.isHidden = false
        if stateChange {
          remainingTimeLabel.alpha = 0.0
          elapsedTimeLabel.alpha = 0.0
          backButton.alpha = 0.0
          forwardButton.alpha = 0.0
          seekForwardButton.alpha = 0.0
          seekBackwardButton.alpha = 0.0
          playNextLabel.alpha = 0.0
          playNextSwitch.alpha = 0.0
        }
        remainingTimeLabel.isHidden = false
        elapsedTimeLabel.isHidden = false
        backButton.isHidden = false
        forwardButton.isHidden = false
        seekForwardButton.isHidden = false
        seekBackwardButton.isHidden = false
        playNextLabel.isHidden = false
        playNextSwitch.isHidden = false
        progressCircle.isHidden = true
        
        toggleButtonTopConstraint_Maxi?.isActive = true///active only in maxi
        toggleButtonBottomConstraint_Maxi?.isActive = true///active only in maxi
        toggleButtonXConstraint_Maxi?.isActive = true///active only in maxi
        titleLabelTopConstraint_Maxi?.isActive = true///active only in maxi
        
        imageView.isHidden = image == nil
        bgImageView.isHidden = image == nil
        blurredEffectView.isHidden = image == nil
        
        imageSizeConstrains_Mini?.height.constant = 0.0

        imageConstrains?.right.isActive = true///maxi only
        
        wrapperConstrains?.top.constant = 38.0 ///mini defaultPadding else 38.0
        wrapperConstrains?.bottom.constant = -180//-98.0 ///mini defaultPadding else 68.0?
        wrapperConstrains?.left.constant = maxiPadding///mini defaultPadding else maxiPadding
        wrapperConstrains?.right.constant = -maxiPadding///mini 104 else maxiPadding
        
        toggleSizeConstrains?.width.constant = 52///mini 30 maxi 52
        toggleSizeConstrains?.height.constant = 52///mini 30 maxi 52

        authorLabelRightConstraint?.constant = -15///maxi -15 else 0
        titleLabelRightConstraint?.constant
        = authorLabel.text?.length ?? 0 == 0 ? -15.0 : 0
        titleLabelLeftConstraint?.constant = 0///mini+image: 32+padding else 0
                
        self.layer.cornerRadius = 13.0
        imageView.contentMode = .scaleAspectFit
        
        titleLabel.numberOfLines = 0
        authorLabel.numberOfLines = 0
        
        titleLabel.boldContentFont(size: 18.0)
        authorLabel.contentFont(size: 17.0)
        wrapperConstrains?.bottom.isActive = true
    }
    updateWidth(doLayout: false)
    if stateChange {
      UIView.animateKeyframes(withDuration: 0.4, delay: 0, animations: {[weak self] in
        UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.1) {
          self?.wrapper.alpha = 0.0
          self?.toggleButton.alpha = 0.0
        }
        UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.6) {
          self?.layoutIfNeeded()
        }
        UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.4) {
          self?.wrapper.alpha = 1.0
          self?.toggleButton.alpha = 1.0
          if stateChange == true {
            self?.remainingTimeLabel.alpha = 1.0
            self?.elapsedTimeLabel.alpha = 1.0
            self?.backButton.alpha = 1.0
            self?.forwardButton.alpha = 1.0
            self?.seekForwardButton.alpha = 1.0
            self?.seekBackwardButton.alpha = 1.0
            self?.playNextLabel.alpha = 1.0
            self?.playNextSwitch.alpha = 1.0
          }
        }
      })
    }
    else {
      UIView.animate(withDuration: 0.3) {[weak self] in
        if self?.isHidden ==  true {
          self?.setNeedsLayout()
          self?.layoutIfNeeded()
        }
        else {
          self?.wrapper.layoutIfNeeded()
        }
      }completion: {[weak self] _ in
        if self?.isHidden == true {
          self?.showAnimated()
        }
      }
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


/// Helper to animate from bottom of a viel not from center
/// helps here to not jump the whole view
fileprivate class CustomWrapper: UIView {
  override func layoutSubviews() {
    self.layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
    super.layoutSubviews()
    self.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
  }
}
