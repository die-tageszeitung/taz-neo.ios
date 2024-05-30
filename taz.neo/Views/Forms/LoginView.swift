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
    
  func marketingContainerWidth(button: Padded.Button,
                               htmlFile:String,
                               htmlHeight:CGFloat = 150,
                               fallbackTitle: String?,
                               fallbackText:String,
                               fallbackImage:String?) -> Padded.View{
    let wrapper = Padded.View()
    var intro:UIView
    let trialHtml = File(htmlFile)
    
    if trialHtml.exists {//deactivated for release
      let wv = WebView()
      wv.whenLoaded {_ in
        wv.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, error) in
          wv.pinHeight((height as! CGFloat) - 15.0)
        })
      }
      wv.pinHeight(80, priority: .defaultLow)
      wv.load(url: trialHtml.url)
      wv.isOpaque = true
      wv.backgroundColor = .clear
      intro = wv
    } else {
      let lbl = UILabel()
      lbl.text = fallbackText
      lbl.numberOfLines = 0
      lbl.textAlignment = .left
      lbl.contentFont()
      
      if let title = fallbackTitle, title.length > 0 {
        let tl = UILabel()
        tl.text = title
        tl.numberOfLines = 0
        tl.textAlignment = .left
        tl.contentFont(size: Const.Size.SubtitleFontSize)
        let wrapper = UIStackView()
        wrapper.axis = .vertical
        wrapper.spacing = 6.0
        wrapper.alignment = .top
        wrapper.distribution = .fillProportionally
        wrapper.addArrangedSubview(tl)
        wrapper.addArrangedSubview(lbl)
        intro = wrapper
      }
      else {
        intro = lbl
      }
    }
    
    wrapper.addSubview(intro)
    wrapper.addSubview(button)
    wrapper.backgroundColor = Const.SetColor.HBackground.color
    
    pin(intro, to: wrapper, dist: Const.Dist.margin, exclude: .bottom)
    pin(button.left, to: wrapper.left, dist: Const.Size.DefaultPadding)
    pin(button.right, to: wrapper.right, dist: -Const.Size.DefaultPadding)
    pin(button.top, to: intro.bottom, dist: Const.Dist.margin)
    
    if intro is WebView && button != extendButton {
      let dottedLine = DottedLineView()
      dottedLine.pinHeight(DottedLineView.DottedLineDefaultHeight)
      dottedLine.backgroundColor = .clear
      dottedLine.fillColor = Const.SetColor.ios(.label).color
      dottedLine.strokeColor = Const.SetColor.ios(.label).color
      dottedLine.offset = 1.2
      wrapper.addSubview(dottedLine)
      pin(dottedLine.top, to: button.bottom, dist: 40.0)
      pin(dottedLine.left, to: wrapper.left, dist: Const.Size.DefaultPadding)
      pin(dottedLine.right, to: wrapper.right, dist: -Const.Size.DefaultPadding)
      pin(dottedLine.bottom, to: wrapper.bottom, dist: 0)
    }
    else {
      pin(button.bottom, to: wrapper.bottom, dist: -Const.Dist.margin)
    }
    
    return wrapper
    
  }
  
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
  
  func setup(){
    let mc1 = marketingContainerWidth(button: trialSubscriptionButton,
                                      htmlFile: Dir.appSupportPath.appending("/taz/resources/trial.html"),
                                      fallbackTitle: Localized("login_trial_subscription_title"),
                                      fallbackText: Localized("login_trial_subscription_body"),
                                      fallbackImage: Dir.appSupportPath.appending("/taz/resources/trial.jpg"))
    let mc2 = marketingContainerWidth(button: switchButton,
                                      htmlFile: Dir.appSupportPath.appending("/taz/resources/switch.html"),
                                      fallbackTitle: Localized("login_switch_print2digi_title"),
                                      fallbackText: Localized("login_switch_print2digi_body"),
                                      fallbackImage: Dir.appSupportPath.appending("/taz/resources/switch.jpg"))
    let mc3 = marketingContainerWidth(button: extendButton,
                                      htmlFile: Dir.appSupportPath.appending("/taz/resources/extend.html"),
                                      fallbackTitle: Localized("login_extend_print_with_digi_title"),
                                      fallbackText: Localized("login_extend_print_with_digi_body"),
                                      fallbackImage: Dir.appSupportPath.appending("/taz/resources/extend.jpg"))
    marketingContainer.addSubview(mc1)
    marketingContainer.addSubview(mc2)
    marketingContainer.addSubview(mc3)
    pin(mc1, to: marketingContainer, exclude: .bottom)
    pin(mc2.left, to: marketingContainer.left)
    pin(mc2.right, to: marketingContainer.right)
    pin(mc3.left, to: marketingContainer.left)
    pin(mc3.right, to: marketingContainer.right)
    pin(mc3.bottom, to: marketingContainer.bottom, dist: -30.0)
    pin(mc2.top, to: mc1.bottom)
    pin(mc3.top, to: mc2.bottom)
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
