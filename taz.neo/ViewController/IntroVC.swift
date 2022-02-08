//
//  IntroVC.swift
//
//  Created by Norbert Thies on 25.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A view controller to show introductory HTML-files
class IntroVC: UIViewController {
  
  /// The WebView to show the HTML-files
  var webView = ButtonedWebView()
  /// The file containing the data policy
  var htmlDataPolicy: String?
  /// The file containing the introduction
  var htmlIntro: String?
  
  var topOffset: CGFloat = 0.0 {
    didSet {
      webViewTopOffsetConstraint?.constant = topOffset
    }
  }
  
  var webViewTopOffsetConstraint: NSLayoutConstraint?

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .white
    self.view.addSubview(webView)
    pin(webView, to: self.view, exclude: .top)
    webViewTopOffsetConstraint = pin(webView.top, to: self.view.top, dist: topOffset)
    webView.buttonMargin = 26
    webView.buttonLabel.backgroundColor = Const.Colors.ciColor
    webView.buttonLabel.textColor = .white
    webView.buttonLabel.font = UIFont.boldSystemFont(ofSize: 18)
    webView.buttonLabel.text = "Akzeptieren"
    webView.buttonLabel.clipsToBounds = true
    webView.buttonLabel.layer.cornerRadius = 5
    if let htmlDataPolicy = htmlDataPolicy,
       let htmlIntro = htmlIntro {
      let dataPolicy = File(htmlDataPolicy)
      let intro = File(htmlIntro)
      if dataPolicy.exists && intro.exists {
        webView.webView.load(url: dataPolicy.url)
        webView.onTap { [weak self] _ in
          guard let self = self else { return }
          self.webView.webView.scrollView.contentInsetAdjustmentBehavior = .never
          self.webView.webView.scrollView.isScrollEnabled = false
          self.webView.buttonLabel.text = nil
          self.webView.webView.load(url: intro.url)
          self.webView.onX { _ in
            Notification.send("dataPolicyAccepted") 
          }
        }
      }
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    webView.xButton.tazX(true)
  }

} // WebViewTests
