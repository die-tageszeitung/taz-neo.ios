//
//  WebView.swift
//
//  Created by Norbert Thies on 01.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import WebKit

/// A JSCall-Object describes a native call from JavaScript to Swift
public class JSCall: DoesLog {
  
  /// name of the NativeBridge object
  var bridgeObject = ""
  /// name of the method called
  var method = ""
  /// callback ID
  var callback: Int?
  /// array of arguments
  var args: [Any]?
  /// WebView object receiving the call
  weak var webView: WebView?
  
  /// A new JSCall object is created using a WKScriptMessage
  init( _ msg: WKScriptMessage ) throws {
    if let dict = msg.body as? Dictionary<String,Any> {
      bridgeObject = msg.name
      if let m = dict["method"] as? String {
        method = m
        callback = dict["callback"] as? Int
        args = dict["args"] as? [Any]
      }
      else { throw exception( "JSCall without name of method" ) }
    }
    else { throw exception( "JSCall without proper message body" ) }
  }
  
  // TODO: implement callback to return value to JS callback function
  
} // class JSCall

/// A JSBridgeObject describes a JavaScript object containing
/// methods that are passed to native functions
class JSBridgeObject: DoesLog {
  
  /// Dictionary of JS function names to native closures
  var functions: [String:(JSCall)->()] = [:]
  
  /// calls a native closure
  func call( _ jscall: JSCall ) {
    if let f = functions[jscall.method] {
      debug( "From JS: '\(jscall.bridgeObject).\(jscall.method)' called" )
      f(jscall)
    }
    else {
      error( "From JS: undefined function '\(jscall.bridgeObject).\(jscall.method)' called" )
    }
  }
  
} // class JSBridgeObject

class WebView: WKWebView, WKScriptMessageHandler, UIScrollViewDelegate {

  /// JS NativeBridge objects
  var bridgeObjects: [String:JSBridgeObject] = [:]
  
  /// do horizontal scrolling
//  var isScrollHorizontal = true {
//    didSet {
//      if isScrollHorizontal {
//        self.scrollView.isDirectionalLockEnabled = false
//        self.scrollView.showsHorizontalScrollIndicator = true
//      }
//      else {
//        self.scrollView.isDirectionalLockEnabled = true
//        self.scrollView.showsHorizontalScrollIndicator = false
//      }
//    }
//  }
  
  /// jsexec executes the passed string as JavaScript expression using
  /// evaluateJavaScript, if a closure is given, it is only called when
  /// there is no error.
  func jsexec( _ expr: String, closure: ((Any?)->Void)? ) {
    self.evaluateJavaScript( expr ) {
      [weak self] (retval, error) in
      if let err = error {
        self?.error( "JavaScript error: " + err.localizedDescription )
      }
      else {
        if let callback = closure {
          callback( retval )
        }
      }
    }
  }
  
  /// calls a native closure
  func call( _ jscall: JSCall ) {
    if let bo = bridgeObjects[jscall.bridgeObject] {
      bo.call(jscall)
    }
    else {
      error( "From JS: undefined bridge object '\(jscall.bridgeObject) used" )
    }
  }
  
  // MARK: - WKScriptMessageHandler protocol
  func userContentController(_ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage) {
    if let jsCall = try? JSCall( message ) {
      call( jsCall)
    }
  }
  
  @discardableResult
  func load(_ url: URL) -> WKNavigation? {
    let request = URLRequest(url: url)
    return load(request)
  }
  
  @discardableResult
  func load(_ str: String) -> WKNavigation? {
    if let url = URL(string: str) {
      return load(url)
    }
    else { return nil }
  }
  
//  func scrollViewDidScroll(_ scrollView: UIScrollView) {
//    if isScrollHorizontal && (scrollView.contentOffset.x > 0) {
//      scrollView.contentOffset = CGPoint(x:0, y:scrollView.contentOffset.y)
//    }
//  }
  
  func setup() {
    self.scrollView.delegate = self
  }
  
  override init(frame: CGRect, configuration: WKWebViewConfiguration) {
    super.init(frame: frame, configuration: configuration)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
} // class WebView
