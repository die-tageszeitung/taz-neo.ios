//
//
// LoginView.swift
//
// Created by Ringo Müller-Gromes on 14.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//

import UIKit
import NorthLib
import WebKit

public class LoginView : FormView{
  var idInput = TazTextField(placeholder: App.isTAZ ? Localized("login_username_hint") : "Abo-ID",
                             textContentType: .emailAddress,
                             enablesReturnKeyAutomatically: true,
                             keyboardType: .emailAddress,
                             autocapitalizationType: .none)
  
  var passInput = TazTextField(placeholder: Localized("login_password_hint"),
                               textContentType: .password,
                               isSecureTextEntry: true,
                               enablesReturnKeyAutomatically: true)
  
  var loginButton = Padded.Button(title: Localized("login_button"))
  var cancelButton = Padded.Button(type: .outline, title: Localized("cancel_button"))
  
  var registerButton = Padded.Button(type: .outline,
                                title: Localized("register_free_button"))
  
  var marketingContainer: MarketingContainerWrapperView = MarketingContainerWrapperView()
  
  
  var whereIsTheAboId: Padded.View = {
    let lbl = UILabel()
    lbl.text = "Hilfe"
    lbl.contentFont(size: Const.Size.SmallerFontSize)
    lbl.textColor = Const.SetColor.ios_opaque(.grey).color
    lbl.addBorderView(Const.SetColor.ios_opaque(.grey).color, edge: UIRectEdge.bottom)
    let wrapper = Padded.View()
    wrapper.addSubview(lbl)
    //Allow label to shink if wrapper shrinks, not alow to grow more than needed
    pin(lbl, to: wrapper).right.priority = .defaultLow
    lbl.setContentHuggingPriority(.required, for: .horizontal)
    lbl.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    wrapper.paddingBottom = miniPadding
    wrapper.paddingTop = 5.0
    return wrapper
  }()
  
  var passForgottButton: Padded.View = {
    let lbl = UILabel()
    lbl.text = Localized("login_forgot_password")
    lbl.contentFont(size: Const.Size.SmallerFontSize)
    lbl.textColor = Const.SetColor.ios_opaque(.grey).color
    lbl.addBorderView(Const.SetColor.ios_opaque(.grey).color, edge: UIRectEdge.bottom)
    let wrapper = Padded.View()
    wrapper.addSubview(lbl)
    //Allow label to shink if wrapper shrinks, not alow to grow more than needed
    pin(lbl, to: wrapper).right.priority = .defaultLow
    lbl.setContentHuggingPriority(.required, for: .horizontal)
    lbl.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    wrapper.paddingBottom = miniPadding
    wrapper.paddingTop = 5.0
    return wrapper
  }()
    
  lazy var privacyLabel : CustomTextView = {
    let view = CustomTextView()
    view.isEditable = false
    view.attributedText = Localized("login_privacy_link").htmlAttributed
    view.linkTextAttributes 
    = [.foregroundColor : Const.SetColor.ios_opaque(.grey).color,
      .underlineColor: Const.SetColor.ios_opaque(.grey).color]
    view.textContainer.lineFragmentPadding = 0;
    view.font = Const.Fonts.contentFont(size: Const.Size.SmallerFontSize)
    view.textColor = Const.SetColor.ios_opaque(.grey).color
    view.textAlignment = .left
    return view
  }()
  
  
  var trialSubscriptionButton
  = Padded.Button(type: .outline, title: Localized("login_trial_subscription_button_text"))
  var switchButton
  = Padded.Button(type: .outline, title: Localized("login_switch_print2digi_button_text"))
  var extendButton
  = Padded.Button(type: .outline, title: Localized("login_extend_print_with_digi_button_text"))
    
  static let miniPadding = 0.0
  
  override func createSubviews() -> [UIView] {
    idInput.paddingBottom = Self.miniPadding
    passInput.paddingBottom = Self.miniPadding
    loginButton.paddingBottom = 30//add some extra Padding
    loginButton.paddingBottom = 30//add some extra Padding
    
    let label
    = Padded.Label(title: "Anmeldung für Digital-Abonnent:innen")
    label.boldContentFont(size: Const.Size.DT_Head_extrasmall).align(.left)
    label.paddingBottom = 25.0
    privacyLabel.paddingBottom = 25.0
    cancelButton.paddingBottom = 25.0
    whereIsTheAboId.paddingBottom = 25.0
    
    if App.isLMD {
      return   [
        label,
        idInput,
        whereIsTheAboId,
        passInput,
        loginButton]
    }
    return   [
      label,
      idInput,
      whereIsTheAboId,
      passInput,
      passForgottButton,
      privacyLabel,
      loginButton,
      cancelButton,
      marketingContainer
    ]
  }
  
  // MARK: validate()
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    var idInput_bottomMessage: String? = nil
    var passInput_bottomMessage: String? = nil
    
    if (idInput.text ?? "").isEmpty {
      idInput_bottomMessage = Localized("login_username_error_empty")
      errors = true
    }
    
