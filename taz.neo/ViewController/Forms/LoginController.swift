//
// LoginController.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//
import UIKit
import NorthLib
import GameController

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
    ui.helpButton.onTapping {   [weak self] _ in self?.handleWhereIsTheAboId() }
    ui.passInput.onResignFirstResponder = { [weak self] in
      guard let self = self else {return}
      self.handleLogin(self.ui.loginButton)
    }
  }
  
  // MARK: Button Actions
  @IBAction func handleLogin(_ sender: UIButton) {
    ui.blocked = true
    if let errormessage = ui.validate() {
      Alert.message(message: errormessage)
      ui.blocked = false
      return
    }
    self.ui.idInput.text = self.ui.idInput.text?.trimed
    self.queryAuthToken(tazId: (self.ui.idInput.text ?? ""),tazIdPass: self.ui.passInput.text ?? "")
  }
  
  @IBAction func handleTrial(_ sender: UIButton) {
    let ctrl = TrialSubscriptionController(self.auth)
    // Prefill register Form with current Input if idInput contains a valid E-Mail
    if (self.ui.idInput.text ?? "").trimed.isValidEmail() {
      ctrl.ui.mailInput.text = self.ui.idInput.text?.trimed
      ctrl.ui.passInput.text = self.ui.passInput.text?.trimed
      ctrl.ui.pass2Input.text = self.ui.passInput.text?.trimed
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
    let pwReset = PwForgottController(id: ui.idInput.text?.trimed,
                                      auth: auth)
    pwReset.fromLogin = true
    modalFromBottom(pwReset)
  }
  func handleWhereIsTheAboId() {
    let faqAction = self.ui.openFaqAction()
    
    Alert.message(title:"",
                  message: App.isLMD ? Localized("fragment_login_help_lmd") : Localized("fragment_login_help"),
                  additionalActions: [faqAction])
    Usage.track(Usage.event.dialog.LoginHelp)
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
          if error is URLError {
            Alert.message(message: Localized("communication_breakdown"))
            self.ui.blocked = false
            return
          }
          
          guard let authStatusError = error as? AuthStatusError else {
            //generell error e.g. no connection
            Alert.message(message: Localized("something_went_wrong_try_later"))
            self.ui.blocked = false
            return
          }
          var alertMessage:String? = authStatusError.message ?? Localized("toast_login_failed_retry")
          
          switch authStatusError.status {
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
              alertMessage = nil
            case .unlinked:
              self.modalFromBottom(AskForTrial_Controller(tazId: tazId,
                                                    tazIdPass: tazIdPass,
                                                    auth: self.auth))
              alertMessage = nil
            case .unknown: fallthrough
            case .alreadyLinked: //Makes no sense here!
              alertMessage = Localized("something_went_wrong_try_later")
            case .invalid:
              self.ui.passInput.bottomMessage = Localized("register_validation_issue")
            case .notValidMail: fallthrough
            default: break
          }
          if let alertMessage = alertMessage { Alert.message(message: alertMessage) }
          self.log("Auth Error: \(authStatusError)", logLevel: .Error)
      }
      self.ui.blocked = false
    })
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if #available(iOS 14.0, *) {
      if Device.isIphone { return }
      ui.passInput.onEnter {[weak self] in
        guard let btn = self?.ui.loginButton else { return }
        self?.handleLogin(btn)
      }
      if GCKeyboard.coalesced == nil { return }//no Hadrware Keyboard
      if ui.idInput.text?.isEmpty == true { ui.idInput.becomeFirstResponder()}
      else { ui.passInput.becomeFirstResponder()}
    }
  }
}

// MARK: - AskForTrial_Controller
///USer has valid taz-Id Credentials
class AskForTrial_Controller: FormsController {
  
  ///just exchange showRegisterTips
  private var contentView = AskForTrial_View()
  override var ui : AskForTrial_View { get { return contentView }}
  
  var tazId:String
  var tazIdPass:String
  
  init(tazId:String,
       tazIdPass:String,
       auth: AuthMediator) {
    self.tazId = tazId
    self.tazIdPass = tazIdPass
    super.init(auth)
    ui.views = [
      Padded.Label(title: Localized(keyWithFormat: "unconnected_taz_id_header", tazId),
                   paddingTop: 30,
                   paddingBottom: 30
                  ),
      Padded.Button(title: Localized("trial_subscroption"),
                    target: self, action: #selector(handleTrialSubscription)),
      ui.registerTipsButton,
      Padded.Label(title: Localized(keyWithFormat: "unconnected_taz_id_contact", tazId),
                   paddingTop: 30,
                   paddingBottom: 30
                  ),
      Padded.Button(title: "Print-Abo in Digital Abo umwandeln",
                    target: self, action: #selector(handlePrint2Digi)),
      Padded.Button(title: "Digital Abo zum Print-Abo aktivieren",
                    target: self, action: #selector(handlePrintPlusDigi))
    ]
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: Button Actions
  @IBAction func handlePrint2Digi(_ sender: UIButton) {
    let child = SubscriptionFormController(formType: .print2Digi,
                                           auth: self.auth)
    child.ui.mailInput.text = self.tazId
    modalFromBottom(child)
  }
  @IBAction func handlePrintPlusDigi(_ sender: UIButton) {
    let child = SubscriptionFormController(formType: .printPlusDigi,
                                           auth: self.auth)
    child.ui.mailInput.text = self.tazId
    modalFromBottom(child)
  }
  
  @IBAction func handleTrialSubscription(_ sender: UIButton) {
    self.ui.blocked = true
    let ctrl = TrialSubscriptionRequestNameCtrl(tazId: tazId, tazIdPassword: tazIdPass, auth: auth)
    ///Test if TrialSubscription work without first/lastname!
    ctrl.onMissingNameRequested = {
      self.modalFromBottom(ctrl)
    }
    ctrl.createTrialSubscription(tazId: tazId, tazIdPassword: tazIdPass)
  }
}

class AskForTrial_View: FormView {
  override func showRegisterTips(_ textField: UITextField) {
    Alert.message(title: Localized("register_tips_button"),
                  message: Localized("register_tips_text_existingtazid"),
                  additionalActions: [openFaqAction()])
   Usage.track(Usage.event.dialog.SubscriptionHelp)
  }
}
