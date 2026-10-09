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
   - feederUnreachable(FeederContext)
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
         openedIssue.date.issueKey == getLatestStoredIssue1()?.date.issueKey {
        UIApplication.shared.applicationIconBadgeNumber = 0
      }
    }
  }
  
  var selectedFeedName:String? { storedFeeder?.selectedFeed.name }
  var feedName:String? { masterFeed?.name }

  /// Name (title) of Feeder, base Dir in 
  public var name: String
  /// Name of default Feed to show
//  public var feedName: String
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
  
  /// The stored feeder from the database.
  /// after app installation, this is `nil`. During initialization, it is ensured
  /// that at least one stored feeder is persisted and available before
  /// `feederReady` is sent and external resources can access it.
  public private(set) var storedFeeder: StoredFeeder?
  
  public var masterFeed: StoredFeed? { storedFeeder?.masterFeed as? StoredFeed }
  
  /// Feeds identified during `updateFeeder` as having fewer locally stored
  /// issues or publication dates than available remotely and requiring
  /// background synchronization.
  public var locallyIncompleteFeeds: [StoredFeed] = []
  
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
    
  @Default("autoloadPdfRequested")
  var autoloadPdfRequested: Bool
  
  @Default("autoloadNewIssues")
  var autoloadNewIssues: Bool
  
  @Default("simulateFailedMinVersion")
  var simulateFailedMinVersion: Bool
  
  ///Do Not add to ConfigDefaults!
  @Default("migrationToIssueLastContent")
  var migrationToIssueLastContent: Bool
  
  @Default("simulateNewVersion")
  var simulateNewVersion: Bool
  
  ///empty if none
  @Key("lastAppPreviewVersion")
  var lastAppPreviewVersion: String
  
  @Default("specialArticleSystemSetting")
  var specialArticleSystemSetting: Bool
  
  @Default("lastExtendedIssueUpdateCalled")
  var lastExtendedIssueUpdateCalled: Date?
  
  var latestPublicationDateForMasterFeed:Date? {
    return masterFeed?.lastIssue
  }
  
  var latestPublicationDateForSelectedFeed:Date? {
    return storedFeeder?.selectedFeed.lastIssue
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

  
  //CHALLANGE
  /// init - update just call update once even if initial init
  private func initFeeder(){
    if self.gqlFeeder == nil {
      self.gqlFeeder = GqlFeeder(title: name,
                                 url: url,
                                 token: DefaultAuthenticator.token)
    }
    
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.handleEnterForeground()
    }
    
    Notification.receive(UIApplication.willResignActiveNotification) { [weak self] _ in
      UIApplication.shared.shortcutItems = Shortcuts.currentItems()
      self?.log("applicationWillResignActive: \(UIApplication.shared.stateDescription)")
    }
    
    storedFeeder = StoredFeeder.get(name: self.name).first

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
    else if storedFeeder?.pr.feeds?.count == 1,
       let oldMasterPersistentFeed
        = storedFeeder?.pr.feeds?.allObjects.first as? PersistentFeed,
       (oldMasterPersistentFeed.type == "publication"
        || oldMasterPersistentFeed.type == FeedType.unknown.rawValue){
      ///Migrate to multi Feed update old local type to new one
      oldMasterPersistentFeed.type = "isMaster"
    }

    notify("feederReady")
    cleanupOldIssues(deleteOlder: true)//requires inited bookmarks
    checkAppUpdate()
    
    if lastExtendedIssueUpdateCalled.map({ $0 < Date()
      .addingTimeInterval(-1 * 60) }) ?? true {
      // lastExtendedIssueUpdateCalled older thean 1 min or not available
      updateFeeder()
    }
    
    if let masterFeed = storedFeeder?.masterFeed as? StoredFeed {
      BackgroundDownloadService.shared.updateFeed(masterFeed)
      handleSoftDataUpdatesIfNeeded(feed:masterFeed)
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
  
  #warning("Do not use this in BG Downloads")
  //if no feed to load given, load all feeds
  private func updateFeeder(feedToLoadAllPublicationDates: StoredFeed? = nil){
    if gqlFeeder.isUpdating {
      debug(">>>...updateFeeder CANCELED because is already updating")
      return
    }
    
    if gqlFeeder.gqlSession?.isBackground == true {
      log("########################### W A R N I N G #######################")
      log("got a bg SESSION!?")
      log("########################### W A R N I N G #######################")
    }
    
    /// Load the latest issue after successfully updating and saving the feeder when no stored feeder exists yet
    let loadLatestIssueInitially = self.storedFeeder == nil
    
    var issueVersionsCountLimit = 0

    if storedFeeder != nil,
       lastExtendedIssueUpdateCalled.map({ $0 < Date().addingTimeInterval(-20 * 60) }) ?? true {
      /// The stored feeder is initialized and the last extended issue update was more than 20 minutes ago.
      ///
      /// Fetch the latest issue versions from the server, using the number of
      /// complete issues currently stored locally as the limit.
      ///
      /// Warning: Older issues may already be complete locally, while the server
      /// may only return the newest issues within this limit.
      issueVersionsCountLimit = min(5, StoredIssue.completeIssueCount())
    }
    
    Notification.send(Const.NotificationNames.checkForNewIssues,
                      content: FetchNewStatusHeader.status.fetchNewIssues,
                      error: nil,
                      sender: self)
    
    gqlFeeder.updateStatus(storedFeeder: storedFeeder,
                           feedToLoadAllPublicationDates: feedToLoadAllPublicationDates,
                           issueVersionsCount: issueVersionsCountLimit) { [weak self] res in
      guard let self = self else { return }
      let needInit = self.storedFeeder == nil
      switch res {
        ///no need to eval res.value due its updated:  self.gqlFeeder = res.value()
        case .success:
          if Device.isSimulator { logGqlFeederStats() }
          
          let handleSignificantChanges = persistedFeedHasSignificantChanges
          if handleSignificantChanges {
            TazAppEnvironment.sharedInstance.service?.resetFeederContext = true
            Notification.send(Const.NotificationNames.closeOpenIssues)
            for feed in storedFeeder?.storedFeeds ?? [] { feed.delete() }
            TazAppEnvironment.sharedInstance.service?.resetFeederContext = false
          }
          
          if feedToLoadAllPublicationDates != nil
              || handleSignificantChanges
              || self.gqlFeederHasChanges {
            self.storedFeeder = StoredFeeder.persist(object: self.gqlFeeder)
            ArticleDB.save()
            self.checkStoredFeedsConsistency()
            log(">>>...publication dates changed, inform UI (if not in background mode)")
            Notification.send(Const.NotificationNames.publicationDatesChanged)
            BackgroundDownloadService
              .downloadNewIssueOnAppForeground(caller: "Feeder Context Update Status: publicationDatesChanged")
          } else {
            debug(">>>...publication dates NOT changed")
          }
          
          if handleSignificantChanges {
            Notification.send(Const.NotificationNames.feedChange)
            Notification.send(Const.NotificationNames.feederChanged)
            log(">>>...handleSignificantChanges\(locallyIncompleteFeeds.count>0 ? "" : "WARNING locallyIncompleteFeeds is empty!")")
            ///locallyIncompleteFeeds should not be empty here, otherwise auto refresh did not work!
          }
          
          self.notifyNetStatus(isConnected: true)
          if loadLatestIssueInitially, isAuthenticated {///initial app start is quite slow, but this is not the reason; checked 25-06-20 on iPad Air2
            BackgroundDownloadService.downloadNewIssueOnAppForeground(caller: "Initially download latestIssue", delay: 5.0)
          }
          loadIncompleteFeedsIfNeeded()
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
  
  private func logGqlFeederStats() {
      log(">>> GqlFeeder Stats")
      for feed in self.gqlFeeder.feeds {
        log(">>> GqlFeed \(feed.name) has \(feed.issueVersions?.count ?? 0) IssueVersions, \(feed.publicationDates?.count ?? 0) PublicationDates (\(feed.publicationDates?.first?.date.short ?? "") - \(feed.publicationDates?.last?.date.short ?? ""))")
      }
  }
    
  
  /// Indicates whether the remotely fetched feeder differs from the locally
  /// persisted feeder.
  ///
  /// The GraphQL feeder contains the latest remote data, while `storedFeeder`
  /// contains the locally persisted data. A change is detected if:
  /// - a remote feed does not exist locally, or
  /// - the number of publication dates differs for any feed.
  private var gqlFeederHasChanges: Bool {
    guard let gqlFeeder = self.gqlFeeder,
          let storedFeeder = self.storedFeeder else {
      return true
    }

    return gqlFeeder.feeds.contains { gqlFeed in
      guard let storedFeed = storedFeeder.storedFeeds.first(where: { $0.name == gqlFeed.name }) else {
        debug(">>> StoredFeed not found for: \(gqlFeed.name)")
        return true
      }
      let storedCount = StoredPublicationDate.count(inFeed: storedFeed)
      let gqlCount = gqlFeed.issueCnt
      if gqlCount != storedCount {
        debug(">>> StoredFeed \(gqlFeed.name) has: \(storedCount) PublicationDates remote has: \(gqlCount)")
      }
      return gqlCount != storedCount
    }
  }
  
  var persistedFeedHasSignificantChanges: Bool {
    gqlFeeder.feeds.contains { gqlFeed in
      storedFeeder?.storedFeeds.first(where: { $0.name == gqlFeed.name })
        .map { $0.cycle != gqlFeed.cycle } ?? false
    }
  }
  
  /// Checks all locally stored feeds for missing or inconsistent publication dates.
  ///
  /// An empty `locallyIncompleteFeeds` array means that all feeds have
  /// complete and consistent publication dates.
  private func checkStoredFeedsConsistency() {
    guard let storedFeeder else {
      log(">>> storedFeeder not initialized yet!")
      return
    }
    
    guard !storedFeeder.feeds.isEmpty else {
      log(">>> no local feeds available => load them")
      return
    }
    
    func addIncompleteFeed(_ feed: StoredFeed) {
      guard !locallyIncompleteFeeds.contains(where: { $0.name == feed.name }) else {
        return
      }
      locallyIncompleteFeeds.append(feed)
    }
    
    for feed in storedFeeder.storedFeeds {
      let pubDateCount = StoredPublicationDate.count(inFeed: feed)
      
      // Podcasts and unknown feeds don't require publication dates.
      if pubDateCount == 0 && feed.type != .podcast && feed.type != .unknown {
        log(">>> no publicationDates for feed: \(feed.name) available => load them")
        addIncompleteFeed(feed)
        continue
      }
      
      let firstPubDate = StoredPublicationDate.getOldest(inFeed: feed)
      let latestPubDate = StoredPublicationDate.getLatest(inFeed: feed)
      
      var changeMessages: [String] = []
      
      if firstPubDate?.date.ISO8601 != feed.firstIssue.ISO8601 {
        changeMessages.append(">>> first PublicationDate did not match: \(firstPubDate?.date.ISO8601 ?? "-") != \(feed.firstIssue.ISO8601)"
        )
      }
      
      if latestPubDate?.date.ISO8601 != feed.lastIssue.ISO8601 {
        changeMessages.append(">>> latest PublicationDate did not match: \(latestPubDate?.date.ISO8601 ?? "-") != \(feed.lastIssue.ISO8601)"
        )
      }
      
      if pubDateCount != feed.issueCnt {
        changeMessages.append(">>> local PublicationDate Count and Feed Issue Count did not match: \(pubDateCount) != \(feed.issueCnt)"
        )
        log(">>> ⚠️ WARNING ⚠️ for feed: \(feed.name) PubDates: \(pubDateCount) != Issues: \(feed.issueCnt)")
      }
      
      guard !changeMessages.isEmpty else {
        debug(">>> All data matching for feed: \(feed.name) => no new issue or missing old issue")
        continue
      }
      
      changeMessages.prependIfPresent(">>> Missing some data for feed \(feed.name) locally:")
      log(changeMessages.joined(separator: "\n "))
      addIncompleteFeed(feed)
    }
    
  }
  
  private func loadIncompleteFeedsIfNeeded(){
    guard let feedToUpdate = locallyIncompleteFeeds.pop()  else { return }
    onMainAfter {[weak self] in
      self?.debug(">>> Update Feed: \(feedToUpdate.name) currently has \(StoredPublicationDate.count(inFeed: feedToUpdate)) PublicationDates")
      self?.updateFeeder(feedToLoadAllPublicationDates: feedToUpdate)
    }
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
  
  private func handleSoftDataUpdatesIfNeeded(feed: StoredFeed){
    /// After Update from old Version migrate everey existing old index to new
    /// for new installations do this also, but there are no issues so trivial & fast exit
    if migrationToIssueLastContent == false {
      log("migrate to last content")
      var needDBsave = false
      for issue in StoredIssue.issuesInFeed(feed: feed) {
        guard issue.lastContent == nil else { continue }
        if let i = issue.lastArticle, let art = issue.allArticles.valueAt(i) {
          issue.lastContent = art
          needDBsave = true
        }
        else if let i = issue.lastSection, let sect = issue.sections?.valueAt(i) {
          issue.lastContent = sect
          needDBsave = true
        }
      }
      if needDBsave { ArticleDB.save() }
      migrationToIssueLastContent = true//Stored in UserDefaults
      log("migrate to last content, done. Changes: \(needDBsave)")
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
  /// name is used for Databasename eg. "App..Support/database/taz.sqlite" in AppSupport Folder/Database
  /// name is used  root folder for data in "App..Support/taz/..."
  public init?(name: String, url: String) {
    if URL(string: url)?.host == nil { return nil }
    self.name = name
    self.url = url
    self.netAvailability = ExtendedNetAvailability(url: url)
    
    self.netAvailability.onChange{[weak self] connected in self?.netStatusChanged(isConnected:connected)
    }
      
    if self.simulateNewVersion || simulateFailedMinVersion {
      self.bundleID = App.isTAZ ? "de.taz.taz.2" : "de.taz.lmd.neo"
    }
    if self.simulateNewVersion {
      self.currentVersion = Version("0.8.15")      
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
  
  public func getLatestStoredIssue1() -> StoredIssue? {
    guard let masterFeed else {
      error("Stored Feed not found");
      return nil
    }
    return StoredIssue.issuesInFeed(feed: masterFeed, count: 1).first
  }
  
  /// Returns true if the Issue needs to be updated
  public func needsUpdate(issue: Issue) -> Bool {
    ///ensure manual download while automatic download is queued in the background.
    ///Warning RaceCondition with autodownload on app resume, solved with
    ///TazAppEnvironment.isDownloading....
    if issue.isAutodownloading {
      issue.isDownloading = false
      issue.isAutodownloading = false
      return true
    }
    guard !issue.isDownloading else { return false }
    
    if issue.isReduced, isAuthenticated, !Defaults.expiredAccount {
      issue.isComplete = false
    }
    return !issue.isComplete
  }
  
  
  public func needsUpdate(issue: Issue, toShowPdf: Bool = false) -> Bool {
    if issue.versionLocal2 < issue.versionRemote2 { return true }
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
    guard Log.appStartContext == .foregroundUserStarted else {
      log("...DO-NOT-CLEANUP, not foreground user started app start")
      return
    }
    guard let feed = self.storedFeeder?.feeds.first(where: {$0.name == self.feedName}) as? StoredFeed else { return }
    migrateFullDownloadedIssuesDatesIfNeeded()
    let persistedIssuesCount:Int = Defaults.singleton["persistedIssuesCount"]?.int ?? 20
    StoredIssue.removeOldest(feed: feed,
                             keepDownloaded: persistedIssuesCount,
                             deleteOlder: deleteOlder,
                             deleteOrphanFolders: true)
  }
  
  func migrateFullDownloadedIssuesDatesIfNeeded(){
    guard let feed = self.storedFeeder?.feeds.first(where: {$0.name == self.feedName}) as? StoredFeed else { return }
    let faultIssues = StoredIssue.issues(feed: feed, onlyComplete: true, onlyWithoutCompleteDate: true)
    guard faultIssues.count > 0 else { return }
    log("WARNING: FIX MISSING COMPLETE DATES for \(faultIssues.count) issues")
    Usage.track(Usage.event.errorEvent.MissingIssueFiles, name: "Fixed missing complere dates for \(faultIssues.count) issues.")
    for issue in faultIssues {
      guard issue.isComplete else { continue }/// unnecessary, but for safety's sake
      issue.fullDownloadedDate = issue.date
    }
    ArticleDB.save()
  }
} // eof FeederContext

extension Issue {
  /// directory where all issue specific data is stored
  var dir: Dir? {
    TazAppEnvironment.sharedInstance.feederContext?.storedFeeder?.issueDir(issue: self)
  }
  
  func createGlobalLinksIfNeeded(){
    guard let dir else {
      Log.error("dir not available")
      return
    }
    guard let feeder = TazAppEnvironment.storedFeeder else {
      Log.error("feeder not available")
      return }
    dir.createGlobalLinksIfNeeded(feeder: feeder)
  }
}

fileprivate extension Feeder {
  
  func hasChanges(to feeder: Feeder?) -> Bool {
    guard let feeder else {  return true }
    // Compare the number of feeds.
    guard feeds.count == feeder.feeds.count else {
      return true
    }
    // Compare each feed by name and publicationDates count.
    for feed in feeds {
      guard let otherFeed = feeder.feeds.first(where: {
        $0.name == feed.name
      }) else {
        // A feed with this name doesn't exist in the other feeder.
        return true
      }
      // Compare the number of publicationDates.
      let count = feed.publicationDates?.count ?? 0
      let otherCount = otherFeed.publicationDates?.count ?? 0
      
      guard count == otherCount else {
        return true
      }
      
      guard feed.lastIssue.short == otherFeed.lastIssue.short else {
        return true
      }
      
      guard feed.firstIssue.short == otherFeed.firstIssue.short else {
        return true
      }
    }
    // No differences found.
    return false
  }
  
  /// Returns all feeds whose publicationDates need to be loaded or updated.
  /// An empty array means that all feeds have complete publicationDates.
  func feedsToNeedLoadAllPublicationDates() -> [Feed] {
      guard feeds.isEmpty else {
        Log.log("no local feeds available => load them")
          return []
      }

      var feedsToLoad: [Feed] = []

      for feed in feeds {
          let pubDates = feed.publicationDates ?? []

          // No publicationDates available: load all dates for this feed.
          if pubDates.isEmpty {
            Log.log("no publicationDates for feed: \(feed.name) available => load them")
              feedsToLoad.append(feed)
              continue
          }

          // Check whether the locally stored dates cover the feed's date range.
          let first = (pubDates.last?.date.ISO8601 ?? "1980-01-01") == feed.firstIssue.ISO8601
          let last = (pubDates.first?.date.ISO8601 ?? "1980-01-01") >= feed.lastIssue.ISO8601
          let count = pubDates.count >= feed.issueCnt

          if pubDates.count != feed.issueCnt {
              // TODO: Keep an eye on this — shouldn't cause issues.
            Log.log("⚠️ WARNING ⚠️ for feed: \(feed.name) PubDates: \(pubDates.count) != Issues: \(feed.issueCnt)")
          }

          // All checks passed: this feed doesn't need an update.
          if first && last && count {
            Log.debug("All data matching for feed: \(feed.name) => no new issue or missing old issue")
              continue
          }

          // At least one check failed: reload publicationDates for this feed.
          let logString = """
              Missing some issues: Match pubDates data == feed data
                firstIssue (\(first)): \(pubDates.last?.date.short ?? "-") == \(feed.firstIssue.short)
                lastIssue (\(last)): \(pubDates.first?.date.short ?? "-") >= \(feed.lastIssue.short)
                count (\(count)): \(pubDates.count) >= \(feed.issueCnt)
          """
        Log.log(logString)
        Log.log("Update all publication Dates")

          feedsToLoad.append(feed)
      }

      return feedsToLoad
  }
  
  ///empty array means load all feeds publicationDates
//  func feedsToNeedLoadAllPublicationDates() -> [Feed]{<= new
  func needLoadAllPublicationDates1() -> Bool{
    
    guard feeds.count > 0 else {
      Log.log("no local feeds available => load them")
      return true
    }
    
    for feed in feeds {
      let pubDates = feed.publicationDates ?? []
      if pubDates.count == 0 {
        Log.log("no publicationDates for feed: \(feed.name) available => load them")
        return true
      }
      let first = pubDates.last?.date.ISO8601 ?? "1980-01-01" == feed.firstIssue.ISO8601
      let last = pubDates.first?.date.ISO8601 ?? "1980-01-01" >= feed.lastIssue.ISO8601
      let count = pubDates.count >= feed.issueCnt
      if pubDates.count != feed.issueCnt {
        // TODO: Keep an eye on this — shouldn't cause issues.
        Log.log("⚠️ WARNING ⚠️ for feed: \(feed.name) PubDates: \(pubDates.count) != Issues: \(feed.issueCnt)")
      }
      if first && last && count {
        Log.debug("All data matching for feed: \(feed.name) => no new issue or missing old issue")
        continue
      }
      let logString = """
          Missing some issues: Match pubDates data == feed data
            firstIssue (\(first)): \(pubDates.last?.date.short ?? "-") == \(feed.firstIssue.short)
            lastIssue (\(last)): \(pubDates.first?.date.short ?? "-") == \(feed.lastIssue.short)
            count (\(count)): \(pubDates.count) == \(feed.issueCnt)
      """
      Log.log(logString)
      Log.log("Update all publication Dates")
      return true
    }
    return false
  }
}
