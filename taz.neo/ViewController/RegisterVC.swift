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
  }
  @IBAction func registerButtonPressed(_ sender: UIButton) {
  }
  @IBAction func cancelButtonPressed(_ sender: UIButton) {
    self.dismiss(animated: false, completion: nil)
  }
  
  override func viewDidLoad() {
//    super.viewDidLoad()
    self.debug("REGISTERVC viewDidLoad")
    self.forgotPasswordButton?.layer.cornerRadius = 5
    self.registerButton?.layer.cornerRadius = 5
    self.cancelButton?.layer.cornerRadius = 5
    self.forgotPasswordButton?.backgroundColor = UIColor.darkGray
    self.registerButton?.backgroundColor = TazRot
    cancelButton?.backgroundColor = UIColor.darkGray
    let pwRule = UITextInputPasswordRules(descriptor: "required: upper; required: lower; required: digit; required: [-().&@?'#,/&quot;+]; max-consecutive: 2; minlength: 8;")
    passwordTF.passwordRules = pwRule
    repeatPasswordTF.passwordRules = pwRule
    topLabel.text = topLabelText
  }
}

// MARK: TrailsubcriptionVC
class TrailsubcriptionVC: RegisterVC {
  
  override func viewDidLoad() {
    
    super.viewDidLoad()
    topLabel.text = "Hier können Sie die digitale taz 14 Tage kostenlos testen."
    registerButton.titleLabel?.text = "Regestrieren"
    forgotPasswordButton.layer.cornerRadius = 5
    registerButton.layer.cornerRadius = 5
    cancelButton.layer.cornerRadius = 5
  }
  
  override func registerButtonPressed(_ sender: UIButton) {
    if emailTextField.text!.isEmpty || passwordTF.text!.isEmpty || repeatPasswordTF.text!.isEmpty {
      authenticator.message(title: "Fehler", message: "\nNutzername und Password dürfen nicht leer sein.")
    } else {
      if !emailTextField.text!.contains("@") {
        authenticator.message(title: "Fehler", message: "\nBitte geben Sie eine E-Mail Adresse an.")
        return
      }
      let email = emailTextField.text
      if passwordTF.text == repeatPasswordTF.text {
        self.authenticator.feeder.trialSubscription(tazId: email!, password: passwordTF.text!, surname: nameTF.text ?? "", firstName: surnameTF.text ?? "", installationId: authenticator.installationId, pushToken: authenticator.pushToken) { result in
          // Result<GqlSubscriptionInfo, Error>
          let substat = result.value()?.status
          switch substat {
          case .waitForProc:
            self.feeder.subscriptionPoll(installationId: self.authenticator.installationId) { res in

            }
          case .waitForMail:
            self.authenticator.message(title: "Mail wurde versand", message: "Danke für Ihre Registrirung! Wir haben Ihnen eine Mail an \(email!) geschickt. Bitte öffnn Sie die Mail und bestädtigen Sie Ihre Adresse. Sobald die Mail-Adresse bestätigt wurde, können Sie die neue taz-App nutzen.")
          case .alreadyLinked:
            self.authenticator.message(title: "Fehler", message: "\nDie eMail-Adresse ist bereits mit einem Digiabo verbunden.")
          case .tazIdNotValid:
            self.authenticator.message(title: "Fehler", message: "\nWir haben Ihnen eine eMail geschickt.")
          case .invalidMail:
            self.authenticator.message(title: "Fehler", message: "\nKeine gültige eMail-Adresse.")
          default :
            self.authenticator.message(title: "Fehler", message: "\nUnbekannte Antwort vom Server.")
          }
        }
      }
    } //
  }
}
