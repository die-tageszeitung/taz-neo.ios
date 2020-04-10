//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import MessageUI
import NorthLib

/// A view allowing the selection of a single Issue using a Picker view
class IssueSelection: UIView {
  var intro = UILabel()
  var picker = Picker()
  var button = UILabel()
  var onSelectionClosure: ((Int)->())?
  
  func onSelection(closure: ((Int)->())?) { onSelectionClosure = closure}
  
  @objc func buttonTapped(sender: UITapGestureRecognizer) {
    onSelectionClosure?(picker.index)  
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    let buttonTap = UITapGestureRecognizer(target: self, action: #selector(buttonTapped))
    button.addGestureRecognizer(buttonTap)
    button.isUserInteractionEnabled = true
    addSubview(intro)
    addSubview(picker)
    addSubview(button)
    intro.text = "Ausgaben"
    intro.font = UIFont.preferredFont(forTextStyle: .largeTitle)
    intro.textColor = UIColor.white
    button.text = "laden/anzeigen"
    button.font = UIFont.preferredFont(forTextStyle: .headline)
    button.textColor = tintColor
    picker.textColor = UIColor.white
    picker.frame = CGRect(x: 0, y: 0, width: 250, height: 400)
    pin(intro.top, to: self.top, dist: 20)
    pin(intro.centerX, to: self.centerX)
    pin(button.bottom, to: self.bottom, dist: -20)
    pin(button.centerX, to: self.centerX)
    self.pinWidth(300)
    self.pinHeight(500)
    isUserInteractionEnabled = true
    backgroundColor = UIColor.clear
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    let w = bounds.size.width
    let h = bounds.size.height
    picker.center = CGPoint(x: w/2, y: h/2)
  }
}

class MainNC: UINavigationController, SectionVCdelegate, MFMailComposeViewControllerDelegate {

  /// Number of seconds to wait until we stop polling for email confirmation
  let PollTimeout: Int64 = 25*3600
  
  var startupView = StartupView()
  var showAnimations = false
  lazy var issueSelection = IssueSelection()
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
  private var isForeground = false
  private var pollingTimer: Timer?
  private var pollEnd: Int64?
  private var pushToken: String?
  private var serverDownloadId: String?
  private var serverDownloadStart: UsTime?
  
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
        "\(Device.singleton): \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
  } 
  
  func setupNotification() {
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
  
  func setupTopMenu() {
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
    self.authenticator.pollSubscription { doContinue in
      guard let pollEnd = self.pollEnd else { endPolling(); return }
      if doContinue { if UsTime.now().sec > pollEnd { endPolling() } }
      else {
        endPolling() 
        if self.gqlFeeder.isAuthenticated { reloadIssue() }
      }
    }
  }
  
  func endPolling() {
    self.pollingTimer?.invalidate()
    self.pollEnd = nil
    Defaults.singleton["pollEnd"] = nil
  }
  
  func setupFeeder(closure: @escaping (Result<[Issue],Error>)->()) {
    self.gqlFeeder = GqlFeeder(title: "taz", url: "https://dl.taz.de/appGraphQl") { (res) in
      guard let nfeeds = res.value() else { return }
      self.debug("Feeder \"\(self.feeder.title)\" provides \(nfeeds) feeds.")
      self.authenticator.pushToken = self.pushToken
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
        self.setupPolling()
        self.authenticator.simpleAuthenticate { [weak self] (res) in
          guard let _ = res.value() else { return }
          self?.getOverview(closure: closure)
        }
      }
    }
  }
 
  func markStartDownload(feed: Feed, issue: Issue) {
    let issueName = self.feeder.date2a(issue.date)
    let idir = feeder.issueDir(feed: feed.name, issue: issueName)
    if !idir.exists { 
      let isPush = self.pushToken != nil
      self.gqlFeeder.startDownload(feed: feed, issue: issue, isPush: isPush) { res in
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
  
  func loadIssue(closure: @escaping (Error?)->()) {
    self.dloader.downloadIssue(issue: self.issue!) { [weak self] err in
      guard let self = self else { return }
      if err != nil { self.debug("Issue DL Errors: last = \(err!)") }
      else { self.debug("Issue DL complete") }
      closure(err)
    }
  }
  
  func reloadIssue() {
    // TODO: for now
    loadIssue {_ in}
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
      if showAnimations {
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
  }
  
  func showIssue(issue: Issue) {
    gqlFeeder.issue(feed: feed!, date: issue.date) { [weak self] res in
      guard let issue = res.value() else { self?.fatal(res.error()!); return }
      self?.issue = issue
      self?.markStartDownload(feed: self!.feed!, issue: issue)
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
              else { self?.markStopDownload() }
            }
          }
          self?.startupView.isHidden = true
          self?.issueSelection.isHidden = true
        }
      }
    }
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
    ContentTableVC.showAnimations = self.showAnimations
    dfl["nStarted"] = "\(nStarted + 1)"
    dfl["lastStarted"] = "\(now.sec)"
    startupView.isAnimating = true
    ArticleDB.singleton.open { err in 
      guard err == nil else { exit(1) }
      self.debug("DB opened: \(ArticleDB.singleton)")
      self.issueSelection.isHidden = true
      self.view.addSubview(self.issueSelection)
      pin(self.issueSelection.centerX, to: self.view.centerX)
      pin(self.issueSelection.centerY, to: self.view.centerY)
      self.setupFeeder { [weak self] res in
        self?.setupNotification()
        guard let ovwIssues = res.value() else { self?.fatal(res.error()!); return }
        let issueDates = ovwIssues.map { $0.date.gLowerDateString(tz: self!.feeder.timeZone) }
        self?.issueSelection.picker.items = issueDates
        self?.issueSelection.isHidden = false
        self?.startupView.showLogo = false
        self?.issueSelection.onSelection { i in 
          self?.issueSelection.isHidden = true          
          self?.startupView.isHidden = false
          self?.startupView.showLogo = true
          self?.startupView.isAnimating = true
          self?.showIssue(issue: ovwIssues[i]) 
        }
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
  }
  
  func testNotification(type: NotificationType) {
    self.gqlFeeder.testNotification(pushToken: self.pushToken, request: type) {_ in}
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    MainNC.singleton = self
    isNavigationBarHidden = true
    isForeground = true
    setupTopMenu()
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
