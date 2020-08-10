//
//  GqlAuth.swift
//
//  Created by Norbert Thies on 19.02.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// Subscription status
enum GqlSubscriptionStatus: String, CodableEnum { 
  /// valid authentication
  case valid = "valid"  
  /// tazId not verified
  case tazIdNotValid = "tazIdNotValid"     
  /// AboId not verified
  case subscriptionIdNotValid = "subscriptionIdNotValid" 
  /// AboId valid but connected to different tazId
  case invalidConnection = "invalidConnection"  
  /// valid tazId connected to different AboId
  case alreadyLinked = "alreadyLinked" 
  /// we are waiting for eMail confirmation (using push/poll)
  case waitForMail = "waitForMail" 
  /// server will confirm later (using push/poll)
  case waitForProc = "waitForProc"     
  /// user probably didn't confirm mail
  case noPollEntry = "noPollEntry" 
  /// invalid mail address (only syntactic check)
  case invalidMail = "invalidMail"    
  /// account provided by token is expired
  case expired = "expired(elapsed)"      
  /// no surname provided - seems to be necessary fro trial subscriptions
  case noSurname = "noSurname"  
  /// no firstname provided 
  case noFirstname = "noFirstname(noFirstName)"           
  case unknown     = "unknown"   /// decoded from unknown string
} // GqlSubscriptionStatus

/// Password reset info
enum GqlPasswordResetInfo: String, CodableEnum {
  /// mail sent to user
  case ok = "ok"     
  /// invalid mail address
  case invalidMail = "invalidMailAddress(invalidMail)" 
  /// currently mail delivery not possible
  case mailError = "mailError"     
  /// internal server error
  case serverError = "serverError(error)" 
  case unknown     = "unknown"   /// decoded from unknown string
} // GqlPasswordResetInfo

/// Subscription reset status
enum GqlSubscriptionResetStatus: String, CodableEnum {
  /// mail sent to user
  case ok = "ok"
  /// invalid/unknown subscription Id aka AboId
  case invalidSubscriptionId = "invalidSubscriptionId" 
  /// unknown mail address
  case unknownMailAdress = "unknownMailAddress(noMail)"
  /// AboId already connected with tazId
  case alreadyConnected = "alreadyConnected(invalidConnection)"     
  case unknown          = "unknown"   /// decoded from unknown string
} // GqlSubscriptionResetStatus

/// A GqlSubscriptionInfo describes an GqlAuthStatus with an optional message
struct GqlSubscriptionInfo: GQLObject {  
  /// Subscription status
  var status:  GqlSubscriptionStatus
  /// Optional message in case of !valid
  var message: String?
  /// Authentication token (JWT-Format)
  var token: String?
  
  static var fields = "status message token"
  
  func toString() -> String {
    var ret = "status: \(status.toString())"
    if let msg = message { ret += "\n message: \(msg)" }
    if let token = token { ret += "token: \(token)" }
    return ret
  }  
} // GqlSubscriptionInfo

/// A GqlSubscriptionResetInfo describes the result of a subscriptionReset method
struct GqlSubscriptionResetInfo: GQLObject {  
  /// Subscription reset status
  var status:  GqlSubscriptionResetStatus
  
  static var fields = "status"
  
  func toString() -> String {
    "status: \(status.toString())"
  }  
} // GqlSubscriptionResetInfo

extension GqlFeeder {
  
