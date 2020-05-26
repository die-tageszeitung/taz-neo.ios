//
//  StartupVC.swift
//
//  Created by Norbert Thies on 27.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A simple view controller only showing a startup screen
class StartupVC: UIViewController {
  
  // The startup view
  var startupView = SpinnerStartupView()
  /// Light status bar because of dark background
  override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(startupView)
    pin(startupView, to: self.view)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    startupView.isAnimating = true
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    startupView.isAnimating = false
  }
  
} // StartupVC
