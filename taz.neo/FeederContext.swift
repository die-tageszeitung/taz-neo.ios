//
//  FeederContext.swift
//
//  Created by Norbert Thies on 17.06.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/**
 A FeederContext manages one Feeder, its GraphQL interface to the backing
 server and its persistent data.
 
 Depending on the state of Feeder access the following Notifications are 
 sent:
   - DBReady
     when database has been initialized
   - feederReachable(FeederContext)
     network connectivity changed, feeder is reachable
   - feederUneachable(FeederContext)
     network connectivity changed, feeder is not reachable
   - feederReady(FeederContext)
     Feeder data is available (if not reachable then data is from DB)
   - feederRelease
     Feeder is going to release its data in 0.5s
   - issueOverview(Result<Issue,Error>)
     Issue Overview has been received (and stored in DB) 
   - gqlIssue(Result<GqlIssue,Error>)
     GraphQL Issue has been received (prior to "issue")
   - issue(Result<Issue,Error>), sender: Issue
     Issue with complete structural data and downloaded files is available
   - issueProgress((bytesLoaded, totalBytes))
     Issue loading progress indicator
   - resourcesReady(FeederContext)
     Resources are loaded and ready
   - resourcesProgress((bytesLoaded, totalBytes))
     Resource loading progress indicator
 */
open class FeederContext: DoesLog {
  
  /// Number of seconds to wait until we stop polling for email confirmation
  let PollTimeout: Int64 = 25*3600
  
  public var openedIssue: Issue? {
    didSet {
      if let openedIssue = openedIssue,
         openedIssue.date == getLatestStoredIssue()?.date {
        UIApplication.shared.applicationIconBadgeNumber = 0
      }
    }
  }

  /// Name (title) of Feeder
  public var name: String
  /// Name of default Feed to show
  public var feedName: String
  /// URL of Feeder (as String)
  public var url: String
  /// Authenticator object
  public var authenticator: Authenticator! {
    didSet { setupPolling() }
  }
  /// The token for remote notifications
  public var pushToken: String?
  /// The GraphQL Feeder (from server)
  public var gqlFeeder: GqlFeeder!
  /// The stored Feeder (from DB)
  public var storedFeeder: StoredFeeder! {
    didSet {
      /// used due  a chicken or the egg causality dilemma
      /// if i start online no db is on startup available to read the data, but we dont want to load all dates if just a few are needed
      /// other challenges: initial start, migration from 0.9.x, online/offline start, switch daily/weekly
      /// ...actually FeederContext needs a big refactoring mybe with a bundled initial issue
      /// to get rid of all the patches
      latestPublicationDate =  (storedFeeder.feeds.first as? StoredFeed)?.lastPublicationDate
      updatePublicationDatesIfNeeded(for: nil)
    }
  }
  /// The default Feed to show
  public var defaultFeed: StoredFeed!
  /// The Downloader to use 
  public var dloader: Downloader! {
    didSet {
      guard let old = oldValue else { return }
      ///This fixes endless Loop of IssueOverviewService.apiLoadMomentImages
      ///if offline scroll to unknown moment, go online due the used downloader did not recognize
      ///online status
      old.release()
    }
  }
  
  
  /**
   [...]
   SCNetworkReachability and  NWPathMonitor
   is not perfect; it can result in both false positives (saying that something is reachable when it’s not) and false negatives (saying that something is unreachable when it is). It also suffers from TOCTTOU issues.
   [...]
   Source: https://developer.apple.com/forums/thread/105822
   Written by: Quinn “The Eskimo!”   Apple Developer Relations, Developer Technical Support, Core OS/Hardware
    => this is maybe the problem within our: Issue not appears, download not work issues
   */
  /// netAvailability is used to check for network access to the Feeder
  public var netAvailability: NetAvailability
  @Default("useMobile")
  public var useMobile: Bool
  
  @Default("autoloadOnlyInWLAN")
  var autoloadOnlyInWLAN: Bool
  
  @Default("autoloadPdf")
  var autoloadPdf: Bool
  
  @Default("autoloadNewIssues")
  var autoloadNewIssues: Bool
  
  @Default("simulateFailedMinVersion")
  var simulateFailedMinVersion: Bool
  
  @Default("simulateNewVersion")
  var simulateNewVersion: Bool
  
  var netStatusVerification = Date()
  
  var latestPublicationDate:Date? {
    didSet {
      Defaults.latestPublicationDate = latestPublicationDate
    }
  }
  
  /// isConnected returns true if the Feeder is available
  public var isConnected: Bool { 
    var isCon: Bool
    if netAvailability.isAvailable {
      if netAvailability.isMobile {
        isCon = useMobile
      } 
      else { isCon = true }
    }
    else { isCon = false }
    
    //every 60 seconds check if NetAvailability really work
    if !isCon,
       netStatusVerification.timeIntervalSinceNow < -10,
        let host = URL(string: self.url)?.host,
        NetAvailability(host: host).isAvailable {
      netStatusVerification = Date()
      log("Seams we need to update NetAvailability")
      updateNetAvailabilityObserver()
      
    }
    
    return isCon
  }
  /// Has the Feeder been initialized yet
  public var isReady = false
  
  /// Has minVersion been met?
  public var minVersionOK = true
  
  /// Bundle ID to use for App store retrieval
  public var bundleID = App.bundleIdentifier
  
  /// Overwrite for current App version
  public var currentVersion = App.version
  
  /// Server required minimal App version
  public var minVersion: Version?

  
//  public private(set) var enqueuedDownlod:[Issue] = [] {
//    didSet {
//      print("Currently Downloading: \(enqueuedDownlod.map{$0.date.gDate()})")
//    }
//  }
  
  /// Are we updating resources
  private var isUpdatingResources = false
  
  /// Are we authenticated with the server?
  public var isAuthenticated: Bool { gqlFeeder.isAuthenticated }

  /// notify sends a Notification to all objects listening to the passed
  /// String 'name'. The receiver closure gets the sending FeederContext
  /// as 'sender' argument.
  private func notify(_ name: String, content: Any? = nil) {
    Notification.send(name, content: content, sender: self)
  }
  
  /// This notify sends a Result<Type,Error>
  private func notify<Type>(_ name: String, result: Result<Type,Error>) {
    Notification.send(name, result: result, sender: self)
  }
  
  /// Present an alert indicating there is no connection to the Feeder
  public func noConnection(to: String? = nil, isExit: Bool = false,
                           closure: (()->())? = nil) {
    var sname: String? = nil
    if storedFeeder != nil { sname = storedFeeder.title }
    if let name = to ?? sname {
      let title = isExit ? "Fehler" : "Warnung"
      var msg = """
        Ich kann den \(name)-Server nicht erreichen, möglicherweise
        besteht keine Verbindung zum Internet. Oder Sie haben der App
        die Verwendung mobiler Daten nicht gestattet.
        """
      if isExit {
        msg += """
          \nBitte versuchen Sie es zu einem späteren Zeitpunkt
          noch einmal.
          """
      }
      else {
        msg += """
          \nSie können allerdings bereits heruntergeladene Ausgaben auch
          ohne Internet-Zugriff lesen.
          """        
      }
      OfflineAlert.message(title: title, message: msg, closure: closure)
    }
  }
  
