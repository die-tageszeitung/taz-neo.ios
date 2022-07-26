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
  var feederContext: FeederContext!
  var feed: StoredFeed!
  var testDate = UsTime(iso: "2020-09-14", tz: "Europe/Berlin").date

  var logView = TestView()
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger(logView: logView)
  
  // checkIssueCount verifies that the given nb. of issues are available
  func checkIssueCount(_ n: Int) -> Bool {
    let issues =  feed.issues as? [StoredIssue]
    guard check(issues != nil, "issues == nil") else { return false }
    guard check(issues!.count == n, "issues.count != \(n)") else { return false }
    return true
  }
  
  // checkFileCount verifies that the given nb. of files are available in one Issue
  func checkFileCount(_ n: Int, inIssue issue: StoredIssue) -> Bool {
    let nfiles = issue.payload.files.count
    guard check(nfiles == n, 
                "Wrong nb. of files in Issue - expected: \(n), got: \(nfiles)") 
      else { return false }
    return true
  }
  
  // check whether Issues have same files
  func checkFiles(from: Issue, to: Issue) -> Bool {
    let fromFiles = from.files
    let toFiles = to.files
    var e = 0
    for f in fromFiles {
      if let idx = toFiles.firstIndex(where: { f.name == $0.name }) {
        let t = toFiles[idx]
        if f.sha256 != t.sha256 { e += 1; error("'from' file \(f) has different SHA256") }
        if f.moTime != t.moTime { e += 1; error("'from' file \(f) has different moTime") }
        if f.size != t.size { e += 1; error("'from' file \(f) has different size") }
      }
      else { e += 1; error("'from' file \(f) not found in 'to'") }
    }
    for t in toFiles {
      if fromFiles.firstIndex(where: { t.name == $0.name }) == nil {
        e += 1; error("'to' file \(t) not found in 'from'") 
      }
    }
    return e == 0
  }
  
  // Load single overview issue of data 2020-09-14 and delete it 
  func testSingleOverview(result: @escaping (Bool)->()) {
    Notification.receiveOnce("issueOverview") { notification in
      if let issue = notification.content as? StoredIssue {
        self.debug("OVW \(issue)")
        guard self.checkIssueCount(1) else { result(false); return }
        guard self.checkFileCount(1, inIssue: issue) else { result(false); return }
        (self.feed.issues![0] as! StoredIssue).delete()
        ArticleDB.save()
        guard self.checkIssueCount(0) else { result(false); return }
        result(true)
      }
      else { self.error("Invalid Notification") }
    }
    self.feederContext.getOvwIssues(feed: self.feed, count: 1, 
                                    fromDate: self.testDate, isAutomatically: false)
  }
  
  // Load single overview issue of data 2020-09-14 and overwrite it with demo issue 
  func testOverwriteOverview(result: @escaping (Bool)->()) {
    var issue: StoredIssue!
    Notification.receiveOnce("issueOverview") { notification in
      issue = notification.content as? StoredIssue
      guard self.check(issue != nil, "Invalid Notification") 
        else { result(false); return }
      self.debug("OVW \(issue!)")
      guard self.checkIssueCount(1) else { result(false); return }
      self.feederContext.getCompleteIssue(issue: issue, isAutomatically: false)
    }
    Notification.receiveOnce("issue") { notification in
      issue = notification.content as? StoredIssue
      guard self.check(issue != nil, "Invalid Notification") 
        else { result(false); return }
      self.debug("Complete \(issue!)")
      guard self.checkIssueCount(1) else { result(false); return }      
      guard self.checkFileCount(145, inIssue: issue) else { result(false); return }
      Notification.receiveOnce(Const.NotificationNames.authenticationSucceeded) {_ in 
        var gqlIssue: GqlIssue? = nil 
        Notification.receiveOnce("gqlIssue", from: issue) { notification in
          gqlIssue = notification.content as? GqlIssue
        }
        Notification.receiveOnce("issue", from: issue) { notification in
          guard self.checkIssueCount(1) else { result(false); return }      
          guard self.checkFileCount(178, inIssue: issue) else { result(false); return }
          if let gis = gqlIssue { result(self.checkFiles(from: gis, to: issue)) }
          else { self.error("no GqlIssue"); result(false) }
        }
        self.feederContext.getCompleteIssue(issue: issue, isAutomatically: false)
      }
      self.feederContext.authenticate()
    }
    self.feederContext.getOvwIssues(feed: self.feed, count: 1, 
                                    fromDate: self.testDate, isAutomatically: false)
  }

  override public var preferredStatusBarStyle: UIStatusBarStyle { .default }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    Log.minLogLevel = .Debug
    Log.append(logger: consoleLogger/*, viewLogger*/)
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
    self.collectionView?.backgroundColor = UIColor.blue
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
    debug("Base directory: \(Dir.appSupportPath)")
    ArticleDB.dbRemove(name: "taz")
    self.feederContext = FeederContext(name: "taz", url: "https://dl.taz.de/appGraphQl",
                                       feed: "taz")
    Notification.receive("issueProgress") { notif in
      if let (loaded,total) = notif.content as? (Int64,Int64) {
        print("issue progress: \(loaded)/\(total)")
      }        
    }
    Notification.receive("resourcesProgress") { notification in
      guard let (loaded, total) = notification.content as? (Int64,Int64) else {return }
      print("resource progress: \(loaded)/\(total)")
    }
    Notification.receive("feederReady") { notification in 
      guard let fctx = notification.sender as? FeederContext else { return }
      self.feederContext = fctx
      self.debug(fctx.storedFeeder.toString())
      self.feed = StoredFeed.get(name: "taz", inFeeder: fctx.storedFeeder)[0]
      self.testSingleOverview { ok in
        if ok { 
          self.debug("testSingleOverview OK") 
          self.testOverwriteOverview { ok in
            if ok {
              self.debug("testOverwriteOverview OK")
            }
            else { self.error("testOverwriteOverview failed") }
          }
        }
        else { self.error("testSingleOverview failed") }
      } 
    }
    Notification.receive("feederReachable") {_ in 
      self.debug("feeder is reachable")
    }
    Notification.receive("feederNotReachable") {_ in 
      self.debug("feeder is not reachable")
    }
  }
  
}
