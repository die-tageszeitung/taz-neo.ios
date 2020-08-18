//
//
// DefaultAuthenticator.swift
//
// Created by Ringo Müller-Gromes on 07.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

/**
  # strategy finding discussion: What is this class? Which technique connects the caller (somewhere in the app) with the forms.
  # Problem: Ich habe 5+ ViewController (ConnectTazIDController, TrialSubscriptionController, Login...), die eine gemeinsame Schnittstelle zur App benötigen
  
  # Lösungsidee #1
  - VC's kümmern sich nur um ihr UI
  - ich habe 7 Requests und deren Behandlung in 4 VC's
  - hier werden die Requests gebündelt und verarbeitet,
  - **nein**, wird unübersichtlich, da an einer stelle requests gemacht werden an anderer stelle darauf im UI reagiert wird
  - Requests werden wie gehabt an entsprechende Stelle im VC implementiert
    
  # Problematik
  - der DefaultAuthenticator müsste "verfügbar sein"
  #1 Singleton NO: Singeltons are bad: loose of transparency, don't use them if there is a better solution
  #2 als Diese Instanz/Klasse Parameter übergeben // reference nightmare: child holds parents reference
  #3 #2 entkoppeln via Protokoll Erweiterung vom Authenticator
     
  # Lösungsskizze
  - App calls DefaultAuthenticator().authenticate()
    DefaultAuthenticator => presents LoginController...
 
    Wohin geht die Reise?  Zustandsautomat?
    => Nein, ich muss mir keinen Zustand merken, der nach App Neustart wieder hergestellt wird
     
    Alternative: Anlehnung an **Mediator Pattern**: Die Instanz dieser Klasse vermittelt zwischen App und den Formularen!
 */

/**
 # Name finding Discussion: Wie heist die Protokoll Erweiterung zum Authenticator?
 
 # Die Klasse, welche die Erweiterung vom Authenticator implementiert heißt: DefaultAuthenticator : Authenticator, ????
 
 # Das Protokoll soll als Vermittler zwischen den Anmelde/Register Dialogen und der App (externen Aufrufhierachie) dienen und stellt dafür folgende funktionalitäten bereit:
 - storeTempUserData
 - getTempUserData
 - deleteTempUserData
 - pollSubscription(id, pass)
 - ZUgriff auf den Feeder vom erweiterten/vererbten Authenticator Protokoll
  
# Wie heißen die Nutzer dieses Protokolls:
 - LoginController -> FormsController
 - TrialSubscriptionController -> FormsController
 - ConnectTazIDController -> TrialSubscriptionController -> FormsController
 - ...
 
 # Wer wird Wie die Referenz zur Instanz halten?
 - FormsController als z.B. **Delegate**, **???Authenticator**
 
 # Kandidaten für Namen
 - AuthenticatorDelegate: zu allgemein, nichtssagend
 - ViewsAuthenticator: zu allgemein, nichtssagend
 - ExtendedAuthenticator: nichtssagend
 - **AuthMediator**: am zutreffensten => AuthMediator ist eine Erweiterung von Authenticator!
 */


/**
 This Protocol defines the handling between AuthForms e.g. LoginForm and the App.
 It extends the Authenticator for Functions to wait for poll with temporary taz-Id and temporara taz-Id Password
 */
public protocol AuthMediator : Authenticator {
  
  func pollSubscription(tmpId:String, tmpPassword:String)
  /**
   Use this method to store user authentication data in user defaults and keychain
   
   id is stored in user defaults and keychain whereas the password is
   only written to the keychain.
   
   - parameters:
     - id: the user's ID
     - password: the user's password
  */
  static func storeTempUserData(tmpId: String, tmpPassword: String)
  
  /**
   Use this method to retrieve user data
   All returned values may be nil if no user data has been stored so far
   
   - returns: A tuple consisting of (id, password)
   */
  static func getTempUserData() -> (tmpId: String?, tmpPassword: String?)
   
  /**
   Use this method to delete authentication relevant user data
   */
  static func deleteTempUserData()

  var performPollingClosure: (()->())? { get set}
  var authenticationSucceededClosure: ((Error?)->())? { get set}
}


extension AuthMediator {
  
