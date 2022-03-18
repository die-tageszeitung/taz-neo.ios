//
//  TazAppEnvironment.swift
//  taz.neo
//
//  Created by Ringo Müller on 01.03.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import NorthLib
import MessageUI

class TazAppEnvironment /*: NSObject, DoesLog, MFMailComposeViewControllerDelegate */{
  /**HACK**/
  func log(_ any:Any?){}
  func debug(_ any:Any?){}
  func error(_ any:Any?){}
  let view = UIView()
  
  var wantLogging = false
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
      window?.hideAnimated() {
        window?.rootViewController = self.rootViewController
        window?.showAnimated()
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
  
  init(){
    let feeder = Defaults.currentFeeder
    feederContext = FeederContext(name: feeder.name, url: feeder.url, feed: feeder.feed)
    
    setupLogging()
    setupTopMenus()
    setupLogging()
    Notification.receive(UIApplication.willResignActiveNotification) { _ in
      self.goingBackground()
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { _ in
      self.goingForeground()
    }
    Notification.receive(UIApplication.willTerminateNotification) { _ in
      self.appWillTerminate()
    }
    setupFeeder()
  }
  
  
  /// Enable logging to file and otional to view
  func setupLogging() {
    let logView = viewLogger.logView
    logView.isHidden = true
    view.addSubview(logView)
    logView.pinToView(view)
    Log.append(logger: consoleLogger, /*viewLogger,*/ fileLogger)
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
    let nd = UIApplication.shared.delegate as! AppDelegate
//    nd.onSbTap { tview in
//      if nd.wantLogging {
//        if logView.isHidden {
//          self.view.bringSubviewToFront(logView)
//          logView.scrollToBottom()
//          logView.isHidden = false
//        }
//        else {
//          self.view.sendSubviewToBack(logView)
//          logView.isHidden = true
//        }
//      }
//    }
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
    let now = UsTime.now()
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
    SimpleAuthenticator.deleteUserData()
    Defaults.expiredAccountDate = nil
    let dfl = Defaults.singleton
    let kc = Keychain.singleton
    kc["dataPolicyAccepted"] = nil
    dfl["isTextNotification"] = "true"
    dfl["nStarted"] = "0"
    dfl["lastStarted"] = "0"
    dfl["installationId"] = nil
    feederContext?.gqlFeeder.authToken = nil
    feederContext?.endPolling()
    logKeychain(msg: "after delete")
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
  
  func setupTopMenus() {
    let reportLPress2 = UILongPressGestureRecognizer(target: self,
        action: #selector(twoFingerErrorReportActivated))
    let reportLPress3 = UILongPressGestureRecognizer(target: self,
        action: #selector(threeFingerTouch))
    reportLPress2.numberOfTouchesRequired = 2
    reportLPress3.numberOfTouchesRequired = 3
    
    
    if let targetView = UIApplication.shared.keyWindow {
      /// currently never executed due keyWindow was nil when logged in
      targetView.isUserInteractionEnabled = true
      targetView.addGestureRecognizer(reportLPress2)
      targetView.ifAlphaApp?.addGestureRecognizer(reportLPress3)
    }
    else if let delegate = UIApplication.shared.delegate as? AppDelegate,
            let targetWindow = delegate.window {
      /// ...improved version of previous comparrison ...should be standalone!
      targetWindow.isUserInteractionEnabled = true
      targetWindow.addGestureRecognizer(reportLPress2)
      targetWindow.ifAlphaApp?.addGestureRecognizer(reportLPress3)
    }
    else {
      self.view.isUserInteractionEnabled = true
      self.view.addGestureRecognizer(reportLPress2)
      self.view.ifAlphaApp?.addGestureRecognizer(reportLPress3)
    }
  }
  
  @objc func threeFingerTouch(_ sender: UIGestureRecognizer) {
    if threeFingerAlertOpen { return } else { threeFingerAlertOpen = true }
    var actions: [UIAlertAction] = []
    
    if App.isAlpha {
      actions.append(Alert.action("Abo-Verknüpfung löschen (⍺)") {[weak self] _ in self?.unlinkSubscriptionId() })
      actions.append(Alert.action("Abo-Push anfordern (⍺)") {[weak self] _ in self?.testNotification(type: NotificationType.subscription) })
      actions.append(Alert.action("Download-Push anfordern (⍺)") {[weak self] _ in self?.testNotification(type: NotificationType.newIssue) })
      actions.append(Alert.action("Protokoll an/aus (⍺)") {[weak self] _ in
        guard let self = self else { return }
        let logView = self.viewLogger.logView
        if logView.isHidden {
          self.view.bringSubviewToFront(logView)
          logView.scrollToBottom()
          logView.isHidden = false
        }
        else {
          self.view.sendSubviewToBack(logView)
          logView.isHidden = true
        }
      })
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
    showFeedbackErrorReport()
  }
  
  func showFeedbackErrorReport(_ feedbackType: FeedbackType? = nil) {
    if isErrorReporting == true { return }//Prevent multiple Calls
    isErrorReporting = true
    
    FeedbackComposer.showWith(logData: fileLogger.data,
                              feederContext: self.feederContext,
                              feedbackType: feedbackType) {[weak self] didSend in
      print("Feedback send? \(didSend)")
      self?.isErrorReporting = false
    }
  }
  
  func reportFatalError(err: Log.Message) {
    guard !isErrorReporting else { return }
    isErrorReporting = true
//    if self.presentedViewController != nil {
//      dismiss(animated: false)
//    }
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
      let logData = fileLogger.data
//      mail.mailComposeDelegate = self
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
//      self.topmostModalVc.present(mail, animated: true, completion: completion)
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
    dfl["offerTrialSubscription"]=nil
    dfl["showBottomTilesAnimation"]=nil
    dfl.setDefaults(values: ConfigDefaults)
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
      switch shortcutServer {
        case Shortcuts.liveServer:
          Defaults.currentServer = .liveServer
          self?.deleteAll()
        case Shortcuts.testServer:
          Defaults.currentServer = .testServer
          self?.deleteAll()
        default:
          break;
      }
    }
    
    let serverSwitchAction = UIAlertAction(title: "Ja Server wechseln",
                                   style: .destructive,
                                   handler: switchServerHandler )
    let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel)
    
    Alert.message(title: "Achtung Serverwechsel!", message: "Möchten Sie den Server vom \(Defaults.serverSwitchText) wechseln?\nAchtung!\nDie App muss neu gestartet werden.\n\n Alle Daten werden gelöscht!", actions: [serverSwitchAction,  cancelAction])
  }
  
  
  /// app icon shortcut action handler
  /// - Parameter shortcutItem: selected shortcut item
  func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
    switch shortcutItem.type {
      case Shortcuts.logging.type:
        wantLogging = !wantLogging
      case Shortcuts.liveServer.type:
        handleServerSwitch(to: Shortcuts.liveServer)
      case Shortcuts.testServer.type:
        handleServerSwitch(to: Shortcuts.testServer)
      case "AppInformation":
        break;
      default:
        Toast.show("Aktion nicht verfügbar!")
        break;
    }
  }
}


// Helper
extension Defaults{
  
  /// Server switch Helper,
  /// check if server switch shortcut item selected and current server is not selected server
  /// - Parameter shortcutItem: app icon shortcut item
  /// - Returns: true if server switch should be performed
  fileprivate static func isServerSwitch(for shortcutItem: UIApplicationShortcutItem) -> Bool{
    if shortcutItem.type == Shortcuts.liveServer.type && currentServer != .liveServer { return true }
    if shortcutItem.type == Shortcuts.testServer.type && currentServer != .testServer { return true }
    return false
  }
  
  ///Helper to get current server from user defaults
  fileprivate static var currentServer : Shortcuts {
    get {
      if let curr = Defaults.singleton["currentServer"], curr == Shortcuts.testServer.type {
        return .testServer
      }
      return .liveServer
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
      if let curr = Defaults.singleton["currentServer"], curr == Shortcuts.testServer.type {
        return (name: "taz-testserver", url: "https://testdl.taz.de/appGraphQl", feed: "taz")
      }
      return (name: "taz", url: "https://dl.taz.de/appGraphQl", feed: "taz")
    }
  }
  
  
  fileprivate static var serverSwitchText : String {
    get {
      if currentServer == .testServer {
        return "Test Server zum Live Server"
      }
      return "Live Server zum Test Server"
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
    
    if Defaults.currentServer == .liveServer {
      itms.append(Shortcuts.liveServer.shortcutItem(.confirmation, subtitle: "aktiv"))
      itms.append(Shortcuts.testServer.shortcutItem())
    }
    else {
      itms.append(Shortcuts.liveServer.shortcutItem())
      itms.append(Shortcuts.testServer.shortcutItem(.confirmation, subtitle: "aktiv"))
    }
    return itms
  }
  
  case liveServer, testServer, feedback, logging
  
  
  /// Identifier for shortcut item
  var type:String{
    switch self {
      case .liveServer: return "shortcutItemLiveServer"
      case .testServer: return "shortcutItemTestServer"
      case .feedback: return "shortcutItemFeedback"
      case .logging: return "shortcutItemLogging"
    }
  }
  
  
  /// human readable title
  var title:String{
    switch self {
      case .liveServer: return "Live Server"
      case .testServer: return "Test Server"
      case .feedback: return "Feedback"
      case .logging: return "Protokoll einschalten"
    }
  }
    
  
  /// ShortcutItem generation Helper
  /// - Parameters:
  ///   - iconType: identifier for shortcut item
  ///   - subtitle: optional subtitle
  /// - Returns: ShortcutItem for app icon context menu
  func shortcutItem(_ iconType:UIApplicationShortcutIcon.IconType? = nil, subtitle: String? = nil) -> UIApplicationShortcutItem {
    return UIApplicationShortcutItem(type: self.type,
                                     localizedTitle: self.title,
                                     localizedSubtitle: subtitle,
                                     icon: iconType == nil ? nil : UIApplicationShortcutIcon(type: iconType!) )
  }
}
