//
//
// ConnectTazIdView.swift
//
// Created by Ringo Müller-Gromes on 14.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 
import UIKit
import NorthLib

public class ConnectTazIdView : FormView{
  
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
  
  var alreadyHaveTazIdButton = Padded.Button(type: .label,
                                        title: Localized("login_missing_credentials_switch_to_login"))
  
  var registerButton = Padded.Button(title: Localized("register_button"))
  
  var cancelButton =  Padded.Button(type:.outline, title: Localized("cancel_button"))
  
  
  
  // MARK: agbAcceptLabel with Checkbox
  lazy var agbAcceptTV : CheckboxWithText = {
    let view = CheckboxWithText()
    view.textView.isEditable = false
    view.textView.attributedText = Localized("fragment_login_request_test_subscription_terms_and_conditions").htmlAttributed
    view.textView.linkTextAttributes = [.foregroundColor : Const.SetColor.CIColor.color, .underlineColor: UIColor.clear]
    view.textView.font = Const.Fonts.contentFont(size: DefaultFontSize)
    view.textView.textColor = Const.SetColor.HText.color
    return view
  }()
  
  override func createSubviews() -> [UIView] {
    return [
      TazHeader(),
      Padded.Label(title: Localized("taz_id_account_create_intro")),
      alreadyHaveTazIdButton,
      mailInput,
      passInput,
      pass2Input,
      firstnameInput,
      lastnameInput,
      agbAcceptTV,
      registerButton,
      cancelButton,
    ]
  }
  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    
    mailInput.bottomMessage = ""
    passInput.bottomMessage = ""
    firstnameInput.bottomMessage = ""
    lastnameInput.bottomMessage = ""
    agbAcceptTV.error = false
    
    if (mailInput.text ?? "").isEmpty {
      errors = true
      mailInput.bottomMessage = Localized("login_email_error_empty")
    } else if (mailInput.text ?? "").isValidEmail() == false {
      errors = true
      mailInput.bottomMessage = Localized("login_email_error_no_email")
    }
    
    if (passInput.text ?? "").isEmpty {
      errors = true
      passInput.bottomMessage = Localized("login_password_error_empty")
    }
    else if (passInput.text ?? "").length < 7 {
      errors = true
      passInput.bottomMessage = Localized("password_too_short")
    }
    
    if pass2Input.isVisible, (pass2Input.text ?? "").isEmpty {
      errors = true
      pass2Input.bottomMessage = Localized("login_password_error_empty")
    }
    else if pass2Input.text != passInput.text {
      pass2Input.bottomMessage = Localized("login_password_confirmation_error_match")
    }
    
    if (firstnameInput.text ?? "").isEmpty {
      errors = true
      firstnameInput.bottomMessage = Localized("login_first_name_error_empty")
    }
    
    if (lastnameInput.text ?? "").isEmpty {
      errors = true
      lastnameInput.bottomMessage = Localized("login_surname_error_empty")
    }
    
    
    if agbAcceptTV.checked == false {
      agbAcceptTV.error = true
      return Localized("register_validation_issue_agb")
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    
    return nil
  }
  
  func validateAsRequestTazIdLogin() -> String?{
    var errors = false
    
    mailInput.bottomMessage = ""
    passInput.bottomMessage = ""
    agbAcceptTV.error = false
        
     if (mailInput.text ?? "").isEmpty {
         errors = true
         mailInput.bottomMessage = Localized("login_email_error_empty")
       } else if (mailInput.text ?? "").isValidEmail() == false {
         errors = true
         mailInput.bottomMessage = Localized("login_email_error_no_email")
       }
    
    if (passInput.text ?? "").isEmpty {
      errors = true
      passInput.bottomMessage = Localized("login_password_error_empty")
    }
    
    if agbAcceptTV.checked == false {
      agbAcceptTV.error = true
      return Localized("register_validation_issue_agb")
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    
    return nil
  }
  
  
  
  func validateAsRequestAboIdLogin() -> String?{
    var errors = false
    
    mailInput.bottomMessage = ""
    passInput.bottomMessage = ""
    agbAcceptTV.error = false
        
    if (mailInput.text ?? "").isEmpty {
      errors = true
      mailInput.bottomMessage = Localized("login_subscription_error_empty")
    }
    
    if (passInput.text ?? "").isEmpty {
      errors = true
      passInput.bottomMessage = Localized("login_password_error_empty")
    }
    
    if agbAcceptTV.checked == false {
      agbAcceptTV.error = true
      return Localized("register_validation_issue_agb")
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    
    return nil
  }
  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validateAsRequestName() -> String?{
    var errors = false
    
    firstnameInput.bottomMessage = ""
    lastnameInput.bottomMessage = ""
    agbAcceptTV.error = false
 
    if (firstnameInput.text ?? "").isEmpty {
      errors = true
      firstnameInput.bottomMessage = Localized("login_first_name_error_empty")
    }
    
    if (lastnameInput.text ?? "").isEmpty {
      errors = true
      lastnameInput.bottomMessage = Localized("login_surname_error_empty")
    }
    
    if agbAcceptTV.checked == false {
      agbAcceptTV.error = true
      return Localized("register_validation_issue_agb")
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    
    return nil
  }
}
