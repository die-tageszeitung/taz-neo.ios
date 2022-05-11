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
}

class TempUserDataStorage {
  private static let sharedInstance = TempUserDataStorage()
  private var id: String?
  private var pass: String?
  fileprivate static var id: String? {
    get { return sharedInstance.id }
    set { sharedInstance.id = newValue }
  }
  fileprivate static var pass: String? {
    get { return sharedInstance.pass }
    set { sharedInstance.pass = newValue }
  }
}

extension AuthMediator {
  
  func pollSubscription(tmpId:String, tmpPassword:String){
    return pollSubscription(tmpId:tmpId, tmpPassword:tmpPassword, requestSoon:false, resultSuccessText: nil)
  }
  
  func pollSubscription(tmpId:String, tmpPassword:String, requestSoon:Bool){
    return pollSubscription(tmpId:tmpId, tmpPassword:tmpPassword, requestSoon:requestSoon, resultSuccessText: nil)
  }

  static var defaultsTempId: String { return "tmpId" }
  static var defaults: String { return "tmpPassword" }
  

  
  public static func storeTempUserData(tmpId: String, tmpPassword: String) {
    let dfl = Defaults.singleton
    dfl[Self.defaultsTempId] = tmpId
    dfl[Self.defaults] = tmpPassword
    TempUserDataStorage.id = tmpId
    TempUserDataStorage.pass = tmpPassword
  }
  
  public static func getTempUserData() -> (tmpId: String?, tmpPassword: String?) {
    let dfl = Defaults.singleton
    return (tmpId: TempUserDataStorage.id ?? dfl[Self.defaultsTempId],
            tmpPassword: TempUserDataStorage.pass ?? dfl[Self.defaults])
  }
  
  public static func deleteTempUserData() {
    let dfl = Defaults.singleton
    dfl[Self.defaultsTempId] = nil
    dfl[Self.defaults] = nil
    //hold it for now maybe empty braces bug its a race condition
//    TempUserDataStorage.id = nil
//    TempUserDataStorage.pass = nil
  }
}

extension DefaultAuthenticator : AuthMediator{
  
  public func pollSubscription(tmpId: String, tmpPassword: String, requestSoon: Bool = false) {
    pollSubscription(tmpId: tmpId, tmpPassword: tmpPassword, requestSoon: requestSoon, resultSuccessText: nil)
  }
  
  public func pollSubscription(tmpId:String, tmpPassword:String, requestSoon:Bool = false, resultSuccessText:String?){
    
    if let rt = resultSuccessText { self.resultSuccessText = rt}
    
    Self.storeTempUserData(tmpId: tmpId, tmpPassword: tmpPassword)
    let firstPollRequest: DispatchTime = .now() + (requestSoon ? 1.5 : 15.0)
    DispatchQueue.global().asyncAfter(deadline: firstPollRequest) { [weak self] in
      self?.pollSubscription {  [weak self] (resume) in
        if resume == true { self?.performPollingClosure?() }
      }
    }
  }
}

public class DefaultAuthenticator: Authenticator {
  
  /// Ref to feeder providing Data
  public var feeder: GqlFeeder
  
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
  private var performPollingClosure: (()->())?
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
                  onMainAfter {//delay otherwise "Aktualisiere Daten hides this!"
                    Toast.show("Erfolgreich angemeldet!")//like Android!
                  }
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
                                             backButtonTitle: FormsController.backButtonTitle,
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
              /// In this case user received the E-Mail for PW Reset,
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
  public func authenticate(with targetVC:UIViewController? = nil) {
    guard let rootVC = targetVC ?? rootVC else { return }

    let registerController = LoginController(self)
    
    registerController.modalPresentationStyle
      =  .formSheet

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
                  if MainNC.singleton.isErrorReporting { return }
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
