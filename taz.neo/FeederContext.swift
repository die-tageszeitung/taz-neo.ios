//
//  FeederContext.swift
//
//  Created by Norbert Thies on 17.06.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/**
 - GqlFeeder => Downloader
    - Start Download after offline start then online
 - online start use Stored...(if any) then connect
 
 Fehler
 - REGRESSION new installation recheck, mehrfaches update des Feeders 1 reicht
 - DONE kein Onboarding wird angezeigt
 - nicht verbunden verschwindet nicht: offline start, online download, login, karussell!
 - erster Start nach langer Zeit aktuelle Ausgabe wird nicht angezeigt erst nach pull to Refresh
  - nach Pull to Refresh verschwindet Lade Vorschau nicht
 
 Check
 - update publicationDates
 - verhalten, bei App Resume etc nach mehreren Stunden!, früher wurde der GqlFeeder+Downloader häufig neu instanziert, jetzt nicht!
 - version checks
 - update set auth
      * on login
      * setup poll/push
 
 */


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
  public var gqlFeeder: GqlFeeder!{
    didSet {
      guard gqlFeeder != nil else { return }///required currently on reset
      self.dloader = Downloader(feeder: gqlFeeder)
      if authenticator == nil {
        authenticator = DefaultAuthenticator(feeder: gqlFeeder)
      } else {
        authenticator.feeder = gqlFeeder
      }
    }
  }
  /// The stored Feeder (from DB)
  public private(set) var storedFeeder: StoredFeeder! {
    didSet {
      if self.gqlFeeder == nil {
        self.gqlFeeder = GqlFeeder(title: name,
                                   url: url,
                                   token: DefaultAuthenticator.token)
        updateFeeder()
      }
      
      guard storedFeeder != nil else { return }
      /// used due  a chicken or the egg causality dilemma
      /// if i start online no db is on startup available to read the data, but we dont want to load all dates if just a few are needed
      /// other challenges: initial start, migration from 0.9.x, online/offline start, switch daily/weekly
      /// ...actually FeederContext needs a big refactoring mybe with a bundled initial issue
      /// to get rid of all the patches
      if oldValue == nil {
        checkAppUpdate()
        updatePublicationDatesIfNeeded(for: nil)
        cleanupOldIssues()
        defaultFeed = storedFeeder.feeds.first as? StoredFeed
        //Alternative:
        //defaultFeed = StoredFeed.get(name: feedName, inFeeder: storedFeeder).first
        notify("feederReady")
        return
      }
      
      if oldValue?.feeds.first?.publicationDates?.count
      != self.storedFeeder?.feeds.first?.publicationDates?.count {
        Notification.send(Const.NotificationNames.publicationDatesChanged)
      }
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
  
  var pollingTimer: Timer?
  var pollEnd: Int64?
  
  ///Helper to handle Network changes
  private(set) var netAvailability: ExtendedNetAvailability
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
  
  var latestPublicationDate:Date? {
    guard defaultFeed != nil else { return nil }
    return defaultFeed.lastIssue
  }
  ///Shortcut
  var isConnected: Bool { netAvailability.isConnected }
  
  /// Has minVersion been met?
  public var minVersionOK = true
  
  /// Bundle ID to use for App store retrieval
  public var bundleID = App.bundleIdentifier
  
  /// Overwrite for current App version
  public var currentVersion = App.version
  
  /// Server required minimal App version
  public var minVersion: Version?
  
  /// Are we updating resources
  var isUpdatingResources = false
  
  /// Are we authenticated with the server?
  public var isAuthenticated: Bool { gqlFeeder.isAuthenticated }

  /// Do we need reinitialization?
  func needsReInit() -> Bool {
    if let storedFeeder = self.storedFeeder,
       let sfeed = storedFeeder.feeds.first,
       let gfeed = gqlFeeder.feeds.first {
      return !(sfeed.cycle == gfeed.cycle)
    }
    return false
  }
  
  private func updateFeeder(){
    if gqlFeeder.isUpdating { return }
    gqlFeeder.updateStatus {[weak self] res in
      guard let self = self else { return }
      switch res {
        case .success:
          self.storedFeeder = StoredFeeder.persist(object: self.gqlFeeder)
          if self.netAvailability.wasConnected == false {
            self.netAvailability.recheck()
          }
        case .failure:
          if self.storedFeeder == nil {
            OfflineAlert.show(type: .initial){[weak self] in
              self?.netAvailability.recheck()
              self?.updateFeeder()
            }
          } else if self.netAvailability.wasConnected {
            self.netAvailability.recheck()
            self.notifyNetStatusChanged(isConnected: false)
          }
      }
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
  }
  
  private func netStatusChanged(isConnected:Bool){
    isConnected ? updateFeeder() : notifyNetStatusChanged(isConnected: false)
  }
  
  private func notifyNetStatusChanged(isConnected:Bool){
    if isConnected {
      self.debug("Feeder now reachable")
      notify(Const.NotificationNames.feederReachable)
    }
    else {
      self.debug("Feeder now unreachable")
      notify(Const.NotificationNames.feederUnreachable)
    }
  }

  /// openDB opens the Article database and sends a "DBReady" notification  
  private func openDB(name: String) {
    guard ArticleDB.singleton == nil else { return }
    ArticleDB(name: name) { [weak self] _ in
      guard let self = self else { return }
      self.storedFeeder = StoredFeeder.get(name: self.name).first
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
    //#warning("REMOVE THE FOLLOWING LINE!!! just for Debugging DB is Days -2")
    self.netAvailability = ExtendedNetAvailability(url: url)
    
    self.netAvailability.onChange{[weak self] connected in self?.netStatusChanged(isConnected:connected)
    }
      
    if self.simulateNewVersion || simulateFailedMinVersion {
      self.bundleID = "de.taz.taz.2"
    }
    if self.simulateNewVersion {
      self.currentVersion = Version("0.5.0")      
    }
    ///Bad Code?
    ///force update from API User clicks update, update not started e.g. due not Internet, user wants to read taz app app crashes without a notification!
    ///Crash or not? => Not to crash NEVER! @see: https://developer.apple.com/forums/thread/63795
    ///So Refactor: Alert User only Button is the Store Button (is still bad behaviour, hopefully never needed)
    #warning("todo change")
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
  
  var currentFeederErrorReason : FeederError?
  
  func clearExpiredAccountFeederError(){
    if currentFeederErrorReason == .expiredAccount(nil) {
      currentFeederErrorReason = nil
    }
  }
  
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
  
  func cleanupOldIssues(){
    if self.dloader.isDownloading { return }
    guard let feed = self.storedFeeder?.feeds[0] as? StoredFeed else { return }
    let persistedIssuesCount:Int = Defaults.singleton["persistedIssuesCount"]?.int ?? 20
    StoredIssue.removeOldest(feed: feed,
                             keepDownloaded: persistedIssuesCount,
                             deleteOrphanFolders: true)
  }
} // FeederContext
