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
  
  var failedLoginCount : Int = 0
  
  private var contentView = LoginView()
  override var ui : LoginView { get { return contentView }}
  
  // MARK: viewDidLoad
  override func viewDidLoad() {
    super.viewDidLoad()
    ui.idInput.text = MainNC.singleton.getUserData().id
    ui.loginButton.touch(self, action: #selector(handleLogin))
    ui.registerButton.touch(self, action: #selector(handleRegister))
    ui.passForgottButton.touch(self, action: #selector(handlePwForgot))
  }
  
  // MARK: Button Actions
  @IBAction func handleLogin(_ sender: UIButton) {
    ui.blocked = true
    if let errormessage = self.validate() {
      Toast.show(errormessage, .alert)
      ui.blocked = false
      showPwForgottButton()
      return
    }
    
    if (ui.idInput.text ?? "").isNumber {
      self.queryCheckSubscriptionId(aboId: (ui.idInput.text ?? ""),aboIdPass: ui.passInput.text ?? "")
    }
    else {
      self.queryAuthToken(tazId: (ui.idInput.text ?? ""),tazIdPass: ui.passInput.text ?? "")
    }
  }
  
  @IBAction func handleRegister(_ sender: UIButton) {
    let ctrl = TrialSubscriptionController(self.auth)
    // Prefill register Form with current Input if idInput contains a valid E-Mail
    if (self.ui.idInput.text ?? "").isValidEmail() {
      ctrl.ui.mailInput.text = self.ui.idInput.text
      ctrl.ui.passInput.text = self.ui.passInput.text
      ctrl.ui.pass2Input.text = self.ui.passInput.text
    }
    modalFlip(ctrl)
  }
  
  @IBAction func handlePwForgot(_ sender: UIButton) {
    self.failedLoginCount = 0//reset failed count
    modalFlip(PwForgottController(id: ui.idInput.text?.trim,
                                  auth: auth))
  }
  
  // MARK: validate()
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    ui.idInput.bottomMessage = ""
    ui.passInput.bottomMessage = ""
    
    if (ui.idInput.text ?? "").isEmpty {
      ui.idInput.bottomMessage = Localized("login_username_error_empty")
      errors = true
    }
    
    if (ui.passInput.text ?? "").isEmpty {
      ui.passInput.bottomMessage = Localized("login_password_error_empty")
      errors = true
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    return nil
  }
  
  // MARK: queryAuthToken
  func queryAuthToken(tazId: String, tazIdPass: String){
    auth.feeder.authenticateWithTazId(account: tazId, password: tazIdPass, closure:{ [weak self] (result) in
      guard let self = self else { return }
      switch result {
        case .success(let token):
          DefaultAuthenticator.storeUserData(id: tazId, password: tazIdPass, token: token)
          self.dismiss(animated: true, completion: nil)
          self.auth.authenticationSucceededClosure?(nil)
        case .failure(let error):
          guard let authStatusError = error as? AuthStatusError else {
            //generell error e.g. no connection
            Toast.show(Localized("something_went_wrong_try_later"))
            return
          }
          switch authStatusError.status {
            case .invalid:
              //wrong Credentials
              self.showPwForgottButton()
              self.failedLoginCount += 1
              if self.failedLoginCount < 3 {//just 2 fails
                Toast.show(Localized("toast_login_failed_retry"))
              }
              else {
                self.handlePwForgot(self.ui.passForgottButton)
            }
            
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
              self.modalFlip(ConnectTazIdController(aboId: aboId,
                                                    aboIdPassword: aboIdPass, auth: self.auth))
            case .expired:
              self.modalFlip(SubscriptionIdElapsedController(expireDateMessage: info.message,
                                                             dismissType: .current))
            case .alreadyLinked:
              self.ui.idInput.text = info.message
              self.ui.passInput.text = ""
              //              Toast.show(Localized("toast_login_with_email"))
              self.showResultWith(message: Localized("toast_login_with_email"),
                                  backButtonTitle: Localized("back_to_login"),
                                  dismissType: .leftFirst)
            case .unlinked: fallthrough
            case .invalid: fallthrough //tested 111&111
            case .notValidMail: fallthrough//tested
            default: //Falsche Credentials
              print("Succeed with status: \(info.status) message: \(info.message ?? "-")")
              self.showPwForgottButton()
              self.failedLoginCount += 1
              if self.failedLoginCount < 3 {//just 2 fails
                Toast.show(Localized("toast_login_failed_retry"))
              }
              else {
                self.handlePwForgot(self.ui.passForgottButton)
            }
        }
        case .failure:
          Toast.show(Localized("toast_login_failed_retry"))
      }
      self.ui.blocked = false
    })
  }
  
  // MARK: showPwForgottButton
  func showPwForgottButton(){
    if ui.passForgottButton.isHidden == false { return }
    self.ui.passForgottButton.alpha = 0.0
    self.ui.passForgottButton.isHidden = false
    UIView.animate(seconds: 0.3) {
      self.ui.passForgottButton.alpha = 1.0
    }
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
      UIButton(type: .outline,
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
    ui.views = [
      TazHeader(),
      UILabel(title: Localized("unconnected_taz_id_header"),
              paddingTop: 30,
              paddingBottom: 30
      ),
      UIButton(title: Localized("connect_abo_id"),
               target: self, action: #selector(handleConnectAboId)),
      UILabel(title: Localized("ask_for_trial_subscription_title"),
              paddingTop: 30,
              paddingBottom: 30
      ),
      UIButton(title: Localized("trial_subscroption"),
               target: self, action: #selector(handleRegister)),
      UIButton(type:.outline,
               title: Localized("cancel_button"),
               target: self, action: #selector(handleBack))
    ]
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: Button Actions
  @IBAction func handleConnectAboId(_ sender: UIButton) {
    modalFlip(NotLinkedLoginAboID_Controller(tazId: self.tazId,
                                             tazIdPass: self.tazIdPass,
                                             auth: self.auth))
  }
  
  @IBAction func handleRegister(_ sender: UIButton) {
    let ctrl = TrialSubscriptionController(self.auth)
    /// Prefill register Form with current Input if idInput contains a valid E-Mail
    //    if (self.idInput.text ?? "").isValidEmail() {
    //      ctrl.mailInput.text = self.idInput.text
    //      ctrl.passInput.text = self.passInput.text
    //      ctrl.pass2Input.text = self.passInput.text
    //    }
    modalFlip(ctrl)
  }
}

// MARK: - AskForTrial_Controller
///USer has valid taz-Id Credentials
class NotLinkedLoginAboID_Controller: LoginController {
  
  private var contentView = NotLinkedLoginAboIDView()
  override var ui : NotLinkedLoginAboIDView { get { return contentView }}
  
  var tazId:String
  var tazIdPass:String
  
  init(tazId:String,
                   tazIdPass:String,
                   auth: AuthMediator) {
    self.tazId = tazId
    self.tazIdPass = tazIdPass
    super.init(auth)

  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: viewDidLoad
   override func viewDidLoad() {
     super.viewDidLoad()
     ui.idInput.text = MainNC.singleton.getUserData().id
     ui.connectButton.touch(self, action: #selector(handleConnect))
   }
  
  // MARK: Button Actions
  @IBAction func handleConnect(_ sender: UIButton) {
    ui.blocked = true
    
//    if let errormessage = ui.validate() {
//      Toast.show(errormessage, .alert)
//      ui.blocked = false
//      return
//    }
    
    let aboId = ui.aboIdInput.text ?? ""
    let aboIdPass = ui.passInput.text ?? ""
    
///ToDo work on.....
      
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
  
  
}
