//
//  json.swift
//
//  Created by Norbert Thies on 03.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import Foundation

public func json2Object<T>(_ json: String) -> T? {
  do {
    if let data = json.data(using: .utf8) {
      return try JSONSerialization.jsonObject(with:data) as? T
    }
  }
  catch { Log.exception(error) }
  return nil
}

/// Extension to convert Dictionary<String,Any> to JSON and vice versa
public extension Dictionary where Key==String, Value==Any {
  
  /// Return the Dictionary in JSON-Format if possible
  public var json: String {
    var ret = "{}"
    if let jsonData = try? JSONSerialization.data(withJSONObject: self,
                                                  options:.sortedKeys) {
      if let s = String(bytes: jsonData, encoding: String.Encoding.utf8) {
        ret = s
      }
    }
    return ret
  }
  
  public static func json(_ str: String) -> Dictionary<String,Any>? {
    return json2Object(str)
  }
  
}

/// Extension to convert Array<Any> to JSON and vice versa
public extension Array where Element==Any {
  
  /// Return the Dictionary in JSON-Format if possible
  public var json: String {
    var ret = "[]"
    if let jsonData = try? JSONSerialization.data(withJSONObject: self,
                                                  options:.sortedKeys) {
      if let s = String(bytes: jsonData, encoding: String.Encoding.utf8) {
        ret = s
      }
    }
    return ret
  }
  
  public static func json(_ str: String) -> Dictionary<String,Any>? {
    return json2Object(str)
  }
  
}