    if (passInput.text ?? "").isEmpty {
      passInput_bottomMessage = Localized("login_password_error_empty")
      errors = true
    }
    
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.idInput.bottomMessage = idInput_bottomMessage
      self?.passInput.bottomMessage = passInput_bottomMessage
      self?.layoutIfNeeded()
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    return nil
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  func dottedLine() -> UIView {
    let dottedLine = DottedLineView()
//    dottedLine.offset = 1.7
    dottedLine.pinHeight(Const.Size.DottedLineHeight*1.2)
    dottedLine.fillColor = Const.SetColor.HText.color
    dottedLine.strokeColor = Const.SetColor.HText.color
    return dottedLine
  }
  
  func setup(){
    let mc1 = MarketingContainerView(button: trialSubscriptionButton,
                                     title: Localized("login_trial_subscription_title"),
                                     text: Localized("login_trial_subscription_body"),
                                     imageName:  "BundledResources/trial.jpg")
    let dottedLine1 = dottedLine()
    let mc2 = MarketingContainerView(button: switchButton,
                                     title: Localized("login_switch_print2digi_title"),
                                     text: Localized("login_switch_print2digi_body"),
                                     imageName: "BundledResources/switch.jpg",
                                     imageLeftAligned: true)
    let dottedLine2 = dottedLine()
    let mc3 = MarketingContainerView(button: extendButton,
                                     title: Localized("login_extend_print_with_digi_title"),
                                     text: Localized("login_extend_print_with_digi_body"),
                                     imageName: "BundledResources/extend.jpg")
    marketingContainer.addSubview(mc1)
    marketingContainer.addSubview(dottedLine1)
    marketingContainer.addSubview(mc2)
    marketingContainer.addSubview(dottedLine2)
    marketingContainer.addSubview(mc3)
    pin(mc1, to: marketingContainer, exclude: .bottom)
    pin(dottedLine1.left, to: marketingContainer.left, dist: Const.Size.DefaultPadding)
    pin(dottedLine1.right, to: marketingContainer.right, dist: -Const.Size.DefaultPadding)
    pin(mc2.left, to: marketingContainer.left)
    pin(mc2.right, to: marketingContainer.right)
    pin(dottedLine2.left, to: marketingContainer.left, dist: Const.Size.DefaultPadding)
    pin(dottedLine2.right, to: marketingContainer.right, dist: -Const.Size.DefaultPadding)
    pin(mc3.left, to: marketingContainer.left)
    pin(mc3.right, to: marketingContainer.right)
    pin(mc3.bottom, to: marketingContainer.bottom, dist: -30.0)
    pin(dottedLine1.top, to: mc1.bottom, dist: 2*Const.Size.BiggerPadding)
    pin(mc2.top, to: dottedLine1.bottom)
    pin(dottedLine2.top, to: mc2.bottom, dist: 2*Const.Size.BiggerPadding)
    pin(mc3.top, to: dottedLine2.bottom)
    marketingContainer.backgroundColor = Const.SetColor.HBackground.color
  }
}


public class NotLinkedLoginAboIDView : LoginView {
  
  var aboIdInput = TazTextField(placeholder: Localized("login_subscription_hint"),
                             textContentType: .emailAddress,
                             enablesReturnKeyAutomatically: true,
                             keyboardType: .numberPad,
                             autocapitalizationType: .none)
  
  var connectButton = Padded.Button(title: Localized("connect_this_abo_id_with_taz_id"))
  
  override func createSubviews() -> [UIView] {
    loginButton.setTitle(Localized("connect_this_abo_id_with_taz_id"), for: .normal)
    return   [
      Padded.Label(title: Localized("connect_abo_id_title")),
      aboIdInput,
      passInput,
      connectButton,
      passForgottButton
    ]
  }
}

class MarketingContainerWrapperView: UIView {}

class MarketingContainerView: Padded.View {
  
  var imageLeftAligned: Bool
  
  var button: Padded.Button
  var titleLabel = UILabel()
  var textLabel = UILabel()
  var imageView = UIImageView()
  
  var firstWrapper = UIView()
  var secondWrapper = UIView()
  
  var first2sv_bottomConstraint: NSLayoutConstraint?
  var first2sv_rightConstraint: NSLayoutConstraint?
  
  var second2sv_topConstraint: NSLayoutConstraint?
  var second2sv_leftConstraint: NSLayoutConstraint?
  
  var first2second_verticalConstraint: NSLayoutConstraint?
  var firstHalf_widthConstraint: NSLayoutConstraint?
  var secondHalf_widthConstraint: NSLayoutConstraint?
  
  var imageAspectConstraint: NSLayoutConstraint?
  
