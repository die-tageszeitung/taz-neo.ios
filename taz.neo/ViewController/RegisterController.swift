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
  
  var registerView = RegisterView()
  var scrollView = UIScrollView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // First setupRegisterview before add to ScrollView, otherwise
    // NSLayoutConstraint Unsatisfiable error, due Priority conflicts
    scrollView.addSubview(registerView)
    NorthLib.pin(registerView, to: scrollView)
    let wConstraint = registerView.pinWidth(to: self.view.width)
    wConstraint.constant = UIScreen.main.bounds.width
    wConstraint.priority = .required
    //Now we can add/setup the Scrollview
    self.view.addSubview(scrollView)
    NorthLib.pin(scrollView, toSafe: self.view)
    
    /// Add Handler
    registerView.switchToTazIdButton.addTarget(self,
                                               action: #selector(switchToTazIdButtonTapped),
                                               for: .touchUpInside)
  }
  
  @IBAction func switchToTazIdButtonTapped(_ sender: UIButton) {
    print("switch Form")
  }
}
