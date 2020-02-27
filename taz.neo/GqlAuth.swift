//
//  GqlAuth.swift
//
//  Created by Norbert Thies on 19.02.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// Subscription status
enum GqlSubscriptionStatus: Decodable {  
  case valid                  /// valid authentication
  case tazIdNotValid          /// tazId not verified
  case subscriptionIdNotValid /// AboId not verified
  case invalidConnection      /// AboId valid but connected to different tazId
  case alreadyLinked          /// valid tazId connected to different AboId
  case waitForMail            /// we are waiting for eMail confirmation
  case waitForProc            /// server will confirm later, use polling/push not.
  case noPollEntry            /// user probably didn't confirm mail
  case invalidMail            /// invalid mail address 
  case expired                /// account provided by token is expired
  case unknown                /// unknown subscription status    
  
  func toString() -> String {
    switch self {
    case .valid:                  return "valid"
    case .tazIdNotValid:          return "tazIdNotValid"
    case .subscriptionIdNotValid: return "subscriptionIdNotValid"
    case .invalidConnection:      return "invalidConnection"
    case .alreadyLinked:          return "alreadyLinked"
    case .waitForMail:            return "waitForMail"
    case .waitForProc:            return "waitForProc"
    case .noPollEntry:            return "noPollEntry"
    case .invalidMail:            return "invalidMail"
    case .expired:                return "expired"
    case .unknown:                return "unknown"
    }
  }
  
  init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "valid"   :               self = .valid
    case "tazIdNotValid":          self = .tazIdNotValid
    case "subscriptionIdNotValid": self = .subscriptionIdNotValid
    case "invalidConnection":      self = .invalidConnection
    case "alreadyLinked":          self = .alreadyLinked
    case "waitForMail":            self = .waitForMail
    case "waitForProc":            self = .waitForProc
    case "noPollEntry":            self = .noPollEntry
    case "invalidMail":            self = .invalidMail
    case "elapsed" :               self = .expired
    default:                       self = .unknown  
    }
  }
  
} // GqlSubscriptionStatus

/// Password reset info
enum GqlPasswordResetInfo: Decodable {

  case ok           /// mail sent to user
  case invalidMail  /// invalid mail address
  case mailError    /// currently mail delivery not possible
  case error        /// internal server error
  case unknown      /// unknown situation
  
  func toString() -> String {
    switch self {
    case .ok:          return "mail has been sent"
    case .invalidMail: return "invalid mail address"
    case .mailError:   return "currently mail delivery not possible"
    case .error:       return "internal server error"
    case .unknown:     return "undefined situation"
    }
  }
  
  init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "ok"   :       self = .ok
    case "invalidMail": self = .invalidMail
    case "mailError":   self = .mailError
    case "error":       self = .error
    default:            self = .unknown  
    }
  }

} // GqlPasswordResetInfo

/// Subscription reset status
enum GqlSubscriptionResetStatus: Decodable {

  case ok                     /// mail sent to user
  case invalidSubscriptionId  /// invalid subscription Id
  case noMail                 /// no mail address known on server
  case invalidConnection      /// internal server error
  case unknown                /// unknown situation
  
  func toString() -> String {
    switch self {
    case .ok:                    return "mail has been sent"
    case .invalidSubscriptionId: return "invalid subscription ID"
    case .noMail:                return "unknown mail address"
    case .invalidConnection:     return "invalid connection"
    case .unknown:               return "undefined situation"
    }
  }
  
  init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "ok"   :                 self = .ok
    case "invalidSubscriptionId": self = .invalidSubscriptionId
    case "noMail":                self = .noMail
    case "invalidConnection":     self = .invalidConnection
    default:                      self = .unknown  
    }
  }

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
  /// Mail recipient or tazId mail address if invalidConnection
  var mail: String?
  
  static var fields = "status mail"
  
  func toString() -> String {
    var ret = "status: \(status.toString())"
    if let mail = mail { ret += "\n mail: \(mail)" }
    return ret
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