  func setup(){
    if imageLeftAligned {
      secondWrapper.addSubview(titleLabel)
      secondWrapper.addSubview(textLabel)
      firstWrapper.addSubview(imageView)
    }
    else {
      firstWrapper.addSubview(titleLabel)
      firstWrapper.addSubview(textLabel)
      secondWrapper.addSubview(imageView)
    }
    
    let imgSv = imageLeftAligned ? firstWrapper : secondWrapper
    let lblSv = imageLeftAligned ? secondWrapper : firstWrapper
    
    firstWrapper.addBorder(.yellow)
    secondWrapper.addBorder(.green)
    
    self.addBorder(.red)
    
    titleLabel.addBorder(.blue)
    textLabel.addBorder(.systemPink)
    imageView.addBorder(.purple)
    button.addBorder(.magenta)
    
    self.addSubview(firstWrapper)
    self.addSubview(secondWrapper)
    self.addSubview(button)
    
    pin(titleLabel, to: lblSv, dist: Const.Size.DefaultPadding, exclude: .bottom)
    pin(textLabel, to: lblSv, dist: Const.Size.DefaultPadding, exclude: .top)
    pin(textLabel.top, to: titleLabel.bottom, dist: Const.Size.SmallPadding)
    
    pin(imageView, to: imgSv, dist: Const.Size.DefaultPadding)
    imageView.contentMode = .scaleAspectFit
    if let img = imageView.image,
       img.size.width > 0,
       img.size.height > 0 {
      imageView.pinAspect(ratio: img.size.width/img.size.height, priority: .defaultHigh)
    }
    
    let c1 = pin(firstWrapper, to: self)
    first2sv_bottomConstraint = c1.bottom
    first2sv_rightConstraint = c1.right
    first2sv_bottomConstraint?.isActive = false
    first2sv_rightConstraint?.isActive = false
    c1.bottom.constant = -46 //dist for button
    
    let c2 = pin(secondWrapper, to: self)
    second2sv_topConstraint = c2.top
    second2sv_leftConstraint = c2.left
    second2sv_topConstraint?.isActive = false
    second2sv_leftConstraint?.isActive = false
    c2.bottom.constant = -46 //dist for button
    
    firstHalf_widthConstraint = firstWrapper.pinWidth(to: self.width, factor: 0.5)
    secondHalf_widthConstraint = secondWrapper.pinWidth(to: self.width, factor: 0.5)
    first2second_verticalConstraint = pin(secondWrapper.top, to: firstWrapper.bottom)
    
    titleLabel.numberOfLines = 0
    titleLabel.textAlignment = .left
    titleLabel.marketingHead()
    
    textLabel.numberOfLines = 0
    textLabel.textAlignment = .left
    textLabel.contentFont()
    
    self.backgroundColor = Const.SetColor.HBackground.color
    
    pin(button.bottom, to: self.bottom)
    pin(button.width, to: firstWrapper.width, dist: -2*Const.Size.DefaultPadding)
    if imageLeftAligned {
      pin(button.right, to: self.right, dist: -Const.Size.DefaultPadding)
    }
    else {
      pin(button.left, to: self.left, dist: Const.Size.DefaultPadding)
    }
  }
  
  override func layoutSubviews() {
    resetConstrainsIfNeeded()
    super.layoutSubviews()
  }
  
  var updatedConstrainsAtWidth: CGFloat = 0.0
  
  func resetConstrainsIfNeeded(){
    if abs(updatedConstrainsAtWidth - self.frame.size.width) < 10 { return }
    updatedConstrainsAtWidth = self.frame.size.width
    first2sv_bottomConstraint?.isActive = false
    first2sv_rightConstraint?.isActive = false
    second2sv_topConstraint?.isActive = false
    second2sv_leftConstraint?.isActive = false
    firstHalf_widthConstraint?.isActive = false
    secondHalf_widthConstraint?.isActive = false
    first2second_verticalConstraint?.isActive = false
    imageAspectConstraint?.isActive = false
    if self.frame.size.width > 550 {
      first2sv_bottomConstraint?.isActive = true
      second2sv_topConstraint?.isActive = true
      firstHalf_widthConstraint?.isActive = true
      secondHalf_widthConstraint?.isActive = true
    }
    else {
      first2sv_rightConstraint?.isActive = true
      second2sv_leftConstraint?.isActive = true
      first2second_verticalConstraint?.isActive = true
      imageAspectConstraint?.isActive = true
    }
  }
  
  
  /// Creates Marketing Container View with given Layout
  /// - Parameters:
  ///   - button: Button for Action
  ///   - title: Title for MarketingContainer
  ///   - text: Text for MarketingContainer
  ///   - imageName: image to use
  ///   - imageLeftAligned: true if image left and Text/Button right; false otherwise
  init(button: Padded.Button,
       title: String,
       text:String,
       imageName:String?,
       imageLeftAligned: Bool = false
  ) {
    self.imageLeftAligned = imageLeftAligned
    self.button = button
    self.titleLabel.text = title
    self.textLabel.attributedText = text.attributedStringWith(lineHeightMultiplier: 1.25)
    if let img = imageName {
        self.imageView.image = UIImage(named: img)
    }
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
