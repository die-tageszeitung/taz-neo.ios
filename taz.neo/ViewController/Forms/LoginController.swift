//
//
// LoginController.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//
import UIKit

/// A view controller to show introductory HTML-files
class LoginController: FormsController {
  lazy var loginView = LoginView()
  
  override func viewDidLoad() {
    contentView = loginView
    super.viewDidLoad()
    loginView.loginClosure = { [weak self] (id, password) in
      self?.handleLogin(id: id, password: password)
    }
    loginView.pwForgotClosure = { [weak self] id in
      self?.handlePwForgot(id: id)
    }
  }
  
  func handleLogin(id: String?, password:String?) {
    print("handle login with: \(id), pass: \(password)")
  }

  func handlePwForgot(id: String?) {
    let child = SubscriptionResetSuccess()
//    child.pwForgotView.idInput.text = id
    child.modalPresentationStyle = .overCurrentContext
    child.modalTransitionStyle = .flipHorizontal
    self.present(child, animated: true, completion: nil)
  }
}


