//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import MessageUI
import NorthLib


class MainNC: UINavigationController, IssueVCdelegate,
              MFMailComposeViewControllerDelegate, UIGestureRecognizerDelegate {
  
  /// Number of seconds to wait until we stop polling for email confirmation
  let PollTimeout: Int64 = 25*3600
  
  var showAnimations = false
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger()
  lazy var fileLogger = Log.FileLogger()
  let net = NetAvailability()
  var _gqlFeeder: GqlFeeder!  
  var gqlFeeder: GqlFeeder { return _gqlFeeder }
  var feeder: Feeder { return gqlFeeder }
  lazy var authenticator = Authentication(feeder: self.gqlFeeder)
  var _feed: Feed?
  var feed: Feed { return _feed! }
  var currentIssue: Issue?
  var issue: Issue { return currentIssue! }
  lazy var dloader = Downloader(feeder: feeder)
  static var singleton: MainNC!
  private var isErrorReporting = false
  private var isForeground = false
  private var pollingTimer: Timer?
  private var pollEnd: Int64?
  private var pushToken: String?
  private var serverDownloadId: String?
  private var serverDownloadStart: UsTime?
  private var inIntro = true
  private var ovwIssues: [Issue]?

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
    if !net.isAvailable { error("Network not available") }
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
    log("App: \"\(App.name)\" \(App.bundleVersion)-\(App.buildNumber)\n" +
        "\(Device.singleton): \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n" +
        "Path: \(Dir.appSupportPath)")
  } 
  
  func setupRemoteNotifications() {
    let nd = UIApplication.shared.delegate as! AppDelegate
    let dfl = Defaults.singleton
    let oldToken = dfl["pushToken"]
    self.pushToken = oldToken
    nd.onReceivePush { (pn, payload) in
      self.debug(payload.toString())
    }
    nd.permitPush { pn in
      if pn.isPermitted { 
        self.debug("Push permission granted") 
        self.pushToken = pn.deviceId
      }
      else { 
        self.debug("No push permission") 
        self.pushToken = nil
      }
      dfl["pushToken"] = self.pushToken 
      if oldToken != self.pushToken {
        let isTextNotification = dfl["isTextNotification"]!.bool
        self.gqlFeeder.notification(pushToken: self.pushToken, oldToken: oldToken,
                                    isTextNotification: isTextNotification) { res in
          if let err = res.error() { self.error(err) }
        }
      }
    }
  }
  
  func writeTazApiCss(topMargin: CGFloat, bottomMargin: CGFloat) {
    let dir = feeder.resourcesDir
    dir.create()
    let cssFile = File(dir: dir.path, fname: "tazApi.css")
    let cssContent = """
      @import "scroll.css";
      #content {
        padding-top: \(topMargin+UIWindow.topInset/2)px;
        padding-bottom: \(bottomMargin+UIWindow.bottomInset/2)px;
      } 
    """
    File.open(path: cssFile.path, mode: "w") { f in f.writeline(cssContent) }
  }
  
  func produceErrorReport(recipient: String) {
    let mail =  MFMailComposeViewController()
    let screenshot = UIWindow.screenshot?.jpeg
    let logData = fileLogger.data
    mail.mailComposeDelegate = self
    mail.setToRecipients([recipient])
    mail.setSubject("Rückmeldung zu taz.neo (iOS)")
    mail.setMessageBody("App: \"\(App.name)\" \(App.bundleVersion)-\(App.buildNumber)\n" +
      "\(Device.singleton): \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n\n...\n",
      isHTML: false)
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
    guard let recog = sender as? UILongPressGestureRecognizer,
          !isErrorReporting && MFMailComposeViewController.canSendMail()
      else { return }
    isErrorReporting = true
    Alert.confirm(title: "Rückmeldung", 
      message: "Wollen Sie uns eine Fehlermeldung senden oder haben Sie einen " +
               "Kommentar zu unserer App?") { yes in
                if yes { 
                  var recipient = "app@taz.de"
                  if recog.numberOfTouchesRequired == 3 { recipient = "norbert@taz.de" }
                  self.produceErrorReport(recipient: recipient) 
                }
      else { self.isErrorReporting = false }
    }
  }
  
  @objc func threeFingerTouch(_ sender: UIGestureRecognizer) {
    let logView = viewLogger.logView
    let actions: [UIAlertAction] = [
      Alert.action("Fehlerbericht senden") {_ in self.errorReportActivated(sender) },
      Alert.action("Alle Ausgaben löschen") {_ in self.deleteAll() },
      Alert.action("Kundendaten löschen") {_ in self.deleteUserData() },
      Alert.action("Abo-Verknüpfung löschen") {_ in self.unlinkSubscriptionId() },
      Alert.action("Abo-Push anfordern") {_ in self.testNotification(type: NotificationType.subscription) },
      Alert.action("Download-Push anfordern") {_ in self.testNotification(type: NotificationType.newIssue) },
      Alert.action("Protokoll an/aus") {_ in 
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
    ]
    Alert.actionSheet(title: "Beta-Test", actions: actions)
  }
  
  func setupTopMenus() {
    let reportLPress2 = UILongPressGestureRecognizer(target: self, 
        action: #selector(errorReportActivated))
    let reportLPress3 = UILongPressGestureRecognizer(target: self, 
        action: #selector(threeFingerTouch))
    reportLPress2.numberOfTouchesRequired = 2
    reportLPress3.numberOfTouchesRequired = 3
    self.view.isUserInteractionEnabled = true
    self.view.addGestureRecognizer(reportLPress2)
    self.view.addGestureRecognizer(reportLPress3)
  }
    
  func getOverview() {
    gqlFeeder.issues(feed: feed, count: 20) { res in
      if let issues = res.value() {
        Notification.send("overviewReceived", object: issues)
      }
    }
  }
  
  func overviewReceived(issues: [Issue]) {
    if inIntro { ovwIssues = issues }
    else { showIssueVC(issues: issues) }
  }
  
  func setupPolling() {
    self.authenticator.whenPollingRequired { self.startPolling() }
    if let peStr = Defaults.singleton["pollEnd"] {
      let pe = Int64(peStr)
      if pe! <= UsTime.now().sec { endPolling() }
      else {
        pollEnd = pe
        self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, 
          repeats: true) { _ in self.doPolling() }        
      }
    }
  }
  
  func startPolling() {
    self.pollEnd = UsTime.now().sec + PollTimeout
    Defaults.singleton["pollEnd"] = "\(pollEnd!)"
    self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, 
      repeats: true) { _ in self.doPolling() }
  }
  
  func doPolling() {
    self.authenticator.pollSubscription { [weak self] doContinue in
      guard let self = self else { return }
      guard let pollEnd = self.pollEnd else { self.endPolling(); return }
      if doContinue { if UsTime.now().sec > pollEnd { self.endPolling() } }
      else {
        self.endPolling() 
        if self.gqlFeeder.isAuthenticated { /*reloadIssue()*/ }
      }
    }
  }
  
  func endPolling() {
    self.pollingTimer?.invalidate()
    self.pollEnd = nil
    Defaults.singleton["pollEnd"] = nil
  }
  
  func setupFeeder(closure: @escaping (Result<Feeder,Error>)->()) {
    self._gqlFeeder = GqlFeeder(title: "taz", url: "https://dl.taz.de/appGraphQl") { [weak self] (res) in
      guard let self = self else { return }
      guard let nfeeds = res.value() else { return }
      self.debug("Feeder \"\(self.feeder.title)\" provides \(nfeeds) feeds.")
      self.debug(self.gqlFeeder.toString())
      self._feed = self.gqlFeeder.feeds[0]
      self.authenticator.pushToken = self.pushToken
      self.writeTazApiCss(topMargin: CGFloat(TopMargin), bottomMargin: CGFloat(BottomMargin))
      let (token, _, _) = self.getUserData()
      Notification.receive("overviewReceived") { [weak self] issues in
        if let issues = issues as? [Issue] {
          self?.overviewReceived(issues: issues) 
        }
      }
      if let token = token { 
        self.gqlFeeder.authToken = token
        self.getOverview()
      }
      else {
        self.setupPolling()
        self.authenticator.simpleAuthenticate { [weak self] (res) in
          guard let _ = res.value() else { return }
          self?.getOverview()
        }
      }
      closure(.success(self.feeder))
    }
  }
 
  func markStartDownload(feed: Feed, issue: Issue) {
    let issueName = self.feeder.date2a(issue.date)
    let idir = feeder.issueDir(feed: feed.name, issue: issueName)
    if !idir.exists { 
      let isPush = self.pushToken != nil
      self.gqlFeeder.startDownload(feed: feed, issue: issue, isPush: isPush) { [weak self] res in
        guard let self = self else { return }
        if let dlId = res.value() {
          self.serverDownloadId = dlId
          self.serverDownloadStart = UsTime.now()
        }
      }
    }
  }
  
  func markStopDownload() {
    if let dlId = self.serverDownloadId {
      let nsec = UsTime.now().timeInterval - self.serverDownloadStart!.timeInterval
      self.gqlFeeder.stopDownload(dlId: dlId, seconds: nsec) {_ in}
      self.serverDownloadId = nil
      self.serverDownloadStart = nil
    }
  }
    
  func showIssueVC(issues: [Issue]) {
    self.setupRemoteNotifications()
    let ivc = IssueVC()
    ivc.delegate = self
    ivc.issuesReceived(issues: issues)
    pushViewController(ivc, animated: false)
  }
  
  func showIntro() {
    let hasAccepted = Keychain.singleton["dataPolicyAccepted"]
    if hasAccepted != nil && !hasAccepted!.bool {
      inIntro = true
      let introVC = IntroVC()
      let resdir = feeder.resourcesDir.path
      introVC.htmlDataPolicy = resdir + "/welcomeSlidesDataPolicy.html"
      introVC.htmlIntro = resdir + "/welcomeSlides.html"
      Notification.receive("dataPolicyAccepted") { [weak self] obj in
        self?.introHasFinished()
      }
      pushViewController(introVC, animated: false)
    }
  }
  
  func introHasFinished() {
    popViewController(animated: false)
    let kc = Keychain.singleton
//    kc["dataPolicyAccepted"] = "true"
    kc["dataPolicyAccepted"] = "false"
    if let issues = ovwIssues { showIssueVC(issues: issues) }
  }
  
  func startup() {
    let dfl = Defaults.singleton
    dfl.setDefaults(values: ConfigDefaults)
    let oneWeek = 7*24*3600
    let nStarted = dfl["nStarted"]!.int!
    let lastStarted = dfl["lastStarted"]!.usTime
    debug("Startup: #\(nStarted), last: \(lastStarted.isoDate())")
    let now = UsTime.now()
    self.showAnimations = (nStarted < 2) || (now.sec - lastStarted.sec) > oneWeek
    IssueVC.showAnimations = self.showAnimations
    SectionVC.showAnimations = self.showAnimations
    ContentTableVC.showAnimations = self.showAnimations
    dfl["nStarted"] = "\(nStarted + 1)"
    dfl["lastStarted"] = "\(now.sec)"
    ArticleDB.singleton.open { [weak self] err in 
      guard let self = self else { return }
      guard err == nil else { exit(1) }
      self.debug("DB opened: \(ArticleDB.singleton)")
      self.setupFeeder { [weak self] res in
        guard let self = self else { return }
        self.dloader.downloadResources { _ in self.showIntro() }
      }
    }
  } 
  
  @objc func goingBackground() {
    isForeground = false
    debug("Going background")
  }
  
  @objc func goingForeground() {
    isForeground = true
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
  
  func unlinkSubscriptionId() {
    self.authenticator.unlinkSubscriptionId()
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
    dfl["pushToken"] = nil
    dfl["isTextNotification"] = "true"
    dfl["nStarted"] = "0"
    dfl["lastStarted"] = "0"
  }
  
  func testNotification(type: NotificationType) {
    self.gqlFeeder.testNotification(pushToken: self.pushToken, request: type) {_ in}
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    pushViewController(StartupVC(), animated: false)
    MainNC.singleton = self
    isNavigationBarHidden = true
    isForeground = true
    setupTopMenus()
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(goingBackground), 
      name: UIApplication.willResignActiveNotification, object: nil)
    nc.addObserver(self, selector: #selector(goingForeground), 
                   name: UIApplication.willEnterForegroundNotification, object: nil)
    // allow swipe from left edge to pop view controllers
    interactivePopGestureRecognizer?.delegate = self
    setupLogging()
    startup()
  }

  // MARK: UIGestureRecognizerDelegate protocol

  // necessary to allow swipe from left edge to pop view controllers
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
} // MainNC
