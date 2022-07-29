//
//  TazAppEnvironment.swift
//  taz.neo
//
//  Created by Ringo Müller on 01.03.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import NorthLib
import MessageUI
import UIKit

class TazAppEnvironment: NSObject, DoesLog, MFMailComposeViewControllerDelegate{
  
  private var threeFingerAlertOpen: Bool = false
  
  public private(set) lazy var rootViewController : UIViewController = {
    let vc = UIViewController()//Startup Splash Screen?!
    let spinner = UIActivityIndicatorView()
    vc.view.addSubview(spinner)
    spinner.center()
    spinner.color = .white
    spinner.startAnimating()
    return vc
  }()  {
    didSet {
      guard let window = UIApplication.shared.delegate?.window else { return }
      window?.hideAnimated() {[weak self] in
        guard
          let self = self,
          let window = UIApplication.shared.delegate?.window as? UIWindow
        else { return }
        window.rootViewController = self.rootViewController
        window.showAnimated()
        self.setupTopMenus(targetWindow: window)
      }
    }
  }
  
  public static let sharedInstance = TazAppEnvironment()
  
  var showAnimations = false
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger()
  lazy var fileLogger = Log.FileLogger()
  var feederContext: FeederContext?
  let net = NetAvailability()
  
  var authenticator: Authenticator? { return feederContext?.authenticator }
  
  public var expiredAccountInfoShown = false

  @Key("dataPolicyAccepted")
  public var dataPolicyAccepted: Bool
  
  public private(set) var isErrorReporting = false
  private var isForeground = false
  
