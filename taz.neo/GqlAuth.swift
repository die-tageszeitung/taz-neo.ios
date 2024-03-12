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
  /// firstname+lastname is too long
   case nameTooLong = "nameTooLong"
  /// firstname and lastname only contain invalid chars
  case invalidAccountholder = "invalidAccountHolder"
  /// invalid char in surname
  case invalidSurname = "invalidSurname"
  /// invalid char in firstname
  case invalidFirstname = "invalidFirstname(invalidFirstName)"
  /// too many poll tries
  case tooManyPollTrys = "tooManyPollTrys"
  ///not handling payment:   ibanInvalidChecksum,   ibanNoSepaCountry,   invalidCity,   invalidCountry,   invalidPostcode,   invalidStreet,   priceNotValid
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

/// A GqlSubscriptionInfo describes an GqlAuthStatus with an optional message
struct GqlSubscriptionFormData: GQLObject {
  /// Subscription status
  var error:  GqlSubscriptionFormDataError?
  /// Optional message in case of !valid
  var errorMessage: String?

  
  static var fields = "error errorMessage"
  
  func toString() -> String {
    var ret = ""
    if let error = error { ret += "\n error: \(error.toString())" }
    if let errorMessage = errorMessage { ret += "errorMessage: \(errorMessage)" }
    return ret
  }
} // GqlSubscriptionInfo

/// Subscription Form Data Error
enum GqlSubscriptionFormDataError: String, CodableEnum {
  case noMail = "noMail" //no mail adress given
  case invalidMail = "invalidMail" //invalid mail adress
  case noSurname = "noSurname" //no noSurname" given
  case noFirstName = "noFirstName" //no Firstname given
  case noCity = "noCity" //no City given
  case employees = "employees" //form not for internal users
  case unknown          = "unknown"   /// decoded from unknown string

  func errWithMessage(message: String?) -> SubscriptionFormDataError {
    switch self {
      case .noMail:
        return .noMail(message)
      case .invalidMail:
        return .invalidMail(message)
      case .noSurname:
        return .noSurname(message)
      case .noFirstName:
        return .noFirstName(message)
      case .noCity:
        return .noCity(message)
      case .employees:
        return .employees(message)
      case .unknown:
        return .unknown(message)
    }
  }
  
  
}

/// Subscription Form Data Error
enum SubscriptionFormDataError: Error {
  case noMail(String?)
  case invalidMail(String?)
  case noSurname(String?)
  case noFirstName(String?)
  case noCity(String?)
  case employees(String?)
  case unknown(String?)
  case unexpectedResponse(String?)

  public var errorDescription: String? { return description }
  
  public var associatedValue: String? {
    switch self {
      case .noMail(let msg): return msg
      case .invalidMail(let msg): return msg
      case .noSurname(let msg): return msg
      case .noFirstName(let msg): return msg
      case .noCity(let msg): return msg
      case .employees(let msg): return msg
      case .unknown(let msg): return msg
      case .unexpectedResponse(let msg): return msg
    }
  }

} // SubscriptionFormDataError


/// A GqlSubscriptionResetInfo describes the result of a subscriptionReset method
struct GqlSubscriptionResetInfo: GQLObject {  
  /// Subscription reset status
  var status:  GqlSubscriptionResetStatus
  
  static var fields = "status"
  
  func toString() -> String {
    "status: \(status.toString())"
  }  
} // GqlSubscriptionResetInfo

/// GqlCancellationStatus describes the result for user account cancelation/deletion
struct GqlCancellationStatus: GQLObject {
  
  var tazIdMail:  String? //Mail of the taz-ID
  var info:GqlCancellationInfo //Infos for account cancelation details
  var cancellationLink: String? //link to portal for deletion of other roles
  var canceled: Bool //is account already canceled?
  
  static var fields = "tazIdMail cancellationLink info canceled"
  
  func toString() -> String {
    return " \(info.toString())"
    + " tazIdMail \(tazIdMail ?? "-")"
    + " cancellationLink \(cancellationLink ?? "-")"
    + " canceled \(canceled)"
  }
} // GqlCancellationStatus

/// GqlCancellationInfo hold details for GqlCancellationStatus response
enum GqlCancellationInfo: String, CodableEnum {
  case aboId = "aboId"//regular cancelation with aboId, can be deleted from app with force delete flag
  case tazId = "tazId"//regular cancelation with tazId
  case noAuthToken = "noAuthToken"//invalid request missing auth token
  case elapsed = "elapsed"//subscription already elapsed, call portal link to delete other roles
  case specialAccess = "specialAccess"//special Access, cannot be deleted
  case unknown = "unknown"   /// decoded from unknown string
} // GqlCancellationInfo

extension GqlFeeder {
  
