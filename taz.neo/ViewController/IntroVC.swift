//
//  IntroVC.swift
//
//  Created by Norbert Thies on 25.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib
import WebKit

/// A view controller to show introductory HTML-files
class IntroVC: UIViewController {
  
  /// The WebView to show the HTML-files
  var webView = ButtonedWebView(customXButton: Button<ImageView>(), configuration: IntroVC.webViewConfiguration())
  /// The file containing the data policy
  var htmlDataPolicy: String?
  /// The file containing the introduction
  var htmlIntro: String?
  
  static func webViewConfiguration() -> WKWebViewConfiguration? {
    if Defaults.darkMode == false { return nil }
    let cssString
    = "#welcome-carousel .carousel-inner img:not(#slide2 .second-inner-div img){ filter: invert(1); }"
    let source = """
        var link = document.createElement("link");
        link.href = "themeNight.css";
        link.rel = "stylesheet";
        document.head.appendChild(link);
        var style = document.createElement('style');
        style.innerHTML = '\(cssString)';
        document.head.appendChild(style);
        """
    
    let userScript = WKUserScript(source: source,
                                   injectionTime: .atDocumentEnd,
                                   forMainFrameOnly: true)
    let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
    
    return configuration
  }
  
  var topOffset: CGFloat = 0.0 {
    didSet {
      webViewTopOffsetConstraint?.constant = topOffset
    }
  }
  
  var webViewTopOffsetConstraint: NSLayoutConstraint?
  
  public func linkPressed(from: URL?, to: URL?) {
    guard let to = to else { return }
    
    self.debug("Calling application for: \(to.absoluteString)")
    if UIApplication.shared.canOpenURL(to) {
      UIApplication.shared.open(to, options: [:], completionHandler: nil)
    }
    else {
      error("No application or no permission for: \(to.absoluteString)")
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = Const.SetColor.CTBackground.color
    self.view.addSubview(webView)
    if #available(iOS 16.4, *) {
      webView.webView.isInspectable = true
    }
    pin(webView, to: self.view, exclude: .top)
    webViewTopOffsetConstraint = pin(webView.top, to: self.view.top, dist: topOffset)
    webView.buttonMargin = 26
    webView.buttonLabel.backgroundColor = Const.SetColor.CIColor.color
    webView.buttonLabel.textColor = .white
    webView.buttonLabel.font = UIFont.boldSystemFont(ofSize: 18)
    webView.buttonLabel.text = "Akzeptieren"
    webView.buttonLabel.label.accessibilityLabel = "Datenschutzerklärung akzeptieren und schließen"
    webView.buttonLabel.clipsToBounds = true
    webView.buttonLabel.layer.cornerRadius = 5
    webView.xButton.tazX()
    if let htmlDataPolicy = htmlDataPolicy,
       let htmlIntro = htmlIntro {
      let dataPolicy = File(htmlDataPolicy)
      let intro = File(htmlIntro)
      if dataPolicy.exists && intro.exists {
        webView.webView.load(url: dataPolicy.url)
        webView.xButton.isAccessibilityElement = false
        webView.accessibilityElements
        = [webView.buttonLabel, webView.webView]
        webView.onTap { [weak self] _ in
          guard let self = self else { return }
          self.webView.webView.scrollView.contentInsetAdjustmentBehavior = .never
          self.webView.webView.scrollView.isScrollEnabled = false
          self.webView.buttonLabel.text = nil
          webView.xButton.accessibilityLabel = Localized("close_window")
          webView.xButton.isAccessibilityElement = true
          webView.accessibilityElements
          = [webView.xButton, webView.webView, webView.buttonLabel]
          self.webView.webView.load(url: intro.url)
          self.webView.onX { _ in
            Notification.send("dataPolicyAccepted") 
          }
        }
      }
    }
    webView.webView.whenLinkPressed { [weak self] (from, to) in
      if UIApplication.shared.applicationState != .active { return }
      self?.linkPressed(from: from, to: to)
    }
  }
} // WebViewTests
