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

class TazAppEnvironment: NSObject, DoesLog, MFMailComposeViewControllerDelegate {
  
  class Spinner: UIViewController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
      super.viewWillTransition(to: size, with: coordinator)
      Notification.send(Const.NotificationNames.viewSizeTransition,
                        content: size,
                        error: nil,
                        sender: nil)
    }
    
    
    convenience init() {
      self.init(nibName: nil, bundle: nil)
      self.view.backgroundColor = .black
      let spinner = UIActivityIndicatorView()
      view.addSubview(spinner)
      spinner.center()
      spinner.color = .white
      spinner.startAnimating()
      let lb = UILabel()
      lb.isHidden = true
      lb.text = "Verbinde..."
      lb.textAlignment = .center
      view.addSubview(lb)
      lb.numberOfLines = 0
      pin(lb.left, to: view.left, dist: 10.0)
      pin(lb.right, to: view.right, dist: -10.0)
      lb.contentFont(size: 12.0)
      lb.textColor = .lightGray
      pin(lb.top, to: spinner.bottom, dist: 20.0)
      onMain(after: 2.0) {
        lb.showAnimated()
      }
      onMain(after: 9.0) {
        lb.text = "Ups, das dauert aber heute lang!\n\nBitte überprüfen Sie Ihre Internetverbindung oder tippen Sie bitte hier, um uns einen Fehler zu melden."
        lb.onTapping {_ in
          TazAppEnvironment.sharedInstance.showFeedbackErrorReport(screenshot: UIWindow.screenshot)
          lb.text = "Falls das Problem weiterhin besteht und die taz Server erreichbar sind:\n• Fehlerbericht wurde erfolgreich gesendet\n• taz.de ist im Browser erreichbar\nbeenden Sie bitte die App und starten sie diese neu."
        }
      }
    }
  }
  
  private var threeFingerAlertOpen: Bool = false
  private var devGestureRecognizer: UIGestureRecognizer?
  
  var shouldShowNotifications = true
  
  public private(set) lazy var rootViewController : UIViewController = {
    // Startup Splash Screen!
    return Spinner()
  }()  {
    didSet {
//      return;//Simulate Connect Errors
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
  lazy var fileLogger = Log.FileLogger()
  var feederContext: FeederContext?
  var service: IssueOverviewService?
  let net = NetAvailability()
  
  var authenticator: Authenticator? { return feederContext?.authenticator }
  
  //ToDo Refactor this, make a small Business which includes Settings, Accound Expired, handle login with expiredAccount ... when implement login with expiredAccount
  ///Last error: loggedIn with Expired Account, ExpiredAccountFeederError was not unset when login with other account, when this also expiures (in one App Session!) popup not shown, no more "Ihr Konto ist wieder aktiv"
  ///...expired Info not shown in Settings until App-Restart; Under demo Article No Info
  public var expiredAccountInfoShown = false {
    didSet {
      if expiredAccountInfoShown == false {
        feederContext?.clearExpiredAccountFeederError()
      }
    }
  }

  @Key("dataPolicyAccepted")
  public var dataPolicyAccepted: Bool
  
  public private(set) var isErrorReporting = false
  private var isForeground = false
  
  override init(){
    super.init()
    Notification.receive(UIApplication.willResignActiveNotification) { [weak self] _ in
      self?.goingBackground()
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.goingForeground()
    }
    Notification.receive(UIApplication.willTerminateNotification) { [weak self] _ in
      self?.appWillTerminate()
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
    setupLogging()
    setupFeeder()
  }
  
  /// Enable logging to file and otional to view
  func setupLogging() {
    Log.log("Setting up logging")
    Log.append(logger: fileLogger)
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
    logSystemEvents()
    let now = UsTime.now
    self.showAnimations = (nStarted < 2) || (now.sec - lastStarted.sec) > oneWeek
    SectionVC.showAnimations = self.showAnimations
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
    debug("Entering foreground is connected?: \(feederContext?.isConnected)")
  }
  
  func appWillTerminate() {
    ArticleDB.save()//You have 5 Seconds!!
    debug("App is going to be terminated")
  }
 
  func deleteAll() {
    reset(isDelete: true)
  }
  
  func deleteData() {
    for f in Dir.appSupport.scan() {
      debug("remove: \(f)")
      File(f).remove()
    }
    log("App data deleted.")
  }
  
  func reset(isDelete: Bool = true) {
    rootViewController = Spinner()
    feederContext?.release(isRemove: isDelete) { [weak self] in
      guard let self else { return }
      self.feederContext = nil
      if isDelete { self.deleteData() } 
        // TODO: reinitialize feederContext when this no longer crashes
//      self.setupFeeder(isStartup: false)
      exit(0) // until feederContext is removed properly
    }
  }
  
  enum resetAppReason {
    case cycleChangeWithLogin, wrongCycleDownloadError
  }

  /// Reset App and delete data
  /// - Parameter reason: reason to display right message to user
  /// Warning in some unknown cases a weekend login did not fire resetApp(.cycleChangeWithLogin) then
  /// it may fired immediately on update an weekday issue
  public func resetApp(_ reason: resetAppReason) {
    let weeklyLogin = self.feederContext?.gqlFeeder.feeds.first?.cycle == .weekly
    var message: String
    switch (reason, weeklyLogin) {
      case (.cycleChangeWithLogin, _):
        message = """
            Zur Reinitialisierung der App ist ein Neustart erforderlich.
            Die App wird sich jetzt beenden. Starten Sie sie bitte anschließend
            erneut.
          """
      case (.wrongCycleDownloadError, true):
        message = """
            Es ist ein Fehler aufgetreten.
            Anscheinend sind Sie mit einem Wochentaz Abo angemeldet,
            in den lokalen Daten sind jedoch Werktagsausgaben vorhanden.
            Eine Reinitialisierung und Neustart der App ist erforderlich.
            Die App wird sich jetzt beenden. Starten Sie sie bitte anschließend
            erneut.
          """
      case (.wrongCycleDownloadError, false):
        message = """
            Es ist ein Fehler aufgetreten.
            Eine Reinitialisierung und Neustart der App ist erforderlich.
            Die App wird sich jetzt beenden. Starten Sie sie bitte anschließend
            erneut.
          """
    }
    Alert.message(title: "Neustart erforderlich",
      message: message) { [weak self] in
      self?.reset(isDelete: true)
    }
  }
  
  static var hasValidAuth: Bool { Self.sharedInstance.hasValidAuth }
  static var isAuthenticated: Bool { Self.sharedInstance.isAuthenticated }
  
  var isAuthenticated: Bool {
    feederContext?.isAuthenticated
    ?? (DefaultAuthenticator.getUserData().token != nil)
  }
  
  var hasValidAuth: Bool {
    isAuthenticated && Defaults.expiredAccount == false
  }

  func unlinkSubscriptionId() {
    authenticator?.unlinkSubscriptionId()
  }
  
  func deleteUserData(logoutFromServer: Bool = false, resetAppState: Bool) {
    SimpleAuthenticator.deleteUserData(logoutFromServer: logoutFromServer)
    Defaults.expiredAccountDate = nil
    if resetAppState == true {
      let dfl = Defaults.singleton
      dfl["isTextNotification"] = "true"
      Defaults.deleteAppStateDefaults()
    }
    feederContext?.gqlFeeder.authToken = nil
    feederContext?.endPolling()
    logKeychain(msg: "after delete")
    onThreadAfter {
      Notification.send(Const.NotificationNames.logoutUserDataDeleted)
    }
    expiredAccountInfoShown = false
    feederContext?.setupRemoteNotifications(force: true)
  }
  
  func testNotification(type: NotificationType) {
    if let pushToken = Defaults.singleton["pushToken"] {
      feederContext?.gqlFeeder.testNotification(pushToken: pushToken, request: type) {_ in}
    }
  }
  
  func setupFeeder(isStartup: Bool = true) {
    let feeder = Defaults.currentFeeder
    log("Connecting to feeder: \(feeder.name) feed: \(feeder.feed)")
    Notification.receiveOnce("feederReady") { [weak self] notification in
      guard let self, let fctx = notification.sender as? FeederContext else { return }
      self.debug(fctx.storedFeeder.toString())
      if isStartup { self.startup() }
      else { self.showHome() }
    }
    feederContext = FeederContext(name: feeder.name, url: feeder.url, feed: feeder.feed)
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
  
  func logSystemEvents() {
    
    NotificationCenter.default.addObserver(forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                                           object: nil,
                                           queue: nil,
                                           using: { [weak self] _ in
      self?.log("isLowPowerModeEnabled: \(ProcessInfo.processInfo.isLowPowerModeEnabled)")
    })
    
    NotificationCenter.default.addObserver(forName: UIApplication.backgroundRefreshStatusDidChangeNotification,
                                           object: nil,
                                           queue: nil,
                                           using: { [weak self] _ in
      self?.log("backgroundRefreshStatus: \(UIApplication.shared.backgroundRefreshStatus)")
    })
    
    self.log("isLowPowerModeEnabled: \(ProcessInfo.processInfo.isLowPowerModeEnabled)")
    self.log("backgroundRefreshStatus: \(UIApplication.shared.backgroundRefreshStatus)")
  }
  
  func showIntro(closure: @escaping ()->()) {
    Notification.receiveOnce("resourcesReady") { [weak self] _ in
      guard let self = self else { return }
      self.debug("Showing Intro")
      let introVC = IntroVC()
      let feeder = self.feederContext?.storedFeeder
      introVC.webView.toggleBottomButton = false
      introVC.htmlDataPolicy = feeder?.dataPolicy
      introVC.htmlIntro = feeder?.welcomeSlides
      Notification.receiveOnce("dataPolicyAccepted") { notif in
        let kc = Keychain.singleton
        kc["dataPolicyAccepted"] = "true"
        closure()
      }
      self.rootViewController = introVC
      onMainAfter(0.3) { [weak self] in
        guard let self = self,
                let fc = self.feederContext else { return }
        self.service = IssueOverviewService(feederContext: fc)
        _ = self.service?.cellData(for: 0)
        _ = self.service?.cellData(for: 3)
      }
    }
    feederContext?.updateResources(toVersion: -1)
  }
  
  func showHome() {
    guard let feederContext = self.feederContext else {
      log("FeaderContextNot ready!")
      return
    }
    self.rootViewController = MainTabVC(feederContext: feederContext,
                                        service: service
                                        ?? IssueOverviewService(feederContext: feederContext))
    feederContext.setupRemoteNotifications()
  }
  
  private func isTazUser() -> Bool {
    let dfl = Defaults.singleton
    let id = dfl["id"]
    if let id = id, id =~ ".*\\@taz\\.de$" { return true }
    return false
  }
  
  // is called after successful login
  func addThreeFingerMenu(targetWindow:UIWindow?) {
    guard devGestureRecognizer == nil else { return }
    let reportLPress3 = UILongPressGestureRecognizer(target: self,
        action: #selector(threeFingerTouch))
    reportLPress3.numberOfTouchesRequired = 3
    targetWindow?.isUserInteractionEnabled = true
    targetWindow?.addGestureRecognizer(reportLPress3)
    devGestureRecognizer = reportLPress3
  }
  
  static func checkcDevMenu() {
    guard let win = UIApplication.shared.delegate?.window else { return }
    let env = TazAppEnvironment.sharedInstance
    if env.isTazUser() { env.addThreeFingerMenu(targetWindow: win) }
    else if let recog = env.devGestureRecognizer, !App.isAlpha {
      win?.removeGestureRecognizer(recog)
      env.devGestureRecognizer = nil
    }
  }
  
  func setupTopMenus(targetWindow:UIWindow) {
    self.threeFingerAlertOpen = false
    let reportLPress2 = UILongPressGestureRecognizer(target: self,
        action: #selector(twoFingerErrorReportActivated))
    reportLPress2.numberOfTouchesRequired = 2
    targetWindow.isUserInteractionEnabled = true
    targetWindow.addGestureRecognizer(reportLPress2)
    if App.isAlpha || isTazUser() { addThreeFingerMenu(targetWindow: targetWindow) }
  }
  
  @objc func threeFingerTouch(_ sender: UIGestureRecognizer) {
    if threeFingerAlertOpen { return } else { threeFingerAlertOpen = true }
    var actions: [UIAlertAction] = []
    let dfl = Defaults.singleton
    
    actions.append(Alert.action("Abo-Verknüpfung löschen") {[weak self] _ in self?.unlinkSubscriptionId() })
    actions.append(Alert.action("Abo-Push anfordern") {[weak self] _ in self?.testNotification(type: NotificationType.subscription) })
    actions.append(Alert.action("Download-Push anfordern") {[weak self] _ in self?.testNotification(type: NotificationType.newIssue) })
    if App.isAlpha { actions.append(contentsOf: UIAlertAction.developerPushActions(callback: { _ in })) }
    
    let sMin = Alert.action("Simuliere höhere Minimalversion") { _ in
      dfl["simulateFailedMinVersion"] = "true"
      Alert.confirm(title: "Beenden",
                    message: "Die App wird jetzt beendet, zum Simulieren bitte neu starten") { terminate in
        if terminate { exit(0) }
      }
    }
    actions.append(sMin)
    let sCheck = Alert.action("Simuliere höhere Version im AppStore") { _ in
      dfl["simulateNewVersion"] = "true"
      Alert.confirm(title: "Beenden",
                    message: "Die App wird jetzt beendet, zum Simulieren bitte neu starten") { terminate in
        if terminate { exit(0) }
      }
    }
    actions.append(sCheck)
    
    ///Simulate App Termination by System not forced by user
    ///may wait some minutes to test backgroud data update by push
    if (DefaultAuthenticator.getUserData().id ?? "") == "ringo.mueller@taz.de" {
      actions.append(Alert.action("App beenden") {_ in exit(0)})
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
    showFeedbackErrorReport(screenshot: UIWindow.screenshot)
  }
  
  func showFeedbackErrorReport(_ feedbackType: FeedbackType? = nil, screenshot: UIImage? = nil) {
    isErrorReporting = true //No Check here to ensure error reporting is available at least from settings
    
    FeedbackComposer.showWith(logData: fileLogger.mem?.data,
                              screenshot: screenshot,
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
  
  func produceErrorReport(recipient: String,
                          subject: String = "Feedback",
                          logData: Data? = nil,
                          addScreenshot: Bool = true,
                          completion: (()->())? = nil) {
    if MFMailComposeViewController.canSendMail() {
      let mail =  MFMailComposeViewController()
      let screenshot = UIWindow.screenshot?.jpeg
      let logData = logData ?? fileLogger.mem?.data
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
      if addScreenshot, let screenshot = screenshot {
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
    File(Log.FileLogger.lastLogfile)
      .copy(to: Log.FileLogger.secondLastLogfile, isOverwrite: true)
    File(Log.FileLogger.tmpLogfile)
      .copy(to: Log.FileLogger.lastLogfile, isOverwrite: true)
  }
  
  static func updateDefaultsIfNeeded(){
    let dfl = Defaults.singleton
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
    
    let intermediateVc = StartupVC()
    intermediateVc.text = "Bitte warten!\nWechsle zu:\n\(shortcutServer.title)\nDie App wird gleich beendet und muss manuell neu gestartet werden!"
    self.rootViewController = intermediateVc
    
    onMainAfter {[weak self] in
      guard let self else { return }
      self.reset(isDelete: false)
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
        exit(0)
//        self?.setup()
      }
    }
  }
  
  func playBookmarks(){
    guard let feeder = feederContext?.storedFeeder else { return }
    let bookmarkFeed = BookmarkFeed.allBookmarks(feeder: feeder)
    guard let bi = (bookmarkFeed.issues ?? []).first as? BookmarkIssue else { return }
    ArticlePlayer.singleton.play(issue: bi,
                                 startFromArticle: nil,
                                 enqueueType: .replaceCurrent)
  }
  
  func playLatestIssue(){
    guard let feederContext = feederContext,
          feederContext.defaultFeed != nil,
          let si = feederContext.getLatestStoredIssue() else {
      LocalNotifications.notifyOfflineListenNotPossible()
      return
    }
    ArticlePlayer.singleton.play(issue: si,
                                 startFromArticle: nil,
                                 enqueueType: .replaceCurrent)
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
      case Shortcuts.playBookmarks.type:
        if UIApplication.shared.applicationState == .active {
          playBookmarks()
          return
        }
        onMainAfter(0.3) { [weak self] in
          self?.playBookmarks()
        }
      case Shortcuts.playLatestIssue.type:
        if UIApplication.shared.applicationState == .active {
          playLatestIssue()
          return
        }
        onMainAfter(1.3) { [weak self] in
          self?.playLatestIssue()
        }
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
    var itms:[UIApplicationShortcutItem]
    = [Shortcuts.playLatestIssue.shortcutItem]
    
    if let sf = TazAppEnvironment.sharedInstance.feederContext?.storedFeeder ,
       BookmarkFeed.allBookmarks(feeder: sf).issues?.first?.allArticles.count ?? 0 > 0 {
      itms.append(Shortcuts.playBookmarks.shortcutItem)
    }
    // No Server Switch for Release App
    if App.isRelease { return itms }
    itms.append(Shortcuts.liveServer.shortcutItem)
    itms.append(Shortcuts.lmdServer.shortcutItem)
    itms.append(Shortcuts.testServer.shortcutItem)
    return itms
  }
  
  case liveServer, testServer, lmdServer, feedback, playBookmarks, playLatestIssue
  
  /// Identifier for shortcut item
  var type:String{
    switch self {
      case .liveServer: return "shortcutItemLiveServer"
      case .testServer: return "shortcutItemTestServer"
      case .lmdServer: return "shortcutItemLMdServer"
      case .feedback: return "shortcutItemFeedback"
      case .playBookmarks: return "shortcutItemBookmarks"
      case .playLatestIssue: return "shortcutItemLatestIssue"
    }
  }
  
  /// human readable title
  var title:String{
    switch self {
      case .liveServer: return "Live Server"
      case .testServer: return "Test Server"
      case .lmdServer: return "LMd Server"
      case .feedback: return "Feedback"
      case .playBookmarks: return "Leseliste abspielen"
      case .playLatestIssue: return "Aktuelle Ausgabe abspielen"
    }
  }

  /// ShortcutItem generation Helper for app icon context menu
  var shortcutItem:UIApplicationShortcutItem { get {
    let active = Defaults.currentServer == self
    var icon:UIApplicationShortcutIcon?
    switch self {
      case .playBookmarks, .playLatestIssue:
        icon = UIApplicationShortcutIcon(type: .audio)
      default:
        icon = active ? UIApplicationShortcutIcon(type: .confirmation) : nil
    }
    
    return UIApplicationShortcutItem(type: self.type,
                                     localizedTitle: self.title,
                                     localizedSubtitle: active ? "aktiv" : nil,
                                     icon: icon)
    }
  }
}
