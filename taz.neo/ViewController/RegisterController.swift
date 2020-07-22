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
  
  lazy var loginView = LoginView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    loginView.loginClosure = { [weak self] (id, password) in
      self?.handleLogin(id: id, password: password)
    }
    loginView.pwForgotClosure = { [weak self] id in
      self?.handlePwForgot(id: id)
    }
    
    let wConstraint = loginView.container.pinWidth(to: self.view.width)
    wConstraint.constant = UIScreen.main.bounds.width
    wConstraint.priority = .required
    self.view.addSubview(loginView)
    pin(loginView, to: self.view, exclude: .top)
    let c = pin(loginView.top, to: self.view.topGuide())
    c.priority = UILayoutPriority(rawValue: 10)
    
    
    

//    pin(loginView, to: self.view)
  }
  
  func handleLogin(id: String?, password:String?) {
    print("handle login with: \(id), pass: \(password)")
  }

  func handlePwForgot(id: String?) {
    print("handle handlePwForgot with: \(id)")
  }
  

}
