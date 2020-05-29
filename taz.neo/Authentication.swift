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
  public func pollSubscription(closure: @escaping (Bool)->()) {
    // ...
    self.feeder.subscriptionPoll(installationId: self.installationId) { result in
      switch result {
      case .success(let subInfo) :
        switch subInfo.status {
        case .valid :
          closure(false)
        case .waitForProc, .waitForMail :
          closure(true)
        default:
          closure(true)
        }
      case .failure(_) :
        closure(true)
      }
    }
    closure(true)
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
  var myalert : UIAlertController?
  public func message(title: String, message: String, closure: (()->())? = nil) {
    myalert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    guard let myalert = myalert else { return}
    let okButton = UIAlertAction(title: "OK", style: .default) { _ in closure?() }
    myalert.addAction(okButton)
    rootVC?.present(myalert, animated: false, completion: nil)
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
 
  /// Password reset for aboid or tazid
  public func resetPassword(id: String) {
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
            self.message(title: "Fehler", message: "Unbekannte Antwort vom Server")
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
            self.message(title: "Fehler", message: "Unbekannte Antwort vom Server")
            self.debug("default: resetting PW for \(id) failed!")
          }
        }
      }
    }
  }
  
  /// Popup message to user, with option to reset password
  public func failedLoginMessage(title: String, message: String, id: String, closure: (()->())? = nil) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    let okButton = UIAlertAction(title: "OK", style: .default) { _ in closure?() }
    let mailButton = UIAlertAction(title: "Password zurücksetzen", style: .destructive) { _ in
      // Send mail for resetting Password
      self.resetPassword(id: id)
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
  
  
  
  public func authenticateAndBind(closure: @escaping (Result<String,Error>)->()) {
    let sb = UIStoryboard(name: "Login", bundle: nil)
    let vc = sb.instantiateViewController(withIdentifier: "loginView") as! LoginVC
    vc.feeder = self.feeder
    vc.returnclosure = closure
//    self.rootVC?.present(vc, animated: true, completion: nil)
//    MainNC.singleton.show(vc, sender: self)
    MainNC.singleton.pushViewController(vc, animated: true)
//    self.navigationController?.pushViewController(vc, animated: false)
  }
  
  /// Authentication with tazID or aboID and binds them if necessary.
  /// - Parameter id: String containing Numbers as aboID or Email as tazID
  /// - Parameter password: String containing password
  /// - Parameter closure: Login result containing server response
  public func checkLoginCredentials(id: String?, password: String?, closure: @escaping (Result<String,Error>)->()) {
//    guard let this = self else { return }
    if let id = id, let password = password {
      // investigates the type of ID (taz,abo or promo)
      
      if id.contains("@") {   // tazID
        self.debug("tazID erkannt: \(id)")
        self.feeder.authenticate(account: id, password: password) { result in
          if let token = result.value() {
            let dfl = Defaults.singleton
            let kc = Keychain.singleton
            dfl["token"] = token
            dfl["id"] = id
            kc["token"] = token
            kc["id"] = id
            kc["password"] = password
            self.feeder.authToken = token
            let authStatus = self.feeder.status?.authInfo.status
            switch authStatus {
            case .valid:    // valid user with all permissions
              self.debug("valid tazID")
              self.message(title: "Anmeldung erfolgreich", message: "Vielen Dank für Ihre Anmeldung! Viel Spaß mit der neuen digitalen taz"){MainNC.singleton.popViewController(animated: false)}
              return closure(.success("valid tazID"))
            case .invalid: // somthings wrong with pw or id
              self.failedLoginMessage(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt", id: id){}
              closure(result)
            case .expired: // token is expired
              let expirationDate = self.feeder.date2a((self.feeder.a2date(self.feeder.status?.authInfo.message ?? "")))
              self.message(title: "Fehler", message: "\nDas taz-Digiabo ist am \(expirationDate) abgelaufen, bitte kontaktieren sie unseren Service digiabo@taz.de")
              closure(result)
            case .unlinked: //aboID an PW okay, but not linked to tazID! :O
              self.debug("tazID unlinked")
              self.message(title: "Fehler", message: "\n Bitte geben Sie zuerst ihre aboID an")
              closure(result)
            case .notValidMail : // AboId existiert aber das Passwort ist falsch
              self.debug(self.feeder.status?.authInfo.message)
              self.message(title: "aboID bereits verknüpft", message: "die aboID: \"" + id + "\" ist bereits mit der tazID:  \"" + (self.feeder.status?.authInfo.message ?? "") + "\" verknüpft"){}
              closure(result)
            default:
              self.debug("default: Fehler Kundendaten sind nicht korrekt bzw Unbekannte Antwort vom Server")
              self.message(title: "Fehler", message: "\nUnbekannte Antwort vom Server."){}
              closure(result)
            }
            
          } else {
            self.failedLoginMessage(title: "Fehler", message: "\n Login fehlgeschlagen.\n Kein Token erhalten.", id: id){}
          }
          
          closure(result)
        }
      }
      if id.isAboID {        // aboID - digiAboId
        self.debug("AboID erkannt: \(id)")
        /*
         es muss gecheckt werden ob tazID exestiert
         wenn ja dann verknüfen, sonst
         tazID erstellen und mit abo verknüfen
         */
        self.feeder.checkSubscriptionId(aboId: id, password: password) { resAuthInfo in
          if let AuthInfo = resAuthInfo.value() {
            switch AuthInfo.status {
            case .valid:    // valid aboID
              return closure(.success("valid aboID"))
            case .invalid: // somthings wrong with pw or id
              self.message(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt"){}
              closure(.success(AuthInfo.status.toString()))
            case .notValidMail: //id is correckt, pw is wrong and can be reseted via mail
//              let mail = AuthInfo.message
              self.failedLoginMessage(title: "Fehler", message: "\nIhre Kundendaten sind nicht korrekt", id: id){}
              closure(.success(AuthInfo.status.toString()))
            case .expired: // subscription is expired
              let expirationDate = self.feeder.date2a((self.feeder.a2date(AuthInfo.message ?? "")))
              self.message(title: "Fehler", message: "\nDas taz-Digiabo ist am \(expirationDate) abgelaufen, bitte kontaktieren sie unseren Service digiabo@taz.de")
              closure(.success(AuthInfo.status.toString()))
            case .alreadyLinked:
              self.debug(AuthInfo.message)
              self.message(title: "aboID bereits verknüpft", message: "die aboID: \"" + id + "\" ist bereits mit der tazID:  \"" + (AuthInfo.message ?? "") + "\" verknüpft"){}
              closure(.success(AuthInfo.status.toString()))
            default:
              // fatal error
              self.message(title: "Fehler", message: "\nUnbekannte Antwort vom Server"){self.askingAgainForLogin()}
              closure(.success(AuthInfo.status.toString()))
            }
          }
          switch resAuthInfo {
          case .success(let info):
            closure(.success(info.message ?? ""))
          case .failure:
            closure(.failure(self.error("User refused to log in")))
          }
        }
        
      } //endif aboid
      if !id.contains("@") && !id.isAboID  {
        self.debug("Promocode wurde erkannt")
        self.feeder.authenticate(account: id, password: password) { result in
          if let token = result.value() {
            let dfl = Defaults.singleton
            dfl["token"] = token
            dfl["id"] = id
          }
          else {
            self.message(title: "Fehler", message: "\nDer Promocode ist nicht korrekt"){ exit(0) }
          }
          closure(result)
        }
      } //endif promo
    } //end if let
  }
  
  ///
  public func bindingIDs(tazId: String, password: String, aboId: String, aboIdPW: String, surname: String?, firstName: String?, closure: @escaping (Result<String,Error>)->()){
    self.feeder.subscriptionId2tazId(tazId: tazId, password: password, aboId: aboId, aboIdPW: aboIdPW, surname: surname, firstName: firstName, installationId: self.installationId, pushToken: self.pushToken) { /*(Result<GqlSubscriptionInfo, Error>)*/ bindResult in
      switch bindResult {
      case .success(let subinfo):
        let subStatus = subinfo.status
        switch subStatus {
        case .valid:
          closure(.success(subStatus.toString()))
        case .waitForProc:
          self.feeder.subscriptionPoll(installationId: self.installationId) { /*(Result<GqlSubscriptionInfo, Error>)*/ pollResult in
            
          }
        case .waitForMail:
          self.message(title: "Mail wurde versand", message: "Danke für Ihre Registrirung! Wir haben Ihnen eine Mail an \(tazId) geschickt. Bitte öffnn Sie die Mail und bestädtigen Sie Ihre Adresse. Sobald die Mail-Adresse bestätigt wurde, können Sie die neue taz-App nutzen.")
          closure(.success(subStatus.toString()))
        case .alreadyLinked:
          self.message(title: "Fehler", message: "\nDie eMail-Adresse ist bereits mit einem Digiabo verbunden.")
          closure(.success(subStatus.toString()))
        case .tazIdNotValid:
          self.message(title: "Fehler", message: "\nWir haben Ihnen eine eMail geschickt.")
          closure(.success(subStatus.toString()))
        case .invalidMail:
          self.message(title: "Fehler", message: "\nKeine gültige eMail-Adresse.")
          closure(.success(subStatus.toString()))
        default :
          self.message(title: "Fehler", message: "\nUnbekannte Antwort vom Server.")
          closure(.success(subStatus.toString()))
        }
      case .failure(let error) :
        closure(.failure(error))
      }
      
    }
  }
    
  /// registering a trialsubscription to the given tazID
  public func trail4tazID(mail : String, password: String, surname: String?, firstname: String?) {
    if !mail.contains("@") {
      self.message(title: "Fehler", message: "\nBitte geben Sie eine E-Mail Adresse an.")
      return
    }
    
    self.feeder.trialSubscription(tazId: mail, password: password, surname: surname ?? "", firstName: firstname ?? "", installationId: self.installationId, pushToken: self.pushToken) { result in
      // Result<GqlSubscriptionInfo, Error>
      let substat = result.value()?.status
      switch substat {
      case .waitForProc:
        self.feeder.subscriptionPoll(installationId: self.installationId) { res in
          
        }
      case .waitForMail:
        self.message(title: "Mail wurde versand", message: "Danke für Ihre Registrirung! Wir haben Ihnen eine Mail an \(mail) geschickt. Bitte öffnn Sie die Mail und bestädtigen Sie Ihre Adresse. Sobald die Mail-Adresse bestätigt wurde, können Sie die neue taz-App nutzen.")
      case .alreadyLinked:
        self.message(title: "Fehler", message: "\nDie eMail-Adresse ist bereits mit einem Digiabo verbunden.")
      case .tazIdNotValid:
        self.message(title: "Fehler", message: "\nWir haben Ihnen eine eMail geschickt.")
      case .invalidMail:
        self.message(title: "Fehler", message: "\nKeine gültige eMail-Adresse.")
      default :
        self.message(title: "Fehler", message: "\nUnbekannte Antwort vom Server.")
      }
    }
  }
  
  /// Ask user for id/password, check abo- or taz-ID and link them if necessary
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
                  self?.debug("default: Unbekannte Antwort vom Server")
                  this.message(title: "Fehler", message: "\nUnbekannte Antwort vom Server."){this.askingAgainForLogin()}
                  }
            
            } else {
              this.failedLoginMessage(title: "Fehler", message: "\n Login fehlgeschlagen.", id: id){ this.askingAgainForLogin()}
            }
            
            closure(result)
          }
        }
        if id.isAboID {        // aboID - digiAboId
          this.debug("AboID erkannt: \(id)")
          /*
           es muss gecheckt werden ob tazID exestiert
           wenn ja dann verknüfen, sonst
           tazID erstellen und mit abo verknüfen
           */
          this.feeder.checkSubscriptionId(aboId: id, password: password) { resAuthInfo in
            if let AuthInfo = resAuthInfo.value() {
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
                // let mail = AuthInfo.message
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
                    this.feeder.authToken = token
                    this.askingForUserData { (tazId :String?, tazPassword: String?, surname: String?, firstname: String?) in
                      self?.debug(token)
                      this.feeder.subscriptionId2tazId(tazId: tazId ?? "", password: tazPassword ?? "", aboId: id, aboIdPW: password, surname: surname, firstName: firstname, installationId: this.installationId, pushToken: this.pushToken) { Result in
//                        var ret: Result<GqlSubscriptionInfo, Error>
                        self?.debug(Result.value()?.status.toString())
                        switch Result {
                        case .success(let info):
                          closure(.success(info.message ?? ""))
                        case .failure:
                          closure(.failure(this.error("User refused to log in")))
                        }
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
                this.message(title: "Fehler", message: "\nUnbekannte Antwort vom Server"){this.askingAgainForLogin()}
              }
            }
              switch resAuthInfo {
              case .success(let info):
                closure(.success(info.message ?? ""))
              case .failure:
                closure(.failure(this.error("User refused to log in")))
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
            closure(result)
          }
        } //endif promo
      } // end if let
      closure(.failure(this.error("User refused to log in")))
    }
  }
}

extension String  {
  /// checking if this String is aboID (Number)
  var isAboID: Bool {
    return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
  }
}
