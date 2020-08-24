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
 This Protocol defines the handling between AuthForms e.g. LoginForm and the App.
 It extends the Authenticator for Functions to wait for poll with temporary taz-Id and temporara taz-Id Password
 */
public protocol AuthMediator : Authenticator {
  
  
  ///  save temporary credentials in Keychain and setup pollSubscription (timer/apn)
  /// - Parameters:
  ///   - tmpId: temporary taz-ID
  ///   - tmpPassword: temporary taz-ID Password
  ///   - requestSoon: request the first poll after short timeout, e.g. used in case of `waitForProc`
  func pollSubscription(tmpId:String, tmpPassword:String, requestSoon:Bool)
  
  /// Use this method to store user authentication data in user defaults and keychain
  /// id is stored in user defaults and keychain whereas the password is
  /// only written to the keychain.
  /// - Parameters:
  ///   - tmpId: temporary taz-ID
  ///   - tmpPassword: temporary taz-ID Password
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
  
  func pollSubscription(tmpId:String, tmpPassword:String){
    return pollSubscription(tmpId:tmpId, tmpPassword:tmpPassword, requestSoon:false)
  }
  
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
  
  public func pollSubscription(tmpId:String, tmpPassword:String, requestSoon:Bool = false){
    Self.storeTempUserData(tmpId: tmpId, tmpPassword: tmpPassword)
    if requestSoon == true {
      DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
        self.pollSubscription {  [weak self] (resume) in
          guard let self = self else {return;}
          if resume == true {
            self.performPollingClosure?()
          }
        }
      }
      return;
    }//eof: requestSoon == true
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
          switch info.status {
            case .valid:
              guard let token = info.token, token.length > 10 else {
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
