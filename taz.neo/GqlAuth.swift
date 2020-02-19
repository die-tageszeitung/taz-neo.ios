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
  case valid             /// valid authentication
  case tazIdNotValid     /// tazId not verified
  case aboIdNotValid     /// AboId not verified
  case invalidConnection /// AboId valid but connected to different tazId
  case alreadyLinked     /// valid tazId connected to different AboId
  case waitForMail       /// we are waiting for eMail confirmation
  case waitForProc       /// server will confirm later, use polling/push not.
  case noPollEntry       /// user probably didn't confirm mail
  case invalidMail       /// invalid mail address 
  case expired           /// account provided by token is expired
  case unknown           /// unknown subscription status    
  
  func toString() -> String {
    switch self {
    case .valid:             return "valid"
    case .tazIdNotValid:     return "tazIdNotValid"
    case .aboIdNotValid:     return "aboIdNotValid"
    case .invalidConnection: return "invalidConnection"
    case .alreadyLinked:     return "alreadyLinked"
    case .waitForMail:       return "waitForMail"
    case .waitForProc:       return "waitForProc"
    case .noPollEntry:       return "noPollEntry"
    case .invalidMail:       return "invalidMail"
    case .expired:           return "expired"
    case .unknown:           return "unknown"
    }
  }
  
  init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "valid"   :          self = .valid
    case "tazIdNotValid":     self = .tazIdNotValid
    case "aboIdNotValid":     self = .aboIdNotValid
    case "invalidConnection": self = .invalidConnection
    case "alreadyLinked":     self = .alreadyLinked
    case "waitForMail":       self = .waitForMail
    case "waitForProc":       self = .waitForProc
    case "noPollEntry":       self = .noPollEntry
    case "invalidMail":       self = .invalidMail
    case "elapsed" :          self = .expired
    default:                  self = .unknown
    }
  }
  
} // GqlSubscriptionStatus

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
    var ret = status.toString()
    if let msg = message { ret += ": (\(msg))" }
    return ret
  }  
} // GqlSubscriptionInfo

extension GqlFeeder {
  
  // Get GqlSubscriptionInfo
  func subscriptionInfo(installationId: String,
                        closure: @escaping(Result<GqlSubscriptionInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      subscriptionInfo: 
        subscriptionPoll(installationId: "\(installationId)")" {
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

} // GqlFeeder