  private func enforceUpdate(closure: (()->())? = nil) {
    let id = bundleID
    guard let store = try? StoreApp(id) else { 
      error("Can't find App with bundle ID '\(id)' in AppStore")
      return 
    }
    let minVersion = self.minVersion?.toString() ?? "unbekannt"
    let msg = """
      Es liegt eine neue Version dieser App mit folgenden Änderungen vor:
        
      \(store.releaseNotes)
        
      Sie haben momentan die Version \(currentVersion) installiert. Um aktuelle
      Ausgaben zu laden, ist mindestens die Version \(minVersion)
      erforderlich. Möchten Sie jetzt eine neue Version laden?
    """
    Alert.confirm(title: "Update erforderlich", message: msg) { [weak self] doUpdate in
      guard let self else { return }
      if self.simulateFailedMinVersion {
        Defaults.singleton["simulateFailedMinVersion"] = "false"
      }
      if doUpdate { 
        store.openInAppStore { closure?() }
      }
      else { exit(0) }
    }
  }
  
  private func check4Update() {
    async { [weak self] in
      guard let self else { return }
      let id = self.bundleID
      let version = self.currentVersion
      guard let store = try? StoreApp(id) else { 
        self.error("Can't find App with bundle ID '\(id)' in AppStore")
        return 
      }
      self.debug("Version check: \(version) current, \(store.version) store")
      if store.needUpdate() {
        let msg = """
        Sie haben momentan die Version \(self.currentVersion) installiert.
        Es liegt eine neue Version \(store.version) mit folgenden Änderungen vor:
        
        \(store.releaseNotes)
        
        Möchten Sie im AppStore ein Update veranlassen?
        """
        onMain(after: 2.0) { 
          Alert.confirm(title: "Update", message: msg) { [weak self] doUpdate in
            guard let self else { return }
            if self.simulateNewVersion {
              Defaults.singleton["simulateNewVersion"] = "false"
            }
            if doUpdate { store.openInAppStore() }
            else { Defaults.newStoreVersionFoundDate = Date()}///delay again for 20? days
          }
        }
      }
    }
  }
  
  /// Feeder is now reachable
  private func feederReachable(feeder: Feeder) {
    self.debug("Feeder now reachable")
    self.dloader = Downloader(feeder: feeder as! GqlFeeder)
    notify(Const.NotificationNames.feederReachable)
    LocalNotifications.removeOfflineListenNotPossibleNotifications()
  }
  
  /// Feeder is not reachable
  private func feederUnreachable() {
    self.debug("Feeder now unreachable")
    notify(Const.NotificationNames.feederUnreachable)
  }
  
  private func updateNetAvailabilityObserver() {
    guard let host = URL(string: self.url)?.host else {
      log("cannot update NetAvailabilityObserver for URL Host: \(url)")
      return
    }
    self.netAvailability = NetAvailability(host: host)
    self.netAvailability.onChange { [weak self] _ in self?.checkNetwork() }
  }
  
