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
  
  var whereIsTheAboId: Padded.View = {
    let lbl = UILabel()
    lbl.text = "Hilfe"
    lbl.contentFont(size: Const.Size.MiniPageNumberFontSize)
    lbl.textColor = .gray
    lbl.addBorderView(.gray, edge: UIRectEdge.bottom)
    let wrapper = Padded.View()
    wrapper.addSubview(lbl)
    //Allow label to shink if wrapper shrinks, not alow to grow more than needed
    pin(lbl, to: wrapper).right.priority = .defaultLow
    lbl.setContentHuggingPriority(.required, for: .horizontal)
    lbl.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    wrapper.paddingBottom = miniPadding
    wrapper.paddingTop = miniPadding
    return wrapper
  }()
  
  var passForgottButton: Padded.View = {
    let lbl = UILabel()
    lbl.text = Localized("login_forgot_password")
    lbl.contentFont(size: Const.Size.MiniPageNumberFontSize)
    lbl.textColor = .gray
    lbl.addBorderView(.gray, edge: UIRectEdge.bottom)
    let wrapper = Padded.View()
    wrapper.addSubview(lbl)
    //Allow label to shink if wrapper shrinks, not alow to grow more than needed
    pin(lbl, to: wrapper).right.priority = .defaultLow
    lbl.setContentHuggingPriority(.required, for: .horizontal)
    lbl.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    wrapper.paddingBottom = miniPadding
    wrapper.paddingTop = miniPadding
    return wrapper
  }()
  
  var trialSubscriptionButton = Padded.Button(title: Localized("login_trial_subscription_button_text"))
  var switchButton = Padded.Button(title: Localized("login_switch_print2digi_button_text"))
  var extendButton = Padded.Button(title: Localized("login_extend_print_with_digi_button_text"))
    
  func marketingContainerWidth(button: Padded.Button,
                               htmlFile:String,
                               htmlHeight:CGFloat = 150,
                               fallbackTitle: String?,
                               fallbackText:String) -> Padded.View{
    let wrapper = Padded.View()
    var intro:UIView
    let trialHtml = File(htmlFile)
    
    if false && trialHtml.exists {//deactivated for release
      let wv = WebView()
      wv.whenLoaded {_ in
        wv.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, error) in
          wv.pinHeight((height as! CGFloat) - 15.0)
        })
      }
      wv.load(url: trialHtml.url)
      wv.isOpaque = false
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
    
    pin(intro, to: wrapper, dist: Const.Dist.margin, exclude: .bottom)
    pin(button, to: wrapper, dist: Const.Dist.margin, exclude: .top)
    pin(button.top, to: intro.bottom, dist: Const.Dist.margin)
    
    wrapper.backgroundColor = Const.SetColor.taz(.secondaryBackground).color
    wrapper.layer.cornerRadius = 8.0
    
    return wrapper
    
  }
  
  static let miniPadding = 0.0
  
  override func createSubviews() -> [UIView] {
    idInput.paddingBottom = Self.miniPadding
    passInput.paddingBottom = Self.miniPadding
    if App.isLMD {
      return   [
        Padded.Label(title: "Anmeldung für Digital-Abonnent:innen").contentFont(size: Const.Size.SubtitleFontSize).align(.left),
        idInput,
        whereIsTheAboId,
        passInput,
        loginButton]
    }
    
    
    return   [
      Padded.Label(title: "Anmeldung für Digital-Abonnent:innen").contentFont(size: Const.Size.SubtitleFontSize).align(.left),
      idInput,
      whereIsTheAboId,
      passInput,
      passForgottButton,
      loginButton,
      marketingContainerWidth(button: trialSubscriptionButton,
                              htmlFile: Dir.appSupportPath.appending("/taz/resources/trialNOTEXISTFALLBACHTEST.html"),
                              fallbackTitle: Localized("login_trial_subscription_title"),
                              fallbackText: Localized("login_trial_subscription_body")),
      marketingContainerWidth(button: switchButton,
                              htmlFile: Dir.appSupportPath.appending("/taz/resources/switch1.html"),
                              fallbackTitle: Localized("login_switch_print2digi_title"),
                              fallbackText: Localized("login_switch_print2digi_body")),
      marketingContainerWidth(button: extendButton,
                              htmlFile: Dir.appSupportPath.appending("/taz/resources/extend1.html"),
                              fallbackTitle: Localized("login_extend_print_with_digi_title"),
                              fallbackText: Localized("login_extend_print_with_digi_body"))
    ]
  }
  
  // MARK: validate()
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    idInput.bottomMessage = ""
    passInput.bottomMessage = ""
    
    if (idInput.text ?? "").isEmpty {
      idInput.bottomMessage = Localized("login_username_error_empty")
      errors = true
    }
    
    if (passInput.text ?? "").isEmpty {
      passInput.bottomMessage = Localized("login_password_error_empty")
      errors = true
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    return nil
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
