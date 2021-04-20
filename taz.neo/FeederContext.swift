//
//  FeederContext.swift
//
//  Created by Norbert Thies on 17.06.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
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
  public var storedFeeder: StoredFeeder!
  /// The default Feed to show
  public var defaultFeed: StoredFeed!
  /// The Downloader to use 
  public var dloader: Downloader!
  /// netAvailability is used to check for network access to the Feeder
  public var netAvailability: NetAvailability
  @DefaultBool(key: "useMobile")
  public var useMobile: Bool
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
    return isCon
  }
  /// Has the Feeder been initialized yet
  public var isReady = false
  
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
  
  /// Feeder is now reachable
  private func feederReachable(feeder: Feeder) {
    self.debug("Feeder now reachable")
    self.dloader = Downloader(feeder: feeder as! GqlFeeder)
    notify("feederReachable")    
  }
  
  /// Feeder is not reachable
  private func feederUnreachable() {
    self.debug("Feeder now unreachable")
    notify("feederUneachable")
  }
  
  /// Network status has changed 
  private func checkNetwork() {
    if isConnected {
      self.gqlFeeder = GqlFeeder(title: name, url: url) { [weak self] res in
        guard let self = self else { return }
        if let feeder = res.value() {
          if let gqlFeeder = feeder as? GqlFeeder,
             let storedAuth = SimpleAuthenticator.getUserData().token {
            gqlFeeder.authToken = storedAuth
          }
          self.feederReachable(feeder: feeder)
        }
        else { self.feederUnreachable() }
      }
    }
    else { self.feederUnreachable() }
  }
  
  /// Feeder is initialized, set up other objects
  private func feederReady() {
    self.dloader = Downloader(feeder: gqlFeeder)
    netAvailability.onChange { [weak self] _ in self?.checkNetwork() }
    defaultFeed = StoredFeed.get(name: feedName, inFeeder: storedFeeder)[0]
    isReady = true
    notify("feederReady")            
  }
  
  /// React to the feeder being online or not
  private func feederStatus(isOnline: Bool) {
    if isOnline {
      self.storedFeeder = StoredFeeder.persist(object: self.gqlFeeder)
      feederReady()
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
        self.noConnection(to: name, isExit: true) { exit(0) }
      }
    }
  }
  
  private var pollingTimer: Timer?
  private var pollEnd: Int64?
  
  /// Start Polling if necessary
  public func setupPolling() {
    authenticator.whenPollingRequired { self.startPolling() }
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
  
  /// Method called by Authenticator to start polling timer
  private func startPolling() {
    self.pollEnd = UsTime.now().sec + PollTimeout
    Defaults.singleton["pollEnd"] = "\(pollEnd!)"
    self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, 
      repeats: true) { _ in self.doPolling() }
  }
  
  /// Ask Authenticator to poll server for authentication,
  /// send 
  private func doPolling() {
    authenticator.pollSubscription { [weak self] doContinue in
      guard let self = self else { return }
      guard let pollEnd = self.pollEnd else { self.endPolling(); return }
      if doContinue { if UsTime.now().sec > pollEnd { self.endPolling() } }
      else { self.endPolling() }
    }
  }
  
  /// Terminate polling
  public func endPolling() {
    self.pollingTimer?.invalidate()
    self.pollEnd = nil
    Defaults.singleton["pollEnd"] = nil
  }

  /// Ask for push token and report it to server
  public func setupRemoteNotifications() {
    let nd = UIApplication.shared.delegate as! AppDelegate
    let dfl = Defaults.singleton
    let oldToken = dfl["pushToken"]
    pushToken = oldToken
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
  
  /// Request authentication from Authenticator
  /// Authenticator will send "authenticationSucceeded" Notification if successful
  public func authenticate() {
    authenticator.authenticate()
  }
  
  /// Connect to Feeder and send "feederReady" Notification
  private func connect() {
    gqlFeeder = GqlFeeder(title: name, url: url) { [weak self] res in
      let feeder = res.value()
      self?.feederStatus(isOnline: feeder != nil)
    }
    authenticator = DefaultAuthenticator(feeder: gqlFeeder)
  }

  /// openDB opens the Article database and sends a "DBReady" notification  
  private func openDB(name: String) {
    guard ArticleDB.singleton == nil else { return }
    ArticleDB(name: name) { [weak self] _ in self?.notify("DBReady") }  
  }
  
  /// resetDB removes the Article database and uses openDB to reopen a new version
  private func resetDB() {
    guard ArticleDB.singleton != nil else { return }
    let name = ArticleDB.singleton.name
    ArticleDB.dbRemove(name: name)
    ArticleDB.singleton = nil
    openDB(name: name)
  }
  
  /// init sends a "feederReady" Notification when the feeder context has
  /// been set up
  public init?(name: String, url: String, feed feedName: String) {
    guard let host = URL(string: url)?.host else { return nil }
    self.name = name
    self.url = url
    self.feedName = feedName
    self.netAvailability = NetAvailability(host: host)
    Notification.receive("DBReady") { [weak self] _ in
      self?.debug("DB Ready")
      self?.connect()
    }
    openDB(name: name)
  }
  
  /// Downloads resources if necessary
  public func updateResources(toVersion: Int = -1) {
    let version = (toVersion < 0) ? storedFeeder.resourceVersion : toVersion
    let latestResources = StoredResources.latest()
    if let latest = latestResources {
      if latest.isDownloading { return } 
      if (latest.resourceVersion >= version && latest.isComplete) || !isConnected { 
        notify("resourcesReady"); return
      }
    }
    else if case let bundledResources = BundledResources(),
            let result = bundledResources.ressourcesPayload.value(),
            let res = result["product"],
            res.resourceVersion == version,
            bundledResources.bundledFiles.count > 0 {
      //Use Bundled Resources!
      res.setPayload(feeder: self.gqlFeeder)
      let resources = StoredResources.persist(object: res)
      self.dloader.createDirs()
      resources.isDownloading = true //Why???
      
      var success = true
      
      if bundledResources.bundledFiles.count != res.files.count {
        log("WARNING: Something is Wrong maybe need to download additional Files!")
        success = false
      }
      
      var bundledRessourceFiles : [File] = []
      
      for fileUrl in bundledResources.bundledFiles {
        let file = File(fileUrl)
        if file.exists {
          bundledRessourceFiles.append(file)
        }
      }
      
      let globalFiles = resources.payload.files.filter {
        $0.storageType != .global
      }
      
      for globalFile in globalFiles {
        let bundledFiles = bundledRessourceFiles.filter{ $0.basename == globalFile.name }
        if bundledFiles.count > 1 { log("Warning found multiple matching Files!")}
        guard let bundledFile = bundledFiles.first else {
          log("Warning not found matching File!")
          success = false
          continue
        }
        
        /// File Creation Dates did not Match! bundledFile.mTime != globalFile.moTime
        if bundledFile.exists,
           bundledFile.size == globalFile.size {
          bundledFile.copy(to: self.gqlFeeder.resourcesDir.path + "/" + globalFile.name)
          log("File \(bundledFile.basename) moved... exist in resdir? : \(globalFile.existsIgnoringTime(inDir: self.gqlFeeder.resourcesDir.path))")
        } else {
          log("* Warning: File \(bundledFile.basename) may not exist (\(bundledFile.exists)), mtime, size is wrong  \(bundledFile.size) !=? \(globalFile.size)")
          success = false
        }
      }
      if success == true {
        resources.isDownloading = false
        ArticleDB.save()
        log("Bundled Ressources successful Loaded")
        self.notify("resourcesReady")
        return
      } else {
        resources.delete()
      }
      //no need to download additional stuff
    }
            
      
    // update from server needed
    guard isConnected else { 
      noConnection()
      return
    }
    gqlFeeder.resources { [weak self] result in
      guard let self = self, let res = result.value() else { return }
      let previous = latestResources
      let resources = StoredResources.persist(object: res)
      self.dloader.createDirs()
      resources.isDownloading = true
      self.dloader.downloadPayload(payload: resources.payload as! StoredPayload, 
        onProgress: { (bytesLoaded,totalBytes) in
          self.notify("resourcesProgress", content: (bytesLoaded,totalBytes))
        }) { err in
        resources.isDownloading = false
        if err == nil {
          self.notify("resourcesReady")
          /// Delete unneeded old resources
          if let prev = previous, prev.resourceVersion < version { prev.delete() }
        }
      }
    }
  }
  
  /// Feeder has flagged an error
  func handleFeederError(_ err: FeederError, closure: @escaping ()->()) {
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
    DefaultAuthenticator.deleteUserData()
    Alert.message(title: "Fehler", message: text) { self.authenticate() }
  }
  
  /**
   Get Overview Issues from Feed
   
   If we are online, 'count' Issue overviews are requested from the server.
   Otherwise 'count' Issues from the DB are returned. The returned Issues are always 
   StoredIssues.
   */
  public func getOvwIssues(feed: Feed, count: Int, fromDate: Date? = nil) {
    let sfs = StoredFeed.get(name: feed.name, inFeeder: storedFeeder)
    guard sfs.count > 0 else { return }
    let sfeed = sfs[0]
    Notification.receiveOnce("resourcesReady") { [weak self] err in
      guard let self = self else { return }
      if self.isConnected {
        self.gqlFeeder.issues(feed: sfeed, date: fromDate, count: max(count, 20), 
                              isOverview: true, isPages: true) { res in
          if let issues = res.value() {
            for issue in issues {
              let si = StoredIssue.get(date: issue.date, inFeed: sfeed)
              if si.count < 1 { StoredIssue.persist(object: issue) }
            }
            ArticleDB.save()
            let sissues = StoredIssue.issuesInFeed(feed: sfeed, count: count, 
                                                   fromDate: fromDate)
            for issue in sissues { self.downloadIssue(issue: issue) }
          }
          else {
            if let err = res.error() as? FeederError {
              self.handleFeederError(err) { 
                self.getOvwIssues(feed: feed, count: count, fromDate: fromDate)
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
            self.downloadIssue(issue: issue)
          }
        }
      }
    }
    updateResources()
  }
  
  /// checkForNewIssues requests new overview issues from the server if
  /// more than 12 hours have passed since the latest stored issue
  public func checkForNewIssues(feed: Feed) {
    let sfs = StoredFeed.get(name: feed.name, inFeeder: storedFeeder)
    guard sfs.count > 0 else { return }
    let sfeed = sfs[0]
    if let latest = StoredIssue.latest(feed: sfeed), self.isConnected {
      let now = UsTime.now()
      let latestLoaded = UsTime(latest.date)
      let nHours = (now.sec - latestLoaded.sec) / 3600
      if nHours > 6 {
        let ndays = (now.sec - latestLoaded.sec) / (3600*24) + 1
        getOvwIssues(feed: feed, count: Int(ndays))
      }
    }
  }

  /// Returns true if the Issue needs to be updated
  public func needsUpdate(issue: StoredIssue) -> Bool {
    guard !issue.isDownloading else { return false }
    if issue.isComplete { 
      if issue.isReduced && isAuthenticated { issue.isComplete = false }
      return issue.isReduced
    }
    else { return true }
  }
  
  /**
   Get an Issue from Server or local DB
   
   This method retrieves a complete Issue (ie downloaded Issue with complete structural
   data) from the database. If necessary all files are downloaded from the server.
   */
  public func getCompleteIssue(issue: StoredIssue, isPages: Bool = false) {
    if issue.isDownloading {
      Notification.receiveOnce("issue", from: issue) { [weak self] notif in
        self?.getCompleteIssue(issue: issue)
      }
    }
    guard needsUpdate(issue: issue) else {
      Notification.send("issue", result: .success(issue), sender: issue)
      return      
    }
    if self.isConnected {
      gqlFeeder.issues(feed: issue.feed, date: issue.date, count: 1,
                       isPages: isPages) { res in
        if let issues = res.value(), issues.count == 1 {
          let dissue = issues[0]
          Notification.send("gqlIssue", result: .success(dissue), sender: issue)
          issue.update(from: dissue)
          ArticleDB.save()
          Notification.send("issueStructure", result: .success(issue), sender: issue)
          self.downloadIssue(issue: issue, isComplete: true)
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
  func markStartDownload(feed: Feed, issue: Issue, closure: @escaping (String?, UsTime)->()) {
    let isPush = pushToken != nil
    debug("Sending start of download to server")
    self.gqlFeeder.startDownload(feed: feed, issue: issue, isPush: isPush) { res in
      closure(res.value(), UsTime.now())
    }
  }
  
  /// Tell server we stopped downloading
  func markStopDownload(dlId: String?, tstart: UsTime) {
    if let dlId = dlId {
      let nsec = UsTime.now().timeInterval - tstart.timeInterval
      debug("Sending stop of download to server")
      self.gqlFeeder.stopDownload(dlId: dlId, seconds: nsec) {_ in}
    }
  }
  
  /// Download partial Payload of Issue
  private func downloadPartialIssue(issue: StoredIssue) {
    self.dloader.downloadPayload(payload: issue.payload as! StoredPayload) { err in
      var res: Result<StoredIssue,Error>
      if err == nil {
        issue.isOvwComplete = true
        res = .success(issue) 
        ArticleDB.save()
      }
      else { res = .failure(err!) }
      Notification.send("issueOverview", result: res, sender: issue)
    }
  }

  /// Download complete Payload of Issue
  private func downloadCompleteIssue(issue: StoredIssue) {
    markStartDownload(feed: issue.feed, issue: issue) { (dlId, tstart) in
      issue.isDownloading = true
      self.dloader.downloadPayload(payload: issue.payload as! StoredPayload, 
        onProgress: { (bytesLoaded,totalBytes) in
          Notification.send("issueProgress", content: (bytesLoaded,totalBytes),
                            sender: issue)
        }) { err in
        issue.isDownloading = false
        var res: Result<StoredIssue,Error>
        if err == nil { 
          res = .success(issue) 
          issue.isComplete = true
          ArticleDB.save()
        }
        else { res = .failure(err!) }
        self.markStopDownload(dlId: dlId, tstart: tstart)
        Notification.send("issue", result: res, sender: issue)
      }
    }
  }
  
  /// Download Issue files and resources if necessary
  private func downloadIssue(issue: StoredIssue, isComplete: Bool = false) {
    Notification.receiveOnce("resourcesReady") { [weak self] err in
      guard let self = self else { return }
      self.dloader.createIssueDir(issue: issue)
      if self.isConnected { 
        if isComplete { self.downloadCompleteIssue(issue: issue) }
        else { self.downloadPartialIssue(issue: issue) }
      }
      else { self.noConnection() }
    }
    updateResources(toVersion: issue.minResourceVersion)
  }

} // FeederContext
