//
//
// LoginView.swift
//
// Created by Ringo Müller-Gromes on 14.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

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
  
  var loginButton = Padded.PUIButton(title: Localized("login_button"))
  
  var registerButton = Padded.PUIButton(type: .outline,
                                title: Localized("register_button"))
  
  var passForgottButton = Padded.PUIButton(type: .label,
                                   title: Localized("login_forgot_password"))
  
  var helpLabel = Padded.PUILabel(title: Localized("help"))
  override func createSubviews() -> [UIView] {
    helpLabel.textColor = TazColor.CIColor.color
    helpLabel.onTapping {  _ in
      Alert.message(title: Localized("help"), message: Localized("article_read_onreadon"))
    }
    return   [
      TazHeader(),
      Padded.PUILabel(title: Localized("login_required")),
      idInput,
      passInput,
      loginButton,
      Padded.PUILabel(title: Localized("ask_for_trial_subscription_title")),
      registerButton,
      passForgottButton,
      helpLabel
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
  
  var connectButton = Padded.PUIButton(title: Localized("connect_this_abo_id_with_taz_id"))
  
  override func createSubviews() -> [UIView] {
    loginButton.setTitle(Localized("connect_this_abo_id_with_taz_id"), for: .normal)
    return   [
      TazHeader(),
      Padded.PUILabel(title: Localized("connect_abo_id_title")),
      aboIdInput,
      passInput,
      connectButton,
      passForgottButton
    ]
  }
}
