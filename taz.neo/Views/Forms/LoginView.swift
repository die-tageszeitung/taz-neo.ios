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
  
  @Default("offerTrialSubscription")
  var offerTrialSubscription: Bool
  
  var idInput = TazTextField(placeholder: Localized("login_username_hint"),
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
    lbl.text = "Wo finde ich die AboID?"
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
  
  static var trialSubscriptionButton = Padded.Button(title: "Kostenlos Probelesen")
  
  var trialSubscriptionView: Padded.View = {
    let wrapper = Padded.View()
    var intro:UIView
    let filepath =  Dir.appSupportPath.appending("/taz/resources/trial2.html")
    let trialHtml = File(filepath)
    
    if trialHtml.exists {
      let wv = WebView()
//      wv.webView.load(url: dataPolicy.url)
      wv.load(url: trialHtml.url)
      wv.pinHeight(150)
      wv.isOpaque = false
      wv.backgroundColor = .clear
      intro = wv
    } else {
      let lbl = UILabel()
      lbl.text = Localized("trial_subscription_title")
      lbl.numberOfLines = 0
      lbl.textAlignment = .center
      lbl.contentFont()
      intro = lbl
    }
    
    wrapper.addSubview(intro)
    wrapper.addSubview(trialSubscriptionButton)
    
    pin(intro, to: wrapper, dist: Const.Dist.margin, exclude: .bottom)
    pin(trialSubscriptionButton, to: wrapper, dist: Const.Dist.margin, exclude: .top)
    pin(trialSubscriptionButton.top, to: intro.bottom, dist: Const.Dist.margin)
    
    wrapper.backgroundColor = UIColor.rgb(0xDEDEDE)
    wrapper.layer.cornerRadius = 8.0
    
    wrapper.paddingBottom = miniPadding
    wrapper.paddingTop = miniPadding
    return wrapper
  }()
  
  static let miniPadding = 0.0
  
  override func createSubviews() -> [UIView] {
    idInput.paddingBottom = Self.miniPadding
    passInput.paddingBottom = Self.miniPadding
    if offerTrialSubscription {
       // Dialog mit Probeabo
      return   [
        Padded.Label(title: "Anmeldung für Digital-Abonnent:innen").titleFont(),
        idInput,
        whereIsTheAboId,
        passInput,
        passForgottButton,
        loginButton,
        Padded.Label(title: Localized("trial_subscription_title")),
        registerButton,
        trialSubscriptionView,
        loginTipsButton
      ]
     }
     else {
       // Dialog ohne Probeabo
      return   [
        TazHeader(),
        Padded.Label(title: Localized("login_required")),
        idInput,
        passInput,
        loginButton,
        passForgottButton,
        loginTipsButton
      ]
     }
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
      TazHeader(),
      Padded.Label(title: Localized("connect_abo_id_title")),
      aboIdInput,
      passInput,
      connectButton,
      passForgottButton
    ]
  }
}
