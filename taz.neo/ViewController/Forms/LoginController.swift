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
  
  // MARK: viewDidLoad Action
  override func viewDidLoad() {
    self.contentView = FormularView()
//    idInput.text = ""
//    passInput.text = ""
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
         passForgottButton,
         FormularView.button(title: "x",
                     target: self, action: #selector(handleX)),
       ]
    super.viewDidLoad()
  }
  @IBAction func handleX(_ sender: UIButton) {
    self.dismiss(animated: true, completion: nil)
  }
  
  // MARK: handleLogin Action
  @IBAction func handleLogin(_ sender: UIButton) {
    
    var errors = false
    idInput.bottomMessage = ""
    passInput.bottomMessage = ""
    let id = idInput.text ?? ""
    let pass = passInput.text ?? ""
    
    if id.isEmpty {
      idInput.bottomMessage = Localized("login_username_error_empty")
      errors = true
    }
    
    if pass.isEmpty {
      passInput.bottomMessage = Localized("login_password_error_empty")
      errors = true
    }
    
    if errors {
      showPwForgottButton()
      return
    }
    
    if id.isNumber {
      self.queryCheckSubscriptionId((idInput.text ?? ""),pass)
    }
    else {
      self.queryAuthToken(id,pass)
    }
  }
  
  // MARK: queryAuthToken
  func queryAuthToken(_ id: String, _ pass: String){
    print("queryAuthToken with: \(id), \(pass)"); return;
    SharedFeeder.shared.feeder?.authenticate(account: id, password: pass, closure:{ (result) in
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
        switch result {
        case .success(let info):
          //ToDo #900
          switch info.status {
            case .valid:
              let child = ConnectTazIDController(aboId: aboId, aboIdPassword: password)
              child.modalPresentationStyle = .overCurrentContext
              child.modalTransitionStyle = .flipHorizontal
              self.present(child, animated: true, completion: nil)
              break;
            case .alreadyLinked:
              fallthrough
            case .expired:
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
              print("Succeed with status: \(info.status) message: \(info.message)")
          }
        case .failure:
          Toast.show("ein Fehler...")
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