  static var keychainTempId: String { return "tmpId" }
  static var keychainTempIdPassword: String { return "tmpPassword" }
  

  
  public static func storeTempUserData(tmpId: String, tmpPassword: String) {
    let kc = Keychain.singleton
    kc[Self.keychainTempId] = tmpId
    kc[Self.keychainTempIdPassword] = tmpPassword
  }
  
  public static func getTempUserData() -> (tmpId: String?, tmpPassword: String?) {
    let kc = Keychain.singleton
    return (tmpId: kc[Self.keychainTempId],
            tmpPassword: kc[Self.keychainTempIdPassword])
  }
  
  public static func deleteTempUserData() {
    let kc = Keychain.singleton
    kc[Self.keychainTempId] = nil
    kc[Self.keychainTempIdPassword] = nil
  }

}


extension DefaultAuthenticator : AuthMediator{
  public func pollSubscription(tmpId:String, tmpPassword:String){
    Self.storeTempUserData(tmpId: tmpId, tmpPassword: tmpPassword)
    performPollingClosure?()//tell app start polling for incomming push or start timer!
  }
}

public class DefaultAuthenticator: Authenticator {
  
  /// Ref to feeder providing Data
  public var feeder: GqlFeeder

  private var firstPresentedAuthController:UIViewController?
  
  /// Root view controller to present Forms
  private lazy var rootVC: UIViewController? = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return appDelegate.window?.rootViewController
  }()
  
  /// Closure to call when polling of suscription status is required
  public var performPollingClosure: (()->())?
  /// Define closure to call when polling is necessary
  public func whenPollingRequired(closure: @escaping ()->()) {
    performPollingClosure = closure
  }
  
  /// Closure to call when authentication succeeded
  public var authenticationSucceededClosure: ((Error?)->())?
  
  required public init(feeder: GqlFeeder) {
    self.feeder = feeder
    self.pollSubscription { (_) in }
  }
  
  //Called if incomming PushNotification comes or Timer fires
  public func pollSubscription(closure: @escaping (_ continue: Bool)->()) {
    feeder.subscriptionPoll(installationId: installationId) { (result) in
      switch result{
        case .success(let info):
          self.log("subscriptionPoll succeed with status: \(info.status) message: \(info.message ?? "-")")
          switch info.status {
            case .valid:
              guard let token = info.token, token.length > 10 else {
                self.log("Expected Subscription Poll Success have jwt token as info.message, got something else: \(info.message ?? "-")")
                closure(true)//continue polling
                return;
              }
              let tempData = Self.getTempUserData()
              Self.storeUserData(id: tempData.tmpId ?? "",
                                 password: tempData.tmpPassword ?? "",
                                 token: token)
              if let loginFormVc = self.firstPresentedAuthController as? FormsController {
                //Present Success Ctrl if still presenting one of the Auth Controller
                loginFormVc.showResultWith(message: Localized("fragment_login_registration_successful_header"),
                backButtonTitle: Localized("fragment_login_success_login_back_article"),
                dismissType: .all)
              }
              closure(false)//stop polling
              return;
            case .noPollEntry:
              ///happens, if user dies subscriptionId2TazId with existing taz-Id but wrong password
              /// In this case user recived the E-Mail for PW Reset,
              /// and connects them next time, so stop polling
              closure(false)//stop polling
              return;
            case .waitForProc: fallthrough
            case .waitForMail: fallthrough
            default:
              self.log("subscriptionPoll status: \(info.status)", logLevel: .Info)
        }
        case .failure(let err):
          self.log("subscriptionPoll failed with error: \(err)")
        }
        closure(true)//continue polling in case of errors, wait status or invalid
    }
  }
  
  /// Ask user for id/password, check with GraphQL-Server and store in user defaults
  public func authenticate(closure: @escaping (Error?)->()) {
    guard let rootVC = rootVC else { return }
    rootVC.modalPresentationStyle = .formSheet
    let registerController = LoginController(self)
    if #available(iOS 13.0, *) {
      //Prevent dismis by pan down in various modalPresentationStyles
      //the default < iOS 13 Behaviour
      registerController.isModalInPresentation = true
    }
    firstPresentedAuthController = registerController
    authenticationSucceededClosure = closure
    rootVC.present(registerController, animated: true, completion: nil)
  }
}
