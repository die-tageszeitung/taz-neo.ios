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
class ConnectTazIDController : TrialSubscriptionController {
  
  var aboId:String
  var aboIdPassword:String
  
  init(aboId:String, aboIdPassword:String) {
    self.aboId = aboId
    self.aboIdPassword = aboIdPassword
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: viewDidLoad Action
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =   [
      FormularView.header(),
      FormularView.label(title:
        Localized("taz_id_account_create_intro")),
      mailInput,
      passInput,
      pass2Input,
      firstnameInput,
      lastnameInput,
      FormularView.label(title:
        Localized("fragment_login_request_test_subscription_existing_account")),
      FormularView.labelLikeButton(title: Localized("login_forgot_password"),
                                   target: self,
                                   action: #selector(handlePwForgot)),
      contentView!.agbAcceptTV,
      FormularView.button(title: Localized("login_button"),
                          target: self,
                          action: #selector(handleSend)),
      FormularView.outlineButton(title: Localized("cancel_button"),
                                 target: self,
                                 action: #selector(handleCancel)),
    ]
    super.viewDidLoad()
  }
    
  // MARK: handleLogin Action
  @IBAction override func handleSend(_ sender: UIButton) {
    sender.isEnabled = false
    
    if let errormessage = self.validate() {
      Toast.show(errormessage, .alert)
      sender.isEnabled = true
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
    //spinner.enabler=true
    SharedFeeder.shared.feeder?.subscriptionId2tazId(tazId: mail, password: pass, aboId: self.aboId, aboIdPW: aboIdPassword, surname: lastname, firstName: firstname, installationId: installationId, pushToken: pushToken, closure: { (result) in
      //Re-Enable Button if needed
      sender.isEnabled = true
      //      spinner.enabler=false
      switch result {
        case .success(let info):
          //ToDo #900
          switch info.status {
            /// we are waiting for eMail confirmation (using push/poll)
            case .waitForMail:
              self.registerForSubscriptionPoll(installationId: installationId)
              self.showResultWith(message: Localized("fragment_login_confirm_email_header"),
                                  backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                  dismissType: .all)
            /// valid authentication
            case .valid:
              self.showResultWith(message: Localized("ask_for_trial_subscription_title"),
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
              self.registerForSubscriptionPoll(installationId: installationId)
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
          Toast.show(Localized("error"))
      }
    })
  }
}





