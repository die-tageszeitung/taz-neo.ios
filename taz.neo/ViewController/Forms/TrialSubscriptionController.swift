//
//
// TrialSubscriptionController.swift
//
// Created by Ringo Müller-Gromes on 29.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

// MARK: - ConnectTazIDController
/// Presents Register TazID Form and Functionallity
/// ChildViews/Controller are pushed modaly
class TrialSubscriptionController : FormsController {
  
  override public var uiBlocked : Bool {
    didSet{
      super.uiBlocked = uiBlocked
      submitButton.isEnabled = !uiBlocked
    }
  }
  
  let mailInput
    = TazTextField(placeholder: Localized("login_email_hint"),
                   textContentType: .emailAddress,
                   enablesReturnKeyAutomatically: true,
                   keyboardType: .emailAddress,
                   autocapitalizationType: .none
  )
  
  let passInput
    = TazTextField(placeholder: Localized("login_password_hint"),
                   textContentType: .password,
                   isSecureTextEntry: true,
                   enablesReturnKeyAutomatically: true)
  
  let pass2Input
    = TazTextField(placeholder: Localized("login_password_hint"),
                   textContentType: .password,
                   isSecureTextEntry: true,
                   enablesReturnKeyAutomatically: true)
  
  let firstnameInput
    = TazTextField(placeholder: Localized("login_first_name_hint"),
                   textContentType: .givenName,
                   enablesReturnKeyAutomatically: true,
                   keyboardType: .namePhonePad,
                   autocapitalizationType: .words
  )
  
  let lastnameInput
    = TazTextField(placeholder: Localized("login_surname_hint"),
                   textContentType: .familyName,
                   enablesReturnKeyAutomatically: true,
                   keyboardType: .namePhonePad,
                   autocapitalizationType: .words
  )
  
  let submitButton = UIButton(title: Localized("register_button"),
           target: self,
           action: #selector(handleSend))
  
  override func getContentViews() -> [UIView] {
    contentView.agbAcceptTV.textView.delegate = self
    return  [
      TazHeader(),
      UILabel(title: Localized("trial_subscription_title")),
      mailInput,
      passInput,
      pass2Input,
      firstnameInput,
      lastnameInput,
      UILabel(title:
        Localized("fragment_login_request_test_subscription_existing_account")),
      //      FormularView.labelLikeButton(title: Localized("login_forgot_password"),
      //                                   target: self,
      //                                   action: #selector(handlePwForgot)),
      contentView.agbAcceptTV,
      submitButton,
      defaultCancelButton
    ]
  }
  
  // MARK: handlePwForgot Action
  @IBAction func handlePwForgot(_ sender: UIButton) {
    let child = PwForgottController(auth)
    child.idInput.text = mailInput.text?.trim
    child.modalPresentationStyle = .overCurrentContext
    child.modalTransitionStyle = .flipHorizontal
    self.present(child, animated: true, completion: nil)
  }
  
  // MARK: handleLogin Action
  @IBAction func handleSend(_ sender: UIButton) {
    self.uiBlocked = true
    
    if let errormessage = self.validate() {
      Toast.show(errormessage, .alert)
      self.uiBlocked = false
      return
    }
    
    let mail = mailInput.text ?? ""
    let pass = passInput.text ?? ""
    let lastname = lastnameInput.text ?? ""
    let firstname = firstnameInput.text ?? ""
    
    let dfl = Defaults.singleton
    let pushToken = dfl["pushToken"]
    let installationId = dfl["installationId"] ?? App.installationId
    
    //Start mutationSubscriptionId2tazId
    auth.feeder.trialSubscription(tazId: mail, password: pass, surname: lastname, firstName: firstname, installationId: installationId, pushToken: pushToken, closure: { (result) in
      switch result {
        case .success(let info):
          switch info.status {
            /// we are waiting for eMail confirmation (using push/poll)
            case .waitForMail:
              self.showResultWith(message: Localized("fragment_login_confirm_email_header"),
                                  backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                  dismissType: .all)
              self.auth.pollSubscription(tmpId: mail, tmpPassword: pass)
            /// valid authentication
            case .valid:
              self.showResultWith(message: Localized("fragment_login_registration_successful_header"),
                                  backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                  dismissType: .all)
            /// valid tazId connected to different AboId
            case .alreadyLinked:
              if let loginCtrl = self.presentingViewController as? LoginController {
                loginCtrl.idInput.text = self.mailInput.text
                loginCtrl.passInput.text = self.passInput.text
              }
              self.showResultWith(message: Localized("subscriptionId2tazId_alreadyLinked"),
                                  backButtonTitle: Localized("back_to_login"),
                                  dismissType: .leftFirst)
            /// invalid mail address (only syntactic check)
            case .invalidMail:
              self.mailInput.bottomMessage = Localized("login_email_error_no_email")
              Toast.show(Localized("register_validation_issue"))
            /// tazId not verified
            case .tazIdNotValid:
              Toast.show(Localized("toast_login_failed_retry"))//ToDo
            /// AboId not verified
            /// server will confirm later (using push/poll)
            case .waitForProc:
              self.auth.pollSubscription(tmpId: mail, tmpPassword: pass)
            case .subscriptionIdNotValid:
              fallthrough
            /// AboId valid but connected to different tazId
            case .invalidConnection:
              fallthrough
            /// user probably didn't confirm mail
            case .noPollEntry:
              fallthrough
            /// account provided by token is expired
            case .expired:
              fallthrough
            /// no surname provided - seems to be necessary fro trial subscriptions
            case .noSurname:
              fallthrough
            /// no firstname provided
            case .noFirstname:
              fallthrough
            case .unknown:  /// decoded from unknown string
              fallthrough
            default:
              Toast.show(Localized("toast_login_failed_retry"))
              print("Succeed with status: \(info.status) message: \(info.message ?? "-")")
        }
        case .failure:
          Toast.show(Localized("toast_login_failed_retry"))
      }
      self.uiBlocked = false
    })
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
    else if (passInput.text ?? "").length < 7 {
      errors = true
      passInput.bottomMessage = Localized("password_too_short")
    }
    
    if (pass2Input.text ?? "").isEmpty {
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