  /// Network status has changed 
  private func checkNetwork() {
    self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated)")
    if isConnected {
      //#warning("ToDo: 0.9.4 loock for logs&errors after 0.9.3 release")
      /// To discuss: idea to reset previous feeder's gqlSession's URLSession to get rid of download errors
      /// e.g. if the session exists over 3h...
      //      if let oldFeeder = self.gqlFeeder {
      //        oldFeeder.gqlSession?.session.reset {   [weak self] in
      //          self?.log("Old Session Resetted!!")
      //        }
      //      }
      
      self.gqlFeeder = GqlFeeder(title: name, url: url) { [weak self] res in
        guard let self = self else { return }
        if let feeder = res.value() {
          if let gqlFeeder = feeder as? GqlFeeder,
             let storedAuth = SimpleAuthenticator.getUserData().token {
            gqlFeeder.authToken = storedAuth
          }
          if let gqlFeeder = feeder as? GqlFeeder {
            //Update Feeder with PublicationDates
            self.persist(gqlFeeder: gqlFeeder)
          }
          self.feederReachable(feeder: feeder)
        }
        else { self.feederUnreachable() }
      }
      ///Fix timing Bug, Demo Issue Downloaded, and probably login form shown
      if let storedAuth = SimpleAuthenticator.getUserData().token, self.gqlFeeder.authToken == nil {
        self.gqlFeeder.authToken = storedAuth
      }
    }
    else { self.feederUnreachable() }
  }
  
  private func persist(gqlFeeder:GqlFeeder){
    let oldCnt
    = storedFeeder == nil ///WARNING DO NOT REMOVE THE CHECK OTHERWISE APP WILL CRASH on init
    ? 0 ///unfortunately refactor storedFeeder to be an optional is an enormous undertaking
    : self.storedFeeder?.feeds.first?.publicationDates?.count
    self.storedFeeder = StoredFeeder.persist(object: self.gqlFeeder)
    let newCnt = self.storedFeeder?.feeds.first?.publicationDates?.count
    if oldCnt == newCnt { return }
    Notification.send(Const.NotificationNames.publicationDatesChanged)
  }
  
  /// Feeder is initialized, set up other objects
  private func feederReady() {
    self.dloader = Downloader(feeder: gqlFeeder)
    netAvailability.onChange { [weak self] _ in self?.checkNetwork() }
    guard let storedFeeder = storedFeeder else {
      log("storedFeeder not initialized yet!")
      return
    }
    defaultFeed = StoredFeed.get(name: feedName, inFeeder: storedFeeder)[0]
    isReady = true
    cleanupOldIssues()
    notify("feederReady")            
  }
  
  /// Do we need reinitialization?
  func needsReInit() -> Bool {
    if let storedFeeder = self.storedFeeder,
       let sfeed = storedFeeder.feeds.first,
       let gfeed = gqlFeeder.feeds.first {
      return !(sfeed.cycle == gfeed.cycle)
    }
    return false
  }
  
  /// React to the feeder being online or not
  private func feederStatus(isOnline: Bool) {
    debug("isOnline: \(isOnline)")
    if isOnline {
      guard minVersionOK else {
        enforceUpdate()
        return
      }
      if needsReInit() { 
        TazAppEnvironment.sharedInstance.resetApp(.cycleChangeWithLogin) 
      }
      else {
        self.persist(gqlFeeder: self.gqlFeeder)
        feederReady()
        check4Update()
      }
    }
    else {
      let feeders = StoredFeeder.get(name: name)
      if feeders.count == 1 {
        self.storedFeeder = feeders[0]
        self.noConnection(to: name, isExit: false) {  [weak self] in
          self?.feederReady()
        }
      }
      else {
        self.noConnection(to: name, isExit: true) {   [weak self] in
          guard let self = self else { exit(0) }
          /// Try to connect if network is available now e.g. User has seen Popup No Connection
          /// User activated MobileData/WLAN, press OK => Retry not App Exit
          if self.netAvailability.isAvailable { self.connect() }
          else { exit(0) }
        }
      }
    }
  }
  
  private var pollingTimer: Timer?
  private var pollEnd: Int64?
  
  public func resume() {
    self.checkNetwork()
  }
  
  /// Start Polling if necessary
  public func setupPolling() {
    authenticator.whenPollingRequired { self.startPolling() }
    if let peStr = Defaults.singleton["pollEnd"]  {
      if self.isAuthenticated {
        endPolling()
        return
      }
      let pe = Int64(peStr)
      if pe! <= UsTime.now.sec { endPolling() }
      else {
        pollEnd = pe
        self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, 
          repeats: true) { _ in self.doPolling() }        
      }
    }
  }
  
  /// Method called by Authenticator to start polling timer
  private func startPolling() {
    self.pollEnd = UsTime.now.sec + PollTimeout
    Defaults.singleton["pollEnd"] = "\(pollEnd!)"
    self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, 
      repeats: true) { _ in self.doPolling() }
  }
  
  /// Ask Authenticator to poll server for authentication,
  /// send 
  func doPolling(_ fetchCompletionHandler: FetchCompletionHandler? = nil) {
    ///prevent login with another acount
    if authenticator.feeder.authToken?.isEmpty == false {
      log("still logged in, prevent login with another acount")
      return
    }
    authenticator.pollSubscription { [weak self] doContinue in
      ///No matter if continue or not, iusually activate account takes more than 30s
      ///so its necessary to call push fetchCompletionHandler after first attempt
      fetchCompletionHandler?(.noData)
      guard let self = self else { return }
      guard let pollEnd = self.pollEnd else { self.endPolling(); return }
      if doContinue { if UsTime.now.sec > pollEnd { self.endPolling() } }
      else { self.endPolling() }
    }
  }
  
  /// Terminate polling
  public func endPolling() {
    if pollingTimer != nil {
      log("stop active polling")
    }
    self.pollingTimer?.invalidate()
    self.pollEnd = nil
    Defaults.singleton["pollEnd"] = nil
  }

  /// Ask for push token and report it to server
  public func setupRemoteNotifications(force: Bool? = false) {
    let nd = UIApplication.shared.delegate as! AppDelegate
    let dfl = Defaults.singleton
    let oldToken = dfl["pushToken"] ?? Defaults.lastKnownPushToken
    Defaults.lastKnownPushToken = oldToken
    pushToken = oldToken
    nd.onReceivePush { [weak self] (pn, payload, completion) in
      self?.processPushNotification(pn: pn, payload: payload, fetchCompletionHandler: completion)
    }
    nd.permitPush {[weak self] pn in
      guard let self = self else { return }
      if pn.isPermitted { 
        self.debug("Push permission granted") 
        self.pushToken = pn.deviceId
        Defaults.lastKnownPushToken = self.pushToken
      }
      else { 
        self.debug("No push permission") 
        self.pushToken = nil
      }
      dfl["pushToken"] = self.pushToken
     
      //not send request if no change and not force happens eg. on every App Start
      if force == false && oldToken == self.pushToken { return }
      // if force ensure not to send old token if oldToken == newToken
      let oldToken = (force == true && oldToken == self.pushToken) ? nil : oldToken
            
      let isTextNotification = dfl["isTextNotification"]!.bool
      
      self.gqlFeeder.notification(pushToken: self.pushToken, oldToken: oldToken,
                                  isTextNotification: isTextNotification) { [weak self] res in
        if let err = res.error() { self?.error(err) }
        else {
          Defaults.lastKnownPushToken = self?.pushToken
          self?.debug("Updated PushToken")
        }
      }
    }
  }
  
  func processPushNotification(pn: PushNotification, payload: PushNotification.Payload, fetchCompletionHandler: FetchCompletionHandler?){
    log("Processing: \(payload) AppState: \(UIApplication.shared.stateDescription)")
    switch payload.notificationType {
      case .subscription:
        log("check subscription status")
        doPolling(fetchCompletionHandler)
      case .newIssue:
        handleNewIssuePush(fetchCompletionHandler)
      case .textNotificationAlert:
        #warning("may comes in double if real PN!")
        if UIApplication.shared.applicationState == .active {
          LocalNotifications.notify(payload: payload)
        }
        fetchCompletionHandler?(.noData)
      case .textNotificationToast:
        if UIApplication.shared.applicationState == .active,
           let msg = payload.textNotificationMessage {
          Toast.show(msg)
        }
        fetchCompletionHandler?(.noData)
      default:
        fetchCompletionHandler?(.noData)
    }
  }
  
  /// Request authentication from Authenticator
  /// Authenticator will send Const.NotificationNames.authenticationSucceeded Notification if successful
  public func authenticate() {
    authenticator.authenticate(with: nil)
    Notification.receiveOnce(Const.NotificationNames.authenticationSucceeded) {[weak self] _ in
      self?.endPolling()
    }
  }
  
  public func updateAuthIfNeeded() {
    //self.isAuthenticated == false
    if let storedAuth = SimpleAuthenticator.getUserData().token,
       ( self.gqlFeeder.authToken == nil || self.gqlFeeder.authToken != storedAuth )
    {
      self.gqlFeeder.authToken = storedAuth
    }
  }
  
  func updatePublicationDatesIfNeeded(for feed: Feed?){
    guard let storedFeeder = storedFeeder else {
      log("storedFeeder not initialized yet!")
      return
    }
    guard let feed = feed ?? storedFeeder.feeds.first else { return }
    guard let pubDates = storedFeeder.feeds.first?.publicationDates else { return }
    
    let first = pubDates.last?.date.startOfDay == feed.firstIssue.startOfDay
    let last = pubDates.first?.date.startOfDay == feed.lastIssue.startOfDay
    let count = pubDates.count == feed.issueCnt
    
    if first && last && count {
      log("All data matching, no new issue or missing old issue")
      return
    }
    
    let logString = """
        Missing some issues: Match pubDates data == feed data
          firstIssue (\(first)): \(pubDates.last?.date.short ?? "-") == \(feed.firstIssue.short)
          lastIssue (\(last)): \(pubDates.first?.date.short ?? "-") == \(feed.lastIssue.short)
          count (\(count)): \(pubDates.count) == \(feed.issueCnt)
    """
    
    log(logString)
    log("Update all publication Dates")
    
    latestPublicationDate = nil
    checkNetwork()
  }
  
  /// Connect to Feeder and send "feederReady" Notification
  private func connect() {
    gqlFeeder = GqlFeeder(title: name, url: url) { [weak self] res in
      guard let self else { return }
      
      if let feeder = res.value() {
        if let gqlFeeder = feeder as? GqlFeeder,
           gqlFeeder.status?.authInfo.status == .valid
            || gqlFeeder.status?.authInfo.status == .expired
        {
          log("valid auth stop polling if any")
          self.endPolling()
        }
        ///on init storedFeeder not available yet ...on rreconnect probably available
        updatePublicationDatesIfNeeded(for: gqlFeeder.status?.feeds.first)
        if self.simulateFailedMinVersion {
          self.minVersion = Version("135.0.0")
          self.minVersionOK = false
        }
        else { self.minVersionOK = true }
        self.feederStatus(isOnline: true)
      }
      else {
        if let err = res.error() as? FeederError {
          if case .minVersionRequired(let smv) = err {
            self.minVersion = Version(smv)
            self.debug("App Min Version \(smv) failed")
            self.minVersionOK = false
          }
          else { self.minVersionOK = true }
        }
        self.feederStatus(isOnline: false)
      }
    }
    authenticator = DefaultAuthenticator(feeder: gqlFeeder)
  }

  /// openDB opens the Article database and sends a "DBReady" notification  
  private func openDB(name: String) {
    guard ArticleDB.singleton == nil else { return }
    ArticleDB(name: name) { [weak self] _ in
      self?.notify("DBReady") 
    }
  }
  
  /// closeDB closes the Article database
  private func closeDB() {
    if let db = ArticleDB.singleton {
      db.close()
      ArticleDB.singleton = nil
    }
  }
  
  /// resetDB removes the Article database and uses openDB to reopen a new version
  private func resetDB() {
    guard ArticleDB.singleton != nil else { return }
    let name = ArticleDB.singleton.name
    closeDB()
    Defaults.latestPublicationDate = nil
    ArticleDB.dbRemove(name: name)
    openDB(name: name)
  }
    
  /// init sends a "feederReady" Notification when the feeder context has
  /// been set up
  public init?(name: String, url: String, feed feedName: String) {
    guard let host = URL(string: url)?.host else { return nil }
    self.name = name
    self.url = url
    self.feedName = feedName
    self.latestPublicationDate = Defaults.latestPublicationDate
    self.netAvailability = NetAvailability(host: host)
    if self.simulateNewVersion || simulateFailedMinVersion {
      self.bundleID = "de.taz.taz.2"
    }
    if self.simulateNewVersion {
      self.currentVersion = Version("0.5.0")      
    }
    Notification.receive("DBReady") { [weak self] _ in
      self?.debug("DB Ready")
      self?.connect()
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      guard let self else { return }
      if !self.minVersionOK { 
        onMain(after: 1.0) {
          self.log("Exit due to minimal version not met")
          exit(0)
        }
      }
    }
    openDB(name: name)
  }
  
  /// release closes the Database and removes all feeder specific content
  /// if isRemove == true. Also all other resources are released.
  public func release(isRemove: Bool, onRelease: @escaping ()->()) {
    notify("feederRelease")
    onMain(after: 0.5) { [weak self] in
      guard let self else { return }
      let feederDir = self.gqlFeeder?.dir
      self.gqlFeeder?.release()
      self.gqlFeeder = nil
      self.dloader?.release()
      self.dloader = nil
      self.closeDB()
      if let dir = feederDir, isRemove {
        for f in dir.scan() { File(f).remove() }
      }
      onRelease()
    }
  }
  
  private func loadBundledResources(setVersion: Int? = nil) {
    if case let bundledResources = BundledResources(),
            let result = bundledResources.resourcesPayload.value(),
            let res = result["resources"],
            bundledResources.bundledFiles.count > 0 {
      if let v = setVersion { res.resourceVersion = v }
      let success = persistBundledResources(bundledResources: bundledResources,
                                             resData: res)
      if success == true {
        ArticleDB.save()
        log("Bundled Resources version \(res.resourceVersion) successfully loaded")
      }
    }
  }
  
  /// Load resources from server with optional cache directory
  private func loadResources(res: Resources, fromCacheDir: String? = nil) {
    let previous = StoredResources.latest()
    let resources = StoredResources.persist(object: res)
    self.dloader.createDirs()
    var onProgress: ((Int64,Int64)->())? = { (bytesLoaded,totalBytes) in
      self.notify("resourcesProgress", content: (bytesLoaded,totalBytes))
    }
    if fromCacheDir != nil { onProgress = nil }
    resources.isDownloading = true
    self.dloader.downloadPayload(payload: resources.payload as! StoredPayload,
                                 fromCacheDir: fromCacheDir,
                                 onProgress: onProgress) { err in
      resources.isDownloading = false
      if err == nil {
        let source: String = fromCacheDir ?? "server"
        self.debug("Resources version \(resources.resourceVersion) loaded from \(source)")
        self.notify("resourcesReady")
        /// Delete unneeded old resources
        if let prev = previous, prev.resourceVersion < resources.resourceVersion {
          prev.delete()
        }
        ArticleDB.save()
      }
      self.isUpdatingResources = false
    }
  }
  
  /// Downloads resources if necessary
  public func updateResources(toVersion: Int = -1) {
    guard !isUpdatingResources else { return }
    guard let storedFeeder = storedFeeder else {
      log("storedFeeder not initialized yet!")
      return
    }
    isUpdatingResources = true
    let version = (toVersion < 0) ? storedFeeder.resourceVersion : toVersion
    if StoredResources.latest() == nil { loadBundledResources(/*setVersion: 1*/) }
    if let latest = StoredResources.latest() {
      if latest.resourceVersion >= version, latest.isComplete {
        isUpdatingResources = false
        debug("No need to read resources version \(latest.resourceVersion)")
        notify("resourcesReady");
        return
      }
    }
    if !isConnected {
      //Skip Offline Start Deathlock //TODO TEST either notify("resourcesReady"); or:
      isUpdatingResources = false
      noConnection()
      return
    }
    // update from server needed
    gqlFeeder.resources { [weak self] result in
      guard let self = self, let res = result.value() else { return }
      self.loadResources(res: res)
    }
  }
  
  /// persist helper function for updateResources
  /// - Parameters:
  ///   - bundledResources: the resources (with files) to persist
  ///   - resData: the GqlResources data object to persist
  /// - Returns: true if succeed
  private func persistBundledResources(bundledResources: BundledResources,
                                        resData : GqlResources) -> Bool {
    //Use Bundled Resources!
    resData.setPayload(feeder: self.gqlFeeder)
    let resources = StoredResources.persist(object: resData)
    self.dloader.createDirs()
    resources.isDownloading = true
    var success = true
    
    if bundledResources.bundledFiles.count != resData.files.count {
      log("WARNING: Something is Wrong maybe need to download additional Files!")
      success = false
    }
    
    var bundledResourceFiles : [File] = []
    
    for fileUrl in bundledResources.bundledFiles {
      let file = File(fileUrl)
      if file.exists {
        bundledResourceFiles.append(file)
      }
    }
    
    let globalFiles = resources.payload.files.filter {
      $0.storageType != .global
    }
    
    for globalFile in globalFiles {
      let bundledFiles = bundledResourceFiles.filter{ $0.basename == globalFile.name }
      if bundledFiles.count > 1 { log("Warning found multiple matching Files!")}
      guard let bundledFile = bundledFiles.first else {
        log("Warning not found matching File!")
        success = false
        continue
      }
      
      /// File Creation Dates did not Match! bundledFile.mTime != globalFile.moTime
      if bundledFile.exists,
         bundledFile.size == globalFile.size {
        let targetPath = self.gqlFeeder.resourcesDir.path + "/" + globalFile.name
        bundledFile.copy(to: targetPath)
        let destFile = File(targetPath)
        if destFile.exists { destFile.mTime = globalFile.moTime }
        debug("File \(bundledFile.basename) moved... exist in resdir? : \(globalFile.existsIgnoringTime(inDir: self.gqlFeeder.resourcesDir.path))")
      } else {
        log("* Warning: File \(bundledFile.basename) may not exist (\(bundledFile.exists)), mtime, size is wrong  \(bundledFile.size) !=? \(globalFile.size)")
        success = false
      }
    }
    resources.isDownloading = false
    if success == false {
      log("* Warning: There was an error due persisting Bundled Ressources ....delete them.")
      resources.delete()
    }
    return success
  }
  
  func updateSubscriptionStatus(closure: @escaping (Bool)->()) {
    self.gqlFeeder.customerInfo { [weak self] res in
      switch res {
      case .success(let ci):
          Defaults.customerType = ci.customerType
          closure(true)
      case .failure(let err):
          self?.log("cannot get customerInfo: \(err)")
          closure(false)
      }
    }
  }
  
  func clearExpiredAccountFeederError(){
    if currentFeederErrorReason == .expiredAccount(nil) {
      currentFeederErrorReason = nil
    }
  }
  
  var currentFeederErrorReason : FeederError?
  
  /// Feeder has flagged an error
  func handleFeederError(_ err: FeederError, closure: @escaping ()->()) {
    //prevent multiple appeariance of the same alert
    if let curr = currentFeederErrorReason, curr === err {
      ///not refactor and add closures to alert cause in case of later changes/programming errors may
      ///lot of similar closure calls added and may result in other errors e.g. multiple times of calling getOwvIssue...
      log("Closure not added"); return
    }
    debug("handleFeederError for: \(err)")
    currentFeederErrorReason = err
    var text = ""
    switch err {
      case .expiredAccount: text = "Ihr Abonnement ist am \(err.expiredAccountDate?.gDate() ?? "-") abgelaufen.\nSie können bereits heruntergeladene Ausgaben weiterhin lesen.\n\nUm auf weitere Ausgaben zuzugreifen melden Sie sich bitte mit einem aktiven Abo an. Für Fragen zu Ihrem Abonnement kontaktieren Sie bitte unseren Service via: digiabo@taz.de."
        if Defaults.expiredAccountDate != nil {
          closure()
          return //dont show popup on each start
        }
        if Defaults.expiredAccountDate == nil {
          Defaults.expiredAccountDate =  err.expiredAccountDate ?? Date()
        }
        updateSubscriptionStatus { _ in
          self.authenticator.authenticate(with: nil)
        }
        closure()
        return; //Prevent default Popup
      case .invalidAccount: text = "Ihre Kundendaten sind nicht korrekt."
        fallthrough
      case .changedAccount: text = "Ihre Kundendaten haben sich geändert.\n\nSie wurden abgemeldet. Bitte melden Sie sich erneut an!"
        debug("OLD Token: ...\((Defaults.singleton["token"] ?? "").suffix(20)) used: \(Defaults.singleton["token"] == self.gqlFeeder.authToken) 4ses: \(self.gqlFeeder.gqlSession?.authToken == self.gqlFeeder.authToken)")
        
        TazAppEnvironment.sharedInstance.deleteUserData(logoutFromServer: true)
      case .unexpectedResponse:
        Alert.message(title: "Fehler",
                      message: "Es gab ein Problem bei der Kommunikation mit dem Server") {
          exit(0)
        }
      case.minVersionRequired: break
    }
    Alert.message(title: "Fehler", message: text, additionalActions: nil,  closure: { [weak self] in
      ///Do not authenticate here because its not needed here e.g.
      /// expired account due probeabo, user may not want to auth again
      /// additionally it makes more problems currently e.g. Overlay may appear and not disappear
      self?.currentFeederErrorReason = nil
      closure()
    })
  }
  
  
  /// GET IS BULLSHIT DUE IT NOT RETURNS A ISSUE!
  /// - Parameters:
  ///   - feed: feed description
  ///   - count: count description
  public func getStoredOvwIssues(feed: Feed, count: Int = 10){
    let sfs = StoredFeed.get(name: feed.name, inFeeder: storedFeeder)
    if let sf0 = sfs.first {
      let sissues = StoredIssue.issuesInFeed(feed: sf0, count: 10)
      for issue in sissues {
        if issue.isOvwComplete {
          self.notify("issueOverview", result: .success(issue))
        }
      }
    }
  }
  
  public func getLatestStoredIssue() -> StoredIssue? {
    let sfs = StoredFeed.get(name: defaultFeed.name, inFeeder: storedFeeder)
    guard let sf0 = sfs.first else {error("sfs.first not found"); return nil }
    return StoredIssue.issuesInFeed(feed: sf0, count: 1).first
  }
  
  
  /// Get/Download latestIssue requested by PushNotification
  /// - Parameter fetchCompletionHandler: handler to be called on end
  ///
  /// Not using zipped download due if download breaks all received data is gone
  public func handleNewIssuePush(_ fetchCompletionHandler: FetchCompletionHandler?) {
    ///Challange: on receive push usually a download happen and then a newData is needed (no matter if full download or just overviewDownload)
    ///in case of full download the newData send is simple
    ///But how to implement the partialDownloadForNewData?
    ///When is the last issue downloaded? e.g. last App Issue Download 1.1. today 14.1. missing ~10 Issues
    ///some strange things happen due no download still happen but now i have internet and receive the PN in active Mackground Mode
    ///if we send remoteNotificationFetchCompleete newData too early the System killy all Download Processes and wen miss data
    ///if wen send it too late the automatic .failed is told the system
    ///can we check that there are still downloads?
    
    if App.isAvailable(.AUTODOWNLOAD) == false {
      log("Currently not handle new Issue Push\n  Current App State: \(UIApplication.shared.stateDescription)\n  feed: \(self.defaultFeed.name)")
      fetchCompletionHandler?(.noData)
      return
    }
    log("Handle new Issue Push\n  Current App State: \(UIApplication.shared.stateDescription)\n  feed: \(self.defaultFeed.name)")
    
    guard let storedFeeder = storedFeeder,
          let sFeed = StoredFeed.get(name: self.defaultFeed.name, inFeeder: storedFeeder).first else {
      self.error("Expected to have a stored feed, but did not found one.")
      fetchCompletionHandler?(.noData)
      return
    }
    
    Notification.receiveOnce("resourcesReady") { [weak self] err in
      guard let self = self else { return }
      self.gqlFeeder.issues(feed: sFeed,
                            count: 1,
                            isOverview: false,
                            isPages: self.autoloadPdf) { res in
        if let issues = res.value() {//Fetch result got an 'latest' Issue
          guard issues.count == 1 else {
            self.error("Expected to find 1 issue found: \(issues.count)")
            fetchCompletionHandler?(.failed)
            return
          }
          guard let issue = issues.first else { return }
          
          let si = StoredIssue.get(date: issue.date, inFeed: sFeed)
          #warning("did not overwrite existing issue")
          ///in 03/2023 due an server/editorial error the next day issue was published round 3:00 pm, was revoked but server logs said 5-10 People got this issue **HOW TO HANDLE THIS IN FUTURE?**
          ///
          ///
          self.log("got issue from \(issue.date.short) from server with status: \(issue.status) got issue in db with status: \(si.first?.status.localizedDescription ?? "- no Issue in DB -") dbIssue isComplete: \(si.first?.isComplete ?? false)")
          
          
          /* Possible states for both
                case regular = "regular"          /// authenticated Issue access
                case demo    = "demo"             /// demo Issue
                case locked  = "locked"           /// no access
                case reduced = "reduced(public)"  /// available for everybody/incomplete articles
                case unknown = "unknown"          /// decoded from unknown string
          */
          
          var persist = false
          
          ///ensure no full issue (demo/regular) is overwritten with reduced
          if issue.status == .regular {
            self.log("persist server version due its a regular one")//probably overwrite old local one
            persist = true
          }///update with the new one
          else if (si.first?.status == .regular || si.first?.status == .demo) == false {
            self.log("there is no full issue locally so overwrite it with the new one from server")
            persist = true
          }
          
          #warning("got issue from 30.3.2023 from server with status: regular got issue in db with status: regular dbIssue isComplete: false")
          ///Discussion: overwrite regular overview with regular full is ok!
          
          if persist {
            StoredIssue.persist(object: issue)
            ArticleDB.save()
          }
          
          guard let sissue = StoredIssue.issuesInFeed(feed: sFeed,
                                                      count: 1,
                                                      fromDate: issue.date).first else {
            self.error("Expected to find downloaded issue (\(issue.date.short) in db.")
            fetchCompletionHandler?(.failed)
            return
          }
          
          if self.autoloadOnlyInWLAN, self.netAvailability.isMobile {
            self.log("Prevent compleete Download in celluar for: \(sissue.date.short), just load overview")
            LocalNotifications.notifyNewIssue(issue: sissue, feeder: self.gqlFeeder)
            fetchCompletionHandler?(.newData)
            return
          }
          self.log("Download Compleete Issue: \(sissue.date.short)")
          
          self.dloader.createIssueDir(issue: issue)
          Notification.receive("issue"){ notif in
            ///ensure the issue download comes from here!
            guard let downloaded = notif.object as? Issue else { return }
            guard downloaded.date.short == issue.date.short else { return }
            LocalNotifications.notifyNewIssue(issue: sissue, feeder: self.gqlFeeder)
            #warning("KILL SWITCH due 2nd call on receive issue!")
            fetchCompletionHandler?(.newData)//2nd Time Call!
          }
          self.downloadCompleteIssue(issue: sissue, isAutomatically: true)
        }
        else if let err = res.error() as? FeederError {
          self.error("There was an error: \(err)")
          let res: Result<Issue,Error> = .failure(err)
          self.notify("issueOverview", result: res)
          fetchCompletionHandler?(.failed)
        }
        else {
          self.error("Did not found a issue")
          let res: Result<Issue,Error> = .failure(Log.error("Did not found a issue"))
          self.notify("issueOverview", result: res)
          fetchCompletionHandler?(.noData)
        }
      }
    }
    updateResources()
  }
  
  /**
   Get Overview Issues from Feed
   
   If we are online, 'count' Issue overviews are requested from the server.
   Otherwise 'count' Issues from the DB are returned. The returned Issues are always 
   StoredIssues.
   */
  public func getOvwIssues(feed: Feed, count: Int, fromDate: Date? = nil, isAutomatically: Bool) {
    log("feed: \(feed.name) count: \(count) fromDate: \(fromDate?.short ?? "-")")
    guard let storedFeeder = storedFeeder else {
      log("storedFeeder not initialized yet!")
      return
    }
    let sfs = StoredFeed.get(name: feed.name, inFeeder: storedFeeder)
    guard sfs.count > 0 else { return }
    let sfeed = sfs[0]
    let sicount = sfeed.issues?.count ?? 0
    guard sicount < sfeed.issueCnt else { return }
    Notification.receiveOnce("resourcesReady") { [weak self] err in
      guard let self = self else { return }
      if self.isConnected {
        self.gqlFeeder.issues(feed: sfeed, date: fromDate, count: min(count, 20),
                              isOverview: true) { res in
          if let issues = res.value() {
            for issue in issues {
              let si = StoredIssue.get(date: issue.date, inFeed: sfeed)
              if si.count < 1 { StoredIssue.persist(object: issue) }
              //#warning("ToDo 0.9.4+: Missing Update of an stored Issue")
              ///in old app timestamps are compared!
              ///What if Overview new MoTime but compleete Issue is in DB and User is in Issue to read!!
              /// if si.first?.moTime != issue.moTime ...
              /// an update may result in a crash
            }
            ArticleDB.save()
            let sissues = StoredIssue.issuesInFeed(feed: sfeed, count: count, 
                                                   fromDate: fromDate)
            for issue in sissues { self.downloadIssue(issue: issue, isAutomatically: isAutomatically) }
          }
          else {
            if let err = res.error() as? FeederError {
              self.handleFeederError(err) { 
                self.getOvwIssues(feed: feed, count: count, fromDate: fromDate, isAutomatically: isAutomatically)
              }
            }
            else { 
              let res: Result<Issue,Error> = .failure(res.error()!)
              self.notify("issueOverview", result: res)
            }
            return
          }
        }
      }
      else {
        let sissues = StoredIssue.issuesInFeed(feed: sfeed, count: count, 
                                               fromDate: fromDate)
        for issue in sissues {
          if issue.isOvwComplete {
            self.notify("issueOverview", result: .success(issue))
          }
          else {
            self.downloadIssue(issue: issue, isAutomatically: isAutomatically)
          }
        }
      }
    }
    updateResources()
  }

  /// Returns true if the Issue needs to be updated
  public func needsUpdate(issue: Issue) -> Bool {
    guard !issue.isDownloading else { return false }
    
    if issue.isComplete, issue.isReduced, isAuthenticated, !Defaults.expiredAccount {
      issue.isComplete = false
    }
    return !issue.isComplete
  }
  
  
  public func needsUpdate(issue: Issue, toShowPdf: Bool = false) -> Bool {
    var needsUpdate = needsUpdate(issue: issue)
    if needsUpdate == false && toShowPdf == true {
      needsUpdate = !issue.isCompleetePDF(in: gqlFeeder.issueDir(issue: issue))
    }
    return needsUpdate
  }
  
  /**
   Get an Issue from Server or local DB
   
   This method retrieves a complete Issue (ie downloaded Issue with complete structural
   data) from the database. If necessary all files are downloaded from the server.
   */
  public func getCompleteIssue(issue: StoredIssue, isPages: Bool = false, isAutomatically: Bool) {
    self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated) issueDate:  \(issue.date.short)")
    if issue.isDownloading {
      Notification.receiveOnce("issue", from: issue) { [weak self] notif in
        self?.getCompleteIssue(issue: issue, isPages: isPages, isAutomatically: isAutomatically)
      }
      return
    }
    let loadPages = isPages || autoloadPdf
    guard needsUpdate(issue: issue, toShowPdf: loadPages) else {
      Notification.send("issue", result: .success(issue), sender: issue)
      return      
    }
    if self.isConnected {
      gqlFeeder.issues(feed: issue.feed, date: issue.date, count: 1,
                       isPages: loadPages) { res in
        if let issues = res.value(), issues.count == 1 {
          let dissue = issues[0]
          Notification.send("gqlIssue", result: .success(dissue), sender: issue)
          if issue.date != dissue.date {
            self.error("Cannot Update issue \(issue.date.short)/\(issue.isWeekend ? "weekend" : "weekday") with issue \(dissue.date.short)/\(dissue.isWeekend ? "weekend" : "weekday") feeders cycle: \(self.gqlFeeder.feeds.first?.cycle.toString() ?? "-")")
            let unexpectedResult : Result<[Issue], Error>
              = .failure(DownloadError(message: "Weekend Login cannot load weekday issues", handled: true))
            Notification.send("issueStructure", result: unexpectedResult, sender: issue)
            TazAppEnvironment.sharedInstance.resetApp(.wrongCycleDownloadError)
            return
          }
          issue.update(from: dissue)
          ArticleDB.save()
          Notification.send("issueStructure", result: .success(issue), sender: issue)
          self.downloadIssue(issue: issue, isComplete: true, isAutomatically: isAutomatically)
        }
        else if let err = res.error() {
          let errorResult : Result<[Issue], Error>
            = .failure(DownloadError(handled: false, enclosedError: err))
          Notification.send("issueStructure",
                            result: errorResult,
                            sender: issue)
        }
        else {
          //prevent ui deadlock
          let unexpectedResult : Result<[Issue], Error>
            = .failure(DownloadError(message: "Unexpected Behaviour", handled: false))
          Notification.send("issueStructure", result: unexpectedResult, sender: issue)
        }
      }
    }
    else {
      noConnection();
      let res : Result<Any, Error>
        = .failure(DownloadError(message: "no connection", handled: true))
      Notification.send("issueStructure", result: res, sender: issue)
    }
  }
  
  /// Tell server we are starting to download
  func markStartDownload(feed: Feed, issue: Issue, isAutomatically: Bool, closure: @escaping (String?, UsTime)->()) {
    let isPush = pushToken != nil
    debug("Sending start of download to server")
    self.gqlFeeder.startDownload(feed: feed, issue: issue, isPush: isPush, pushToken: self.pushToken, isAutomatically: isAutomatically) { res in
      closure(res.value(), UsTime.now)
    }
  }
  
  /// Tell server we stopped downloading
  func markStopDownload(dlId: String?, tstart: UsTime) {
    if let dlId = dlId {
      let nsec = UsTime.now.timeInterval - tstart.timeInterval
      debug("Sending stop of download to server")
      self.gqlFeeder.stopDownload(dlId: dlId, seconds: nsec){_ in}
    }
  }
  
  func didDownload(_ issue: Issue){
    guard issue.date == self.defaultFeed.lastIssue else { return }
    guard let momentPublicationDate = issue.moment.files.first?.moTime else { return }
    ///momentPublicationDate is in UTC timeIntervalSinceNow calculates also with utc, so timeZone calculation needed!
    //is called multiple times!
    //debug("New Issue:\n  issue Date: \(issue.date)\n  defaultFeed.lastIssue: \(self.defaultFeed.lastIssue)\n  defaultFeed.lastUpdated: \(self.defaultFeed.lastUpdated)\n  defaultFeed.lastIssueRead: \(self.defaultFeed.lastIssueRead)")
    NotificationBusiness
      .sharedInstance
      .showPopupIfNeeded(newIssueAvailableSince: -momentPublicationDate.timeIntervalSinceNow)
    
  }
  
  func cleanupOldIssues(){
    if self.dloader.isDownloading { return }
    guard let feed = self.storedFeeder?.feeds[0] as? StoredFeed else { return }
    let persistedIssuesCount:Int = Defaults.singleton["persistedIssuesCount"]?.int ?? 20
    StoredIssue.removeOldest(feed: feed,
                             keepDownloaded: persistedIssuesCount,
                             deleteOrphanFolders: true)
  }
  
  /// Download partial Payload of Issue
  private func downloadPartialIssue(issue: StoredIssue) {
    self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated) issueDate: \(issue.date.short)")
    self.dloader.downloadPayload(payload: issue.payload as! StoredPayload, atEnd: { [weak self] err in
      var res: Result<StoredIssue,Error>
      if err == nil {
        issue.isOvwComplete = true
        res = .success(issue)
        ArticleDB.save()
        self?.didDownload(issue)
      }
      else { res = .failure(err!) }
      Notification.send("issueOverview", result: res, sender: issue)
    })
  }

  /// Download complete Payload of Issue
  private func downloadCompleteIssue(issue: StoredIssue, isAutomatically: Bool) {
//    enqueuedDownlod.append(issue)
    self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated)")
    markStartDownload(feed: issue.feed, issue: issue, isAutomatically: isAutomatically) { (dlId, tstart) in
      issue.isDownloading = true
      self.dloader.downloadPayload(payload: issue.payload as! StoredPayload, 
        onProgress: { (bytesLoaded,totalBytes) in
          Notification.send("issueProgress", content: (bytesLoaded,totalBytes),
                            sender: issue)
        }) {[weak self] err in
        issue.isDownloading = false
        var res: Result<StoredIssue,Error>
        if err == nil { 
          res = .success(issue) 
          issue.isComplete = true
          ArticleDB.save()
          self?.didDownload(issue)
          //inform DownloadStatusButton: download finished
          Notification.send("issueProgress", content: (1,1), sender: issue)
        }
        else { res = .failure(err!) }
        self?.markStopDownload(dlId: dlId, tstart: tstart)
//        self.enqueuedDownlod.removeAll{ $0.date == issue.date}
        Notification.send("issue", result: res, sender: issue)
      }
    }
  }
  
  /// Download Issue files and resources if necessary
  private func downloadIssue(issue: StoredIssue, isComplete: Bool = false, isAutomatically: Bool) {
    self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated)\(Defaults.expiredAccount ? " Expired!" : "") isComplete: \(isComplete) issueDate: \(issue.date.short)")
    Notification.receiveOnce("resourcesReady") { [weak self] err in
      guard let self = self else { return }
      self.dloader.createIssueDir(issue: issue)
      if self.isConnected { 
        if isComplete { self.downloadCompleteIssue(issue: issue, isAutomatically: isAutomatically) }
        else { self.downloadPartialIssue(issue: issue) }
      }
      else { self.noConnection() }
    }
    updateResources(toVersion: issue.minResourceVersion)
  }

} // FeederContext


