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
class CreateTazIDController : TrialSubscriptionController {
  
  var aboId:String
  var aboIdPassword:String
  
  init(aboId:String, aboIdPassword:String, auth:AuthMediator) {
    self.aboId = aboId
    self.aboIdPassword = aboIdPassword
    super.init(auth)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func getContentViews() -> [UIView] {
    contentView.agbAcceptTV.textView.delegate = self
    submitButton.setTitle(Localized("login_button"), for: .normal)
    return [
      TazHeader(),
      UILabel(title: Localized("taz_id_account_create_intro")),
      UIButton(type: .label,
               title: Localized("login_missing_credentials_switch_to_login"),
               target: self,
               action: #selector(handleAlreadyHaveTazId)),
      mailInput,
      passInput,
      pass2Input,
      firstnameInput,
      lastnameInput,
      contentView.agbAcceptTV,
      submitButton,
      defaultCancelButton,
      defaultPWForgotButton
    ]
  }
  
  // MARK: handleLogin Action
  @IBAction func handleAlreadyHaveTazId(_ sender: UIButton) {
    let child = ConnectExistingTazIdController(tazId: (mailInput.text ?? "").trim,
                                               tazIdPassword: (passInput.text ?? "").trim,
                                               aboId: aboId,
                                               aboIdPassword: aboIdPassword,
                                               auth: auth)
    modalFlip(child)
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
    let lastName = lastnameInput.text ?? ""
    let firstName = firstnameInput.text ?? ""
    
    self.connectWith(tazId: mail, tazIdPassword: pass, aboId: self.aboId, aboIdPW: self.aboIdPassword, lastName: lastName, firstName: firstName)
  }
  
  
  func connectWith(tazId: String, tazIdPassword: String, aboId: String, aboIdPW: String, lastName: String, firstName: String){
    
    let dfl = Defaults.singleton
    let pushToken = dfl["pushToken"]
    let installationId = dfl["installationId"] ?? App.installationId
    
    //Start mutationSubscriptionId2tazId
    //spinner.enabler=true
    auth.feeder.subscriptionId2tazId(tazId: tazId, password: tazIdPassword, aboId: self.aboId, aboIdPW: aboIdPassword, surname: lastName, firstName: firstName, installationId: installationId, pushToken: pushToken, closure: { (result) in
      switch result {
        case .success(let info):
          switch info.status {
            case .valid:/// valid authentication
              DefaultAuthenticator.storeUserData(id: tazId, password: tazIdPassword, token: info.token ?? "")
              self.showResultWith(message: Localized("fragment_login_registration_successful_header"),
                                  backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                  dismissType: .all)
              self.auth.authenticationSucceededClosure?(nil)
            case .waitForMail:///user need to confirm mail
              if (info.token ?? "").length > 0 {//@ToDo Maybe API Change
                DefaultAuthenticator.storeUserData(id: tazId, password: tazIdPassword, token: info.token ?? "")
                self.showResultWith(message: Localized("fragment_login_registration_successful_header"),
                                       backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                       dismissType: .all)
                self.auth.authenticationSucceededClosure?(nil)
                return
              }
              self.showResultWith(message: Localized("fragment_login_confirm_email_header"),
                                  backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                  dismissType: .all)
              self.auth.pollSubscription(tmpId: tazId, tmpPassword: tazIdPassword)
            case .alreadyLinked:/// valid tazId connected to different AboId
              if let loginCtrl = self.presentingViewController as? LoginController {
                loginCtrl.idInput.text = self.mailInput.text
                loginCtrl.passInput.text = self.passInput.text
              }
              self.showResultWith(message: Localized("subscriptionId2tazId_alreadyLinked"),
                                  backButtonTitle: Localized("back_to_login"),
                                  dismissType: .leftFirst)
           
            case .invalidMail: /// invalid mail address (only syntactic check)
              self.mailInput.bottomMessage = Localized("login_email_error_no_email")
              Toast.show(Localized("register_validation_issue"))
            /// tazId not verified
            case .tazIdNotValid:
              Toast.show(Localized("toast_login_failed_retry"))//ToDo
            case .waitForProc:// AboId not verified, server will confirm later (using push/poll)
              self.auth.pollSubscription(tmpId: tazId, tmpPassword: tazIdPassword)
            case .subscriptionIdNotValid:
              fallthrough
            case .invalidConnection:/// AboId valid but connected to different tazId
              fallthrough
            case .noPollEntry: /// user probably didn't confirm mail
              fallthrough
            case .expired: /// account provided by token is expired
              fallthrough
            case .noSurname:/// no surname provided - seems to be necessary fro trial subscriptions
              fallthrough
            case .noFirstname: /// no firstname provided
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
      //Re-Enable Button if needed
      self.uiBlocked = false
    })
  }
}





