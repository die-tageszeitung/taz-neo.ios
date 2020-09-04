//
//  TestController.swift
//
//  Created by Norbert Thies on 19.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class TestView: SimpleLogView {
  
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
    super.init(frame: CGRect())
    self.isEditable = true    
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
}

class TestController: PageCollectionVC {
  var logView = TestView()
  var feederContext: FeederContext?
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger(logView: logView)
  
  override public var preferredStatusBarStyle: UIStatusBarStyle { .default }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    Log.minLogLevel = .Debug
    Log.append(logger: consoleLogger, viewLogger)
    let nd = NotifiedDelegate.singleton!
    nd.statusBar.backgroundColor = UIColor.green
    nd.onSbTap { view in
      self.debug("Tapped")
      ArticleDB.singleton.reset {_ in}
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
    viewProvider { (index, oview) in
      return views[index]
    }
    ArticleDB(name: "taz") { [weak self] err in 
      guard let self = self else { return }
      guard err == nil else { exit(1) }
      self.debug("DB opened: \(ArticleDB.singleton!)")
      self.feederContext = FeederContext(name: "taz", 
                                         url: "https://dl.taz.de/appGraphQl")
      Notification.receive("feederReady") { fctx in 
        guard let fctx = fctx as? FeederContext else { return }
        self.debug(fctx.storedFeeder.toString())
        if let latestResources = StoredResources.latest() {
          self.debug(latestResources.toString())
        }
        else { self.debug("no resources stored") }
      }
      Notification.receive("feederReachable") {_ in 
        self.debug("feeder is reachable")
      }
      Notification.receive("feederNotReachable") {_ in 
        self.debug("feeder is not reachable")
      }
    }

  }
  
}
