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
  
  var failedLoginCount : Int = 0
  
  var idInput
    = FormularView.textField(placeholder: NSLocalizedString("login_username_hint",
                                                            comment: "E-Mail Input")
  )
  var passInput
    = FormularView.textField(placeholder: NSLocalizedString("login_password_hint",
                                                            comment: "Passwort Input"),
                             textContentType: .password,
                             isSecureTextEntry: true)
  
  var passForgottButton: UIButton
    =   FormularView.labelLikeButton(title: NSLocalizedString("login_forgot_password", comment: "registrieren"),
                                     target: self, action: #selector(handlePwForgot))
  
  var loginButton: UIButton?
  
  // MARK: viewDidLoad Action
  override func viewDidLoad() {
    self.contentView = FormularView()
    passForgottButton.isHidden = true
    idInput.text = MainNC.singleton.getUserData().id
    self.contentView?.views =   [
      FormularView.header(),
      FormularView.label(title: Localized("article_read_onreadon")),
      idInput,
      passInput,
      FormularView.button(title: NSLocalizedString("login_button", comment: "login"),
                          target: self, action: #selector(handleLogin)),
      FormularView.label(title: NSLocalizedString("trial_subscription_title",
                                                  comment: "14 tage probeabo text")),
      FormularView.outlineButton(title: NSLocalizedString("register_button", comment: "registrieren"),
                                 target: self, action: #selector(handleRegister)),
      passForgottButton
    ]
    idInput.autocapitalizationType = .none
    idInput.textContentType = .emailAddress
    
    super.viewDidLoad()
  }
  
  // MARK: handleLogin Action
  @IBAction func handleLogin(_ sender: UIButton) {
    loginButton = sender
    loginButton?.isEnabled = false
    
    if let errormessage = self.validate() {
      Toast.show(errormessage, .alert)
      sender.isEnabled = true
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
    SharedFeeder.shared.feeder?.authenticateWithTazId(account: id, password: pass, closure:{ [weak self] (result) in
      //ToDo #902
      guard let self = self else { return }
      self.loginButton?.isEnabled = true
      switch result {
        case .success(let info):
          //ToDo Persist Auth
          print("done success \(info)")
          self.dismiss(animated: true, completion: nil)
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
              self.showResultWith(message: Localized("fragment_login_confirm_email_header"),
                                  backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                  dismissType: .all)
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
    })
  }
  
  func showAskForTrial(){
    class AskForTrial_Controller : FormsController_Result_Controller {
      override func viewDidLoad() {
        self.views = [
          FormularView.header(),
          FormularView.label(title: Localized("ask_for_trial_subscription_title"),
                             paddingTop: 30,
                             paddingBottom: 30
          ),
          FormularView.button(title: Localized("yes_trial_subscroption"),
                              target: self, action: #selector(handleTrial)),
          FormularView.labelLikeButton(title: Localized("cancel_button"),
                                       target: self, action: #selector(handleBack)),
          
        ]
        super.viewDidLoad()
      }
      
      // MARK: handleBack Action
      @IBAction func handleTrial(_ sender: UIButton) {
        modalFlip(TrialSubscriptionController())
      }
    }
    modalFlip(AskForTrial_Controller())
  }
  
  // MARK: queryCheckSubscriptionId
  func queryCheckSubscriptionId(_ aboId: String, _ password: String){
    SharedFeeder.shared.feeder?.checkSubscriptionId(aboId: aboId, password: password, closure: { (result) in
      self.loginButton?.isEnabled = true
      switch result {
        case .success(let info):
          //ToDo #900
          switch info.status {
            case .valid:
              self.modalFlip(ConnectTazIDController(aboId: aboId,
                                                    aboIdPassword: password))
              break;
            case .expired:
              self.modalFlip(SubscriptionIdElapsedController(expireDateMessage: info.message,
                                                             dismissType: .current))
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
    modalFlip(TrialSubscriptionController())
  }
  
  // MARK: handlePwForgot Action
  @IBAction func handlePwForgot(_ sender: UIButton) {
    let child = PwForgottController()
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
  private(set) var expiredDate : String = ""
  
  convenience init(expireDateMessage:String?, dismissType:dismissType) {
    self.init(nibName:nil, bundle:nil)
    var dateString = "-"
    if let msg = expireDateMessage {
      dateString = UsTime(iso:msg).date.gDate()
    }
    
    self.views =  [
      FormularView.header(),
      CustomTextView(htmlText: Localized(keyWithFormat: "subscription_id_expired", dateString),
                     textAlignment: .center,
                     linkTextAttributes: CustomTextView.boldLinks),
      FormularView.button(title: Localized("cancel_button"),
                          target: self, action: #selector(handleBack)),
    ]
  }
}
