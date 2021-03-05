//
//  StartupVC.swift
//
//  Created by Norbert Thies on 27.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

fileprivate var TopFont = UIFont.boldSystemFont(ofSize: 24)
fileprivate var BottomFont = UIFont.boldSystemFont(ofSize: 18)

open class ReleaseChangeView: UIView {
  
  private var topLabel = UILabel()
  private var bottomLabel = UILabel()
  
  public var topText: String? {
    get { return topLabel.text }
    set { topLabel.text = newValue }
  }
  public var bottomText: String? {
    get { return bottomLabel.text }
    set { bottomLabel.text = newValue }
  }
    
  private func setup() {
    backgroundColor = UIColor.black
    topLabel.font = TopFont
    topLabel.textColor = UIColor.white
    topLabel.numberOfLines = 0
    topLabel.textAlignment = .center
    bottomLabel.font = BottomFont
    bottomLabel.textColor = UIColor.white
    bottomLabel.numberOfLines = 1
    bottomLabel.textAlignment = .center
    bottomLabel.adjustsFontSizeToFitWidth = true
    topLabel.textColor = UIColor.white
    bottomLabel.textColor = UIColor.white

    addSubview(topLabel)
    addSubview(bottomLabel)
    pin(topLabel.top, to: self.top, dist: 100)
    pin(topLabel.left, to: self.left, dist: 16)
    pin(topLabel.right, to: self.right, dist: -16)
    pin(bottomLabel.bottom, to: self.bottom, dist: -50)
    pin(bottomLabel.left, to: self.left, dist: 16)
    pin(bottomLabel.right, to: self.right, dist: -16)
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public convenience init() { self.init(frame: CGRect()) }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
} // ReleaseChangeView

/// A simple view controller only showing a startup screen
open class StartupVC: UIViewController {
  
  // The startup view
  var startupView = SpinnerStartupView()
  // The Release Change View
  var rcView = ReleaseChangeView()
  /// Light status bar because of dark background
  override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  open override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(startupView)
    pin(startupView, to: self.view)
//    self.view.addSubview(rcView)
//    pin(rcView, to: self.view)
  }
  
  private func checkReleaseStatus() {
    App.setAlternateIcon { (from, to, willChange) in
      if willChange {
        if to == "Release" {
          self.rcView.topText = "Du verwendest jetzt einen offiziellen Release"
        }
        else {
          self.rcView.topText = "Du verwendest jetzt eine \(to)-Version"          
        }
        self.rcView.bottomText = "\(App.name), Version \(App.version), " +
          "Build \(App.buildNumber)"
      }
      else {
        self.rcView.removeFromSuperview()
        Notification.send("startupReady")
      }
    }
  }
  
  open override func viewDidAppear(_ animated: Bool) {
    startupView.isAnimating = true
    checkReleaseStatus()
  }
  
  open override func viewDidDisappear(_ animated: Bool) {
    startupView.isAnimating = false
  }
  
} // StartupVC
