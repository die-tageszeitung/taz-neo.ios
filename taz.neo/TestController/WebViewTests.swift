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
  var webView = ButtonedWebView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .white
    self.view.addSubview(webView)
    pin(webView, toSafe: self.view)
    let html = """
    <h1>This is a test</h1>
    """
    //webView.webView.load("https://www.taz.de")
    webView.webView.load(html: html)
    webView.buttonMargin = 16
    webView.buttonLabel.backgroundColor = .red
    webView.buttonLabel.textColor = .white
    webView.buttonLabel.font = UIFont.boldSystemFont(ofSize: 18)
    webView.buttonLabel.text = "  Akzeptieren  "
    webView.onTap { str in
      print(str)
    }
    self.webView.onX {
      print("X pressed")
    }
  } 

} // WebViewTests