extension PushNotification.Payload {
  public var notificationType: NotificationType? {
    get {
      guard let data = self.custom["data"] as? [AnyHashable:Any] else { return nil }
      for case let (key, value) as (String, String) in data {
        if key == "perform" && value == "subscriptionPoll" {
          return NotificationType.subscription
        }
        else if key == "refresh" && value == "aboPoll" {
          return NotificationType.newIssue
        }
        else if key == "type" && value == "alert" {
          return NotificationType.textNotificationAlert
        }
        else if key == "type" && value == "toast" {
          return NotificationType.textNotificationToast
        }
      }
      return nil
    }
  }
  
  public var textNotificationMessage: String? {
    get {
      guard let data = self.custom["data"] as? [AnyHashable:Any] else { return nil }
      debug("found data: \(data)")
      guard data["type"] as? String == "alert" ||
              data["type"] as? String == "toast" else {
        debug("value for data.type is: \(data["type"] ?? "-")")
        return nil
      }
      guard let body = data["body"] as? String else {
        debug("no value for data.body")
        return nil
      }
      debug("data.body is: \(body)")
      return body
    }
  }
}

extension LocalNotifications {
  static let tazAppOfflineListenNotPossibleIdentifier = "tazAppOfflineListenNotPossible"
  static func notifyOfflineListenNotPossible(){
    Self.notify(title: "Sie müssen online sein, um die Vorlesefunktion zu nutzen!",
                              message: "Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.",
                              notificationIdentifier: tazAppOfflineListenNotPossibleIdentifier)
  }
  static func removeOfflineListenNotPossibleNotifications(){
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers:[tazAppOfflineListenNotPossibleIdentifier])
    UNUserNotificationCenter.current()
      .removeDeliveredNotifications(withIdentifiers:[tazAppOfflineListenNotPossibleIdentifier])
  }
}