  override init(){
    super.init()
    Notification.receive(UIApplication.willResignActiveNotification) { _ in
      self.goingBackground()
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { _ in
      self.goingForeground()
    }
    Notification.receive(UIApplication.willTerminateNotification) { _ in
      self.appWillTerminate()
    }
    setup()
    copyDemoContent()
    registerForStyleUpdates()
  }
  
  func copyDemoContent(){
    let demoFiles = ["trial", "extend", "switch"]
    for filename in demoFiles {
      if let url = Bundle.main.url(forResource: filename, withExtension: "html", subdirectory: "BundledResources") {
        let file = File(url.path )
        file.copy(to: Dir.appSupportPath.appending("/taz/resources/\(filename).html"))
      }
    }
  }
  
  func setup(){
    let feeder = Defaults.currentFeeder
    setupLogging()
    log("Connect to feeder: \(feeder.name) feed: \(feeder.feed)")
    feederContext = FeederContext(name: feeder.name, url: feeder.url, feed: feeder.feed)
    setupFeeder()
  }
  
  
  /// Enable logging to file and otional to view
  func setupLogging() {
    Log.append(logger: consoleLogger, fileLogger)
    Log.minLogLevel = .Debug
    HttpSession.isDebug = false
    PdfRenderService.isDebug = false
    ZoomedImageView.isDebug = false
    Log.onFatal { msg in
      self.log("fatal closure called, error id: \(msg.id)")
      self.reportFatalError(err: msg)
    }
    net.onChange { (flags) in self.log("net changed: \(flags)") }
    net.whenUp { self.log("Network up") }
    net.whenDown { self.log("Network down") }
    if !net.isAvailable { error("Network not available") }
    log("App: \"\(App.name)\" \(App.bundleVersion)-\(App.buildNumber)\n" +
        "\(App.bundleIdentifier)\n" +
        "\(Device.singleton): \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n" +
        "git-hash: \(BuildConst.hash)\n" +
        "Path: \(Dir.appSupportPath)")
  }
  
  func startup() {
    let dfl = Defaults.singleton
    let oneWeek = 7*24*3600
    let nStarted = dfl["nStarted"]!.int!
    let lastStarted = dfl["lastStarted"]!.usTime
    debug("Startup: #\(nStarted), last: \(lastStarted.isoDate())")
    logKeychain(msg: "initial")
    let now = UsTime.now
    self.showAnimations = (nStarted < 2) || (now.sec - lastStarted.sec) > oneWeek
    IssueVC.showAnimations = self.showAnimations
    SectionVC.showAnimations = self.showAnimations
    ContentTableVC.showAnimations = self.showAnimations
    dfl["nStarted"] = "\(nStarted + 1)"
    dfl["lastStarted"] = "\(now.sec)"
    if !dataPolicyAccepted {
      showIntro() { self.showHome() }
    }
    else {
      showHome()
    }
  }
  
  func goingBackground() {
    isForeground = false
    ArticleDB.save()
    debug("Going background")
  }
  
  func goingForeground() {
    isForeground = true
    debug("Entering foreground")
  }
  
  func appWillTerminate() {
    ArticleDB.save()//You have 5 Seconds!!
    debug("App is going to be terminated")
  }
 
  func deleteAll() {
//    popToRootViewController(animated: false)
    feederContext?.cancelAll()
    ArticleDB.singleton.close()
    /// Remove all content
    for f in Dir.appSupport.scan() {
      debug("remove: \(f)")
      File(f).remove()
    }
    log("delete all done successfully")
    exit(0)
  }
  
  func unlinkSubscriptionId() {
    authenticator?.unlinkSubscriptionId()
  }
  
  func deleteUserData() {
    SimpleAuthenticator.deleteUserData(excludeDataPolicyAccepted: false)
    Defaults.expiredAccountDate = nil
    let dfl = Defaults.singleton
    dfl["isTextNotification"] = "true"
    dfl["nStarted"] = "0"
    dfl["lastStarted"] = "0"
    dfl["installationId"] = nil
    feederContext?.gqlFeeder.authToken = nil
    feederContext?.endPolling()
    logKeychain(msg: "after delete")
    onThreadAfter {
      Notification.send(Const.NotificationNames.logoutUserDataDeleted)
    }
  }
  
  func testNotification(type: NotificationType) {
    if let pushToken = Defaults.singleton["pushToken"] {
      feederContext?.gqlFeeder.testNotification(pushToken: pushToken, request: type) {_ in}
    }
  }
  
  func setupFeeder() {
    Notification.receiveOnce("feederReady") { notification in
      guard let fctx = notification.sender as? FeederContext else { return }
      self.debug(fctx.storedFeeder.toString())
      self.startup()
    }
  }
  
  // Logs Keychain variables if in debug mode
  func logKeychain(msg: String? = nil) {
    var str = ""
    for k in ["id", "password", "token", "dataPolicyAccepted"] {
      var val = Keychain.singleton[k]
      if k == "password" && val != nil { val = "defined (but hidden on purpose)" }
      else if k == "token" && val != nil { val = val![0..<30] }
      str += "  \(k): \(val ?? "undefined")\n"
    }
    str = str[0..<str.count-1]
    var intro = "Keychain variables"
    if let msg = msg { intro += " (\(msg))" }
    intro += ":\n"
    debug("\(intro)\(str)")
  }
  
  func showIntro(closure: @escaping ()->()) {
    Notification.receiveOnce("resourcesReady") { [weak self] _ in
      guard let self = self else { return }
      self.debug("Showing Intro")
      let introVC = IntroVC()
      let feeder = self.feederContext?.storedFeeder
      introVC.htmlDataPolicy = feeder?.dataPolicy
      introVC.htmlIntro = feeder?.welcomeSlides
      Notification.receiveOnce("dataPolicyAccepted") { notif in
//        self?.popViewController(animated: false)
        let kc = Keychain.singleton
        kc["dataPolicyAccepted"] = "true"
        closure()
      }
      self.rootViewController = introVC
      
      onMainAfter(0.3) { [weak self] in
        guard let self = self, let fc = self.feederContext else { return }
        fc.getOvwIssues(feed: fc.defaultFeed, count: 4, isAutomatically: false)
      }
    }
    feederContext?.updateResources(toVersion: -1)
  }
  
  func showHome() {
    guard let feederContext = self.feederContext else {
      log("FeaderContextNot ready!")
      return
    }
    self.rootViewController = MainTabVC(feederContext: feederContext)
    feederContext.setupRemoteNotifications()
  }
  
  func setupTopMenus(targetWindow:UIWindow) {
    self.threeFingerAlertOpen = false
    let reportLPress2 = UILongPressGestureRecognizer(target: self,
        action: #selector(twoFingerErrorReportActivated))
    let reportLPress3 = UILongPressGestureRecognizer(target: self,
        action: #selector(threeFingerTouch))
    reportLPress2.numberOfTouchesRequired = 2
    reportLPress3.numberOfTouchesRequired = 3
    
    targetWindow.isUserInteractionEnabled = true
    targetWindow.addGestureRecognizer(reportLPress2)
    targetWindow.ifAlphaApp?.addGestureRecognizer(reportLPress3)
  }
  
  @objc func threeFingerTouch(_ sender: UIGestureRecognizer) {
    if threeFingerAlertOpen { return } else { threeFingerAlertOpen = true }
    var actions: [UIAlertAction] = []
    
    if App.isAlpha {
      actions.append(Alert.action("Abo-Verknüpfung löschen (⍺)") {[weak self] _ in self?.unlinkSubscriptionId() })
      actions.append(Alert.action("Abo-Push anfordern (⍺)") {[weak self] _ in self?.testNotification(type: NotificationType.subscription) })
      actions.append(Alert.action("Download-Push anfordern (⍺)") {[weak self] _ in self?.testNotification(type: NotificationType.newIssue) })
    }
    
    let title = App.appInfo + "\n" + App.authInfo(with: feederContext)
    Alert.actionSheet(title: title,
                      actions: actions) { [weak self] in
      self?.threeFingerAlertOpen = false
    }
  }
  func mailComposeController(_ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true)
    isErrorReporting = false
  }
  
  @objc func twoFingerErrorReportActivated(_ sender: UIGestureRecognizer) {
    if isErrorReporting == true { return }//Prevent multiple Calls
    showFeedbackErrorReport()
  }
  
  func showFeedbackErrorReport(_ feedbackType: FeedbackType? = nil) {
    isErrorReporting = true //No Check here to ensure error reporting is available at least from settings
    
    FeedbackComposer.showWith(logData: fileLogger.mem?.data,
                              feederContext: self.feederContext,
                              feedbackType: feedbackType) {[weak self] didSend in
      self?.log("Feedback send? \(didSend)")
      self?.isErrorReporting = false
    }
  }
  
  func reportFatalError(err: Log.Message) {
    guard !isErrorReporting else { return }
    isErrorReporting = true
    
    
    
    if let topVc = UIViewController.top(),
       topVc.presentedViewController != nil {
      topVc.dismiss(animated: false)
    }
    Alert.confirm(title: "Interner Fehler",
                  message: "Es liegt ein schwerwiegender interner Fehler vor, möchten Sie uns " +
                           "darüber mit einer Nachricht informieren?\n" +
                           "Interne Fehlermeldung:\n\(err)") { yes in
      if yes {
        self.produceErrorReport(recipient: "app@taz.de", subject: "Interner Fehler")
      }
      else { self.isErrorReporting = false }
    }
  }
  
  func produceErrorReport(recipient: String, subject: String = "Feedback",
                          completion: (()->())? = nil) {
    if MFMailComposeViewController.canSendMail() {
      let mail =  MFMailComposeViewController()
      let screenshot = UIWindow.screenshot?.jpeg
      let logData = fileLogger.mem?.data
      mail.mailComposeDelegate = self
      mail.setToRecipients([recipient])
      
      var tazIdText = ""
      let data = DefaultAuthenticator.getUserData()
      if let tazID = data.id, tazID.isEmpty == false {
        tazIdText = " taz-Konto: \(tazID)"
      }
      
      mail.setSubject("\(subject) \"\(App.name)\" (iOS)\(tazIdText)")
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
      UIViewController.top()?.topmostModalVc.present(mail, animated: true, completion: completion)
    }
  }
  
  static func saveLastLog(){
    /** copy last logfile before overwrite
     not solving:
     - multiple starts before send feedback
     - app did not start, overwrite "interesting" logfile
     Ideas:
     - do not overwrite with mini file
     - use kind of log rotataion next: which logfile to add?
     - use app context menu to acces last logfile?
    @see also FeedbackViewController adds this in feedback request
     Question: is this called for incomming push notification?
     */
    File(Log.FileLogger.defaultLogfile)
      .copy(to: Log.FileLogger.lastLogfile, isOverwrite: true)
  }
  
  static func updateDefaultsIfNeeded(){
    let dfl = Defaults.singleton
    dfl["showBottomTilesAnimation"]=nil
    dfl["fakeSubscriptionRequests"]=nil
    dfl.setDefaults(values: ConfigDefaults)
  }
  
  static func setupDefaultStyles(){
    if let defaultFontName = Const.Fonts.contentFontName,
       let defaultFont10 =  UIFont(name: defaultFontName, size: 10){
      UITabBarItem.appearance()
        .setTitleTextAttributes([NSAttributedString.Key.font:defaultFont10],
                                for: .normal)
      //Not working
      // UILabel.appearance(whenContainedInInstancesOf: [UIDatePicker.self]) ...
      // UILabel.appearance().font = Const.Fonts.contentFont
            
//      UITabBarItem.appearance()
//        .setTitleTextAttributes([NSAttributedString.Key.font:defaultFont10],
//                                for: .selected)
//      #warning("in search ugly fly in effect in simulator")
//      UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
//        .setTitleTextAttributes([NSAttributedString.Key.font:defaultFont],
//                                for: .normal)
//      UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
//        .setTitleTextAttributes([NSAttributedString.Key.font:defaultFont],
//                                for: .selected)
    }
    else {
      Log.log("Error default taz Font missing")
    }
  }
}


//App Context Menu helper
extension TazAppEnvironment {
  
  //#warning("ToDo: 0.9.4 Server Switch without App Restart")
  /// server switch helper
  /// initiate server switch request switch with confirm alert
  /// - Parameter shortcutServer: new server to use identified by shortcut item
  func handleServerSwitch(to shortcutServer: Shortcuts) {
    if Defaults.currentServer == shortcutServer {//already selected!
      Toast.show("\(shortcutServer.title) wird bereits verwendet!")
      return
    }
    
    let switchServerHandler: (Any?) -> Void = { [weak self]_ in
      self?.doServerSwitch(to: shortcutServer)
    }
    
    let serverSwitchAction = UIAlertAction(title: "Ja Server wechseln",
                                   style: .destructive,
                                   handler: switchServerHandler )
    let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel)
    
    let switchText
    = "Möchten Sie den Server vom "
    + Defaults.currentServer.title
    +  " zum "
    + shortcutServer.title
    + "wechseln?"
    + "\nDie App wird im Anschluss beendet und muss manuell neu gestartet werden!"
    
    Alert.message(title: "Achtung Serverwechsel!",
                  message: switchText,
                  actions: [serverSwitchAction,  cancelAction],
                  presentationController: rootViewController)
  }
  

  func doServerSwitch(to shortcutServer: Shortcuts) {
    let oldRoot =  self.rootViewController
    
    let intermediateVc = StartupVc()
    intermediateVc.text = "Bitte warten!\nWechsle zu:\n\(shortcutServer.title)\nDie App wird gleich beendet und muss manuell neu gestartet werden!"
    self.rootViewController = intermediateVc
    
    onMainAfter {[weak self] in
      self?.feederContext?.cancelAll()
      ArticleDB.singleton.close()
      ArticleDB.singleton = nil
      self?.feederContext = nil
      
      if let tab = oldRoot as? MainTabVC {
        for case let navCtrl as UINavigationController in tab.viewControllers ?? [] {
          navCtrl.popToRootViewController(animated: false)
          navCtrl.dismiss(animated: false)
        }
        for ctrl in tab.viewControllers ?? [] {
          if let navCtrl = ctrl as? UINavigationController {
            for ctrl in navCtrl.viewControllers {
              NotificationCenter.default.removeObserver(ctrl)
            }
            navCtrl.popToRootViewController(animated: false)
          }
          NotificationCenter.default.removeObserver(ctrl)
          ctrl.dismiss(animated: false)
        }
        tab.viewControllers = []
      }
      Defaults.currentServer = shortcutServer
      onMainAfter(3) {
        /// Too many handlers deinit on IssueVC did not work, recives issueOverview and more and crashes
        exit(0)
//        self?.setup()
      }
    }
  }
  
  /// app icon shortcut action handler
  /// - Parameter shortcutItem: selected shortcut item
  func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
    switch shortcutItem.type {
      case Shortcuts.liveServer.type:
        handleServerSwitch(to: Shortcuts.liveServer)
      case Shortcuts.testServer.type:
        handleServerSwitch(to: Shortcuts.testServer)
      case Shortcuts.lmdServer.type:
        handleServerSwitch(to: Shortcuts.lmdServer)
      case "AppInformation":
        break;
      default:
        Toast.show("Aktion nicht verfügbar!")
        break;
    }
  }
}
extension TazAppEnvironment : UIStyleChangeDelegate {
  func applyStyles() {
    if let img  = UIImage(name:"xmark")?
      .imageWithInsets(UIEdgeInsets(top: 1, left: 9, bottom: 1, right: 9),
                       tintColor: Const.SetColor.taz(.textFieldClear).color) {
      UIButton.appearance(whenContainedInInstancesOf: [UITextField.self]).setImage(img, for: .normal)
    }
  }
}

