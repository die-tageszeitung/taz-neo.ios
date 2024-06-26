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
  
  var registerButton = Padded.Button(type: .outline,
                                title: Localized("register_free_button"))
  
  var marketingContainer: MarketingContainerWrapperView = MarketingContainerWrapperView()
  
  var buttonWidthConstraint: NSLayoutConstraint?
  
  var helpButton: Padded.View = {
    let lbl = UILabel()
    lbl.text = "Hilfe"
    lbl.contentFont(size: Const.Size.SmallerFontSize)
    lbl.accessibilityTraits = .button
    lbl.textColor = Const.SetColor.taz2(.text_icon_grey).color
    lbl.addBorderView(Const.SetColor.taz2(.text_icon_grey).color, edge: UIRectEdge.bottom)
    let wrapper = Padded.View()
    wrapper.addSubview(lbl)
    //Allow label to shink if wrapper shrinks, not alow to grow more than needed
    pin(lbl, to: wrapper).right.priority = .defaultLow
    lbl.setContentHuggingPriority(.required, for: .horizontal)
    lbl.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    wrapper.paddingTop = 5.0
    return wrapper
  }()
  
  var passForgottButton: Padded.View = {
    let lbl = UILabel()
    lbl.text = Localized("login_forgot_password")
    lbl.contentFont(size: Const.Size.SmallerFontSize)
    lbl.accessibilityTraits = .button
    lbl.textColor = Const.SetColor.taz2(.text_icon_grey).color
    lbl.addBorderView(Const.SetColor.taz2(.text_icon_grey).color, edge: UIRectEdge.bottom)
    let wrapper = Padded.View()
    wrapper.addSubview(lbl)
    //Allow label to shink if wrapper shrinks, not alow to grow more than needed
    pin(lbl, to: wrapper).right.priority = .defaultLow
    lbl.setContentHuggingPriority(.required, for: .horizontal)
    lbl.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    wrapper.paddingTop = 5.0
    return wrapper
  }()
  
    
  var trialSubscriptionButton
  = Padded.Button(type: .outline, title: Localized("login_trial_subscription_button_text"))
  var switchButton
  = Padded.Button(type: .outline, title: Localized("login_switch_print2digi_button_text"))
  var extendButton
  = Padded.Button(type: .outline, title: Localized("login_extend_print_with_digi_button_text"))
    
  override public func updateCustomConstraints() {
    super.updateCustomConstraints()
    let isTabletLayout = isTabletLayout
    buttonWidthConstraint?.isActive = isTabletLayout
    marketingContainer.updateCustomConstraints(isTabletLayout: isTabletLayout)
  }
  
  override func createSubviews() -> [UIView] {
    let label
    = Padded.Label(title: "Anmeldung für Digital-Abonnent:innen")
    label.boldContentFont(size: Const.Size.DT_Head_extrasmall).align(.left)
    label.paddingBottom = 25.0
    label.accessibilityTraits = .none
    idInput.accessibilityTraits = .none
    
    let loginWrapper = loginButton.centeredWrapper()
    
    idInput.accessibilityLabel = "Eingabe E-Mail-Adresse oder Abo Ei Di"
    
    helpButton.paddingBottom = 25.0
    passForgottButton.paddingBottom = Const.Dist2.m15
    loginWrapper.paddingBottom = Const.Dist2.l

    if App.isLMD {
      return   [
        label,
        idInput,
        helpButton,
        passInput,
        loginWrapper]
    }
    return   [
      label,
      idInput,
      helpButton,
      passInput,
      passForgottButton,
      loginWrapper,
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
                                     imageName: "BundledResources/switch.jpg")
    let dottedLine2 = dottedLine()
    let mc3 = MarketingContainerView(button: extendButton,
                                     title: Localized("login_extend_print_with_digi_title"),
                                     text: Localized("login_extend_print_with_digi_body"),
                                     imageName: "BundledResources/extend.jpg")
    marketingContainer.addViewToWrapper(mc1)
    marketingContainer.addViewToWrapper(dottedLine1)
    marketingContainer.addViewToWrapper(mc2)
    marketingContainer.addViewToWrapper(dottedLine2)
    marketingContainer.addViewToWrapper(mc3)
    pin(dottedLine1.left, to: marketingContainer.wrapper.left)
    pin(dottedLine1.right, to: marketingContainer.wrapper.right)
    pin(mc2.left, to: marketingContainer.wrapper.left)
    pin(mc2.right, to: marketingContainer.wrapper.right)
    pin(dottedLine2.left, to: marketingContainer.wrapper.left)
    pin(dottedLine2.right, to: marketingContainer.wrapper.right)
    pin(mc3.left, to: marketingContainer.wrapper.left)
    pin(mc3.right, to: marketingContainer.wrapper.right)
    
    pin(mc1, to: marketingContainer.wrapper, exclude: .bottom)
    pin(dottedLine1.top, to: mc1.bottom, dist: Const.Dist2.l)
    pin(mc2.top, to: dottedLine1.bottom, dist: Const.Dist2.m15)
    pin(dottedLine2.top, to: mc2.bottom, dist: Const.Dist2.l)
    pin(mc3.top, to: dottedLine2.bottom, dist: Const.Dist2.m15)
    pin(mc3.bottom,
        to: marketingContainer.wrapper.bottom,
        dist: -2*Const.Dist2.l)///2 times because of overflow in scrollview to hide grey bg
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
