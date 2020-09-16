//
//  GraphQlSession.swift
//
//  Created by Norbert Thies on 12.09.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// An Error returned by a GraphQL server
public class GraphQlError: LocalizedError, Codable, CustomStringConvertible {  
  
  public struct Location: Codable {
    var line: Int
    var column: Int
    func toString() -> String { return "line \(line), col \(column)" }
  }
  public struct Error: Codable {
    var message: String
    var category: String?
    var locations: [Location]
    func toString() -> String {
      var ret = "\(message) "
      if let cat = category { ret += "[\(cat)] " }
      var pre = "at"
      for loc in locations {
        ret += "\(pre) \(loc.toString())"
        pre = "&"
      }
      return ret
    }
  }  
  public var errors: [Error]
  public var description: String { return toString() }
  public var errorDescription: String? { return toString() }
  
  /// Get GraphQlError from JSON Data
  public static func from(data: Data) -> GraphQlError? {
    let dec = JSONDecoder()
    let ret = try? dec.decode(self, from: data)
    return ret
  }
  
  /// Get GraphQlError from JSON String
  public static func from(json: String) -> GraphQlError? {
    guard let data = json.data(using: .utf8) else { return nil }
    return from(data: data)
  }
  
  /// Return String describing error
  public func toString() -> String {
    var ret = ""
    for e in errors {
      ret += "\(e.toString())\n"
    }
    return ret
  }
  
} // GraphQlError

/// A class to read/write from GraphQL servers
open class GraphQlSession: HttpSession {
  
  /// The Server URL to get data from
  public var url: String?
  
  /// The authentication token to use
  public var authToken: String? {
    didSet { if let auth = authToken { header["X-tazAppAuthKey"] = auth } }
  }
  
  public init(_ url: String, authToken: String? = nil) {
    self.url = url
    self.authToken = authToken
    super.init(name: "GQL:\(url)")
    header["Accept"] = "application/json, */*"
    header["Content-Type"] = "application/json"
    header["Accept-Encoding"] = "gzip"
  }
  
  public func request<T>(requestType: String, graphql: String, type: T.Type, closure: @escaping(Result<T,Error>)->()) 
    where T: Decodable {
    guard let url = self.url else { return }
    let quoted = "\(requestType) {\(graphql)}".quote()
    let str = "{ \"query\": \(quoted) }"
    debug("Sending: \"\(str)\"")
      debug(graphql)
    post(url, data: str.data(using: .utf8)!) { res in
      var result: Result<T,Error>
      switch res {
      case .success(let data):
        if let d = data {
          //self.debug("Received: \"\(String(decoding: d, as: UTF8.self))\"")
          if let gerr = GraphQlError.from(data: d) {
            result = .failure(gerr)
          }
          else {
            do {
              let dec = JSONDecoder()
              let dict = try dec.decode([String:T].self, from: d)
              result = .success(dict["data"]!)
            }
            catch {
              result = .failure(self.error("JSON decoding error"))
            }
          }
        }
        else { result = .failure(self.error("No data from GraphQL server")) }
      case .failure(let err): 
        result = .failure(err)
      }
      closure(result)
    }
  }
  
  public func query<T>(graphql: String, type: T.Type, closure: @escaping(Result<T,Error>)->()) 
    where T: Decodable { 
      request(requestType: "query", graphql: graphql, type: type, closure: closure)
  }
  
  public func mutation<T>(graphql: String, type: T.Type, closure: @escaping(Result<T,Error>)->()) 
    where T: Decodable { 
      request(requestType: "mutation", graphql: graphql, type: type, closure: closure)
  }
  
} // class GraphQlSession
