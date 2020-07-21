//
//
// RegisterController.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//

import UIKit
import NorthLib

/// A view controller to show introductory HTML-files
class RegisterController: UIViewController {
  
  lazy var loginView = RegisterView(loginSubviews)
  lazy var loginSubviews : [UIView] = {
    return [
      RegisterView.header(),
      RegisterView.label(title: NSLocalizedString("login_missing_credentials_header_login",
                                                  comment: "login header")),
      RegisterView.textField(placeholder: NSLocalizedString("login_username_hint", comment: "E-Mail Input")
                            ),
      RegisterView.textField(placeholder: NSLocalizedString("login_password_hint", comment: "Passwort Input"),
                            textContentType: .password,
                            isSecureTextEntry: true
                            ),
      RegisterView.button(title: NSLocalizedString("login_button", comment: "login"),
                          target: self, action: #selector(handleLogin)),
      RegisterView.label(title: NSLocalizedString("dssaD",
                                                  comment: "login header")),
      RegisterView.outlineButton(title: NSLocalizedString("REG", comment: "login"),
                          target: self, action: #selector(handleLogin)),
    ]
  }()
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
//    if #available(iOS 13.0, *) {
//      #if DEBUG
//      // change the appearance only while testing
//      // test the combination with high Contrast with Environment Overrides Button Below
//      // seams the simulator did not handle env correctly
//      overrideUserInterfaceStyle = .dark
//      #endif
//    }
    let wConstraint = loginView.container.pinWidth(to: self.view.width)
    wConstraint.constant = UIScreen.main.bounds.width
    wConstraint.priority = .required
    self.view.addSubview(loginView)
    NorthLib.pin(loginView, toSafe: self.view)
    
    /// Add Handler
    loginView.switchToTazIdButton.addTarget(self,
                                             action: #selector(switchToTazIdButtonTapped),
                                             for: .touchUpInside)
  }
  
  
  
  @IBAction func switchToTazIdButtonTapped(_ sender: UIButton) {
    print("switch Form")
  }
  
  
  @IBAction func handleLogin(_ sender: UIButton) {
    print("handleLogin")
  }
  
  
//  @objc func flip() {
//      let transitionOptions: UIView.AnimationOptions = [.transitionFlipFromRight, .showHideTransitionViews]
//
//      UIView.transition(with: firstView, duration: 1.0, options: transitionOptions, animations: {
//          self.firstView.isHidden = true
//      })
//
//      UIView.transition(with: secondView, duration: 1.0, options: transitionOptions, animations: {
//          self.secondView.isHidden = false
//      })
//  }
  
}
