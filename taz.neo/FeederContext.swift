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
 
 TODO:
 - handle fetch new issue header for issuecarousell
 - **DO:**test migration from 0.9.x store
 - test new issue push
 
 
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
         openedIssue.date.issueKey == getLatestStoredIssue()?.date.issueKey {
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
  public private(set) var storedFeeder: StoredFeeder!
  
  /// The default Feed to show
  public var defaultFeed: StoredFeed! {
    didSet { if let feed = defaultFeed { BackgroundDownloadService.shared.updateFeed(feed)}}
  }
  
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
  
  func stopDownloadsAndResetDownloader(){
    guard let gqlFeeder else { return }
    self.dloader = Downloader(feeder: gqlFeeder)
  }
  
  var pollingTimer: Timer?
  var pollEnd: Int64?
  var updateAlert: AlertController?
  
  ///Helper to handle Network changes
  private(set) var netAvailability: ExtendedNetAvailability
  
  @Default("autoloadOnlyInWLAN2")
  var autoloadOnlyInWLAN: Bool
  
  @Default("autoloadPdf")
  var autoloadPdf: Bool
  
  @Default("autoloadNewIssues")
  var autoloadNewIssues: Bool
  
  @Default("simulateFailedMinVersion")
  var simulateFailedMinVersion: Bool
  
  @Default("simulateNewVersion")
  var simulateNewVersion: Bool
  
  ///empty if none
  @Key("lastAppPreviewVersion")
  var lastAppPreviewVersion: String
  
  @Default("specialArticleSystemSetting")
  var specialArticleSystemSetting: Bool
  
  var latestPublicationDate:Date? {
    guard defaultFeed != nil else { return nil }
    return defaultFeed.lastIssue
  }
  ///Shortcut
  var isConnected: Bool { netAvailability.isConnected }
  
  /// Has minVersion been met?
  public var minVersionOK = true {
    didSet {
      if minVersionOK == false { enforceUpdate() }
    }
  }
  
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
  
  //CHALLANGE
  /// init - update just call update once even if initial init
  private func initFeeder(){
    if self.gqlFeeder == nil {
      self.gqlFeeder = GqlFeeder(title: name,
                                 url: url,
                                 token: DefaultAuthenticator.token)
    }
    
    let needUpdate = self.storedFeeder == nil
    
    if needUpdate {
      self.storedFeeder = StoredFeeder.get(name: self.name).first
    }

    ///Handle initial App Start
    if storedFeeder == nil {
      if netAvailability.isConnected == false {
        OfflineAlert.show(type: .initial){[weak self] in
          self?.netAvailability.recheck()
          self?.initFeeder()
        }
        ///No feeder update possible if offline
        return
      }
      log("No stored Feeder found, update Feeder caLLED FROM INIT")
      updateFeeder()
      return
    }
    
    let loadAll = needLoadAllPublicationDates()
    defaultFeed = StoredFeed.get(name: feedName, inFeeder: storedFeeder).first
    //Alternative: defaultFeed = storedFeeder.feeds.first as? StoredFeed
    notify("feederReady")
    cleanupOldIssues(deleteOlder: true)//requires inited bookmarks
    checkAppUpdate()
    if needUpdate {
      updateFeeder(loadAllPublicationDates: loadAll)
    }
    onMainAfter(2.0){[weak self] in  self?.handleUnfinshedDownloads() }
  }
  
  func checkForNewIssues(force: Bool = false){
    log("checkForNewIssues force: \(force) url: \(netAvailability.url)")
    if force || netAvailability.isConnected == false {
      netAvailability.recheck(force: force)
//      Notification.send(Const.NotificationNames.checkForNewIssues,
//                        content: FetchNewStatusHeader.status.offline,
//                        error: nil,
//                        sender: self)
      self.notifyNetStatus(isConnected: netAvailability.isConnected)
    }
    else {
        updateFeeder()
    }
  }
#warning("maybe do not use this in BG Download Stuff!!!")
  private func updateFeeder(loadAllPublicationDates:Bool = false){
    if loadAllPublicationDates == false && gqlFeeder.isUpdating {
      debug("...updateFeeder called BUT CANCELED, loadAllPublicationDates: \(loadAllPublicationDates) isUpdating: \(gqlFeeder.isUpdating)")
      return
    }
    
    if gqlFeeder.gqlSession?.isBackground == true {
      log("########################### W A R N I N G #######################")
      log("got a bg SESSION!?")
      log("########################### W A R N I N G #######################")
    }
    
    
    log("...updateFeeder called, loadAllPublicationDates: \(loadAllPublicationDates) is backgroundFeeder? \(gqlFeeder.gqlSession?.isBackground)")
    Notification.send(Const.NotificationNames.checkForNewIssues,
                      content: FetchNewStatusHeader.status.fetchNewIssues,
                      error: nil,
                      sender: self)
    gqlFeeder.updateStatus(loadAllPublicationDates: loadAllPublicationDates) {
      [weak self] res in
      guard let self = self else { return }
      let needInit = self.storedFeeder == nil
      switch res {
        ///no need to eval res.value due its updated:  self!.gqlFeeder === res.value()
        case .success:
          let initialCall = self.storedFeeder == nil
          ///remember old data due on set storedFeeder  old reference is overwritten
          let publicationDatesChanged
          = self.storedFeeder != nil
          && self.gqlFeeder?.feeds.first?.publicationDates?.count != 1
          && self.storedFeeder.feeds.first?.publicationDates?.count
          != self.gqlFeeder?.feeds.first?.publicationDates?.count
          self.storedFeeder = StoredFeeder.persist(object: self.gqlFeeder)
          if publicationDatesChanged {
            ArticleDB.save()
            log("...publication dates changed, inform UI (if not in background mode)")
            Notification.send(Const.NotificationNames.publicationDatesChanged)
            BackgroundDownloadService
              .downloadNewIssueOnAppForeground(caller: "Feeder Context Update Status: publicationDatesChanged")
          } else {
            debug("...publication dates NOT changed")///4345 Issues
          }
          self.notifyNetStatus(isConnected: true)
          if initialCall, isAuthenticated {///initial app start is quite slow, but this is not the reason; checked 25-06-20 on iPad Air2
            BackgroundDownloadService.downloadNewIssueOnAppForeground(caller: "Initially download latestIssue", delay: 5.0)
          }
          
        case .failure:
          if let err = res.error() as? FeederError {
            if case .minVersionRequired(let smv) = err {
              self.minVersion = Version(smv)
              self.debug("App Min Version \(smv) failed")
              self.minVersionOK = false
            }
            else { self.minVersionOK = true }
          }
          self.notifyNetStatus(isConnected: false)
      }
      if needInit { initFeeder() }
    }
  }
  
  /// Request authentication from Authenticator
  /// Authenticator will send Const.NotificationNames.authenticationSucceeded Notification if successful
  public func authenticate(with targetVC:UIViewController? = nil) {
    authenticator.authenticate(with: targetVC)
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
  
  func needLoadAllPublicationDates() -> Bool{
    guard let storedFeeder = storedFeeder else {
      log("storedFeeder not initialized yet!")
      return true
    }
    guard let feed = storedFeeder.feeds.first else {
      log("No Stored Feed => load all Publication Dates... for feed: \(storedFeeder.feeds.first?.name ?? "-")")
      return true
    }
    guard let pubDates = storedFeeder.feeds.first?.publicationDates else {
      log("No Publication Dates => load all Publication Dates... for feed: \(storedFeeder.feeds.first?.name ?? "-")")
      return true
    }
    
    let first = pubDates.last?.date.ISO8601 ?? "1980-01-01" == feed.firstIssue.ISO8601
    let last = pubDates.first?.date.ISO8601 ?? "1980-01-01" >= feed.lastIssue.ISO8601
    let count = pubDates.count >= feed.issueCnt
    
    if first && last && count {
      log("All data matching, no new issue or missing old issue")
      return false
    }
    
    if pubDates.count != feed.issueCnt {
      // TODO: Keep an eye on this — shouldn't cause issues.
      log("⚠️ WARNING ⚠️")
    }
    
    let logString = """
        Missing some issues: Match pubDates data == feed data
          firstIssue (\(first)): \(pubDates.last?.date.short ?? "-") == \(feed.firstIssue.short)
          lastIssue (\(last)): \(pubDates.first?.date.short ?? "-") == \(feed.lastIssue.short)
          count (\(count)): \(pubDates.count) == \(feed.issueCnt)
    """
    
    log(logString)
    log("Update all publication Dates")
    return true
  }
  
  private func netStatusChanged(isConnected:Bool){
    log("NET STATUS CHANGED isConnected: \(isConnected)")
    if isConnected,
       BackgroundDownloadService.shared.executeScheduledCheckIfNeeded() == false {
      updateFeeder()
    }
    notifyNetStatus(isConnected: isConnected)
  }
  
  private func notifyNetStatus(isConnected:Bool){
    if isConnected {
      self.debug("Feeder now reachable")
      notify(Const.NotificationNames.feederReachable)
    }
    else {
      self.debug("Feeder now unreachable")
      notify(Const.NotificationNames.feederUnreachable)
    }
    
    if self.netAvailability.wasConnected != isConnected {
      self.netAvailability.recheck()
    }
  }

  /// openDB opens the Article database and sends a "DBReady" notification  
  private func openDB(name: String) {
    guard ArticleDB.singleton == nil else { return }
    ArticleDB(name: name) { [weak self] _ in
      self?.initFeeder()
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
  /// NOT USED CURRENTLY SO DISABLED!
//  private func resetDB() {
//    guard ArticleDB.singleton != nil else { return }
//    let name = ArticleDB.singleton.name
//    closeDB()
//    ArticleDB.dbRemove(name: name)
//    openDB(name: name)
//  }
    
  /// init sends a "feederReady" Notification when the feeder context has
  /// been set up
  public init?(name: String, url: String, feed feedName: String) {
    if URL(string: url)?.host == nil { return nil }
    self.name = name
    self.url = url
    self.feedName = feedName
    self.netAvailability = ExtendedNetAvailability(url: url)
    
    self.netAvailability.onChange{[weak self] connected in self?.netStatusChanged(isConnected:connected)
    }
      
    if self.simulateNewVersion || simulateFailedMinVersion {
      self.bundleID = App.isTAZ ? "de.taz.taz.2" : "de.taz.lmd.neo"
    }
    if self.simulateNewVersion {
      self.currentVersion = Version("0.8.15")      
    }

    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.handleEnterForeground()
    }
    openDB(name: name)
  }

  ///used in VersionCheck, Check NetworkConnection, Update PublicationDates
  func handleEnterForeground(){
    if self.minVersionOK == false {
      enforceUpdate()
    }
    else if netAvailability.isConnected == false {
      netAvailability.recheck()
    }
    else {
      log("Enter Foreground, updateFeeder")
      updateFeeder()
    }
    BackgroundDownloadService.shared.handleEnterForeground()
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
  
  public func getLatestStoredIssue() -> StoredIssue? {
    guard defaultFeed != nil else {
      error("Stored Feed not found");
      return nil
    }
    return StoredIssue.issuesInFeed(feed: defaultFeed, count: 1).first
  }
  
  /// Returns true if the Issue needs to be updated
  public func needsUpdate(issue: Issue) -> Bool {
    guard !issue.isDownloading else { return false }
    
    if issue.isReduced, isAuthenticated, !Defaults.expiredAccount {
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
  
  func handleUnfinshedDownloads(){
    BackgroundDownloadService.shared.applicationRestarted(with: self)
  }
  
  func cleanupOldIssues(deleteOlder:Bool = false){
    log("deleteOlder: \(deleteOlder)")
    if self.dloader.isDownloading { log("...DO-NOT-CLEANUP, downloader is busy"); return }
    guard TazAppEnvironment.currentApplicationStartContext == .foregroundUserStarted else {
      log("...DO-NOT-CLEANUP, not foreground user started app start")
      Usage.track(Usage.event.errorEvent.MissingIssueFiles, name: "Prevented Cleanup")
      return
    }
    guard let feed = self.storedFeeder?.feeds[0] as? StoredFeed else { return }
    let persistedIssuesCount:Int = Defaults.singleton["persistedIssuesCount"]?.int ?? 20
    StoredIssue.removeOldest(feed: feed,
                             keepDownloaded: persistedIssuesCount,
                             deleteOlder: deleteOlder,
                             deleteOrphanFolders: true)
  }
} // eof FeederContext
