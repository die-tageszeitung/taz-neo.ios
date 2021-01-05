//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import MessageUI
import NorthLib


class MainNC: NavigationController,
              MFMailComposeViewControllerDelegate {
  
  var showAnimations = false
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger()
  lazy var fileLogger = Log.FileLogger()
  var feederContext: FeederContext!
  let net = NetAvailability()
  
  var authenticator: Authenticator? { return feederContext.authenticator }

  @KeyBool(key: "dataPolicyAccepted")
  public var dataPolicyAccepted: Bool
  
  static var singleton: MainNC!
  private var isErrorReporting = false
  private var isForeground = false

  /// Enable logging to file and otional to view
  func setupLogging() {
    let logView = viewLogger.logView
    logView.isHidden = true
    view.addSubview(logView)
    logView.pinToView(view)
    Log.append(logger: consoleLogger, /*viewLogger,*/ fileLogger)
    Log.minLogLevel = .Debug
    HttpSession.isDebug = false
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
                
  func showIssueVC() {
    feederContext.setupRemoteNotifications()
    let ivc = IssueVC(feederContext: feederContext)
    replaceTopViewController(with: ivc, animated: false)
  }
  
  func showIntro(closure: @escaping ()->()) {
    Notification.receiveOnce("resourcesReady") { [weak self] _ in
      guard let self = self else { return }
      self.debug("Showing Intro")
      let introVC = IntroVC()
      let feeder = self.feederContext.storedFeeder!
      introVC.htmlDataPolicy = feeder.dataPolicy
      introVC.htmlIntro = feeder.welcomeSlides
      Notification.receiveOnce("dataPolicyAccepted") { [weak self] notif in
        self?.popViewController(animated: false)
        let kc = Keychain.singleton
        kc["dataPolicyAccepted"] = "true"
        closure()
      }
      self.pushViewController(introVC, animated: false)
    }
    feederContext.updateResources()
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
    if !dataPolicyAccepted {
      showIntro() { self.showIssueVC() }
    }
    else { showIssueVC() }
  } 
  
 func goingBackground() {
    isForeground = false
    debug("Going background")
  }
  
  func goingForeground() {
    isForeground = true
    debug("Entering foreground")
  }
 
  func deleteAll() {
    popToRootViewController(animated: false)
    /// Remove all content
    for f in Dir.appSupport.scan() {
      debug("remove: \(f)")
      try! FileManager.default.removeItem(atPath: f)
    }
    //setupFeeder()
    exit(0)
  }
  
  func unlinkSubscriptionId() {
    authenticator?.unlinkSubscriptionId()
  }
    
  func deleteUserData() {
    SimpleAuthenticator.deleteUserData()
    let dfl = Defaults.singleton
    let kc = Keychain.singleton
    kc["dataPolicyAccepted"] = nil
    dfl["isTextNotification"] = "true"
    dfl["nStarted"] = "0"
    dfl["lastStarted"] = "0"
  }
  
  func testNotification(type: NotificationType) {
    if let pushToken = Defaults.singleton["pushToken"] {
      feederContext.gqlFeeder.testNotification(pushToken: pushToken, request: type) {_ in}
    }
  }
  
  func setupFeeder() {
    Notification.receiveOnce("feederReady") { notification in
      guard let fctx = notification.sender as? FeederContext else { return }
      self.debug(fctx.storedFeeder.toString())
      self.startup()
    }
    self.feederContext = 
      FeederContext(name: "taz", url: "https://dl.taz.de/appGraphQl", feed: "taz")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    pushViewController(StartupVC(), animated: false)
    MainNC.singleton = self
    isNavigationBarHidden = true
    isForeground = true
    // Disallow leaving view controllers IssueVC and IntroVC by edge swipe
    onPopViewController { vc in
      if vc is IssueVC || vc is IntroVC {
        return false
      }
      return true
    }
    setupTopMenus()
    setupLogging()
    Notification.receive(UIApplication.willResignActiveNotification) { _ in
      self.goingBackground()
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { _ in
      self.goingForeground()
    }
    ArticleDB.dbRemove(name: "taz")
//    Database.dbRename(old: "ArticleDB", new: "taz") // to move old name scheme
    setupFeeder()
  } // viewDidLoad

} // MainNC
