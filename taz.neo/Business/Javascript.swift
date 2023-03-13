//
//  Javascript.swift
//  taz.neo
//
//  Created by Ringo Müller on 22.11.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import NorthLib
import WebKit

// MARK: - NorthLib project repository part (later) Helper to wrap WebView only to execute JS

/// Wraps JS execution funtionallity
///
/// May produce **WARNINGS** in log:
/// ... GPUProcessProxy::gpuProcessExited: reason=IdleExit
/// ... WebProcessProxy::gpuProcessExited: reason=IdleExit
/// may deactivate by: Environment Variables set OS_ACTIVITY_MODE = disable
/// @see: https://stackoverflow.com/a/45211641
open class Javascript {
  
  private var jsFileUrl:URL?
  
  private var wv:WebView
  
  @MainActor
  /// Evaluates given JS String in current environment
  /// - Parameter javaScriptString: js to execute
  /// - Returns: result of the script evaluation or an error or nil
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
  
  
  /// constructor
  /// - Parameter jsFileUrl: optional passed js fileUrl with js code e.g. libs
  public init(_ jsFileUrl:URL? = nil) {
    wv = Self.createWebView(jsFileUrl)
  }
}

// MARK: - taz project repository Password Test Class and Helper

/// enum/mapper for password quality/strength level
public enum PasswordStrengthLevel: Int {
  case none = 0
  case low = 1
  case medium = 2
  case height = 3
}

/// helper extension for password quality/strength level enum
extension PasswordStrengthLevel {
  static func from(_ value:Any?) -> Self{
    if let val = value as? Int, let v = Self(rawValue: val) {
      return v
    }
    return .none
  }
  
  var color:UIColor {
    switch self {
      case .height:
        return UIColor.rgb(0x228400)
      case .medium:
        return UIColor.rgb(0xBA5900)
      case .none:
        fallthrough
      case .low:
        fallthrough
      default:
        return UIColor.rgb(0xC01111)
    }
  }
}

/// alias/mapper for password test result
public typealias passwordQuality
= (valid: Bool, message:String?, strength :PasswordStrengthLevel)

/// PasswordValidator class to hide JS execution code from app logic
class PasswordValidator: DoesLog {
 var s =  StoredResources.latest()
  
  var js = Javascript(TazAppEnvironment.sharedInstance.feederContext?.storedFeeder.passwordCheckJsUrl)

  /// Checks whether the password match the required requirements
  /// wrapper for shared JS
  ///  on JS Errors simple alternate check will be executed
  /// - Parameters:
  ///   - password: password to check
  ///   - mail: e-mail address to check if is not part of the password
  /// - Returns: test result with triple contain: valid:Bool, errormessage:String?, strength: PasswordStrengthLevel
  func check(password: String, mail: String?) async -> passwordQuality {
      do {
        let jsCall = "tazPasswordSpec.checkLocal('\(password)', '\(mail ?? "")');"
        let result = try await js.evaluate(jsCall)
        //throw "error" //uncomment to test js error and fallback evaluation
        if let dict = result as? [String: Any],
           let valid = dict["valid"] as? Bool {
          let msg = dict["message"] as? String
          return (valid, msg, PasswordStrengthLevel.from( dict["strength"]))
        }
      } catch {
        log("crash!")
      }
    return checkAlternate(password: password, mail: mail)
  }
  
  func checkAlternate(password: String, mail: String?) -> passwordQuality  {
    log("use alternative password check")
    return password.length > 11
    ? (true, nil, PasswordStrengthLevel.height)
    : (false, "Das Passwort muss mindestens 12 Zeichen lang sein.", PasswordStrengthLevel.none)
  }
}
