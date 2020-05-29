//
//  RegisterVC.swift
//  taz.neo
//
//  Created by Nicolas Patzelt on 18.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib

class RegisterVC : UIViewController {
  
  var feeder: GqlFeeder!
  lazy var authenticator = Authentication(feeder: self.feeder)
  
  var id, pw : String?
  var topLabelText = "Um die neue App zu nutzten, müssen Sie sich zukünftgig mit Ihrer Email-Adresse und selbstgewähltem Passwort einloggen."
  var returnclosure : ((Result<String,Error>)->())!
  
  // from Top to Bottom in RegisterView
  // MARK: Outlets
  @IBOutlet weak var topLabel: UILabel!
  @IBOutlet weak var emailTextField: UITextField!
  @IBOutlet weak var passwordTF: UITextField!
  @IBOutlet weak var repeatPasswordTF: UITextField!
  @IBOutlet weak var nameTF: UITextField!
  @IBOutlet weak var surnameTF: UITextField!
  @IBOutlet weak var centerLabel: UILabel!
  @IBOutlet weak var forgotPasswordButton: UIButton!
  @IBOutlet weak var termsLabel: UILabel!
  @IBOutlet weak var registerButton: UIButton!
  @IBOutlet weak var cancelButton: UIButton!
  
  // MARK: Actions
  @IBAction func forgotPasswordButtonPressed(_ sender: UIButton) {
    if let id : String = emailTextField.text,  !emailTextField.text!.isEmpty {
      self.authenticator.resetPassword(id: id)
    }
  }
  @IBAction func registerButtonPressed(_ sender: UIButton) {
    if emailTextField.text!.isEmpty || passwordTF.text!.isEmpty || repeatPasswordTF.text!.isEmpty {
      authenticator.message(title: "Fehler", message: "\nNutzername und Password dürfen nicht leer sein.")
    } else {
      if !emailTextField.text!.contains("@") {
        authenticator.message(title: "Fehler", message: "\nBitte geben Sie eine E-Mail Adresse an.")
        return
      }
      if passwordTF.text == repeatPasswordTF.text {
        self.authenticator.bindingIDs(tazId: emailTextField.text!, password: passwordTF.text!, aboId: id!, aboIdPW: pw!, surname: surnameTF.text, firstName: nameTF.text) { bindResult in
          switch bindResult {
          case .success(let str) :
            self.debug(str)
            switch str {
            case "valid", "waitForMail", "alreadyLinked":
              MainNC.singleton.popViewController(animated: false)
            case "invalidMail", "tazIdNotValid" :
              break
            case "waitForProc":
              // QUERY SUBSCRIPTIONPOLLL
              break
            default:
              break
            }
          case .failure(let err) :
            self.debug(err.description)
          }
        }
      }
    }
  }
  @IBAction func cancelButtonPressed(_ sender: UIButton) {
    MainNC.singleton.popViewController(animated: false)
  }
  @IBAction func tappedInView(_ sender: Any){
    if emailTextField.isFirstResponder {
      emailTextField.resignFirstResponder()
    }
    if passwordTF.isFirstResponder {
      passwordTF.resignFirstResponder()
    }
    if repeatPasswordTF.isFirstResponder{
      repeatPasswordTF.resignFirstResponder()
    }
    if nameTF.isFirstResponder {
      nameTF.resignFirstResponder()
    }
    if surnameTF.isFirstResponder {
      surnameTF.resignFirstResponder()
    }
  }
  
  override func viewDidLoad() {
//    super.viewDidLoad()
    self.debug("REGISTERVC viewDidLoad")
    self.forgotPasswordButton?.layer.cornerRadius = 5
    self.registerButton?.layer.cornerRadius = 5
    self.cancelButton?.layer.cornerRadius = 5
    self.forgotPasswordButton?.backgroundColor = UIColor.darkGray
    self.registerButton?.backgroundColor = AppColors.tazRot
    cancelButton?.backgroundColor = UIColor.darkGray
    let pwRule = UITextInputPasswordRules(descriptor: "required: upper; required: lower; required: digit; required: [-().&@?'#,/&quot;+]; max-consecutive: 2; minlength: 8;")
    passwordTF.passwordRules = pwRule
    repeatPasswordTF.passwordRules = pwRule
    topLabel.text = topLabelText
  }
}
