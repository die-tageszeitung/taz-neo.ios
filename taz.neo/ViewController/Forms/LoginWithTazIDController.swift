//
//
// LoginWithTazIDController.swift
//
// Created by Ringo Müller-Gromes on 23.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit

// MARK: - LoginController
/// Presents Login Form and Functionallity
/// ChildViews/Controller are pushed modaly
class LoginWithTazIDController: FormsController {
  
  var idInput: UITextField
    = FormularView.textField(placeholder: NSLocalizedString("login_username_hint",
                                                            comment: "E-Mail Input")
  )
  var passInput: UITextField
    = FormularView.textField(placeholder: NSLocalizedString("login_password_hint",
                                                            comment: "Passwort Input"),
                             textContentType: .password,
                             isSecureTextEntry: true)
  
  var passForgottButton: UIButton
    =   FormularView.labelLikeButton(title: NSLocalizedString("login_forgot_password", comment: "registrieren"),
                                     target: self,
                                     action: #selector(handlePwForgot))
  
  // MARK: viewDidLoad Action
  override func viewDidLoad() {
    self.contentView = FormularView()
    passForgottButton.isHidden = true
    self.contentView?.views =   [
      FormularView.header(),
      FormularView.label(title: NSLocalizedString("login_missing_credentials_header_login")),
      FormularView.labelLikeButton(title: NSLocalizedString("fragment_login_missing_credentials_switch_to_registration"),
                                   target: self,
                                   action: #selector(handleCancel)),
      idInput,
      passInput,
      contentView!.errorLabel,
      FormularView.button(title: NSLocalizedString("login_button", comment: "login"),
                          target: self,
                          action: #selector(handleLogin)),
      FormularView.labelLikeButton(title: NSLocalizedString("login_forgot_password"),
                                   target: self,
                                   action: #selector(handlePwForgot))
    ]
    super.viewDidLoad()
  }
  
  // MARK: handleLogin Action
  @IBAction func handleLogin(_ sender: UIButton) {
    let id = idInput.text ?? ""
    if id.isEmpty {
      self.contentView?.errorLabel.text
        = NSLocalizedString("login_email_error_empty")
      return
    }
    
    if id.isNumber {
      self.contentView?.errorLabel.text
        = NSLocalizedString("login_email_error_no_email")
      return
    }
    
    let pass = passInput.text ?? ""
    if pass.isEmpty {
      self.contentView?.errorLabel.text
        = NSLocalizedString("login_password_error_empty")
      return
    }
    self.contentView?.errorLabel.text = nil
    
    //self.queryAuthToken(id,pass)
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
          self.contentView?.errorLabel.text = "ein Fehler..."
        //        print("An error occured: \(String(describing: result.error()))")
      }
    })
  }
  
  
  // MARK: handleCancel
  @IBAction func handleCancel(_ sender: UIButton) {
    self.dismiss(animated: true, completion:nil)
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