fileprivate extension LocalNotifications {
  static func notify(payload: PushNotification.Payload){
    guard let message = payload.standard?.alert?.body else {
      Log.debug("no standard payload found, not notify localy")
      return
    }
    Self.notify(title: payload.standard?.alert?.title, message:message)
  }
  
  //Helper to trigger local Notification if App is in Background
  static func notifyNewIssue(issue:StoredIssue, feeder:Feeder){
    var attachmentURL:URL?
    if let filepath = feeder.smallMomentImageName(issue: issue) {
      Log.log("Found Moment Image in: \(filepath)")
      attachmentURL =  URL(fileURLWithPath: filepath)
    }
    else {
      Log.debug("Not Found Moment Image for: \(issue.date)")
    }
    
    var subtitle: String?
    var message = "Jetzt lesen!"
    
    if let firstArticle = issue.sections?.first?.articles?.first,
       let aTitle = firstArticle.title,
       let aTeaser = firstArticle.teaser {
      subtitle = "Lesen Sie heute: \(aTitle)"
      message = aTeaser
    }
    Self.notify(title: "Die taz vom \(issue.date.short) ist verfügbar.",
                subtitle: subtitle,
                message: message,
                badge: UIApplication.shared.applicationIconBadgeNumber + 1,
                attachmentURL: attachmentURL)
    
  }
}


