//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import MessageUI
import NorthLib


class MainNC: NavigationController, IssueVCdelegate,
              MFMailComposeViewControllerDelegate {
  
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
  lazy var authenticator = SimpleAuthenticator(feeder: self.gqlFeeder)
  var _feed: Feed?
  var feed: Feed { return _feed! }
  var storedFeeder: StoredFeeder!
  var storedFeed: StoredFeed!
  lazy var dloader = Downloader(feeder: feeder)
  static var singleton: MainNC!
  private var isErrorReporting = false
  private var isForeground = false
  private var pollingTimer: Timer?
  private var pollEnd: Int64?
  public var pushToken: String?
  private var inIntro = false
  public var ovwIssues: [Issue]?

  func setupLogging() {
    let logView = viewLogger.logView
    logView.isHidden = true
    view.addSubview(logView)
    logView.pinToView(view)
    Log.append(logger: consoleLogger, /*viewLogger,*/ fileLogger)
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
    Alert.actionSheet(title: "Beta (v) \(App.version)-\(App.buildNumber)", 
      actions: actions)
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
    
  func handleFeederError(_ err: FeederError) {
    var text = ""
    switch err {
    case .invalidAccount: text = "Ihre Kundendaten sind nicht korrekt."
    case .expiredAccount: text = "Ihr Abo ist abgelaufen."
    case .changedAccount: text = "Ihre Kundendaten haben sich geändert."
    case .unexpectedResponse: 
      Alert.message(title: "Fehler", 
                    message: "Es gab ein Problem bei der Kommunikation mit dem Server") {
        exit(0)               
      }
    }
    deleteUserData()
    Alert.message(title: "Fehler", message: text) {
      Notification.send("userLogin", object: nil)
    }
  }
  
  func getOverview() {
    gqlFeeder.issues(feed: feed, count: 20) { res in
      if let issues = res.value() {
        Notification.send("overviewReceived", object: issues)
      }
      else if let err = res.error() as? FeederError {
        self.handleFeederError(err)
      }
    }
  }
  
  func overviewReceived(issues: [Issue]) {
    ovwIssues = issues
//    for issue in issues {
//      let sissues = StoredIssue.get(date: issue.date, inFeed: storedFeed) 
//    }
    if !inIntro { showIssueVC() }
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
  
  func userLogin(closure: @escaping (Error?)->()) {
    let (_,_,token) = SimpleAuthenticator.getUserData()
    if let token = token { 
      self.gqlFeeder.authToken = token
      closure(nil)
    }
    else {
      self.setupPolling()
      self.authenticator.authenticate(isFullScreen: true) { err in closure(err) }
    }
  }
    
  func setupFeeder(closure: @escaping (Result<Feeder,Error>)->()) {
    self._gqlFeeder = GqlFeeder(title: "taz", url: "https://dl.taz.de/appGraphQl") { [weak self] (res) in
      guard let self = self else { return }
      guard res.value() != nil else { return }
      self.debug(self.gqlFeeder.toString())
      self._feed = self.gqlFeeder.feeds[0]
      self.storedFeeder = StoredFeeder.persist(object: self.gqlFeeder)
      Notification.receive("overviewReceived") { [weak self] issues in
        if let issues = issues as? [Issue] {
          self?.overviewReceived(issues: issues) 
        }
      }
      Notification.receive("userLogin") { [weak self] _ in
        self?.userLogin() { [weak self] err in
          guard let self = self else { return }
          if err != nil { exit(0) }
          self.dloader.downloadResources {_ in 
            self.showIntro() 
            self.getOverview()
          }
        }
      }
      Notification.send("userLogin")
      closure(.success(self.feeder))
    }
  }
    
  func showIssueVC() {
    self.setupRemoteNotifications()
    let ivc = IssueVC()
    ivc.delegate = self
    replaceTopViewController(with: ivc, animated: false)
  }
  
  func showIntro() {
    let hasAccepted = Keychain.singleton["dataPolicyAccepted"]
    if hasAccepted == nil || !hasAccepted!.bool {
      debug("Showing Intro")
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
    else if ovwIssues != nil { showIssueVC() }
  }
  
  func introHasFinished() {
    popViewController(animated: false)
    let kc = Keychain.singleton
    kc["dataPolicyAccepted"] = "true"
    if ovwIssues != nil { showIssueVC() }
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
    Database.dbRename(old: "ArticleDB", new: "taz")
    ArticleDB(name: "taz") { [weak self] err in 
      guard let self = self else { return }
      guard err == nil else { exit(1) }
      self.debug("DB opened: \(ArticleDB.singleton!)")
      self.setupFeeder { [weak self] _ in
        guard let self = self else { return }
        self.debug("Feeder ready.")
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
    kc["dataPolicyAccepted"] = nil
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
    onPopViewController { vc in
      if vc is IssueVC || vc is IntroVC {
        return false
      }
      return true
    }
    // isEdgeDetection = true
    setupTopMenus()
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(goingBackground), 
      name: UIApplication.willResignActiveNotification, object: nil)
    nc.addObserver(self, selector: #selector(goingForeground), 
                   name: UIApplication.willEnterForegroundNotification, object: nil)
    setupLogging()
    startup()
  }

} // MainNC
