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
  
  public override var isDebugLogging: Bool { false }
  
  /// The Server URL to get data from
  public var url: String?
  
  /// The authentication token to use
  public var authToken: String? {
    didSet { header["X-tazAppAuthKey"] = authToken }
  }
  
  public init(_ url: String, authToken: String? = nil) {
    self.url = url
    super.init(name: "GQL:\(url)")
    if let authToken {
      self.authToken = authToken
      header["X-tazAppAuthKey"] = authToken
    }
    header["Accept"] = "application/json, */*"
    header["Content-Type"] = "application/json"
    header["Accept-Encoding"] = "gzip"
  }
  
  private func requestResult<T>(data: Data?, graphql: String, type: T.Type)
    -> Result<T,Error> where T: Decodable {
    var result: Result<T,Error>
    if let d = data {
      self.debug("Received: \"\(String(decoding: d, as: UTF8.self)[0..<2000])\"")
      if let gerr = GraphQlError.from(data: d) {
        self.error("Errorneous data sent to server: \(graphql)")
        self.fatal("GraphQL-Server encountered error:\n\(gerr)")
        result = .failure(gerr)
      }
      else {
        do {
          let dec = JSONDecoder()
          let dict = try dec.decode([String:T].self, from: d)
          result = .success(dict["data"]!)
        }
        catch let DecodingError.dataCorrupted(context) {
          print(context)
          result = .failure(self.fatal("JSON decoding error"))
        } catch let DecodingError.keyNotFound(key, context) {
          print("Key '\(key)' not found:", context.debugDescription)
          print("codingPath:", context.codingPath)
          result = .failure(self.fatal("JSON decoding error"))
        } catch let DecodingError.valueNotFound(value, context) {
          print("Value '\(value)' not found:", context.debugDescription)
          print("codingPath:", context.codingPath)
          result = .failure(self.fatal("JSON decoding error"))
        } catch let DecodingError.typeMismatch(type, context)  {
          print("Type '\(type)' mismatch:", context.debugDescription)
          print("codingPath:", context.codingPath)
          result = .failure(self.fatal("JSON decoding error"))
        } catch {
          print("error: ", error)
          result = .failure(self.fatal("JSON decoding error"))
        }
        catch {
          result = .failure(self.fatal("JSON decoding error"))
        }
      }
    }
    else { result = .failure(self.fatal("No data from GraphQL server")) }
    return result
  }
  
  public func request<T>(requestType: String, graphql: String, type: T.Type,
                         fromData: Data? = nil, returnOnMain: Bool = true, closure: @escaping(Result<T,Error>)->())
    where T: Decodable {
    guard let url = self.url else { return }
    if let data = fromData {
      closure(requestResult(data: data, graphql: graphql, type: type))
    }
    else {
      let quoted = "\(requestType) {\(graphql)}".quote()
      let str = "{ \"query\": \(quoted) }"
      debug("Sending: \(requestType) {\n\(graphql)\n}")
      post(url, data: str.data(using: .utf8)!, returnOnMain: returnOnMain) { [weak self] res in
        guard let self = self else { return }
        if case let .success(data) = res {
          closure(self.requestResult(data: data, graphql: graphql, type: type))
        }
        else if case let .failure(err) = res {
          closure(.failure(err))
        }
      }
    }
  }
  
  public func query<T>(graphql: String, type: T.Type,
                       fromData: Data? = nil, returnOnMain: Bool = true, closure: @escaping(Result<T,Error>)->())
    where T: Decodable { 
      request(requestType: "query", graphql: graphql, type: type, fromData: fromData, returnOnMain: returnOnMain,
              closure: closure)
  }
  
  public func mutation<T>(graphql: String, type: T.Type, closure: @escaping(Result<T,Error>)->()) 
    where T: Decodable { 
      request(requestType: "mutation", graphql: graphql, type: type, closure: closure)
  }
  
} // class GraphQlSession
