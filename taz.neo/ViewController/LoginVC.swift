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
  }
  
  // MARK: Actions
  
  @IBAction func loginButtonPressed(_ sender: UIButton) {
    if userTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
      authenticator.message(title: "Fehler", message: "\nNutzername und Password dürfen nicht leer sein.")
    } else {
      self.authenticator.authenticateAndBind(id: userTextField.text!, password: passwordTextField.text!) { authresult in
        switch authresult {
        case .success(let value):
          switch value{
          case "valid tazID":
            self.dismiss(animated: true, completion: nil )
          case "unlinked", "valid aboID":
            self.performSegue(withIdentifier: "tazID", sender: nil)
          case "invalid", "expired", "notValidMail":
            break
          default: break
          }
        case .failure(let e):
          self.authenticator.message(title: "Fehler", message: "Serverfehler: \(e)")
        }
      }
    }
  }
  @IBAction func registerButtonPressed(_ sender: UIButton) {
    
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
    case "login":
      let destination = segue.destination as! RegisterVC
      destination.id = userTextField.text!
    case "trial":
      let destination = segue.destination as! RegisterVC
      destination.topLabelText = "Hier können Sie die digitale taz 14 Tage kostenlos testen:"
    default: break
      
    }
  }
}
