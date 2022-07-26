//
//  Authentication.swift
//
//  Created by Norbert Thies on 20.02.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public class SimpleAuthenticator: Authenticator {
  
  /// Ref to feeder providing Data 
  public var feeder: GqlFeeder
  /// Root view controller
  private lazy var rootVC: UIViewController? = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return appDelegate.window?.rootViewController
  }()
  
  /// Closure to call when polling of suscription status is required
  private var performPollingClosure: (()->())?
  /// Define closure to call when polling is necessary
  public func whenPollingRequired(closure: @escaping ()->()) {
    performPollingClosure = closure
  }
  
  /// Closure to call when authentication succeeded
  private var authenticationSucceededClosure: (()->())?
  
  required public init(feeder: GqlFeeder) {
    self.feeder = feeder
    let (_,_,token) = SimpleAuthenticator.getUserData()
    if token != nil { feeder.authToken = token! }
  }
  
  public func pollSubscription(closure: (_ continue: Bool)->()) {
    // nothing to do in simple case
  }
  
  /// Produce action sheet to ask for id/password
  private func withLoginData(closure: @escaping (_ id: String?, _ password: String?)->()) {
    let alert = UIAlertController(title: "Anmeldung", 
        message: "Bitte melden Sie sich mit Ihren Kundendaten an",
        preferredStyle: .alert)
    alert.addTextField { (textField) in
      textField.placeholder = "ID"
      textField.keyboardType = .emailAddress
    }
    alert.addTextField { (textField) in
      textField.placeholder = "Passwort"
      textField.isSecureTextEntry = true
    }
    let loginAction = UIAlertAction(title: "Anmelden", style: .default) { _ in
      let id = alert.textFields![0]
      let password = alert.textFields![1]
      closure(id.text ?? "", password.text ?? "")
    }
    let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel) { _ in
      closure(nil, nil)
    }
    alert.addAction(loginAction)
    alert.addAction(cancelAction)
    rootVC?.present(alert, animated: true, completion: nil)
  } 
  
  /// Unlink connection from taz-ID to Abo-ID
  public func unlinkSubscriptionId() {
    withLoginData { (id, pw) in
      guard let id = id, let pw = pw else { return }
      self.feeder.unlinkSubscriptionId(aboId: id, password: pw) { res in
        if let info = res.value() {
          self.debug("\(info.toString())")
        }
      }
    }
  }
  
  /// Ask user for id/password, check with GraphQL-Server and store in user defaults
  public func authenticate(with targetVC:UIViewController? = nil) {
    withLoginData { [weak self] (id, password) in
      guard let self = self else { return }
      if let id = id, let password = password {
        self.feeder.authenticate(account: id, password: password) { res in
          switch res {
            case .success(let token): 
              SimpleAuthenticator.storeUserData(id: id, password: password, 
                                                token: token)
              Notification.send(Const.NotificationNames.authenticationSucceeded)
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
                Alert.message(title: "Fehler", message: text)
              }
              else { 
                Alert.message(title: "Fehler", message: "Anmeldung gescheitert.")
              }
          }
        }
      }
      else { self.error("User refused to log in") }
    }
  }
}
