//
//  Authenticator.swift
//
//  Created by Norbert Thies on 07.08.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/**
 An Authenticator is used to handle all authentication related user interactions
 and server operations.
 
 A class obeying the Authenticator protocol must implement:
 
   - var feeder: GqlFeeder
   - init(feeder: GqlFeeder) // to initialize with Feeder
   - whenPollingRequired(closure) // to define a closure to call when polling is needed
   - pollSubscription(closure) // is called by timer when to request new data from server
   - authenticate(closure) // is called to authenticate
 */
public protocol Authenticator: DoesLog {
  
  /// Ref to feeder providing Data 
  var feeder: GqlFeeder { get set }
  /// Temporary Id to identify client if no AuthToken is available
  var installationId: String  { get }
  /// Push token for silent notifications (poll request),
  /// if nil => no push permission
  var pushToken: String? { get}
  
  /// Define closure to call when polling is necessary to set up timer
  func whenPollingRequired(closure: @escaping ()->())
  
  /// Initialize with Feeder and push token  
  init(feeder: GqlFeeder)
  
  /**
   This method is called when either a polling timer fires or a push notification
   indicating authentication changes on the server has been received.
   
   pollSubscription asks the GraphQL-Server for a new subscription status, if 
   a new status is available, the closure is called with a bool indicating
   whether further polling is necessary (true=>continue polling)
   
   - parameters:
     - closure: closure to call when communication with the server has been finished
     - continue: set to true if polling should be continued
  */
  func pollSubscription(closure: @escaping (_ continue: Bool)->())
  
  /// Ask user for id/password, check with GraphQL-Server, store using method 
  /// 'storeUserData' and call closure to indicate success (closure(nil) is success)
  func authenticate()
  
  /**
   Use this method to store user authentication data in user defaults and keychain
   
   token and id are stored in user defaults and keychain whereas the password is
   only written to the keychain.
   
   - parameters:
     - id: the user's ID
     - password: the user's password
     - token: authentication token used when communicating with server
  */
  static func storeUserData(id: String, password: String, token: String) 
  
  /**
   Use this method to retrieve user data
   
   All returned values may be nil if no user data has been stored so far
   
   - returns: A tuple consisting of (id, password, token)
   */
  static func getUserData() -> (id: String?, password: String?, token: String?)
   
  /**
   Use this method to delete authentication relevant user data
   */
  static func deleteUserData()

} // Authenticator 

extension Authenticator {
  /// Returns the App's installation ID
  public var installationId: String  { App.installationId }
  
  /// Returns the App's push token for remote notiofications
  public var pushToken: String?  { Defaults.singleton["pushToken"] }
  
  public static func storeUserData(id: String, password: String, token: String) {
    let dfl = Defaults.singleton
    let kc = Keychain.singleton
    dfl["token"] = token
    dfl["id"] = id
    kc["token"] = token
    kc["id"] = id
    kc["password"] = password
  }
  
  public static func getUserData() -> (id: String?, password: String?, token: String?) {
    let dfl = Defaults.singleton
    let kc = Keychain.singleton
    let kid = kc["id"] 
    let did = dfl["id"]
    let ktoken = kc["token"] 
    let dtoken = dfl["token"]
    if did == nil { dfl["id"] = kid }
    if dtoken == nil { dfl["token"] = ktoken }
    return (id: did, password: kc["password"], token: dtoken)
  } 
  
  public static func deleteUserData() {
    let dfl = Defaults.singleton
    let kc = Keychain.singleton
    kc["token"] = nil
    kc["id"] = nil
    kc["password"] = nil
    dfl["token"] = nil
    dfl["id"] = nil
  }

} // Authenticator extension