  // Get GqlSubscriptionInfo (while waiting for mail confirmation)
  func subscriptionPoll(installationId: String,
                        closure: @escaping(Result<GqlSubscriptionInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      subscriptionInfo: 
        subscriptionPoll(\(deviceInfoString), installationId: "\(installationId)") {
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
      checkSubscriptionId(\(self.deviceInfoString), subscriptionId: \(aboId), password: "\(password)"){
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
    let aid = Int32(aboId) ?? 0
    var args = """
    tazId: \(tazId.quote()), idPw: \(password.quote()),
    subscriptionId: \(aid), subscriptionPw: \(aboIdPW.quote()), 
    installationId: "\(installationId)"
    """
    if let str = surname { args += ", surname: \"\(str)\"" }
    if let str = firstName { args += ", firstName: \"\(str)\"" }
    if let str = pushToken { args += ", pushToken: \"\(str)\"" }
    args += ", \(deviceInfoString)"
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
    var args = """
    tazId: \(tazId.quote()), idPw: \(password.quote()), 
    installationId: "\(installationId)"
    """
    if let str = surname { args += ", surname: \"\(str)\"" }
    if let str = firstName { args += ", firstName: \"\(str)\"" }
    if let str = pushToken { args += ", pushToken: \"\(str)\"" }
    args += ", \(deviceInfoString)"
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
      passwordReset(\(deviceInfoString), eMail: "\(email)")
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
      subscriptionReset(\(deviceInfoString), subscriptionId: \(aboId)) {
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
    let id = Int32(aboId) ?? 0
    let request = """
    unlinkSubscriptionId(\(self.deviceInfoString), subscriptionId: \(id), password: \(password.quote())) {
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
  
  /// send error report to server
  func requestAccountDeletion(forceDelete: Bool = false,
                                     finished: @escaping(Result<GqlCancellationStatus,Error>)->()) {
    guard let gqlSession = self.gqlSession else {
      finished(.failure(fatal("Not connected"))); return
    }
    let request = "cancellation(isForce: \(forceDelete ? "true" : "false")){\(GqlCancellationStatus.fields)}"
    
    gqlSession.mutation(graphql: request, type: [String:GqlCancellationStatus].self) { (res) in
      var ret: Result<GqlCancellationStatus,Error>
      switch res {
        case .success(let dict):
          ret = .success(dict["cancellation"]!)
        case .failure(let err):  ret = .failure(err)
      }
      finished(ret)
    }
  }
  
  // Get current Subscription Infos
  func customerInfo(closure: @escaping(Result<GqlCustomerInfo,Error>)->()) {
    guard let gqlSession = self.gqlSession else {
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      customerInfo{\(GqlCustomerInfo.fields)}
    """
    gqlSession.query(graphql: request, type: [String:GqlCustomerInfo].self) { (res) in
      var ret: Result<GqlCustomerInfo,Error>
      switch res {
      case .success(let dict):
        let ai = dict["customerInfo"]!
        ret = .success(ai)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  /// Send contact form data to subscription department
  func subscriptionFormData(type: SubscriptionFormDataType,
                            mail: String?,
                            surname: String?,
                            firstName: String?,
                            street: String?,
                            city: String?,
                            postcode: String?,
                            subscriptionId: Int32?,
                            message: String?,
                            requestCurrentSubscriptionOpportunities: Bool?,
                            closure: @escaping(Result<Bool,Error>)->()) {
    guard let gqlSession = self.gqlSession else {
      closure(.failure(fatal("Not connected"))); return
    }
    
    var fields:[String] = []
    
    fields.append("type: \(type.toString())")
    
    if let str = mail {  fields.append("mail: \(str.quote())") }
    if let str = surname {  fields.append("surname: \(str.quote())") }
    if let str = firstName {  fields.append("firstName: \(str.quote())") }
    if let str = street {  fields.append("street: \(str.quote())") }
    if let str = city {  fields.append("city: \(str.quote())") }
    if let str = postcode {  fields.append("postcode: \(str.quote())") }
    if let subscriptionId = subscriptionId {  fields.append("subscriptionId: \(subscriptionId)") }
    if let str = message {  fields.append("message: \(str.quote())") }
    if let bool = requestCurrentSubscriptionOpportunities {
      fields.append("requestCurrentSubscriptionOpportunities: \(bool ? "true" : "false")")
    }
    let request = """
      subscriptionFormData(\(fields.joined(separator: ", ")), \(deviceInfoString)) {
        \(GqlSubscriptionFormData.fields)
      }
    """
    
    gqlSession.mutation(graphql: request, type: [String:GqlSubscriptionFormData].self) { (res) in
      var ret: Result<Bool,Error>
      switch res {
        case .success(let dict):
          if let data = dict["subscriptionFormData"],
              let err = data.error,
              let msg = data.errorMessage {
            ret = .failure(err.errWithMessage(message: msg))
          }
          else {
            ret = .success(true)
          }
        case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }

} // GqlFeeder
