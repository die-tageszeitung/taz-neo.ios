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
class ConnectTazIdController : FormsController {
  
  // MARK: vars/const
  var aboId:String
  var aboIdPassword:String
  
  private var contentView = ConnectTazIdView()
  override var ui : ConnectTazIdView { get { return contentView }}
  
  init(aboId:String, aboIdPassword:String, auth:AuthMediator) {
    self.aboId = aboId
    self.aboIdPassword = aboIdPassword
    super.init(auth)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: viewDidLoad
  override func viewDidLoad() {
    super.viewDidLoad()
    ui.alreadyHaveTazIdButton.touch(self, action: #selector(handleAlreadyHaveTazId))
    ui.registerButton.touch(self, action: #selector(handleSubmit))
    ui.cancelButton.touch(self, action: #selector(handleBack))
  }
  
  // MARK: handleLogin Action
  @IBAction func handleAlreadyHaveTazId(_ sender: UIButton) {
        let child = ConnectExistingTazIdController(tazId: (ui.mailInput.text ?? "").trim,
                                                   tazIdPassword: (ui.passInput.text ?? "").trim,
                                                   aboId: aboId,
                                                   aboIdPassword: aboIdPassword,
                                                   auth: auth)
        modalFlip(child)
  }
  
  // MARK: handleLogin Action
  @IBAction func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    
    if let errormessage = ui.validate() {
      Toast.show(errormessage, .alert)
      ui.blocked = false
      return
    }
    
    let mail = ui.mailInput.text ?? ""
    let pass = ui.passInput.text ?? ""
    let lastName = ui.lastnameInput.text ?? ""
    let firstName = ui.firstnameInput.text ?? ""
    
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
                loginCtrl.ui.idInput.text = self.ui.mailInput.text
                loginCtrl.ui.passInput.text = self.ui.passInput.text
              }
              self.showResultWith(message: Localized("subscriptionId2tazId_alreadyLinked"),
                                  backButtonTitle: Localized("back_to_login"),
                                  dismissType: .leftFirst)
            
            case .invalidMail: /// invalid mail address (only syntactic check)
              self.ui.mailInput.bottomMessage = Localized("login_email_error_no_email")
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
      self.ui.blocked = false
    })
  }
}

class ConnectExistingTazIdController : ConnectTazIdController {
  
    convenience init(tazId: String, tazIdPassword: String, aboId:String, aboIdPassword:String, auth:AuthMediator) {
      self.init(aboId: aboId, aboIdPassword: aboIdPassword, auth: auth)
      ui.mailInput.text = tazId
      ui.passInput.text = tazIdPassword
      
      ui.registerButton.setTitle(Localized("login_button"), for: .normal)
      
      ui.views = [
        TazHeader(),
        UILabel(title: Localized("login_missing_credentials_header_login")),
        UIButton(type: .label,
                 title: Localized("fragment_login_missing_credentials_switch_to_registration"),
                 target: self,
                 action: #selector(handleBack)),//just Pop current
        ui.mailInput,
        ui.passInput,
        ui.agbAcceptTV,
        ui.registerButton,
       UIButton(type: .outline,
                  title: Localized("login_forgot_password"),
                  target: self,
                  action: #selector(handlePwForgot)),//just Pop current
        UIButton(type: .label,
                  title: Localized("cancel_button"),
                  target: self,
                  action: #selector(handleBack)),//just Pop current
      ]
    }
  
    // MARK: handleLogin Action
    @IBAction override func handleSubmit(_ sender: UIButton) {
      ui.blocked = true
  
      if let errormessage = self.validate() {
        Toast.show(errormessage, .alert)
        ui.blocked = false
        return
      }
  
      let mail = ui.mailInput.text ?? ""
      let pass = ui.passInput.text ?? ""
      let lastName = ""
      let firstName = ""
  
      self.connectWith(tazId: mail, tazIdPassword: pass, aboId: self.aboId, aboIdPW: self.aboIdPassword, lastName: lastName, firstName: firstName)
    }
  
  @IBAction func handlePwForgot(_ sender: UIButton) {
    modalFlip(PwForgottController(id: ui.mailInput.text?.trim,
                                  auth: auth))
  }
  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    
    ui.mailInput.bottomMessage = ""
    ui.passInput.bottomMessage = ""
    ui.agbAcceptTV.error = false
    
    if (ui.mailInput.text ?? "").isEmpty {
      errors = true
      ui.mailInput.bottomMessage = Localized("login_email_error_empty")
    } else if (ui.mailInput.text ?? "").isValidEmail() == false {
      errors = true
      ui.mailInput.bottomMessage = Localized("login_email_error_no_email")
    }
    
    if (ui.passInput.text ?? "").isEmpty {
      errors = true
      ui.passInput.bottomMessage = Localized("login_password_error_empty")
    }
    
    if ui.agbAcceptTV.checked == false {
      ui.agbAcceptTV.error = true
      return Localized("register_validation_issue_agb")
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    return nil
  }
  
  
}




