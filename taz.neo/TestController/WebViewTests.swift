//
//  WebViewTests.swift
//
//  Created by Norbert Thies on 25.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

// A view controller to test WebViews
class WebViewTests: UIViewController {
  
  // The WebView to test
  var webView = WebView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .white
    self.view.addSubview(webView)
    pin(webView, toSafe: self.view)
    let html = """
    <h1>This is a test</h1>
    """
    let bo = JSBridgeObject(name: "Test")
    bo.addfunc("bridgeTest") { jsCall in
      print(jsCall.toString())
      return NSNull()
    }
    bo.addfunc("getInt") { jscall in
      return 14
    }
    webView.addBridge(bo)
    webView.log2bridge(bo)
    let js = """
      Test.f1 = function() { Test.call("bridgeTest", Test.f3, 1, "huhu") }
      Test.f3 = function(arg) { console.log("called back: ", arg) }
      Test.getInt = function() { Test.call("getInt", Test.f3) }

      Test.f1()
      Test.getInt()
      Test.log("A ", "small ", "test")
      alert("Another ", "simple ", "test")
      console.log("to whom", " it may concern")
    """
    webView.jsexec(js) { _ in
      print(js)
    }
    webView.load(html: html)
    delay(seconds: 5.0) {
      self.webView.jsexec("console.log(\"a delayed test\")")
    }
  } 

} // WebViewTests
