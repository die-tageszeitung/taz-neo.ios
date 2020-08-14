//
//
// LoginView.swift
//
// Created by Ringo Müller-Gromes on 14.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit

public class LoginView : FormView{
  
  var idInput = TazTextField(placeholder: Localized("login_username_hint"),
                             textContentType: .emailAddress,
                             enablesReturnKeyAutomatically: true,
                             keyboardType: .emailAddress,
                             autocapitalizationType: .none)
  
  var passInput = TazTextField(placeholder: Localized("login_password_hint"),
                               textContentType: .password,
                               isSecureTextEntry: true,
                               enablesReturnKeyAutomatically: true)
  
  var loginButton = UIButton(title: Localized("login_button"))
  
  var registerButton = UIButton(type: .outline,
                                title: Localized("register_button"))
  
  var passForgottButton = UIButton(type: .label,
                                   title: Localized("login_forgot_password"))
  
  override func createSubviews() -> [UIView] {
    passForgottButton.isHidden = true
    return   [
      TazHeader(),
      UILabel(title: Localized("article_read_onreadon")),
      idInput,
      passInput,
      loginButton,
      UILabel(title: Localized("ask_for_trial_subscription_title")),
      registerButton,
      passForgottButton
    ]
  }
}
