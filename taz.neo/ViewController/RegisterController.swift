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
    self.view.addSubview(scrollView)
    scrollView.addSubview(registerView)
//    NorthLib.pin(registerView.centerX, to: scrollView.centerX)
//    NorthLib.pin(registerView.centerY, to: scrollView.centerY)
    NorthLib.pin(scrollView, toSafe: self.view)
//    let constrains = NorthLib.pin(registerView, toSafe: scrollView)
    registerView.pinWidth(to: self.view.width).priority = .defaultHigh
    registerView.pinHeight(to: self.view.height).priority = .defaultLow
    NorthLib.pin(registerView.left, to: scrollView.left)
    NorthLib.pin(registerView.top, to: scrollView.top)
//    constrains.bottom.priority = .defaultLow
  }
}