// Helper
extension Defaults{
    
  ///Helper to get current server from user defaults
  fileprivate static var currentServer : Shortcuts {
    get {
      switch Defaults.singleton["currentServer"] {
        case Shortcuts.testServer.type:
          return .testServer
        case Shortcuts.lmdServer.type:
          return .lmdServer
        default:
          return .liveServer
      }
    }
    set {
      ///only update if changed
      if Defaults.singleton["currentServer"] != newValue.type {
        Defaults.singleton["currentServer"] = newValue.type
      }
    }
  }
  
  static var currentFeeder : (name: String, url: String, feed: String) {
    get {
      switch Defaults.singleton["currentServer"] {
        case Shortcuts.testServer.type:
          return (name: "taz-test", url: "https://testdl.taz.de/appGraphQl", feed: "taz")
        case Shortcuts.lmdServer.type:
          return (name: "LMd", url: "https://dl.monde-diplomatique.de/appGraphQl", feed: "LMd")
        default:
          return (name: "taz", url: "https://dl.taz.de/appGraphQl", feed: "taz")
      }
    }
  }
}

/// Helper to add App Shortcuts to App-Icon
/// Warning View Logger did not work untill MainNC -> setupLogging ...   viewLogger is disabled!
/// @see: Log.append(logger: consoleLogger, /*viewLogger,*/ fileLogger)
enum Shortcuts{
  
