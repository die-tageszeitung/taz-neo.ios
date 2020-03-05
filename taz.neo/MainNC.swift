//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import MessageUI
import NorthLib

class MainNC: UINavigationController, SectionVCdelegate, MFMailComposeViewControllerDelegate {

  var startupView = StartupView()
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger()
  lazy var fileLogger = Log.FileLogger()
  let net = NetAvailability()
  var gqlFeeder: GqlFeeder!
  var feeder: Feeder { return gqlFeeder }
  lazy var authenticator = Authentication(feeder: self.gqlFeeder)
  var feed: Feed?
  var issue: Issue!
  lazy var dloader = Downloader(feeder: feeder)
  static var singleton: MainNC!
  private var isErrorReporting = false
  
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
  
  func produceErrorReport() {
    let mail =  MFMailComposeViewController()
    let screenshot = UIWindow.screenshot?.jpeg
    let logData = fileLogger.data
    mail.mailComposeDelegate = self
    mail.setToRecipients(["app@taz.de"])
    mail.setSubject("Rückmeldung zu taz.neo (iOS)")
    if let screenshot = screenshot { 
      mail.addAttachmentData(screenshot, mimeType: "image/jpeg", 
                             fileName: "taz.neo-screenshot.jpg")
    }
    if let logData = logData { 
      mail.addAttachmentData(logData, mimeType: "text/plain", 
                             fileName: "taz.neo-logfile.txt")
    }
    present(mail, animated: true)
  }
  
  func mailComposeController(_ controller: MFMailComposeViewController, 
    didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true)
    isErrorReporting = false
  }
  
  @objc func errorReportActivated(_ sender: UIGestureRecognizer) {
    guard !isErrorReporting else { return }
    guard MFMailComposeViewController.canSendMail() else { return }
    isErrorReporting = true
    Alert.confirm(title: "Rückmeldung", 
      message: "Wollen Sie uns eine Fehlermeldung senden oder haben Sie einen " +
               "Kommentar zu unserer App?") { yes in
      if yes { self.produceErrorReport() }
      else { self.isErrorReporting = false }
    }
  }
  
  func setupErrorReporting() {
    let reportLPress = UILongPressGestureRecognizer(target: self, 
        action: #selector(errorReportActivated))
    reportLPress.numberOfTouchesRequired = 2
    self.view.isUserInteractionEnabled = true
    self.view.addGestureRecognizer(reportLPress)
  }
  
  func getFeederOverview(closure: @escaping (Result<[Issue],Error>)->()) {
    debug(gqlFeeder.toString())
    let feeds = feeder.feeds
    feed = feeds[0]
    gqlFeeder.overview(feed: feed!, closure: closure) 
  }
  
  func getOverview(closure: @escaping (Result<[Issue],Error>)->()) {
    debug(gqlFeeder.toString())
    feed = gqlFeeder.feeds[0]
    gqlFeeder.overview(feed: feed!, closure: closure) 
  }
  
  func setupFeeder(closure: @escaping (Result<[Issue],Error>)->()) {
    self.gqlFeeder = GqlFeeder(title: "taz", url: "https://dl.taz.de/appGraphQl") { (res) in
      guard let nfeeds = res.value() else { return }
      self.debug("Feeder \"\(self.feeder.title)\" provides \(nfeeds) feeds.")
      self.writeTazApiCss(topMargin: CGFloat(TopMargin), bottomMargin: CGFloat(BottomMargin))
      let (token, _, _) = self.getUserData()
      if let token = token { 
        self.gqlFeeder.authToken = token
        self.getOverview() { [weak self] res in
          if let _ = res.value() { closure(res) }
          else { 
            self?.deleteUserData()
            Alert.message(title: "Fehler", message: "Bei der Anmeldung am Server " +
              "trat ein Fehler auf, bitte starten Sie die App noch einmal und " +
              "melden Sie sich erneut an.") { exit(0) }
          }
        }
      }
      else {
        self.authenticator.simpleAuthenticate { [weak self] (res) in
          guard let _ = res.value() else { return }
          self?.getOverview(closure: closure)
        }
      }
    }
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
  
  func pushSectionViews() {
    sectionVC = SectionVC()
    if let svc = sectionVC {
      svc.delegate = self
      pushViewController(svc, animated: true)
      delay(seconds: 1.5) {
        svc.slider.open() { _ in
          delay(seconds: 1.5) {
            svc.slider.close() { _ in
              svc.slider.blinkButton()
            }
          }
        }
      }

    }
  }
  
  func startup() {
    startupView.isAnimating = true
    Database( "ArticleDB" ) { db in 
      self.debug("DB opened: \(db)")
      self.setupFeeder { [weak self] res in
        guard let ovwIssues = res.value() else { self?.fatal(res.error()!); return }
        // get most recent issue
        self?.gqlFeeder.issue(feed: self!.feed!, date: ovwIssues[0].date) { [weak self] res in
          guard let issue = res.value() else { self?.fatal(res.error()!); return }
          self?.issue = issue
          // load "Moment" and 1st section HTML before pushing the web view
          self?.loadSection(section: self!.issue!.sections![0]) { [weak self] err in
            if err != nil { self?.fatal(err!) }
            self?.dloader.downloadMoment(issue: self!.issue!) { [weak self] err in
              if err != nil { self?.fatal(err!) }
              self?.pushSectionViews()
              delay(seconds: 2) { 
                self?.startupView.isAnimating = false 
                self?.loadIssue { err in
                  if err != nil { self?.fatal(err!) }
                }
              }
              self?.startupView.isHidden = true
            }
          }
        }
      }
    }
  } 
  
  @objc func goingBackground() {
    debug("Going background")
  }
  
  @objc func goingForeground() {
    debug("Entering foreground")
  }
 
  func deleteAll() {
    popToRootViewController(animated: false)
    for f in Dir.appSupport.scan() {
      debug("remove: \(f)")
      try! FileManager.default.removeItem(atPath: f)
    }
    exit(0)
  }
  
  func getUserData() -> (token: String?, id: String?, password: String?) {
    let dfl = Defaults.singleton
    let kc = Keychain.singleton
    var token = kc["token"]
    var id = kc["id"]
    let password = kc["password"]
    if token == nil { 
      token = dfl["token"] 
      if token != nil { kc["token"] = token }
    }
    else { dfl["token"] = token }
    if id == nil { 
      id = dfl["id"] 
      if id != nil { kc["id"] = id }
    }
    return(token, id, password)
  }
  
  func deleteUserData() {
    let dfl = Defaults.singleton
    let kc = Keychain.singleton
    kc["token"] = nil
    kc["id"] = nil
    kc["password"] = nil
    dfl["token"] = nil
    dfl["id"] = nil
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    MainNC.singleton = self
    isNavigationBarHidden = true
    setupErrorReporting()
    self.view.addSubview(startupView)
    pin(startupView, to: self.view)
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(goingBackground), 
      name: UIApplication.willResignActiveNotification, object: nil)
    nc.addObserver(self, selector: #selector(goingForeground), 
                   name: UIApplication.willEnterForegroundNotification, object: nil)
    setupLogging()
    startup()
  }
  
} // MainNC
