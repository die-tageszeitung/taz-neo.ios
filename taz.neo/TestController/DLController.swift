//
//  ViewController.swift
//
//  Created by Norbert Thies on 16.05.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class DLController: UIViewController {
  
  lazy var textView = UITextView()
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger()
  lazy var fileLogger = Log.FileLogger()
  let net = NetAvailability()
  var feeder: GqlFeeder!
  lazy var dloader = Downloader(feeder: feeder) 
  lazy var authenticator = Authentication(feeder: self.feeder)

  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(textView)
    pin(textView, to: view, dist: 8)
    Log.append(logger: consoleLogger, viewLogger, fileLogger)
    Log.minLogLevel = .Debug
    Log.onFatal { msg in
      self.log("fatal closure called, error id: \(msg.id)")
    }
    net.onChange { (flags) in
      self.log("net changed: \(flags)")
    }
    net.whenUp {
      self.log("Network up")
    }
    net.whenDown {
      self.log("Network down")
    }
    feeder = GqlFeeder(title: "taz", url: "https://dl.taz.de/appGraphQl") { (res) in
      self.authTest(res)
    }
    debug("current dir: '\(Dir.currentPath)'\ntmpdir: '\(Dir.tmpPath)'\n")
  }
  
  func startup(_ res: Result<Int, Error>) {
    guard let n = res.value() else { return }
    debug("\(n) issues\n\(feeder.toString())")
    feeder.authenticate(account: "test", password: "test") {
      [weak self] (res) in
      guard let key = res.value() else { return }
      self?.debug("key: \(key)")
      self?.debug(self?.feeder.toString())
      if let feeds = self?.feeder.feeds {
        let feed = feeds[0]
        self!.feeder.overview(feed: feed) { res in
          guard let issues = res.value() else { return }
          self!.feeder.issue(feed: feed, date: issues[0].date) { res in
            guard let issue = res.value() else { return }
            self?.dloader.downloadIssue(issue: issue) { err in
              if err != nil { self?.debug("Errors: last = \(err!)") }
              else { self?.debug("Issue DL complete") }
              self?.loadLastSection0(feed: feed, issues: issues)
            }
          }
        }
      }
    }
  }
  
  func authTest(_ res: Result<Int, Error>) {
    guard let n = res.value() else { return }
    debug("\(n) issues\n\(feeder.toString())")
    self.authenticator.detailedAuthenticate { [weak self] (res) in
      guard let _ = res.value() else { return }
      self?.feeder.passwordReset(email: "bla@me.com") { res in
        guard let si = res.value() else { return }
        self?.debug(si.toString())
        self?.feeder.trialSubscription(tazId: "bla@me.com", password: "test", 
          surname: "Bla", firstName: "Buggy", installationId: "1234", 
          pushToken: "abccffe") { res in
          guard let info = res.value() else { return }
          self?.debug(info.toString())
          self?.feeder.subscriptionReset(aboId: "1234") { res in
            guard let info = res.value() else { return }
            self?.debug(info.toString())
            self?.feeder.unlinkSubscriptionId(aboId: "1234", password: "1234") { res in
              guard let info = res.value() else { return }
              self?.debug(info.toString())
            }
          }  
        }
      }
    }
  }
  
  func loadLastSection0(feed: Feed, issues: [Issue]) {
    feeder.issue(feed: feed, date: issues[1].date) { [weak self] res in
      guard let issue = res.value() else { return }
      self?.dloader.downloadSection(issue: issue, section: issue.sections![0]) {
        [weak self] err in
        if err != nil { self?.debug("Errors: last = \(err!)") }
        else { self?.debug("Section 0 DL complete") }
      }   
    }
  }

  @IBAction func logPressed(_ sender: UIButton) {
    debug("NetAvailability.isAvailable: \(net.isAvailable ? "true" : "false")")
    debug("NetAvailability.isMobile:    \(net.isMobile ? "true" : "false")")
  }
  
}

