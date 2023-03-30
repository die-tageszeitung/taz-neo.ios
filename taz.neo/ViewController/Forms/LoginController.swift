//
// LoginController.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//
import UIKit
import NorthLib

// MARK: - LoginCtrl
/// Presents Login Form and Functionallity
/// ChildViews/Controller are pushed modaly
class LoginController: FormsController {
  
  private var contentView = LoginView()
  override var ui : LoginView { get { return contentView }}
  
  // MARK: viewDidLoad
  override func viewDidLoad() {
    super.viewDidLoad()
    ui.idInput.text = DefaultAuthenticator.getUserData().id
    ui.loginButton.touch(self, action: #selector(handleLogin))
    ui.registerButton.touch(self, action: #selector(handleTrial))
    ui.trialSubscriptionButton.touch(self, action: #selector(handleTrial))
    ui.extendButton.touch(self, action: #selector(handleExtend))
    ui.switchButton.touch(self, action: #selector(handleSwitch))
    
    ui.passForgottButton.onTapping {   [weak self] _ in self?.handlePwForgot() }
    ui.whereIsTheAboId.onTapping {   [weak self] _ in self?.handleWhereIsTheAboId() }
    ui.passInput.onResignFirstResponder = { [weak self] in
      guard let self = self else {return}
      self.handleLogin(self.ui.loginButton)
    }
  }
  
  // MARK: Button Actions
  @IBAction func handleLogin(_ sender: UIButton) {
    ui.blocked = true
    if let errormessage = ui.validate() {
      Toast.show(errormessage, .alert)
      ui.blocked = false
      return
    }
    
    if !App.isAvailable(.ABOIDLOGIN) && (ui.idInput.text ?? "").isNumber {
      if let txt = ui.idInput.text, let i = Int32(txt){
        self.queryCheckSubscriptionId(aboId: "\(i)" ,aboIdPass: ui.passInput.text ?? "")
      } else {
        ui.idInput.bottomMessage = Localized("abo_id_validation_error_digit")
        Toast.show(Localized("register_validation_issue"), .alert)
        ui.blocked = false
        return
      }
    }
    else {
      self.queryAuthToken(tazId: (self.ui.idInput.text ?? ""),tazIdPass: self.ui.passInput.text ?? "")
    }
  }
  
  @IBAction func handleTrial(_ sender: UIButton) {
    let ctrl = TrialSubscriptionController(self.auth)
    // Prefill register Form with current Input if idInput contains a valid E-Mail
    if (self.ui.idInput.text ?? "").trim.isValidEmail() {
      ctrl.ui.mailInput.text = self.ui.idInput.text?.trim
      ctrl.ui.passInput.text = self.ui.passInput.text?.trim
      ctrl.ui.pass2Input.text = self.ui.passInput.text?.trim
    }
    modalFromBottom(ctrl)
  }
  
  @IBAction func handleExtend(_ sender: UIButton) {
    modalFromBottom(SubscriptionFormController(formType: .printPlusDigi,
                                         auth: self.auth))
  }
  
  @IBAction func handleSwitch(_ sender: UIButton) {
      modalFromBottom(SubscriptionFormController(formType: .print2Digi,
                                           auth: self.auth))
  }
  
  func handlePwForgot() {
    modalFromBottom(PwForgottController(id: ui.idInput.text?.trim,
                                  auth: auth))
  }
  func handleWhereIsTheAboId() {
    Alert.message(title:"", message:Localized("fragment_login_help"))
  }
  
  // MARK: queryAuthToken
  func queryAuthToken(tazId: String, tazIdPass: String){

    auth.feeder.authenticate(account: tazId, password: tazIdPass, closure:{ [weak self] (result) in
      guard let self = self else { return }
      switch result {
        case .success(let token):
          DefaultAuthenticator.storeUserData(id: tazId, password: tazIdPass, token: token)
          self.dismiss(animated: true){
            (self.auth as? DefaultAuthenticator)?.notifySuccess()
          }
        case .failure(let error):
          guard let authStatusError = error as? AuthStatusError else {
            //generell error e.g. no connection
            Toast.show(Localized("something_went_wrong_try_later"))
            self.ui.blocked = false
            return
          }
          switch authStatusError.status {
            case .invalid:
              //wrong Credentials
              Toast.show(Localized("toast_login_failed_retry"), .alert)
              self.ui.passInput.bottomMessage = Localized("register_validation_issue")
            case .expired:
              var expiredDate: Date?
              if let isoDate = authStatusError.message {
                expiredDate = UsTime(iso:isoDate).date
              }
              TazAppEnvironment.sharedInstance.feederContext?.currentFeederErrorReason =
              FeederError.expiredAccount(authStatusError.message)
              Defaults.expiredAccountDate =  expiredDate ?? Date()
              let expiredForm
              = SubscriptionFormController(formType: authStatusError.customerType?.formDataType ?? .expiredDigiSubscription,
                                           auth: self.auth,
                                           expireDate: expiredDate,
                                           customerType: authStatusError.customerType)
              expiredForm.dismissType = .allReal
              
              if let token = authStatusError.token {
                DefaultAuthenticator.storeUserData(id: tazId, password: tazIdPass, token: token)
                (self.auth as? DefaultAuthenticator)?.notifySuccess()
              }
              
              self.modalFromBottom(expiredForm)
            case .unlinked:
              self.modalFromBottom(AskForTrial_Controller(tazId: tazId,
                                                    tazIdPass: tazIdPass,
                                                    auth: self.auth))
            case .notValidMail: fallthrough
            case .unknown: fallthrough
            case .alreadyLinked: fallthrough //Makes no sense here!
            default:
              self.log("Auth with tazID should not have alreadyLinked as result", logLevel: .Error)
              Toast.show(Localized("something_went_wrong_try_later"))
        }
      }
      self.ui.blocked = false
    })
  }
  
  // MARK: queryCheckSubscriptionId
  // ToDo WARNING Handle expiredSubscription may not work correct!!
  func queryCheckSubscriptionId(aboId: String, aboIdPass: String){
    auth.feeder.checkSubscriptionId(aboId: aboId, password: aboIdPass, closure: { (result) in
      switch result {
        case .success(let info):
          //ToDo #900
          switch info.status {
            case .valid:
              let ctrl = ConnectTazIdController(aboId: aboId,
                                                aboIdPassword: aboIdPass, auth: self.auth)
              ctrl.ui.registerButton.setTitle("taz-Konto erstellen", for: .normal)
              self.modalFromBottom(ctrl)
            case .expired:
              var expiredDate: Date?
              if let isoDate = info.message {
                expiredDate = UsTime(iso:isoDate).date
              }
              self.modalFromBottom(
                SubscriptionFormController(formType: .expiredDigiSubscription,
                                           auth: self.auth,
                                           expireDate: expiredDate,
                                           customerType: nil)
              )
            case .alreadyLinked:
              self.ui.idInput.text = info.message
              self.ui.passInput.text = ""
              Alert.message(message: Localized("toast_login_with_email"))
            case .unlinked: fallthrough
            case .invalid: fallthrough //tested 111&111
            case .notValidMail: fallthrough//tested
            default: //Falsche Credentials
              Toast.show(Localized("toast_login_failed_retry"), .alert)
              self.ui.passInput.bottomMessage = Localized("register_validation_issue")
        }
        case .failure:
          Toast.show(Localized("toast_login_failed_retry"))
      }
      self.ui.blocked = false
    })
  }
}

// MARK: - AskForTrial_Controller
///USer has valid taz-Id Credentials
class AskForTrial_Controller: FormsController {
  var tazId:String
  var tazIdPass:String
  
  init(tazId:String,
       tazIdPass:String,
       auth: AuthMediator) {
    self.tazId = tazId
    self.tazIdPass = tazIdPass
    super.init(auth)
    ui.views = [
      Padded.Label(title: Localized("unconnected_taz_id_header"),
                   paddingTop: 30,
                   paddingBottom: 30
                  ),
      Padded.Button(title: Localized("connect_abo_id"),
                    target: self, action: #selector(handleConnectAboId)),
      Padded.Button(title: Localized("trial_subscroption"),
                    target: self, action: #selector(handleTrialSubscroption)),
      Padded.Button(type:.outline,
                    title: Localized("cancel_button"),
                    target: self, action: #selector(handleBack)),
      ui.registerTipsButton
    ]
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: Button Actions
  @IBAction func handleConnectAboId(_ sender: UIButton) {
    modalFromBottom(ConnectTazIdRequestAboIdCtrl(tazId: tazId, tazIdPassword: tazIdPass, auth: auth))
  }
  
  @IBAction func handleTrialSubscroption(_ sender: UIButton) {
    self.ui.blocked = true
    let ctrl = TrialSubscriptionRequestNameCtrl(tazId: tazId, tazIdPassword: tazIdPass, auth: auth)
    ///Test if TrialSubscription work without first/lastname!
    ctrl.onMissingNameRequested = {
      self.modalFromBottom(ctrl)
    }
    ctrl.createTrialSubscription(tazId: tazId, tazIdPassword: tazIdPass)
    
  }
}
