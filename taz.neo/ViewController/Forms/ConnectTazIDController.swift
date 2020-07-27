//
//
// ConnectTazIDController.swift
//
// Created by Ringo Müller-Gromes on 23.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

// MARK: - ConnectTazIDController
/// Presents Register TazID Form and Functionallity
/// ChildViews/Controller are pushed modaly
class ConnectTazIDController: FormsController {
  
  var mailInput
    = FormularView.textField(placeholder: Localized("login_email_hint")
  )
  var passInput
    = FormularView.textField(placeholder: Localized("login_password_hint"),
                             textContentType: .password,
                             isSecureTextEntry: true)
  
  var pass2Input
    = FormularView.textField(placeholder: Localized("login_password_confirmation_hint"),
                             textContentType: .password,
                             isSecureTextEntry: true)
      
  var firstnameInput
    = FormularView.textField(placeholder: Localized("login_first_name_hint"))
  
  var lastnameInput
    = FormularView.textField(placeholder: Localized("login_surname_hint"))
  
  // MARK: viewDidLoad Action
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =   [
         FormularView.header(),
         FormularView.label(title:
          Localized("login_missing_credentials_header_registration")),
         FormularView.labelLikeButton(title: Localized("fragment_login_missing_credentials_switch_to_login"),
                                      paddingTop: 0,
          paddingBottom: 0,
                             target: self,
                             action: #selector(handleAlreadyHaveTazID)),
         mailInput,
         passInput,
         pass2Input,
         firstnameInput,
         lastnameInput,
         FormularView.label(title:
          Localized("login_missing_credentials_header_login")),
         contentView!.agbAcceptTV,
         FormularView.button(title: Localized("login_button"),
                     target: self,
                     action: #selector(handleSend)),
         FormularView.label(title: Localized("trial_subscription_title")),
         FormularView.outlineButton(title: Localized("cancel"),
                            target: self,
                            action: #selector(handleCancel)),
       ]
    super.viewDidLoad()
    contentView!.agbAcceptTV.pinHeight(100)
  }
  
  // MARK: handleLogin Action
  @IBAction func handleSend(_ sender: UIButton) {
    var errors = false
    
    mailInput.bottomMessage = ""
    passInput.bottomMessage = ""
    pass2Input.bottomMessage = ""
    firstnameInput.bottomMessage = ""
    lastnameInput.bottomMessage = ""
    
    if (mailInput.text ?? "").isEmpty {
      errors = true
      mailInput.bottomMessage = Localized("login_email_error_empty")
    }
    else if mailInput.text?.isValidEmail() == false {
      mailInput.bottomMessage = Localized("login_email_error_no_email")
    }
    
    if (passInput.text ?? "").isEmpty {
      errors = true
      passInput.bottomMessage = Localized("login_password_error_empty")
    }
    
    if (pass2Input.text ?? "").isEmpty {
      errors = true
      pass2Input.bottomMessage = Localized("login_password_error_empty")
    }
    else if passInput.text != pass2Input.text {
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
    
    if errors {
      Toast.show("Es sind fehler aufgetreten Es sind fehler aufgetreten Es sind fehler aufgetreten Es sind fehler aufgetreten bla\n\nbla la la Es sind fehler aufgetreten Es sind fehler aufgetreten Es sind fehler aufgetreten\n\nBye!", .alert)
          Toast.show("Bye!")
      return
      
    }

  }
  
  // MARK: handleLogin Action
  @IBAction func handleCancel(_ sender: UIButton) {
    self.dismiss(animated: true, completion: nil)
  }
  
  @IBAction func handleAlreadyHaveTazID(_ sender: UIButton) {
    let child = LoginWithTazIDController()
    child.modalPresentationStyle = .overCurrentContext
    child.modalTransitionStyle = .flipHorizontal
    self.present(child, animated: true, completion: nil)
  }
}


