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
  
  /// Popup message to user
  public func message(title: String, message: String, closure: (()->())? = nil) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    let okButton = UIAlertAction(title: "OK", style: .default) { _ in closure?() }
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
            let kc = Keychain.singleton
            dfl["token"] = token
            dfl["id"] = id
            kc["token"] = token
            kc["id"] = id
            kc["password"] = password
          }
          else { 
            this.message(title: "Fehler", 
                         message: "\nIhre Kundendaten sind nicht korrekt") { exit(0) }
          }
          closure(res)
        }
      }
      else {
        closure(.failure(this.error("User refused to log in")))
      }
    }
  }
  private func askingAgainForUserData(){
    self.askingForUserData { (id: String?, pw: String?, sN:String?, fN:String?) in
      
    }
  }
  
  /// aksing for the nessary information to link the aboID to a tazID
  func askingForUserData(closure: @escaping (_ id: String?, _ password: String?,_ surname: String?,_ fistname:String?)->()  /*, installID: String*/){
    //      var aboID, aboPW : String
    let alert = UIAlertController(title: "Anmeldung via tazID",
                                  message: "Um die neue App zu nutzen, müssen Sie sich zukünftig mit Ihrer E-Mail-Adresse und selbst gewähltem Passwort einloggen",
                                  preferredStyle: .alert)
    alert.addTextField { (textField) in //0
      textField.placeholder = "E-Mail"
      textField.keyboardType = .emailAddress
    }
    alert.addTextField { (textField) in //1
      textField.placeholder = "Passwort"
      textField.isSecureTextEntry = true
    }
    alert.addTextField { (textField) in //2
      textField.placeholder = "Passwort wiederholen"
      textField.isSecureTextEntry = true
    }
    alert.addTextField { (textField) in //3
      textField.placeholder = "Vorname"
      textField.isSecureTextEntry = false
    }
    alert.addTextField { (textField) in //4
      textField.placeholder = "Nachname"
      textField.isSecureTextEntry = false
    }
    let loginAction = UIAlertAction(title: "Anmelden", style: .default) { _ in
      let id = alert.textFields![0]
      let firstname = alert.textFields![3]
      let surname = alert.textFields![4]
      let passwordTF = {(tf1: UITextField, tf2: UITextField)-> (UITextField) in
        if tf1.text == tf2.text && tf1.text != "" {
          return tf1
        } else {
          self.debug("Passwörter stimmen nicht überein")
          self.askingAgainForUserData()
          return tf2
        }
      }
      let password = passwordTF(alert.textFields![1], alert.textFields![2]) //alert.textFields![1]
      closure(id.text ?? "", password.text ?? "", firstname.text ?? "", surname.text ?? "")
    }
    let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel) { _ in
      closure(nil, nil, nil, nil)
    }
    alert.addAction(loginAction)
    alert.addAction(cancelAction)
    rootVC?.present(alert, animated: true, completion: nil)
  }
  
  public func detailedAuthenticate(closure: @escaping (Result<String,Error>)->()) {
    withLoginData { [weak self] (id, password) in
      guard let this = self else { return }
      if let id = id, let password = password {
        // investigates the type of ID (taz,abo or promo)
        
        if id.contains("@") {   // tazID
          this.debug("tazID erkannt: \(id)")
          this.feeder.authenticate(account: id, password: password) { result in
            if let token = result.value() {
              let dfl = Defaults.singleton
              dfl["token"] = token
              dfl["id"] = id
            }
            else {
              this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt"){ exit(0) }
            }
            let authStatus = this.feeder.status?.authInfo.status
            switch authStatus {
            case .valid:    // this user has it all aboID and tazID DONE
              this.message(title: "Anmeldung erfolgreich", message: "Vielen Dank für Ihre Anmeldung! Viel Spaß mit der neuen digitalen taz"){()}
              this.debug("valid aboID")
            case .invalid: // somthings wrong with pw or id
              this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt")
            case .expired: // token is expired
              this.message(title: "Fehler", message: "\nDas taz-Digiabo ist abgelaufen, bitte kontaktieren sie unseren Service digiabo@taz.de")
            case .unlinked: //aboID an PW okay, but not linked to tazID! :O
              this.debug("tazID unlinked")
              this.withLoginData { (aboID:String?, aboPW:String?) in
                let dfl = Defaults.singleton
                let token = dfl["token"]
                this.feeder.subscriptionId2tazId(tazId: id, password: password, aboId: aboID ?? "", aboIdPW: aboPW ?? "", surname: "", firstName: "", installationId: this.installationId, pushToken: token) { Result in
                  self?.debug(Result.value()?.toString())
                }
              }
            default:
              this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt")
            }
          }
          
        }
        if id.isAboID {        // aboID - digiAboId
          this.debug("AboID erkannt: \(id)")
          /*
           es muss gecheckt werden ob tazID exestiert
           wenn ja dann verknüfen, sonst
           tazID erstellen und mit abo verknüfen
           */
          this.feeder.checkSubscriptionId(aboId: id, password: password) { res in
            if let AuthInfo = res.value() {
              switch AuthInfo.status {
              case .valid:    // valid aboID
                this.askingForUserData { (tazId: String?,tazPassword: String?, surname: String?, firstname: String?) in
                  
                }
              case .invalid: // somthings wrong with pw or id
                this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt")
              case .expired: // token is expired
                this.message(title: "Fehler", message: "\nDas taz-Digiabo ist abgelaufen, bitte kontaktieren sie unseren Service digiabo@taz.de")
              case .unlinked: //aboID an PW okay, but not linked to tazID! :O
                this.feeder.authenticate(account: id, password: password) { res in
                  if let token = res.value() {
                    let dfl = Defaults.singleton
                    dfl["token"] = token
                    dfl["id"] = id
                    this.askingForUserData { (tazId :String?, tazPassword: String?, surname: String?, firstname: String?) in
                      this.feeder.subscriptionId2tazId(tazId: tazId ?? "", password: tazPassword ?? "", aboId: id, aboIdPW: password, surname: surname, firstName: firstname, installationId: this.installationId, pushToken: token) { Result in
                        self?.debug(Result.value()?.toString())
                      }
                    }
                  } else {
                    this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt")
                  }
                  closure(res)
                }
                this.askingForUserData { (tazId :String?, tazPassword: String?, surname: String?, firstname: String?) in
                  //                            this.feeder.subscriptionId2tazId(tazId: tazId ?? "", password: tazPassword ?? "", aboId: id, aboIdPW: password, surname: surname, firstName: firstname, installationId: installationId, pushToken: Defaults["token"]) { (Result<GqlSubscriptionInfo, Error>) in
                  
                  //                            }
                }
              default:
                this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt")
              }
            }
          }
          
        } //endif aboid
        if !id.contains("@") && !id.isAboID  {
          self?.debug("Promocode wurde erkannt")
        } //endif promo
      } // end if let
      
    }
  }
}

extension String  {
  /// checking if this String is aboID (Number)
  var isAboID: Bool {
    return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
  }
}
