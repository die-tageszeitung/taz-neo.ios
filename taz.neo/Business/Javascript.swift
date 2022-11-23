//
//  Javascript.swift
//  taz.neo
//
//  Created by Ringo Müller on 22.11.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import NorthLib
import WebKit

open class Javascript {
  
  private var jsFileUrl:URL?
  
  private var wv:WebView
  
  @MainActor
  open func evaluate(_ javaScriptString: String) async throws -> Any? {
    return try? await wv.evaluateJavaScript(javaScriptString)
  }
  
  private static func createWebView(_ jsFile:URL?=nil) -> WebView{
    let wv = WebView()
    
    var scriptTag = ""
    
    if let f = jsFile, File(f.path).exists {
      wv.baseDir = f.relativePath
      scriptTag
      = """
            <script type="text/javascript" src="\(f.absoluteURL.lastPathComponent)"></script>
         """
    }
    
    let html = """
     <!DOCTYPE html>
     <html lang="de">
       <head>
         <meta charset="utf-8">
         \(scriptTag)
         <title>Webview2EvalJS</title>
       </head>
       <body>
       </body>
     </html>
     """
    
    wv.load(html: html)
    return wv
  }
  
  
  
  public init(_ jsFileUrl:URL? = nil) {
    wv = Self.createWebView(jsFileUrl)
  }
}
 
public enum passwordQualityLevel: Int {
  case none = 0
  case low = 1
  case medium = 2
  case height = 3
}

extension passwordQualityLevel {
  static func from(_ value:Any?) -> Self{
    if let val = value as? Int, let v = Self(rawValue: val) {
      return v
    }
    return .none
  }
  
  var color:UIColor {
    switch self {
      case .height:
        return .green
      case .medium:
        return .orange
      case .low:
        return .red
      case .none:
        fallthrough
      default:
        return .lightGray
    }
  }
}

public typealias passwordQuality
= (valid: Bool, message:String?, quality:passwordQualityLevel)

///Part of Newspaper App Project
class PasswordValidator: DoesLog {
  
  
//    TazAppEnvironment.sharedInstance.feederContext?.updateResources()
//    if let url = Bundle.main.url(forResource: "pwcheckimport", withExtension: "html", subdirectory: "BundledResources") {
//      wv.load(url: url)
//    }
  
  
 var s =  StoredResources.latest()
  
  var js = Javascript(TazAppEnvironment.sharedInstance.feederContext?.storedFeeder.passwordCheckJsUrl)
  
  
//  func check(password: String, mail: String?) async -> passwordQuality {
//    try await js.evaluate(<#T##javaScriptString: String##String#>)
//
//    return {valid:  true, message: "Du bist auf dem richtigen Weg!", level: 2, color: "#fb0"};
//  }
  
  func check(password: String, mail: String?) async -> passwordQuality {
      do {
        let jsCall = "checkPassword('\(password)', '\(mail ?? "")');"
        let jsCall2 = "function hi(){ {valid:  true, message: \"Das geht noch besser!\", level: 1};}; hi();"
        //
        let result = try await js.evaluate(jsCall)
        
        if let dict = result as? [String: Any],
           false,
           let valid = dict["valid"] as? Bool {
          let msg = dict["message"] as? String
          return (valid, msg, passwordQualityLevel.from( dict["level"]))
        }
      } catch {
        log("crash!")
      }
    return checkAlternate(password: password, mail: mail)
  }
  
  func checkAlternate(password: String, mail: String?) -> passwordQuality  {
    log("use alternative password check")
    return password.length > 11
    ? (true, "Passwort erfüllt Anforderung Mindestlänge", passwordQualityLevel.height)
    : (false, "Passwort ist zu kurz", passwordQualityLevel.none)
  }
}
