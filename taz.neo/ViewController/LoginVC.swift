//
//  LoginVC.swift
//  taz.neo
//
//  Created by Nicolas Patzelt on 06.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib

class LoginVC : UIViewController {

  var feeder: GqlFeeder!
  lazy var authenticator = Authentication(feeder: self.feeder)
  var returnclosure : ((Result<String,Error>)->())!
  
//  private var id, password : String;
  @IBOutlet weak var userTextField: UITextField!
  @IBOutlet weak var passwordTextField: UITextField!
  @IBOutlet weak var loginButton: UIButton!
  @IBOutlet weak var passwordResetButton: UIButton!
  @IBOutlet weak var triralButton: UIButton!
  @IBOutlet var backgroundTap: UITapGestureRecognizer!
  

  override func viewDidLoad() {
    loginButton.backgroundColor = TazRot
    triralButton.backgroundColor = UIColor.darkGray
    passwordResetButton.backgroundColor = UIColor.darkGray
    loginButton.layer.cornerRadius = 5
    triralButton.layer.cornerRadius = 5
    passwordResetButton.layer.cornerRadius = 5
    
    UIApplication.shared.keyWindow?.bringSubviewToFront(self.view)
  }
  
  // MARK: Actions
  
  @IBAction func loginButtonPressed(_ sender: UIButton) {
    if userTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
      authenticator.message(title: "Fehler", message: "\nNutzername und Password dürfen nicht leer sein.")
    } else {
      self.authenticator.checkLoginCredentials(id: userTextField.text!, password: passwordTextField.text!) { authresult in
        switch authresult {
        case .success(let value):
          switch value{
          case "valid tazID":
            self.dismiss(animated: true, completion: nil )
            self.returnclosure(.success(value))
          case "unlinked", "valid aboID":
            self.performSegue(withIdentifier: "tazID", sender: nil)
          case "invalid", "expired", "notValidMail", "tazID unlinked":
            self.returnclosure(.failure(self.error(value)))
            break
          default: break
          }
        case .failure(let err):
          if let err = err as? FeederError {
            var text = ""
            switch err {
            case .invalidAccount: text = "Ihre Kundendaten sind nicht korrekt."
            case .expiredAccount: text = "Ihr Abo ist abgelaufen."
            case .changedAccount: text = "Ihre Kundendaten haben sich geändert."
            case .unexpectedResponse:
              text = "Es gab ein Problem bei der Kommunikation mit dem Server."
            }
          }
//          self.authenticator.message(title: "Fehler", message: "Serverfehler: \(e)")
        }
      }
    }
  }
  @IBAction func registerButtonPressed(_ sender: UIButton) {
    self.performSegue(withIdentifier: "trial", sender: nil)
  }
  @IBAction func resendPasswordButtonPressed(_ sender: UIButton) {
    if let id : String = userTextField.text,  !userTextField.text!.isEmpty {
      self.authenticator.resetPassword(id: id)
    }
  }
  
  @IBAction func tappedInView(_ sender: UITapGestureRecognizer) {
    if userTextField.isFirstResponder {
      userTextField.resignFirstResponder()
    }
    if passwordTextField.isFirstResponder {
      passwordTextField.resignFirstResponder()
    }
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let segueid = segue.identifier
    switch segueid {
    case "tazID":
      let destination = segue.destination as! RegisterVC
      destination.id = userTextField.text!
      destination.pw = passwordTextField.text!
      destination.feeder = self.feeder
    case "trial":
      let destination = segue.destination as! TrialSubscriptionVC
      destination.feeder = self.feeder
    case "forgotPW":
      let destination = segue.destination as! ForgotPwVC
      destination.feeder = self.feeder
    default: break
      
    }
  }
}
