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
  private var whenPollingRequiredClosure: (()->())?
  /// Define closure to call when polling is necessary
  public func whenPollingRequired(closure: @escaping ()->()) {
    whenPollingRequiredClosure = closure
  }
  
  public init(feeder: GqlFeeder) {
    self.feeder = feeder
  }
  


  /// PollSubscription asks the GraphQL-Server for a new subscription status, if 
  /// a new status is available, the closure is called with a bool indicating
  /// whether further polling is necessary (true=>continue polling)
  public func pollSubscription(closure: (Bool)->()) {
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
  
  /// Produce action sheet to ask for id/password
  private func withAboId(closure: @escaping (_ id: String?, _ password: String?)->()) {
    let alert = UIAlertController(title: "Abo-ID zurücksetzen", 
                                  message: "Bitte \"klassische\" Abo-ID nebst Passwort angeben",
                                  preferredStyle: .alert)
    alert.addTextField { (textField) in
      textField.placeholder = "ID"
      textField.keyboardType = .emailAddress
    }
    alert.addTextField { (textField) in
      textField.placeholder = "Passwort"
      textField.isSecureTextEntry = true
    }
    let loginAction = UIAlertAction(title: "OK", style: .default) { _ in
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
    withAboId { (id, pw) in
      guard let id = id, let pw = pw else { return }
      self.feeder.unlinkSubscriptionId(aboId: id, password: pw) { res in
        if let info = res.value() {
          self.debug("\(info.toString())")
        }
      }
    }
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
  
  /// restarting the login process
  private func askingAgainForLogin(){
    self.detailedAuthenticate { res in
      guard let _ = res.value() else { return }
      self.debug(res.value() ?? "" + "++--++")
    }
  }
  
  /// recalling askingForUserData( )
  private func askingAgainForUserData(){
    self.askingForUserData { (id: String?, pw: String?, sN:String?, fN:String?) in
      
    }
  }
 
  
  /// Popup message to user, with option to reset password
  public func failedLoginMessage(title: String, message: String, id: String, closure: (()->())? = nil) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    let okButton = UIAlertAction(title: "OK", style: .default) { _ in closure?() }
    let mailButton = UIAlertAction(title: "Password zurücksetzen", style: .destructive) { _ in
      // Send mail for resetting Password
      if id.contains("@") {
        self.feeder.passwordReset(email: id) { (res) in
          if let restInfo = res.value() {
            switch restInfo {
            case .ok:
              self.message(title: "Erfolg", message: "E-Mail zum Passwordzurücksetzten wurde versendet.")
            case .invalidMail:
              self.message(title: "Fehler", message: "Mailadresse \(id) ist fehlerhaft."){}
              self.debug("\(id) ist fehlerhaft.")
            case .mailError :
              self.message(title: "Fehler", message: "Mail kann zur Zeit nicht verschickt werden.")
            case .error :
              self.message(title: "Fehler", message: "Interner Fehler")
            default:
              self.debug("default: resetting PW for \(id) failed!")
            }
          }
        }
      } else {
        self.feeder.subscriptionReset(aboId: id) { result in
          if let restInfo = result.value()?.status {
            let mail = result.value()?.mail
            switch restInfo {
            case .ok:
              self.message(title: "Erfolg", message: "E-Mail zum Passwordzurücksetzten wurde an \(mail!) versendet.")
            case .invalidSubscriptionId:
              self.message(title: "Fehler", message: "AboID \(id) ist ungültig."){}
              self.debug("\(id) ist ungültig.")
            case .noMail :
              self.message(title: "Fehler", message: "Keine Mail-Adresse hinterlegt")
            case .invalidConnection :
              self.message(title: "Fehler", message: "aboId bereits mit tazId verknüpft")
            default:
              self.debug("default: resetting PW for \(id) failed!")
            }
          }
        }
      }
    }
    alert.addAction(okButton)
    alert.addAction(mailButton)
    rootVC?.present(alert, animated: false, completion: nil)
  }
  
  /// aksing for the nessary information to link the aboID to a tazID
  func askingForUserData(closure: @escaping (_ id: String?, _ password: String?,_ surname: String?,_ fistname:String?)->()){
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
  
  /// Ask user for id/password, check if abo- or taz-ID and link them if necessary
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
              let kc = Keychain.singleton
              dfl["token"] = token
              dfl["id"] = id
              kc["token"] = token
              kc["id"] = id
              kc["password"] = password
              this.feeder.authToken = token
            }
            else {
//              this.failedLoginMessage(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt", id: id){ this.askingAgainForLogin()}
            }
            let authStatus = this.feeder.status?.authInfo.status
            switch authStatus {
            case .valid:    // valid user with all permissions
              this.debug("valid aboID")
              this.message(title: "Anmeldung erfolgreich", message: "Vielen Dank für Ihre Anmeldung! Viel Spaß mit der neuen digitalen taz"){()}
            case .invalid: // somthings wrong with pw or id
              this.failedLoginMessage(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt", id: id){this.askingAgainForLogin()}
              
            case .expired: // token is expired
              let expirationDate = self?.feeder.date2a((self?.feeder.a2date(this.feeder.status?.authInfo.message ?? ""))!)
              this.message(title: "Fehler", message: "\nDas taz-Digiabo ist am" + (expirationDate ?? "") + "abgelaufen, bitte kontaktieren sie unseren Service digiabo@taz.de")
            case .unlinked: //aboID an PW okay, but not linked to tazID! :O
              this.debug("tazID unlinked")
              this.withLoginData { (aboID:String?, aboPW:String?) in
                this.feeder.subscriptionId2tazId(tazId: id, password: password, aboId: aboID ?? "", aboIdPW: aboPW ?? "", surname: "", firstName: "", installationId: this.installationId, pushToken: self?.pushToken) { Result in
//                  var ret: Result<GqlSubscriptionInfo, Error>
                  self?.debug(Result.value()?.status.toString())
                }
              }
            case .notValidMail : // AboId existiert aber das Passwort ist falsch
              self?.debug(this.feeder.status?.authInfo.message)
              this.message(title: "aboID bereits verknüpft", message: "die aboID: \"" + id + "\" ist bereits mit der tazID:  \"" + (this.feeder.status?.authInfo.message ?? "") + "\" verknüpft"){this.askingAgainForLogin()}
            default:
              self?.debug("default: Fehler Kundendaten sind nicht korrekt")
              this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt."){this.askingAgainForLogin()}
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
                  this.feeder.subscriptionId2tazId(tazId: tazId ?? "", password: tazPassword ?? "", aboId: id, aboIdPW: password, surname: surname, firstName: firstname, installationId: this.installationId, pushToken: this.pushToken) { Result in
                    let ret: Result<GqlSubscriptionInfo, Error> = Result
                    self?.debug(Result.value()?.status.toString())
                    self?.debug(ret.value()?.status.toString())
                  }
                }
              case .invalid: // somthings wrong with pw or id
                this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt"){this.askingAgainForLogin()}
              case .notValidMail: //id is correckt, pw is wrong and can be reseted via mail
                let mail = AuthInfo.message
                this.failedLoginMessage(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt", id: id){this.askingAgainForLogin()}
              case .expired: // subscription is expired
                let expirationDate = self?.feeder.date2a((self?.feeder.a2date(AuthInfo.message ?? ""))!)
                this.message(title: "Fehler", message: "\nDas taz-Digiabo ist am" + (expirationDate ?? "") + "abgelaufen, bitte kontaktieren sie unseren Service digiabo@taz.de")
              case .unlinked: //aboID an PW okay, but not linked to tazID! :O
                // fatal error
                this.feeder.authenticate(account: id, password: password) { res in
                  if let token = res.value() {
                    let dfl = Defaults.singleton
                    let kc = Keychain.singleton
                    dfl["token"] = token
                    dfl["id"] = id
                    kc["token"] = token
                    kc["id"] = id
                    kc["password"] = password
                    this.askingForUserData { (tazId :String?, tazPassword: String?, surname: String?, firstname: String?) in
                      self?.debug(token)
                      this.feeder.subscriptionId2tazId(tazId: tazId ?? "", password: tazPassword ?? "", aboId: id, aboIdPW: password, surname: surname, firstName: firstname, installationId: this.installationId, pushToken: this.pushToken) { Result in
//                        var ret: Result<GqlSubscriptionInfo, Error>
                        self?.debug(Result.value()?.status.toString())
                      }
                    }
                  } else {
                    this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt"){this.askingAgainForLogin()}
                  }
                  closure(res)
                }
              case .alreadyLinked:
                self?.debug(AuthInfo.message)
                this.message(title: "aboID bereits verknüpft", message: "die aboID: \"" + id + "\" ist bereits mit der tazID:  \"" + (AuthInfo.message ?? "") + "\" verknüpft"){this.askingAgainForLogin()}
              default:
                // fatal error
                this.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt"){this.askingAgainForLogin()}
              }
            }
          }
          
        } //endif aboid
        if !id.contains("@") && !id.isAboID  {
          self?.debug("Promocode wurde erkannt")
          this.feeder.authenticate(account: id, password: password) { result in
            if let token = result.value() {
              let dfl = Defaults.singleton
              dfl["token"] = token
              dfl["id"] = id
            }
            else {
              this.message(title: "Fehler", message: "\nDer Promocode ist nicht korrekt"){ exit(0) }
            }
          }
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