fileprivate extension StoreApp {
  
  ///check if App Update Popup should be shown
  func needUpdate() -> Bool {
    ///ensure store version is higher then running version
    guard self.version > App.version else { return false }
    
    ///ensure store version is the same like the delayed one otherwise delay the store version
    ///to e.g. current version 0.20.0 delayed 0.20.1 has critical bug 0.20.2 is in phased release
    ///ensure not all 0.20.0 users get 0.20.2, they should stay on 0.20.0 for a while
    guard let delayedVersion = Defaults.singleton["newStoreVersion"],
          delayedVersion == self.version.toString() else {
      Defaults.singleton["newStoreVersion"] = self.version.toString()
      Defaults.newStoreVersionFoundDate = Date()
      return false
    }
    
    ///ensure update popup for **NON AUTOMATIC UPDATE USERS only** comes et first after
    /// x days 20 = 60s*60min*24h*20d* = 3600*24*20  ::: Test 2 Minutes == 60*2*
    guard let versionFoundDate = Defaults.newStoreVersionFoundDate,
          abs(versionFoundDate.timeIntervalSinceNow) > 3600*24*20 else {
      return false
    }
    ///update is needed
    return true
  }
}

fileprivate extension Defaults {
  
  ///Helper to persist newStoreVersionFoundDate
  ///no need to reset on reset App, no need to use somewhere else
  static var newStoreVersionFoundDate : Date? {
    get {
      if let curr = Defaults.singleton["newStoreVersionFoundDate"] {
        return Date.fromString(curr)
      }
      return nil
    }
    set {
      if let date = newValue {
        Defaults.singleton["newStoreVersionFoundDate"] = Date.toString(date)
      }
      else {
        Defaults.singleton["newStoreVersionFoundDate"] = nil
      }
    }
  }
}

