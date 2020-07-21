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
  
  var registerView = RegisterView(.createTazId)
  var loginView = RegisterView(.login)
  
  override func viewDidLoad() {
    super.viewDidLoad()

    let wConstraint = registerView.container.pinWidth(to: self.view.width)
    wConstraint.constant = UIScreen.main.bounds.width
    wConstraint.priority = .required
    self.view.addSubview(registerView)
    NorthLib.pin(registerView, toSafe: self.view)
    
    /// Add Handler
    registerView.switchToTazIdButton.addTarget(self,
                                               action: #selector(switchToTazIdButtonTapped),
                                               for: .touchUpInside)
  }
  
  @IBAction func switchToTazIdButtonTapped(_ sender: UIButton) {
    print("switch Form")
  }
}
