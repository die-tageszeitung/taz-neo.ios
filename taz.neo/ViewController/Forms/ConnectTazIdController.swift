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
  var onMissingNameRequested:(()->())?
  
  fileprivate var contentView = ConnectTazIdView()
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
    ui.agbAcceptTV.textView.delegate = self ///FormsController cares
  }
  
  // MARK: handleLogin Action
  @IBAction func handleAlreadyHaveTazId(_ sender: UIButton) {
    let child = ConnectTazIdRequestTazIdCtrl(aboId: self.aboId,
                                             aboIdPassword: self.aboIdPassword,
                                             auth: auth)
    ///may the user already wrote its credentials before he recognize there is a already have taz-Id button
    child.ui.mailInput.text = ui.mailInput.text
    child.ui.passInput.text = ui.passInput.text
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
  
  
  func connectWith(tazId: String, tazIdPassword: String, aboId _aboId: String, aboIdPW _aboIdPassword: String, lastName: String? = nil, firstName: String?=nil){
    
    let dfl = Defaults.singleton
    let pushToken = dfl["pushToken"]
    let installationId = dfl["installationId"] ?? App.installationId
    
    //Start mutationSubscriptionId2tazId
    //spinner.enabler=true
    auth.feeder.subscriptionId2tazId(tazId: tazId, password: tazIdPassword, aboId: _aboId, aboIdPW: _aboIdPassword, surname: lastName, firstName: firstName, installationId: installationId, pushToken: pushToken, closure: { (result) in
      switch result {
        case .success(let info):
          switch info.status {
            case .valid:/// valid authentication
              DefaultAuthenticator.storeUserData(id: tazId, password: tazIdPassword, token: info.token ?? "")
              self.showResultWith(message: Localized("tazid_connect_create_successful_header"),
                                  backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                  dismissType: .all)
              self.auth.authenticationSucceededClosure?(nil)
            case .waitForMail:///user need to confirm mail
              self.showResultWith(message: Localized(keyWithFormat: "fragment_login_confirm_email_header", tazId),
                                  backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                  dismissType: .all)
              self.auth.pollSubscription(tmpId: tazId,
                                         tmpPassword: tazIdPassword,
                                         requestSoon: false,
                                         resultSuccessText: Localized("tazid_connect_create_successful_header"))
            case .alreadyLinked:/// valid tazId connected to different AboId
              if let loginCtrl = self.baseLoginController {
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
            case .nameTooLong:
              self.ui.lastnameInput.bottomMessage = Localized("too_many_chars")
              self.ui.firstnameInput.bottomMessage = Localized("too_many_chars")
              Toast.show(Localized("name_too_long_issue"))
            case .waitForProc:// AboId not verified, server will confirm later (using push/poll)
              self.showResultWith(message: Localized("wait_for_proc_result_Text"),
                                              backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                              dismissType: .all)
              self.auth.pollSubscription(tmpId: tazId,
                                         tmpPassword: tazIdPassword,
                                         requestSoon: true,
                                         resultSuccessText: Localized("tazid_connect_create_successful_header"))
            case .noFirstname, .noSurname:/// no surname provided - seems to be necessary fro trial subscriptions
              if self.onMissingNameRequested == nil { fallthrough }
              self.onMissingNameRequested?()
            case .subscriptionIdNotValid:
              fallthrough
            case .invalidConnection:/// AboId valid but connected to different tazId
              fallthrough
            case .noPollEntry: /// user probably didn't confirm mail
              fallthrough
            case .expired: /// account provided by token is expired
              fallthrough
            case .unknown:  /// decoded from unknown string
              fallthrough
            // case .tazIdNotValid: ///not available here
            default:
              Toast.show(Localized("toast_login_failed_retry"))
              self.log("Succeed with status: \(info.status) message: \(info.message ?? "-")", logLevel: .Debug)
        }
        case .failure:
          Toast.show(Localized("error"))
      }
      //Re-Enable Button if needed
      self.ui.blocked = false
    })
  }
}

/// This is a special version of the ConnectTazIdController
/// to request aboId + password
/// used if user logs in with tazID(tazIdNotLinked) and user choose "Connect existing Abo"
class ConnectTazIdRequestAboIdCtrl : ConnectTazIdController{
  
  var tazId:String
  var tazIdPassword:String
  
  init(tazId: String, tazIdPassword: String, auth:AuthMediator) {
    self.tazId = tazId
    self.tazIdPassword = tazIdPassword
    super.init(aboId: "", aboIdPassword: "", auth: auth)
    //Change to Number Input
    ui.mailInput.keyboardType = .numberPad
    ui.mailInput.placeholder = Localized("login_subscription_hint")

    ui.registerButton.setTitle(Localized("connect_this_abo_id_with_taz_id"), for: .normal)
    
    ui.views = [
      TazHeader(),
      Padded.PUILabel(title: Localized("connect_abo_id_title")),
      ui.mailInput,//Is now Number Input
      ui.passInput,
      ui.agbAcceptTV,
      ui.registerButton,
      ui.cancelButton,
      Padded.PUIButton(type: .label, title: Localized("login_forgot_password"),
               target: self,
               action: #selector(handlePwForgot))
    ]
    
    self.onMissingNameRequested = {
      ///#Attention: Yes its correct! Do not use ConnectTazIdController aboId!
      let aboId = self.ui.mailInput.text ?? ""
      let aboIdPassword = self.ui.passInput.text ?? ""
      
      let ctrl
        = ConnectTazIdRequestNameCtrl(tazId: tazId,
                                      tazIdPassword: tazIdPassword,
                                      aboId:aboId,
                                      aboIdPassword: aboIdPassword,
                                      auth: auth)
      self.modalFlip(ctrl)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: Button Actions
  @IBAction override func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    
    if let errormessage = ui.validateAsRequestAboIdLogin() {
      Toast.show(errormessage, .alert)
      ui.blocked = false
      return
    }
    
    let inputAboId = ui.mailInput.text ?? ""
    let inputAboIdPassword = ui.passInput.text ?? ""
    
    self.connectWith(tazId: self.tazId, tazIdPassword: self.tazIdPassword , aboId: inputAboId, aboIdPW: inputAboIdPassword)
  }
  
  @IBAction func handlePwForgot(_ sender: UIButton) {
    let ctrl = PwForgottController(id: ui.mailInput.text?.trim, auth: auth)
    //Change to SubscriptionReset
    ctrl.ui.idInput.keyboardType = .numberPad
    ctrl.ui.idInput.placeholder = Localized("login_subscription_hint")
    ctrl.ui.introLabel.text = Localized("login_forgot_subscription_password_header")
    
    ctrl.childDismissType = .two //Reset & ResetSuccess
    modalFlip(ctrl)
  }
}

/// This is a special version of the ConnectTazIdController
/// to request irstname and lastname
/// appears if a user tries to login with a taz-Id without connected Abo-Id and still gave its Abo-Id + pass
/// and the api answered that there is missing first/lastname
class ConnectTazIdRequestNameCtrl : ConnectTazIdController{
  
  var tazId:String
  var tazIdPassword:String
  
  init(tazId: String, tazIdPassword: String, aboId:String, aboIdPassword:String, auth:AuthMediator) {
    self.tazId = tazId
    self.tazIdPassword = tazIdPassword
    super.init(aboId: aboId, aboIdPassword: aboIdPassword, auth: auth)
    ui.registerButton.setTitle(Localized("send_button"), for: .normal)
    ui.views = [
      TazHeader(),
      Padded.PUILabel(title: Localized("taz_id_account_create_intro")),
      ui.firstnameInput,
      ui.lastnameInput,
      ui.registerButton,
      ui.cancelButton
    ]
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: handleLogin Action
  @IBAction override func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    
    if let errormessage = ui.validateAsRequestName() {
      Toast.show(errormessage, .alert)
      ui.blocked = false
      return
    }
    
    let firstname = ui.firstnameInput.text ?? ""
    let lastname = ui.lastnameInput.text ?? ""
    
    self.connectWith(tazId: self.tazId, tazIdPassword: self.tazIdPassword, aboId: self.aboId, aboIdPW: self.aboIdPassword, lastName: lastname, firstName: firstname)
  }
}

/// This is a special version of the ConnectTazIdController
/// to request tazId + password
/// used if user logs in with unlinked AboID, ConnectTazIdController appeared user choosed handleAlreadyHaveTazId
fileprivate class ConnectTazIdRequestTazIdCtrl : ConnectTazIdController{
  
  override init(aboId:String, aboIdPassword:String, auth:AuthMediator) {
    super.init(aboId: aboId, aboIdPassword: aboIdPassword, auth: auth)
    ui.mailInput.keyboardType = .emailAddress
    ui.mailInput.placeholder = Localized("login_tazid_hint")

    ui.registerButton.setTitle(Localized("connect_this_abo_id_with_taz_id"), for: .normal)
    
    ui.views = [
      TazHeader(),
      Padded.PUILabel(title: Localized("fragment_login_request_test_subscription_existing_account")),
      Padded.PUIButton(type: .label,
               title: Localized("fragment_login_missing_credentials_switch_to_registration"),
               target: self,
               action: #selector(handleBack)),
      ui.mailInput,
      ui.passInput,
      ui.agbAcceptTV,
      ui.registerButton,
      ui.cancelButton,
      Padded.PUIButton(type: .label, title: Localized("login_forgot_password"),
                  target: self,
                  action: #selector(handlePwForgot))
    ]
    
    self.onMissingNameRequested = {
      let tazId = self.ui.mailInput.text ?? ""
      let tazIdPassword = self.ui.passInput.text ?? ""
      
      let ctrl
        = ConnectTazIdRequestNameCtrl(tazId: tazId,
                                      tazIdPassword: tazIdPassword,
                                      aboId:aboId,
                                      aboIdPassword: aboIdPassword,
                                      auth: auth)
      self.modalFlip(ctrl)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: handleLogin Action
  @IBAction override func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    
    if let errormessage = ui.validateAsRequestTazIdLogin() {
      Toast.show(errormessage, .alert)
      ui.blocked = false
      return
    }
    
    let tazId = ui.mailInput.text ?? ""
    let tazIdPassword = ui.passInput.text ?? ""
    
    /// We're in tazID login Form, check if credentials are invalid, everything else
    /// is handled by subscriptionId2tazId
    auth.feeder.authenticate(account: tazId,
                                      password: tazIdPassword,
                                      closure:{ [weak self] (result) in
      guard let self = self else { return }
      if case .failure(let error) = result,
        let authStatusError = error as? AuthStatusError,
        authStatusError.status == .invalid {
        //wrong Credentials
        Toast.show(Localized("toast_login_failed_retry"), .alert)
        self.ui.passInput.bottomMessage = Localized("register_validation_issue")
        self.ui.blocked = false
      }
      else {
        self.connectWith(tazId: tazId,
                         tazIdPassword: tazIdPassword ,
                         aboId: self.aboId,
                         aboIdPW: self.aboIdPassword)
      }
    })
  }
  
  @IBAction func handlePwForgot(_ sender: UIButton) {
    let ctrl = PwForgottController(id: ui.mailInput.text?.trim, auth: auth)
    //Change to SubscriptionReset
    ctrl.ui.idInput.keyboardType = .emailAddress
    ctrl.ui.idInput.placeholder = Localized("login_tazid_hint")
    ctrl.ui.introLabel.text = Localized("login_forgot_tazid_password_header")
    
    ctrl.childDismissType = .two //Reset & ResetSuccess
    modalFlip(ctrl)
  }
}

