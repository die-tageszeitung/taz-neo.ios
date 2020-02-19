//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class MainNC: UINavigationController, SectionVCdelegate {

  var startupView = StartupView()
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger()
  lazy var fileLogger = Log.FileLogger()
  let net = NetAvailability()
  var gqlFeeder: GqlFeeder!
  var feeder: Feeder { return gqlFeeder }
  var feed: Feed?
  var issue: Issue!
  lazy var dloader = Downloader(feeder: feeder)
  static var singleton: MainNC!
  
  var sectionVC: SectionVC?

  func setupLogging() {
    let logView = viewLogger.logView
    logView.isHidden = true
    view.addSubview(logView)
    logView.pinToView(view)
    Log.append(logger: consoleLogger, viewLogger, fileLogger)
    Log.minLogLevel = .Debug
    Log.onFatal { msg in self.log("fatal closure called, error id: \(msg.id)") }
    net.onChange { (flags) in self.log("net changed: \(flags)") }
    net.whenUp { self.log("Network up") }
    net.whenDown { self.log("Network down") }
    let nd = UIApplication.shared.delegate as! AppDelegate
    nd.onSbTap { tview in 
      if nd.wantLogging {
        if logView.isHidden {
          self.view.bringSubviewToFront(logView) 
          logView.scrollToBottom()
          logView.isHidden = false
        }
        else {
          self.view.sendSubviewToBack(logView)
          logView.isHidden = true
        }
      }
    }
    nd.permitPush { pn in
      if pn.isPermitted { self.debug("Push Permission granted") }
      else { self.debug("No push permission") }
    }
    nd.onReceivePush { (pn, payload) in
      self.debug(payload.toString())
    }
  } 
  
  func writeTazApiCss(topMargin: CGFloat, bottomMargin: CGFloat) {
    let dir = feeder.resourcesDir
    dir.create()
    let cssFile = File(dir: dir.path, fname: "tazApi.css")
    let cssContent = """
      #content {
        padding-top: \(topMargin)px;
        padding-bottom: \(bottomMargin)px;
      } 
    """
    File.open(path: cssFile.path, mode: "w") { f in f.writeline(cssContent) }
  }
  
  func getFeederOverview(closure: @escaping (Result<[Issue],Error>)->()) {
    debug(gqlFeeder.toString())
    let feeds = feeder.feeds
    feed = feeds[0]
    gqlFeeder.overview(feed: feed!, closure: closure) 
  }
  
  func setupFeeder(closure: @escaping (Result<[Issue],Error>)->()) {
    self.gqlFeeder = GqlFeeder(title: "taz", url: "https://dl.taz.de/appGraphQl") { (res) in
      guard let nfeeds = res.value() else { return }
      self.debug("Feeder \"\(self.feeder.title)\" provides \(nfeeds) feeds.")
      self.writeTazApiCss(topMargin: CGFloat(TopMargin), bottomMargin: CGFloat(BottomMargin))
      self.feeder.authenticate(account: "test", password: "test") { 
        [weak self] (res) in
        guard let _ = res.value() else { return }
        self?.debug(self?.gqlFeeder.toString())
        if let feeds = self?.feeder.feeds {
          self!.feed = feeds[0]
          self!.gqlFeeder.overview(feed: self!.feed!, closure: closure) 
        }
      }
    }
  }
  
  func withLoginData(closure: @escaping (_ id: String?, _ password: String?)->()) {
    let alert = UIAlertController(title: "Anmeldung", 
          message: "Bitte melden Sie sich mit Ihren Kundendaten an", 
          preferredStyle: .actionSheet)
    alert.addTextField { (textField) in
      textField.placeholder = "ID"
      textField.keyboardType = .emailAddress
    }
    alert.addTextField { (textField) in
      textField.placeholder = "Passwort"
      textField.isSecureTextEntry = true
    }
    let loginAction = UIAlertAction(title: "Anmelden", style: .default) { _ in
      let id = alert.textFields![0]
      let password = alert.textFields![1]
      closure(id.text ?? "", password.text ?? "")
    }
    let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel) { _ in
      closure(nil, nil)
    }
    alert.addAction(loginAction)
    alert.addAction(cancelAction)
    MainNC.singleton.present(alert, animated: true, completion: nil)
  }
  
  func loadIssue(closure: @escaping (Error?)->()) {
    self.dloader.downloadIssue(issue: self.issue!) { [weak self] err in
      if err != nil { self?.debug("Issue DL Errors: last = \(err!)") }
      else { self?.debug("Issue DL complete") }
      closure(err)
    }
  }
  
  func loadSection(section: Section, closure: @escaping (Error?)->()) {
    self.dloader.downloadSection(issue: self.issue!, section: section) { [weak self] err in
      if err != nil { self?.debug("Section DL Errors: last = \(err!)") }
      else { self?.debug("Section DL complete") }
      closure(err)
    }   
  }
  
  func loadArticle(article: Article, closure: @escaping (Error?)->()) {
    dloader.downloadArticle(issue: self.issue!, article: article) { [weak self] err in
      if err != nil { self?.debug("Article DL Errors: last = \(err!)") }
      else { self?.debug("Article DL complete") }
      closure(err)
    }   
  }
  
  func pushSectionViews() {
    sectionVC = SectionVC()
    if let svc = sectionVC {
      svc.delegate = self
      pushViewController(svc, animated: false)
      delay(seconds: 1) {
        svc.slider.open() { _ in
          delay(seconds: 1) {
            svc.slider.close() { _ in
              svc.slider.blinkButton()
            }
          }
        }
      }

    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    MainNC.singleton = self
    isNavigationBarHidden = true
    self.view.addSubview(startupView)
    pin(startupView, to: self.view)
    setupLogging()
    Database( "ArticleDB" ) { db in 
      self.debug("DB opened: \(db)")
      self.setupFeeder { [weak self] res in
        guard let ovwIssues = res.value() else { self?.fatal(res.error()!); return }
        // get most recent issue
        self?.gqlFeeder.issue(feed: self!.feed!, date: ovwIssues[0].date) { [weak self] res in
          guard let issue = res.value() else { self?.fatal(res.error()!); return }
          self?.issue = issue
//          self?.loadIssue { err in
//            if err != nil { self?.fatal(err!) }
//          }
          // load "Moment" and 1st section HTML before pushing the web view
          self?.loadSection(section: self!.issue!.sections![0]) { [weak self] err in
            if err != nil { self?.fatal(err!) }
            self?.dloader.downloadMoment(issue: self!.issue!) { [weak self] err in
              if err != nil { self?.fatal(err!) }
              self?.pushSectionViews()
              self?.startupView.isHidden = true
            }
          }
        }
      }
    }
  }
  
} // MainNC
