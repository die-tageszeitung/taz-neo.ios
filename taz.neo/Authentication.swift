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
  public var installationId: String 
  /// Root view controller
  private lazy var rootVC: UIViewController? = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return appDelegate.window?.rootViewController
  }()
  
  public init(feeder: GqlFeeder) {
    self.feeder = feeder
    let dfl = Defaults.singleton
    if let iid = dfl["installationId"] { self.installationId = iid }
    else { 
      self.installationId = UUID().uuidString 
      dfl["installationId"] = self.installationId
    }
  }
  
  // Produce action sheet to ask for id/password
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
  
  // Popup message to user
  private func message(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    let okButton = UIAlertAction(title: "OK", style: .default)
    alert.addAction(okButton)
    rootVC?.present(alert, animated: false, completion: nil)
  }
  
  /// Ask user for id/password, check with GraphQL-Server and store in user defaults
  public func simpleAuthenticate(closure: @escaping (Result<String,Error>)->()) {
    withLoginData { [weak self] (id, password) in
      guard let this = self else { return }
      if let id = id, let password = password {
        this.feeder.authenticate(account: id, password: password) { res in
          if let token = res.value() {
            let dfl = Defaults.singleton
            dfl["token"] = token
            dfl["id"] = id
          }
          else { 
            this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt") 
          }
          closure(res)
        }
      }
      else {
        closure(.failure(this.error("User refused to log in")))
      }
    }
  }
    
    func linkingIDs(closure: @escaping (_ id: String?, _ password: String?)->()  /*, installID: String*/){
//      var aboID, aboPW : String
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
//        closure(nil, nil)
      }
      alert.addAction(loginAction)
      alert.addAction(cancelAction)
      rootVC?.present(alert, animated: true, completion: nil)
//        feeder.subscriptionId2tazId(tazId: tazID, password: tazPassword, aboId: <#T##String#>, aboIdPW: <#T##String#>, surname: <#T##String?#>, firstName: <#T##String?#>, installationId: <#T##String#>, pushToken: <#T##String?#>, closure: <#T##(Result<GqlSubscriptionInfo, Error>) -> ()#>)
    }

    public func detailedAuthenticate(closure: @escaping (Result<String,Error>)->()) {
      withLoginData { [weak self] (id, password) in
        guard let this = self else { return }
        if let id = id, let password = password {
            // investigates the type of ID (taz,abo or promo)
            if id.contains("@") {   // tazID
                /*
                 Es muss gecheckt werden ob tazID mit abo verknüpft ist
                 wenn verknüpft alles super kunde darf lesen
                 wenn nein, dann verknüfen oder anlegen
                 */
//                 TODO checkSubscriptionId erwartet aboID aber ich weiß bereits dass es eine tazID ist
                this.feeder.checkSubscriptionId(aboId: id, password: password) { res in
                    if let AuthInfo = res.value() {
                        switch AuthInfo.status {
                        case .valid:    // this user has it all aboID and tazID DONE
                            break
                        case .invalid: // somthings wrong with pw or id
                            this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt")
                        case .expired: // token is expired
                            this.message(title: "Fehler", message: "\nDas taz-Digiabo ist abgelaufen, bitte kontaktieren sie unseren Service digiabo@taz.de")
                        case .unlinked: //aboID an PW okay, but not linked to tazID! :O
                          this.linkingIDs{ [weak self] (id, password)}
                        default:
                            this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt")
                        }
                    }
                } //endif tazID
                
            }
            if id.isNumber {        // aboID
                /*
                 es muss gecheckt werden ob tazID exestiert
                 wenn ja dann verknüfen, sonst
                 tazID erstellen und mit abo verknüfen
                 */
                this.feeder.checkSubscriptionId(aboId: id, password: password) { res in
                    if let AuthInfo = res.value() {
                        switch AuthInfo.status {
                        case .valid:    // valid aboID
                            break
                        case .invalid: // somthings wrong with pw or id
                            this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt")
                        case .expired: // token is expired
                            this.message(title: "Fehler", message: "\nDas taz-Digiabo ist abgelaufen, bitte kontaktieren sie unseren Service digiabo@taz.de")
                        case .unlinked: //aboID an PW okay, but not linked to tazID! :O
                            this.linkingIDs(tazID: id, tazPassword: password)
                        default:
                            this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt")
                        }
                    }
                }
                
            } //endif aboid
            if !id.contains("@") && !id.isNumber  {
                self?.debug("Promocode wurde erkannt")
            } //endif promo
        } // end if let
          
      }
    }
}

extension String  {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}