  static func currentItems() -> [UIApplicationShortcutItem]{
    // No Server Switch for Release App
    if App.isRelease {
      return []
      // return [Shortcuts.logging.shortcutItem()] //deactivated logging ui for release
    }
    var itms:[UIApplicationShortcutItem] = [
      // Shortcuts.feedback.shortcutItem(.mail),
      // Shortcuts.logging.shortcutItem(wantsLogging ? .confirmation : nil)
    ]
    
    itms.append(Shortcuts.liveServer.shortcutItem)
    itms.append(Shortcuts.testServer.shortcutItem)
    itms.append(Shortcuts.lmdServer.shortcutItem)
    return itms
  }
  
  case liveServer, testServer, lmdServer, feedback
  
  /// Identifier for shortcut item
  var type:String{
    switch self {
      case .liveServer: return "shortcutItemLiveServer"
      case .testServer: return "shortcutItemTestServer"
      case .lmdServer: return "shortcutItemLMdServer"
      case .feedback: return "shortcutItemFeedback"
    }
  }
  
  /// human readable title
  var title:String{
    switch self {
      case .liveServer: return "Live Server"
      case .testServer: return "Test Server"
      case .lmdServer: return "LMd Server"
      case .feedback: return "Feedback"
    }
  }

  /// ShortcutItem generation Helper for app icon context menu
  var shortcutItem:UIApplicationShortcutItem { get {
    let active = Defaults.currentServer == self
    
    return UIApplicationShortcutItem(type: self.type,
                                     localizedTitle: self.title,
                                     localizedSubtitle: active ? "aktiv" : nil,
                                     icon: active ? UIApplicationShortcutIcon(type: .confirmation) : nil)
    }
  }
}


class StartupVc : UIViewController {
  public var text: String = "Starte..." {
    didSet {
      label.text = text
    }
  }
  
  let label = UILabel()
  
  override func viewDidLoad() {
    label.numberOfLines = -1
    label.text = text
    label.contentFont().center()
    label.textColor = .white
    
    let ai = UIActivityIndicatorView()
    self.view.addSubview(label)
    self.view.addSubview(ai)
    
    pin(label.left, to: self.view.leftGuide(isMargin: true), dist: 10)
    pin(label.right, to: self.view.rightGuide(isMargin: true), dist: 10)
    label.centerY()
    
    ai.centerX()
    pin(label.top, to: ai.bottom, dist: 10)
    
    ai.startAnimating()
  }
}
