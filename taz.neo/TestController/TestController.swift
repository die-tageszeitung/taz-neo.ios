//
//  TestController.swift
//
//  Created by Norbert Thies on 19.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class TestView: UITextView, UIGestureRecognizerDelegate {
  
  static var font = UIFont(name: "Menlo-Regular", size: 14.0)
  
  var index = 0 {
    didSet {
      let v = max(1 - (0.1 * CGFloat(index)), 0)
      if index < 5 { self.textColor = UIColor.black }
      else { self.textColor = UIColor.white }
      self.backgroundColor = UIColor(red: v, green: v, blue: v, alpha: 1.0)
      self.font = TestView.font
    }
  }
  
  init() {
    super.init(frame: CGRect(), textContainer: nil)
    self.isEditable = true    
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
}

class TestController: PageCollectionVC {
  var logView = TestView()
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    Log.minLogLevel = .Debug
    Log.append(logger: consoleLogger, viewLogger)
    let nd = NotifiedDelegate.singleton!
    nd.statusBar.backgroundColor = UIColor.green
    nd.onSbTap { view in
      self.debug("Tapped")
    }
    nd.permitPush { pn in
      if pn.isPermitted { self.debug("Permission granted") }
      else { self.debug("No permission") }
    }
    nd.onReceivePush { (pn, payload) in
      self.debug(payload.toString())
    }
    self.view.backgroundColor = UIColor.red
    self.collectionView.backgroundColor = UIColor.blue
    self.count = 10
    self.index = 0
    self.logView.isEditable = false
    self.logView.index = 0
    var views: [TestView] = [self.logView]
    for i in stride(from: 1, to: 10, by: 1) { 
      views += TestView()
      views[i].index = i
    }
    viewProvider { (index) in
      return views[index]
    }
  }
  
}
