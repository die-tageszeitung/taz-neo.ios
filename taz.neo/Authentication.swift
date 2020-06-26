//
//  Authentication.swift
//
//  Created by Norbert Thies on 20.02.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib

public class Authentication: DoesLog {
  
  /// Ref to feeder providing Data 
  public var feeder: GqlFeeder
  /// Temporary Id to identify client if no AuthToken is available
  public var installationId: String  { App.installationId }
  /// Push token for silent notification (poll request)
  public var pushToken: String?
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
  /// Define closure to call when the authentication succeeded
  public func whenAuthenticationSucceeded(closure: @escaping ()->()) {
    authenticationSucceededClosure = closure
  }
  
  public init(feeder: GqlFeeder) {
    self.feeder = feeder
  }
  
  /**
   This method is called when either a polling timer fires or a push notification
   indicating authentication changes on the server has been received.
   
   PollSubscription asks the GraphQL-Server for a new subscription status, if 
   a new status is available, the closure is called with a bool indicating
   whether further polling is necessary (true=>continue polling)
   
   - parameters:
     - closure: closure to call when communication with the server has been finished
     - continue: set to true if polling should be continued
  */
  public func pollSubscription(closure: (_ continue: Bool)->()) {
    // ...
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
  public func simpleAuthenticate(closure: @escaping (Result<String,Error>)->()) {
    withLoginData { [weak self] (id, password) in
      guard let this = self else { return }
      if let id = id, let password = password {
        this.feeder.authenticate(account: id, password: password) { res in
          if let token = res.value() {
            let dfl = Defaults.singleton
            let kc = Keychain.singleton
            dfl["token"] = token
            dfl["id"] = id
            kc["token"] = token
            kc["id"] = id
            kc["password"] = password
          }
          closure(res)
        }
      }
      else {
        closure(.failure(this.error("User refused to log in")))
      }
    }
  }
}
