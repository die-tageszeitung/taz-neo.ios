//
//
// TrialSubscriptionView.swift
//
// Created by Ringo Müller-Gromes on 14.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

public class TrialSubscriptionView : FormView{
  
  var mailInput = TazTextField(placeholder: Localized("login_email_hint"),
                               textContentType: .emailAddress,
                               enablesReturnKeyAutomatically: true,
                               keyboardType: .emailAddress,
                               autocapitalizationType: .none)
  
  var passInput = TazTextField(placeholder: Localized("login_password_hint"),
                               textContentType: .password,
                               isSecureTextEntry: true,
                               enablesReturnKeyAutomatically: true)
  
  var pass2Input = TazTextField(placeholder: Localized("login_password_hint"),
                                textContentType: .password,
                                isSecureTextEntry: true,
                                enablesReturnKeyAutomatically: true)
  
  
  var firstnameInput = TazTextField(placeholder: Localized("login_first_name_hint"),
                                    textContentType: .givenName,
                                    enablesReturnKeyAutomatically: true,
                                    keyboardType: .namePhonePad,
                                    autocapitalizationType: .words)
  
  var lastnameInput = TazTextField(placeholder: Localized("login_surname_hint"),
                                   textContentType: .familyName,
                                   enablesReturnKeyAutomatically: true,
                                   keyboardType: .namePhonePad,
                                   autocapitalizationType: .words)
  
  var registerButton = Padded.Button(title: Localized("register_button"))
  
  var cancelButton =  Padded.Button(type:.outline, title: Localized("cancel_button"))
  
  
  // MARK: agbAcceptLabel with Checkbox
  lazy var agbAcceptTV : CheckboxWithText = {
    let view = CheckboxWithText()
    view.textView.isEditable = false
    view.textView.attributedText = Localized("fragment_login_request_test_subscription_terms_and_conditions").htmlAttributed
    view.textView.linkTextAttributes = [.foregroundColor : TazColor.CIColor.color, .underlineColor: UIColor.clear]
    view.textView.font = Const.Fonts.contentFont(size: DefaultFontSize)
    view.textView.textColor = TazColor.HText.color
    return view
  }()
  
  override func createSubviews() -> [UIView] {
    return   [
      TazHeader(),
      Padded.Label(title: Localized("trial_subscription_title")),
      mailInput,
      passInput,
      pass2Input,
      firstnameInput,
      lastnameInput,
      Padded.Label(title:
        Localized("fragment_login_request_test_subscription_existing_account")),
      agbAcceptTV,
      registerButton,
      cancelButton
    ]
  }
  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    
    mailInput.bottomMessage = ""
    passInput.bottomMessage = ""
    pass2Input.bottomMessage = ""
    firstnameInput.bottomMessage = ""
    lastnameInput.bottomMessage = ""
    agbAcceptTV.error = false
    
    if mailInput.isUsed, (mailInput.text ?? "").isEmpty {
      errors = true
      mailInput.bottomMessage = Localized("login_email_error_empty")
    } else if mailInput.isUsed, (mailInput.text ?? "").isValidEmail() == false {
      errors = true
      mailInput.bottomMessage = Localized("login_email_error_no_email")
    }
    
    if passInput.isUsed, (passInput.text ?? "").isEmpty {
      errors = true
      passInput.bottomMessage = Localized("login_password_error_empty")
    }
    else if passInput.isUsed, (passInput.text ?? "").length < 7 {
      errors = true
      passInput.bottomMessage = Localized("password_too_short")
    }
    
    if pass2Input.isUsed, pass2Input.isVisible, (pass2Input.text ?? "").isEmpty {
      errors = true
      pass2Input.bottomMessage = Localized("login_password_error_empty")
    }
    else if pass2Input.isUsed, pass2Input.text != passInput.text {
      pass2Input.bottomMessage = Localized("login_password_confirmation_error_match")
    }
    
    if firstnameInput.isUsed, (firstnameInput.text ?? "").isEmpty {
      errors = true
      firstnameInput.bottomMessage = Localized("login_first_name_error_empty")
    }
    
    if lastnameInput.isUsed, (lastnameInput.text ?? "").isEmpty {
      errors = true
      lastnameInput.bottomMessage = Localized("login_surname_error_empty")
    }
    
    if agbAcceptTV.isUsed, agbAcceptTV.checked == false {
      agbAcceptTV.error = true
      return Localized("register_validation_issue_agb")
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    return nil
  }
}

fileprivate extension UIView{
  var isUsed : Bool{
    get{
      return self.superview != nil && self.isHidden == false
    }
  }
}