  // Get GqlSubscriptionInfo (while waiting for mail confirmation)
  func subscriptionPoll(installationId: String,
                        closure: @escaping(Result<GqlSubscriptionInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      subscriptionInfo: 
        subscriptionPoll(installationId: "\(installationId)") {
          \(GqlSubscriptionInfo.fields)
        }
    """
    gqlSession.query(graphql: request, type: [String:GqlSubscriptionInfo].self) { (res) in
      var ret: Result<GqlSubscriptionInfo,Error>
      switch res {
      case .success(let ss):   
        let ssi = ss["subscriptionInfo"]!
        ret = .success(ssi)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  // Check whether AboId password is correct
  func checkSubscriptionId(aboId: String, password: String,
    closure: @escaping(Result<GqlAuthInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      checkSubscriptionId(subscriptionId: \(aboId), password: "\(password)") {
        \(GqlAuthInfo.fields)
      }
    """
    gqlSession.query(graphql: request, type: [String:GqlAuthInfo].self) { (res) in
      var ret: Result<GqlAuthInfo,Error>
      switch res {
      case .success(let dict):   
        let ai = dict["checkSubscriptionId"]!
        ret = .success(ai)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  // Connect a legacy subscription ID to a tazId
  func subscriptionId2tazId(tazId: String, password: String, aboId: String, 
    aboIdPW: String, surname: String?, firstName: String?, installationId: String,
    pushToken: String?, deviceType: String? = "apple",
    closure: @escaping(Result<GqlSubscriptionInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    // TODO: aboId with quotes
    var args = "tazId: \"\(tazId)\", idPw: \"\(password)\", subscriptionId: \(aboId)"
    args += ", subscriptionPw: \"\(aboIdPW)\", installationId: \"\(installationId)\""
    if let str = surname { args += ", surname: \"\(str)\"" }
    if let str = firstName { args += ", firstName: \"\(str)\"" }
    if let str = pushToken { args += ", pushToken: \"\(str)\"" }
    if let str = deviceType { args += ", deviceType: \(str)" }
    let request = """
      subscriptionId2tazId(\(args)) {
        \(GqlSubscriptionInfo.fields)
      }
    """
    gqlSession.mutation(graphql: request, type: [String:GqlSubscriptionInfo].self) { (res) in
      var ret: Result<GqlSubscriptionInfo,Error>
      switch res {
      case .success(let dict):   
        let si = dict["subscriptionId2tazId"]!
        ret = .success(si)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  // Inform server about a trial subscriber
  func trialSubscription(tazId: String, password: String, surname: String?, 
    firstName: String?, installationId: String, pushToken: String?, 
    deviceType: String? = "apple",
    closure: @escaping(Result<GqlSubscriptionInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    // TODO: aboId with quotes
    var args = "tazId: \"\(tazId)\", idPw: \"\(password)\", installationId: \"\(installationId)\""
    if let str = surname { args += ", surname: \"\(str)\"" }
    if let str = firstName { args += ", firstName: \"\(str)\"" }
    if let str = pushToken { args += ", pushToken: \"\(str)\"" }
    if let str = deviceType { args += ", deviceType: \(str)" }
    let request = """
      trialSubscription(\(args)) {
        \(GqlSubscriptionInfo.fields)
      }
    """
    gqlSession.mutation(graphql: request, type: [String:GqlSubscriptionInfo].self) { (res) in
      var ret: Result<GqlSubscriptionInfo,Error>
      switch res {
      case .success(let dict):   
        let si = dict["trialSubscription"]!
        ret = .success(si)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  // asking for a password reset
  // Ask server to send a "password change email" to a user with tazId
  func passwordReset(email: String,
    closure: @escaping(Result<GqlPasswordResetInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      passwordReset(eMail: "\(email)")
    """
    gqlSession.mutation(graphql: request, type: [String:GqlPasswordResetInfo].self) { (res) in
      var ret: Result<GqlPasswordResetInfo,Error>
      switch res {
      case .success(let dict):   
        let pi = dict["passwordReset"]!
        ret = .success(pi)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  // Ask server to send a "password change email" to a user with aboId
  func subscriptionReset(aboId: String,
    closure: @escaping(Result<GqlSubscriptionResetInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      subscriptionReset(subscriptionId: \(aboId)) {
        \(GqlSubscriptionResetInfo.fields)
      }
    """
    gqlSession.mutation(graphql: request, type: [String:GqlSubscriptionResetInfo].self) { (res) in
      var ret: Result<GqlSubscriptionResetInfo,Error>
      switch res {
      case .success(let dict):   
        let si = dict["subscriptionReset"]!
        ret = .success(si)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  // Unlink the connection of a certain subsciptionId with a tazId
  func unlinkSubscriptionId(aboId: String, password: String,
    closure: @escaping(Result<GqlAuthInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      unlinkSubscriptionId(subscriptionId: \(aboId), password: "\(password)") {
        \(GqlAuthInfo.fields)      
      }
    """
    gqlSession.mutation(graphql: request, type: [String:GqlAuthInfo].self) { (res) in
      var ret: Result<GqlAuthInfo,Error>
      switch res {
      case .success(let dict):   
        let ai = dict["unlinkSubscriptionId"]!
        ret = .success(ai)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }

} // GqlFeeder
