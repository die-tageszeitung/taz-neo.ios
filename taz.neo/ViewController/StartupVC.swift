//
//  StartupVC.swift
//
//  Created by Norbert Thies on 27.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A simple view controller only showing a startup screen
/// ...just a Spinner in Git History there is more
open class StartupVC: UIViewController {
  
  // The startup view
  var startupView = SpinnerStartupView()
  /// Light status bar because of dark background
  override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  open override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(startupView)
    pin(startupView, to: self.view)
  }
  
  open override func viewDidAppear(_ animated: Bool) {
    startupView.isAnimating = true
  }
  
  open override func viewDidDisappear(_ animated: Bool) {
    startupView.isAnimating = false
  }
  
} // StartupVC
