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
    self.contentView?.views =   [
         FormularView.header(),
         FormularView.label(title: NSLocalizedString("login_missing_credentials_header_login",
                                             comment: "login header")),
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
    SharedFeeder.shared.feeder?.authenticate(account: id, password: pass, closure:{ (result) in
      self.loginButton?.isEnabled = true
      switch result {
      case .success(let info):
        print("done success \(info.bool)")
//        switch info {
//        case .ok:
//          let successCtrl = PasswordResetRequestedSuccessController()
//          successCtrl.modalPresentationStyle = .overCurrentContext
//          successCtrl.modalTransitionStyle = .flipHorizontal
//          self.present(successCtrl, animated: true, completion:{
//            self.view.isHidden = true
//          })
//        case .invalidMail:
//          self.contentView?.errorLabel.text
//            = NSLocalizedString("error_invalid_email_or_abo_id",
//                                comment: "abbrechen")
//        case .mailError:
//          fallthrough
//        default:
//          self.contentView?.errorLabel.text
//            = NSLocalizedString("error",
//                                comment: "error")
//        }
      case .failure:
        Toast.show("ein Fehler...")
        //        print("An error occured: \(String(describing: result.error()))")
      }
    })
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
              fallthrough
            case .unlinked:
              fallthrough
            case .invalid://tested 111&111
              fallthrough
            case .notValidMail://tested
              fallthrough
            default:
              Toast.show(Localized("toast_login_failed_retry"))
              self.showPwForgottButton()
              print("Succeed with status: \(info.status) message: \(info.message ?? "-")")
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
    print("handle handleRegister")
  }
  
  // MARK: handlePwForgot Action
  @IBAction func handlePwForgot(_ sender: UIButton) {
    let child = PwForgottController()
    child.idInput.text = idInput.text?.trim
    child.modalPresentationStyle = .overCurrentContext
    child.modalTransitionStyle = .flipHorizontal
    self.present(child, animated: true, completion: nil)
  }
}

class SubscriptionIdElapsedController: FormsController_Result_Controller {
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
      FormularView.button(title: "d",
                          target: self, action: #selector(handleBack)),
      
    ]
  }
}


