//
//
// ConnectExistingTazIdController.swift
//
// Created by Ringo Müller-Gromes on 12.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

class ConnectExistingTazIdController : CreateTazIDController {
  
  init(tazId: String, tazIdPassword: String, aboId:String, aboIdPassword:String, auth:AuthMediator) {
    super.init(aboId: aboId, aboIdPassword: aboIdPassword, auth: auth)
    self.mailInput.text = tazId
    self.passInput.text = tazIdPassword
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func getContentViews() -> [UIView] {
    contentView.agbAcceptTV.textView.delegate = self
    submitButton.setTitle(Localized("login_button"), for: .normal)
    return [
      TazHeader(),
      UILabel(title: Localized("login_missing_credentials_header_login")),
      UIButton(type: .label,
               title: Localized("fragment_login_missing_credentials_switch_to_registration"),
               target: self,
               action: #selector(handleDefaultCancel)),//just Pop current
      mailInput,
      passInput,
      contentView.agbAcceptTV,
      submitButton,
      defaultCancelButton,
      defaultPWForgotButton
    ]
  }
  
  // MARK: handleLogin Action
  @IBAction override func handleSend(_ sender: UIButton) {
    uiBlocked = true
    
    if let errormessage = self.validate() {
      Toast.show(errormessage, .alert)
      uiBlocked = false
      return
    }
    
    let mail = mailInput.text ?? ""
    let pass = passInput.text ?? ""
    let lastName = ""
    let firstName = ""
    
    self.connectWith(tazId: mail, tazIdPassword: pass, aboId: self.aboId, aboIdPW: self.aboIdPassword, lastName: lastName, firstName: firstName)
  }
  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  override func validate() -> String?{
    var errors = false
    
    mailInput.bottomMessage = ""
    passInput.bottomMessage = ""
    self.contentView.agbAcceptTV.error = false
    
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
    if self.contentView.agbAcceptTV.checked == false {
      self.contentView.agbAcceptTV.error = true
      return Localized("register_validation_issue_agb")
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    
    return nil
  }
}
