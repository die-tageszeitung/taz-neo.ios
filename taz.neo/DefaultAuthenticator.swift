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
  func pollSubscription(tmpId:String, tmpPassword:String, requestSoon:Bool, resultSuccessText:String?)
  
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
}

extension AuthMediator {
  
  func pollSubscription(tmpId:String, tmpPassword:String){
    return pollSubscription(tmpId:tmpId, tmpPassword:tmpPassword, requestSoon:false, resultSuccessText: nil)
  }
  
  func pollSubscription(tmpId:String, tmpPassword:String, requestSoon:Bool){
    return pollSubscription(tmpId:tmpId, tmpPassword:tmpPassword, requestSoon:requestSoon, resultSuccessText: nil)
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
  
  public func pollSubscription(tmpId: String, tmpPassword: String, requestSoon: Bool = false) {
    pollSubscription(tmpId: tmpId, tmpPassword: tmpPassword, requestSoon: requestSoon, resultSuccessText: nil)
  }
  
  public func pollSubscription(tmpId:String, tmpPassword:String, requestSoon:Bool = false, resultSuccessText:String?){
    
    if let rt = resultSuccessText { self.resultSuccessText = rt}
  
    Self.storeTempUserData(tmpId: tmpId, tmpPassword: tmpPassword)
    if requestSoon == true {
      DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
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

public class DefaultAuthenticator: Authenticator, HandleOrientation {
  
  /// Ref to feeder providing Data
  public var feeder: GqlFeeder
  public var orientationChangedClosure = OrientationClosure()
  
  private var _resultSuccessText:String?
  fileprivate var resultSuccessText:String {
    get {
      if let text = _resultSuccessText { return text}
      if let text = Defaults.singleton["resultSuccessText"] { return text}
      return Localized("trialsubscription_successful_header")
    }
    set {
      _resultSuccessText = newValue
      Defaults.singleton["resultSuccessText"] = newValue
    }
  }
  
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
    
  required public init(feeder: GqlFeeder) {
    self.feeder = feeder
    let (_,_,token) = SimpleAuthenticator.getUserData()
    if token != nil { feeder.authToken = token! }
  }
  
  //Called if incomming PushNotification comes or Timer fires
  public func pollSubscription(closure: @escaping (_ continue: Bool)->()) {
    feeder.subscriptionPoll(installationId: installationId) { [weak self] (result) in
      guard let self = self else { return;}
      switch result{
        case .success(let info):
          switch info.status {
            case .valid:
              /// Check if we have a token otherwise continue polling and return
              guard let token = info.token, token.length > 10 else {
                closure(true)//continue polling
                return;
              }
              /// Store temp user data as user data and store the token, update the feeder, delete temp
              let tempData = Self.getTempUserData()
              Self.storeUserData(id: tempData.tmpId ?? "",
                                 password: tempData.tmpPassword ?? "",
                                 token: token)
              self.feeder.authToken = token
              Self.deleteTempUserData()
              /// Present Result to User, if Login shown!
              if let loginFormVc = self.firstPresentedAuthController as? FormsController {
                ///Fix User dismissed modal Login, nort be able to send notification due this just come in dismiss callback
                if loginFormVc.presentingViewController == nil {
                  self.firstPresentedAuthController = nil
                  Notification.send("authenticationSucceeded")
                  closure(false)//stop polling
                  return;
                }
                
                let dismissFinishedClosure = {
                  Notification.send("authenticationSucceeded")
                  closure(false)//stop polling
                }
                ///If  already a FormsResultController on top of modal stack use its exchange function
                if let resultCtrl = UIViewController.top(controller: loginFormVc) as? FormsResultController,/// as? is also valid for LoginController
                  type(of: resultCtrl) === FormsResultController.self
                {
                  resultCtrl.exchangeWith(self.resultSuccessText)
                  resultCtrl.dismissType = .allReal
                  resultCtrl.dismissAllFinishedClosure = dismissFinishedClosure
                }
                else {
                  /// if there is no FormsResultController yet, present a new  FormsResultController
                  loginFormVc.showResultWith(message: self.resultSuccessText,
                                             backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                             dismissType: .allReal,
                                             dismissAllFinishedClosure: dismissFinishedClosure)
                }
              }
              /// If No Login shown, just execute the callbacks
              else {//No Form displayed anymore directly execute callbacks
                Notification.send("authenticationSucceeded")
                closure(false)//stop polling
              }
              return;
            case .noPollEntry, .tooManyPollTrys:
              ///happens, if user dies subscriptionId2TazId with existing taz-Id but wrong password
              /// In this case user recived the E-Mail for PW Reset,
              _ = self.error(info.status.rawValue)
              Notification.send("authenticationSucceeded")
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
  public func authenticate() {
    guard let rootVC = rootVC else { return }

    let registerController = LoginController(self)
    registerController.modalPresentationStyle
      =  Device.isIpad ? .formSheet : .overCurrentContext

    firstPresentedAuthController = registerController
    rootVC.present(registerController, animated: true, completion: {
      rootVC.presentationController?.presentedView?.gestureRecognizers?[0].isEnabled = true
      /// Add TapOn Background like in popup presentation
      if Device.isIphone { return }
      //Only iPad
      if let window = UIApplication.shared.delegate?.window {
        for view in window?.subviews ?? []{
          if view.typeName == "UITransitionView" {
            for v in view.subviews {
              if v.typeName == "UIDimmingView" {
                v.onTapping { rec in
                  v.removeGestureRecognizer(rec)
                  registerController.dismiss(animated: true)
                }
                return
              }
            }
          }
        }
      }
    })
  }
  
  public func unlinkSubscriptionId() { 
    SimpleAuthenticator(feeder: self.feeder).unlinkSubscriptionId()
  }
  
} // DefaultAuthenticator


extension UIDevice {
  func updatePopupFrame(for ctrl:UIViewController,
                        minWidth:CGFloat = min(650,
                                               UIScreen.main.bounds.size.width,
                                               UIScreen.main.bounds.size.height)){
//    let
  }
  
  static var currentOrientation : String {
    get{
      switch self.current.orientation {
        case .faceDown:
          return "faceDown"
        case .faceUp:
          return "faceUp"
        case .landscapeLeft:
          return "landscapeLeft"
        case .landscapeRight:
          return "landscapeRight"
        case .portrait:
          return "portrait"
        case .portraitUpsideDown:
          return "portraitUpsideDown"
        case .unknown:
          return "unknown"
        @unknown default:
          return "unknown new"
      }
    }
  }
  
  
}


protocol NameDescribable {
    var typeName: String { get }
    static var typeName: String { get }
}

extension NameDescribable {
    var typeName: String {
        return String(describing: type(of: self))
    }

    static var typeName: String {
        return String(describing: self)
    }
}

// Extend with class/struct/enum...
extension NSObject: NameDescribable {}
