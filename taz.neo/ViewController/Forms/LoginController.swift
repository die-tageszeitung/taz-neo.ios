//
// LoginController.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//
import UIKit
import NorthLib

// MARK: - LoginController
/// Presents Login Form and Functionallity
/// ChildViews/Controller are pushed modaly
class LoginController: FormsController {
  
  override public var uiBlocked : Bool {
    didSet{
      super.uiBlocked = uiBlocked
      loginButton?.isEnabled = !uiBlocked
    }
  }
  
  var failedLoginCount : Int = 0
  
  var idInput
    = TazTextField(placeholder: Localized("login_username_hint"),
                   textContentType: .emailAddress,
                   enablesReturnKeyAutomatically: true,
                   keyboardType: .emailAddress,
                   autocapitalizationType: .none
  )
  
  var passInput
    = TazTextField(placeholder: Localized("login_password_hint"),
                   textContentType: .password,
                   isSecureTextEntry: true,
                   enablesReturnKeyAutomatically: true)

  
  lazy var passForgottButton: UIButton = {
    return UIButton(type: .label,
                 title: Localized("login_forgot_password"), target: self, action: #selector(handlePwForgot))
  }()
  
  var loginButton: UIButton?
  
  override func getContentViews() -> [UIView] {
    return   [
      TazHeader(),
      UILabel(title: Localized("article_read_onreadon")),
      idInput,
      passInput,
      UIButton(title: Localized("login_button"),
               target: self, action: #selector(handleLogin)),
      UILabel(title: Localized("ask_for_trial_subscription_title")),
      UIButton(type: .outline,
               title: Localized("register_button"),
               target: self, action: #selector(handleRegister)),
      defaultCancelButton,
      passForgottButton
    ]
  }
  
  // MARK: viewDidLoad Action
  override func viewDidLoad() {
    super.viewDidLoad()
    passForgottButton.isHidden = true
    idInput.text = MainNC.singleton.getUserData().id
  }
  
  // MARK: handleLogin Action
  @IBAction func handleLogin(_ sender: UIButton) {
    loginButton = sender
    self.uiBlocked = true
        
    if let errormessage = self.validate() {
      Toast.show(errormessage, .alert)
      self.uiBlocked = false
      showPwForgottButton()
      return
    }
    
    if (idInput.text ?? "").isNumber {
      self.queryCheckSubscriptionId((idInput.text ?? ""),passInput.text ?? "")
    }
    else {
      self.queryAuthToken((idInput.text ?? ""),passInput.text ?? "")
    }
  }
  

  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    idInput.bottomMessage = ""
    passInput.bottomMessage = ""
    
    if (idInput.text ?? "").isEmpty {
      idInput.bottomMessage = Localized("login_username_error_empty")
      errors = true
    }
    
    if (passInput.text ?? "").isEmpty {
      passInput.bottomMessage = Localized("login_password_error_empty")
      errors = true
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    return nil
  }
  
  // MARK: queryAuthToken
  func queryAuthToken(_ id: String, _ pass: String){
    auth.feeder.authenticateWithTazId(account: id, password: pass, closure:{ [weak self] (result) in
      //ToDo #902
      guard let self = self else { return }
      switch result {
        case .success(let token):
          DefaultAuthenticator.storeUserData(id: id, password: pass, token: token)
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
              //Falsche Credentials
              self.showPwForgottButton()
              self.failedLoginCount += 1
              if self.failedLoginCount < 3 {//just 2 fails
                Toast.show(Localized("toast_login_failed_retry"))
              }
              else {
                self.handlePwForgot(self.passForgottButton)
            }
            
            case .expired:
              self.modalFlip(SubscriptionIdElapsedController(expireDateMessage: authStatusError.message,
                                                             dismissType: .current, auth: self.auth))
            case .unlinked:
              self.showAskForTrial()
            case .notValidMail: fallthrough
            case .unknown: fallthrough
            case .alreadyLinked: fallthrough //Makes no sense here!
            default:
              self.log("Auth with tazID should not have alreadyLinked as result", logLevel: .Error)
              Toast.show(Localized("something_went_wrong_try_later"))
        }
      }
      self.uiBlocked = false
    })
  }
  
  func showAskForTrial(){
    class AskForTrial_Controller : FormsController_Result_Controller {
      
      var id:String?
      var pass:String?
      
      init(id:String?, pass:String?, auth: AuthMediator) {
        self.id = id
        self.pass = pass
        super.init(auth)
      }
      
      required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
      }
      
      override func getContentViews() -> [UIView] {
        return [
          TazHeader(),
          UILabel(title: Localized("ask_for_trial_subscription_title"),
                  paddingTop: 30,
                  paddingBottom: 30
          ),
          UIButton(title: Localized("yes_trial_subscroption"),
                   target: self, action: #selector(handleTrial)),
          UIButton(type: .label,
                   title: Localized("cancel_button"),
                   target: self, action: #selector(handleBack)),
          
        ]
      }
      
      // MARK: handleBack Action
      @IBAction func handleTrial(_ sender: UIButton) {
        let ctrl = TrialSubscriptionController(self.auth)
        ctrl.mailInput.text = self.id
        ctrl.passInput.text = self.pass
        ctrl.pass2Input.text = self.pass
        modalFlip(ctrl)
      }
    }
    modalFlip(AskForTrial_Controller(id: self.idInput.text, pass: self.passInput.text, auth: self.auth))
  }
  
  // MARK: queryCheckSubscriptionId
  func queryCheckSubscriptionId(_ aboId: String, _ password: String){
    auth.feeder.checkSubscriptionId(aboId: aboId, password: password, closure: { (result) in
      switch result {
        case .success(let info):
          //ToDo #900
          switch info.status {
            case .valid:
              self.modalFlip(ConnectTazIDController(aboId: aboId,
                                                    aboIdPassword: password, auth: self.auth))
              break;
            case .expired:
              self.modalFlip(SubscriptionIdElapsedController(expireDateMessage: info.message,
                                                             dismissType: .current, auth: self.auth))
            case .alreadyLinked:
              self.idInput.text = info.message
              self.passInput.text = ""
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
                self.handlePwForgot(self.passForgottButton)
            }
        }
        case .failure:
          Toast.show(Localized("toast_login_failed_retry"))
      }
      self.uiBlocked = false
    })
  }
  
  // MARK: showPwForgottButton
  func showPwForgottButton(){
    if self.passForgottButton.isHidden == false { return }
    self.passForgottButton.alpha = 0.0
    self.passForgottButton.isHidden = false
    UIView.animate(seconds: 0.3) {
      self.passForgottButton.alpha = 1.0
    }
  }
  
  // MARK: handleRegister Action
  @IBAction func handleRegister(_ sender: UIButton) {
    let ctrl = TrialSubscriptionController(self.auth)
    /// Prefill register Form with current Input if idInput contains a valid E-Mail
    if (self.idInput.text ?? "").isValidEmail() {
      ctrl.mailInput.text = self.idInput.text
      ctrl.passInput.text = self.passInput.text
      ctrl.pass2Input.text = self.passInput.text
    }
    modalFlip(ctrl)
  }
  
  // MARK: handlePwForgot Action
  @IBAction func handlePwForgot(_ sender: UIButton) {
    self.failedLoginCount = 0//reset failed count
    let child = PwForgottController(self.auth)
    child.idInput.text = idInput.text?.trim
    modalFlip(child)
  }
}

class SubscriptionIdElapsedController: FormsController_Result_Controller {
  /**
   Discussion TextView with Attributed String for format & handle Links/E-Mail Adresses
   or multiple Views with individual button/click Handler
   Pro: AttributedString Con: multiple views
   + minimal UICreation Code => solve by using compose views...
   - hande of link leaves the app => solve by using individual handler
   - ugly html & data handling
   + super simple add & exchange text
   */
  private(set) var dateString : String = "-"
  
  convenience init(expireDateMessage:String?, dismissType:dismissType, auth: AuthMediator) {
    self.init(auth)
    if let msg = expireDateMessage {
      dateString = UsTime(iso:msg).date.gDate()
    }
  }
  
  override func getContentViews() -> [UIView] {
    return [
      TazHeader(),
      CustomTextView(htmlText: Localized(keyWithFormat: "subscription_id_expired", dateString),
                     textAlignment: .center,
                     linkTextAttributes: CustomTextView.boldLinks),
      UIButton(title: Localized("cancel_button"),
               target: self, action: #selector(handleBack)),
    ]
  }
}