extension UIAlertAction {
  static func developerPushActions(callback: @escaping (Bool) -> ()?) -> [UIAlertAction] {
    let newIssue:UIAlertAction = UIAlertAction(title: "Simulator: NewIssuePush",
                                                 style: .default){_ in
      let payload:[AnyHashable : Any] = [
        "aps":[
          "content-available" : 1,
          "sound": nil],
        "data":[
          "refresh": "aboPoll"
        ]
      ]
      TazAppEnvironment.sharedInstance.feederContext?.processPushNotification(pn: PushNotification(),
                                                                              payload: PushNotification.Payload(payload),
                                                                              fetchCompletionHandler: nil)
      callback(false)
    }

    let textPushAlert:UIAlertAction = UIAlertAction(title: "Simulator: TextPush Alert",
                                                    style: .default){_ in
      let payload:[AnyHashable : Any] = [
        "aps":[
          "alert":[
            "title": "2 Test",
            "body": "Hallo dies ist ein zweiter Test"],
          "sound": "default"],
        "data":[
          "type": "alert",
          "title": " ",
          "body": "<h1>Testüberschrift</h1><h2>Subhead</h2><p><b>Hallo</b> <i>dies <del>ist</del> ein <mark>zweiter</mark></i><br/><u>Test!</u></p>\n"
        ]
      ]
      TazAppEnvironment.sharedInstance.feederContext?.processPushNotification(pn: PushNotification(),
                                                                              payload: PushNotification.Payload(payload),
                                                                              fetchCompletionHandler: nil)
      callback(false)
    }

    let textPushToast:UIAlertAction = UIAlertAction(title: "Simulator: TextPush Toast",
                                                    style: .default){_ in
      let payload:[AnyHashable : Any] = [
        "aps":[
          "alert":[
            "title": "2 Test",
            "body": "Hallo dies ist ein zweiter Test"],
          "sound": "default"],
        "data":[
          "type": "toast",
          "title": " ",
          "body": "<h1>Testüberschrift</h1><h2>Subhead</h2><p><b>Hallo</b> <i>dies <del>ist</del> ein <mark>zweiter</mark></i><br/><u>Test!</u></p>\n"
        ]
      ]
      TazAppEnvironment.sharedInstance.feederContext?.processPushNotification(pn: PushNotification(),
                                                                              payload: PushNotification.Payload(payload),
                                                                              fetchCompletionHandler: nil)
      callback(false)
    }

    return [newIssue, textPushAlert, textPushToast]
  }
}

