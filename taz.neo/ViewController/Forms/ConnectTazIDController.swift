//
//
// ConnectTazIDController.swift
//
// Created by Ringo Müller-Gromes on 23.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit

// MARK: - ConnectTazIDController
/// Presents Register TazID Form and Functionallity
/// ChildViews/Controller are pushed modaly
class ConnectTazIDController: FormsController {
  
  var mailInput
    = FormularView.textField(placeholder: NSLocalizedString("login_username_hint")
  )
  var passInput
    = FormularView.textField(placeholder: NSLocalizedString("login_password_hint"),
                             textContentType: .password,
                             isSecureTextEntry: true)
  
  var pass2Input
    = FormularView.textField(placeholder: NSLocalizedString("login_password_hint"),
                             textContentType: .password,
                             isSecureTextEntry: true)
      
  var firstnameInput
    = FormularView.textField(placeholder: NSLocalizedString("login_username_hint"))
  
  var lastnameInput
    = FormularView.textField(placeholder: NSLocalizedString("login_username_hint"))
  
  // MARK: viewDidLoad Action
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =   [
         FormularView.header(),
         FormularView.label(title:
          NSLocalizedString("fragment_login_missing_credentials_header_registration")),
         FormularView.labelLikeButton(title: NSLocalizedString("fragment_login_missing_credentials_switch_to_login"),
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
          NSLocalizedString("login_missing_credentials_header_login")),
         contentView!.errorLabel,
         FormularView.button(title: NSLocalizedString("login_button"),
                     target: self,
                     action: #selector(handleSend)),
         FormularView.label(title: NSLocalizedString("trial_subscription_title")),
         FormularView.outlineButton(title: NSLocalizedString("cancel"),
                            target: self,
                            action: #selector(handleCancel)),
       ]
    super.viewDidLoad()
  }
  
  // MARK: handleLogin Action
  @IBAction func handleSend(_ sender: UIButton) {
    mailInput.bottomMessage = "ÄÖÜ Tatügqçµ∑{¿±Á‰£ÆÇÇ"
    passInput.bottomMessage = "ÄÖÜ Tatügqçµ∑{¿±Á‰£ÆÇÇ"
    pass2Input.bottomMessage = "ÄÖÜ Tatügqçµ∑{¿±Á‰£ÆÇÇ"
    firstnameInput.bottomMessage = "ÄÖÜ Tatügqçµ∑{¿±Á‰£ÆÇÇ"
    lastnameInput.bottomMessage = "ÄÖÜ Tatügqçµ∑{¿±Á‰£ÆÇÇ"
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


