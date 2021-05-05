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
    ui.registerButton.touch(self, action: #selector(handleRegister))
    ui.passForgottButton.touch(self, action: #selector(handlePwForgot))
  }
  
  // MARK: Button Actions
  @IBAction func handleLogin(_ sender: UIButton) {
    ui.blocked = true
    if let errormessage = ui.validate() {
      Toast.show(errormessage, .alert)
      ui.blocked = false
      return
    }
    
    if (ui.idInput.text ?? "").isNumber {
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
      self.queryAuthToken(tazId: (ui.idInput.text ?? ""),tazIdPass: ui.passInput.text ?? "")
    }
  }
  
  @IBAction func handleRegister(_ sender: UIButton) {
    let ctrl = TrialSubscriptionController(self.auth)
    // Prefill register Form with current Input if idInput contains a valid E-Mail
    if (self.ui.idInput.text ?? "").trim.isValidEmail() {
      ctrl.ui.mailInput.text = self.ui.idInput.text?.trim
      ctrl.ui.passInput.text = self.ui.passInput.text?.trim
      ctrl.ui.pass2Input.text = self.ui.passInput.text?.trim
    }
    modalFlip(ctrl)
  }
  
  @IBAction func handlePwForgot(_ sender: UIButton) {
    modalFlip(PwForgottController(id: ui.idInput.text?.trim,
                                  auth: auth))
  }
  
  
  
  // MARK: queryAuthToken
  func queryAuthToken(tazId: String, tazIdPass: String){
    auth.feeder.authenticate(account: tazId, password: tazIdPass, closure:{ [weak self] (result) in
      guard let self = self else { return }
      switch result {
        case .success(let token):
          DefaultAuthenticator.storeUserData(id: tazId, password: tazIdPass, token: token)
          self.dismiss(animated: true, completion: nil)
          Notification.send("authenticationSucceeded")
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
              self.modalFlip(SubscriptionIdElapsedController(expireDateMessage: authStatusError.message,
                                                             dismissType: .current))
            case .unlinked:
              self.modalFlip(AskForTrial_Controller(tazId: tazId,
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
  func queryCheckSubscriptionId(aboId: String, aboIdPass: String){
    auth.feeder.checkSubscriptionId(aboId: aboId, password: aboIdPass, closure: { (result) in
      switch result {
        case .success(let info):
          //ToDo #900
          switch info.status {
            case .valid:
              let ctrl = ConnectTazIdController(aboId: aboId,
                                                aboIdPassword: aboIdPass, auth: self.auth)
              ctrl.ui.registerButton.setTitle("taz-ID erstellen", for: .normal)
              self.modalFlip(ctrl)
            case .expired:
              self.modalFlip(SubscriptionIdElapsedController(expireDateMessage: info.message,
                                                             dismissType: .current))
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

// MARK: - SubscriptionIdElapsedCtrl
class SubscriptionIdElapsedController: FormsResultController {
  convenience init(expireDateMessage:String?,
                   dismissType:dismissType) {
    self.init()
    var dateString : String = "-"
    if let msg = expireDateMessage {
      dateString = UsTime(iso:msg).date.gDate()
    }
    let htmlText = Localized(keyWithFormat: "subscription_id_expired", dateString)
    ui.views = [
      TazHeader(),
      CustomTextView(htmlText:htmlText,
                     textAlignment: .center,
                     linkTextAttributes: CustomTextView.boldLinks),
      Padded.Button(type: .outline,
               title: Localized("cancel_button"),
               target: self,
               action: #selector(handleBack))]
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
    
    if offerTrialSubscription {
      // Dialog mit Probeabo
      ui.views = [
        TazHeader(),
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
    else {
      // Dialog ohne Probeabo
      ui.views = [
        TazHeader(),
        Padded.Label(title: Localized("unconnected_taz_id_header"),
                paddingTop: 30,
                paddingBottom: 30
        ),
        Padded.Button(title: Localized("connect_abo_id"),
                 target: self, action: #selector(handleConnectAboId)),
        Padded.Button(type:.outline,
                 title: Localized("cancel_button"),
                 target: self, action: #selector(handleBack))
      ]
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: Button Actions
  @IBAction func handleConnectAboId(_ sender: UIButton) {
    modalFlip(ConnectTazIdRequestAboIdCtrl(tazId: tazId, tazIdPassword: tazIdPass, auth: auth))
  }
  
  @IBAction func handleTrialSubscroption(_ sender: UIButton) {
    let ctrl = TrialSubscriptionRequestNameCtrl(tazId: tazId, tazIdPassword: tazIdPass, auth: auth)
    ///Test if TrialSubscription work without first/lastname!
    ctrl.onMissingNameRequested = {
      self.modalFlip(ctrl)
    }
    ctrl.createTrialSubscription(tazId: tazId, tazIdPassword: tazIdPass)
    
  }
}
