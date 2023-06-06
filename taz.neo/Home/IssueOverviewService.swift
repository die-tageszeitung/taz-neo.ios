//
//  DataService.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.01.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib


/**
 Motivation: Helper to load Data from Server uses FeederContext
  
 Bug: leere ausgaben:
 
 #Async Download Images Problematik
 * Wenn Ich eine CVCell habe deren Image ich nicht kenne:
      ** CVC hält Issue Referenz
      ** Task/Async Download des Images
      ** Downloader Success => Notification
      ** ** Haben alle Zellen listener? Auf iPad Pro 12" können das 30 Zellen sein
      ** ** ständiges hinzufügen/entfernen von Listener bringt auch nichts
 
 finish callback?
 
 TODO REFACTOR
 */

//schneller switch PDF - Moment? >> muss verhindern, dass in App Ansicht PDF Moment gezeigt wird!

/// for issueImageLoaded Notification
/// loader to prevent e.g. switch to PDF load finished for app view, worng image set to cell
typealias IssueCellData = (date: PublicationDate, issue:StoredIssue?, image: UIImage?)
typealias EnqueuedMomentLoad = (issue: StoredIssue, files: [FileEntry], isPdf: Bool)
typealias FailedLoad = (date: Date, count: Int)
typealias IndexPathMoved = (from: IndexPath, to: IndexPath)

/// using Dates short String Representation for store and find issues for same date, ignore time
extension Date { var issueKey : String { short } }

extension Date {
  func validityDateText(validityDate: Date?,
                        timeZone:String,
                        short:Bool = false,
                        shorter:Bool = false,
                        leadingText: String? = "woche, ") -> String {
    guard let endDate = validityDate else {
      return shorter ? self.shorter
      : short ? self.short
      : self.gLowerDate(tz: timeZone)
    }
    
    let mSwitch = endDate.components().month != self.components().month
    
    let dfFrom = DateFormatter()
    dfFrom.dateFormat = mSwitch ? "d.M." : "d."
    
    let dfTo = DateFormatter()
    dfTo.dateFormat = shorter ? "d.M.yy" : "d.M.yyyy"
    
    let from = dfFrom.string(from: self)
    let to = dfTo.string(from: endDate)
    
    return "\(leadingText ?? "")\(from) – \(to)"
  }
  
  
}

class IssueOverviewService: NSObject, DoesLog {
  
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  let loadPreviewsQueue = DispatchQueue(label: "apiLoadPreviewQueue",qos: .userInitiated)
  let loadPreviewsGroup = DispatchGroup()
  let loadPreviewsLock = NSLock()
  var loadPreviewsStack: [EnqueuedMomentLoad] = []
  let loadPreviewsSemaphore = DispatchSemaphore(value: 3)
  var lastLoadFailed: FailedLoad?
  
  internal var feederContext: FeederContext
  var feed: StoredFeed
  
  public private(set) var publicationDates: [PublicationDate]
  public var firstIssueDate: Date { feed.firstIssue }
  public var lastIssueDate: Date { feed.lastIssue }
  private var issues: [String:StoredIssue]
  
  
  /// cell data to display issue cell in caroussel or tiles
  /// start download for issuePreview if no data available
  /// start download for image if no image available
  /// - Parameter index: index for requested cell
  /// - Returns: cell data if any with date, issue if locally available, image if locally available
  func cellData(for index: Int) -> IssueCellData? {
    guard let publicationDate = date(at: index) else {
      error("No Entry for: \(index), This should not be requested")
      return nil
    }
    guard let issue = issue(at: publicationDate.date) else {
      apiLoadPreview(for: publicationDate.date, count: 6)
      return IssueCellData(date: publicationDate, issue: nil, image: nil)
    }
    let img = self.storedImage(issue: issue, isPdf: isFacsimile)
    if img == nil { apiLoadMomentImages(for: issue, isPdf: isFacsimile) }
    return IssueCellData(date: publicationDate, issue: issue, image: img)
  }
  
  func date(at index: Int) -> PublicationDate? {
    return publicationDates.valueAt(index)
  }
  
  func nextIndex(for date: Date) -> Int {
    return publicationDates.firstIndex(where: { $0.date <= date }) ?? 0
  }
  
  @discardableResult
  func download(issueAtIndex: Int?) -> StoredIssue? {
    guard let idx = issueAtIndex,
        let issue = issue(at: idx),
          hasDownloadableContent(issue: issue) else {
      self.log("not downloading for idx: \(issueAtIndex ?? -1)")
      return nil
    }
        
    feederContext.getCompleteIssue(issue: issue,
                                   isPages: self.isFacsimile,
                                   isAutomatically: false)
    return issue
  }
  
  func issueDownloadState(at index: Int) -> DownloadStatusIndicatorState {
    guard let d = date(at: index) else {
      print("no date for \(index)")
      return .notStarted
    }
    guard let issue = issue(at: d.date) else {
      print("no issue for \(index) date: \(d.date)")
      return .notStarted
    }
    if issue.isDownloading { return .process }
    print("issue for \(index) date: \(d.date) is either not started or done")
    return feederContext.needsUpdate(issue: issue, toShowPdf: isFacsimile)
    ? .notStarted
    : .done
  }
  
  func issue(at date: Date) -> StoredIssue? {
    return issues[date.issueKey]
  }
  
  func issue(at index: Int) -> StoredIssue? {
    guard let date = publicationDates.valueAt(index) else { return nil }
    return issue(at: date.date)
  }
  
  func issue(at date: String) -> StoredIssue? {
    return issues[date]
  }
  
  func image(for issue: StoredIssue) -> UIImage? {
    let img = self.storedImage(issue: issue, isPdf: isFacsimile)
    if img == nil {
      apiLoadMomentImages(for: issue, isPdf: isFacsimile)
    }
    return img
  }
  
  /// Date keys which are currently loading the preview
  var loadingDates: [String] = []
  var loadFaildPreviews: [StoredIssue] = []
  var isCheckingForNewIssues = false
  var lastUpdateCheck = Date()///set to init time to simplify; on online app start auto check is done and on reconnect
  
  
  ///Optimized load previews
  ///e.g. called on jump to date + ipad need to load date +/- 5 issues
  ///or on scrolling need to load date + 5..10 issues
  ///           5 or 10 5= more stocking because next laod needed //// 10 increased loading time **wrong beause images are loaded asyc in another thread!**
  func apiLoadPreview(for date: Date, count: Int) {
    
    if loadingDates.contains(where: { return $0==date.issueKey}) {
      debug("Already loading: \(date.issueKey), skip loading")
      return
    }
    var count = count
    
    let availableIssues = issues.map({ $0.value.date.issueKey })
    var currentLoadingDates: [Date] = []
    
    for i in -count/2...count/2 {
      var d = date
      d.addDays(-i)
      if availableIssues.contains(d.issueKey) { count = i+1; break }
      if loadingDates.contains(d.issueKey) { count = i+1; break }
      currentLoadingDates.append(d)
    }
    
    let date = currentLoadingDates.first ?? date
    count = abs(currentLoadingDates.count > 0 ? currentLoadingDates.count : count)
    let sCurrentLoadingDates = currentLoadingDates.map{$0.issueKey}
    addToLoading(sCurrentLoadingDates)
    
    self.feederContext.gqlFeeder.issues(feed: feed,
                                        date: date,
                                        count: count,
                                        isOverview: true,
                                        returnOnMain: true) {[weak self] res in
      guard let self = self else { return }
      var newIssues: [StoredIssue] = []
      self.debug("Finished load Issues for: \(date.short), count: \(count)")
      
      if let err = res.error() as? FeederError {
        self.handleDownloadError(error: err)
      } else if let err = res.error() as? URLError {
        ///offline
        self.debug("failed to load")
        self.lastLoadFailed = FailedLoad(date, count)
      } else if let err = res.error(){
        self.debug("failed to load")
        ///unknown
      }
      if let issues = res.value() {
        let start = Date()
        for issue in issues {
          newIssues.append(StoredIssue.persist(object: issue))
        }
        self.log("Finished load Issues for: \(date.short) DB Update duration: \(Date().timeIntervalSince(start))s on Main?: \(Thread.isMain)")
        ArticleDB.save()
        for si in newIssues {
          self.updateIssue(issue: si)
          Notification.send(Const.NotificationNames.issueUpdate,
                            content: si.date,
                            sender: self)
        }
      }
      self.removeFromLoading(sCurrentLoadingDates)
    }
  }
  
  func hasDownloadableContent(issue: Issue) -> Bool {
    guard let sIssue = issue as? StoredIssue else { return true }
    return feederContext.needsUpdate(issue: sIssue,toShowPdf: isFacsimile)
  }
  
  func removeFromLoading(_ dates: [String]){
    loadingDates
    = loadingDates.enumerated().filter { !dates.contains($0.element) }.map { $0.element }
  }
  
  func addToLoading(_ dates: [String]){
    loadingDates.append(contentsOf: dates)
  }
  
  func apiLoadMomentImages(for issue: StoredIssue, isPdf: Bool) {
    let dir = issue.dir
    var files: [FileEntry] = []
    
    if isPdf, let f = issue.pageOneFacsimile {
      files.append(f)
    }
    else if !isPdf, issue.moment.carouselFiles.count > 0 {
      files = issue.moment.carouselFiles
    }
    
    for f in files {
      if f.exists(inDir: dir.path) {
        debug("something went wrong: file exists, need no Download. File: \(f.name) in \(dir.path)")
      }
    }
    
    loadPreviewsQueue.async(group: loadPreviewsGroup) { [weak self] in
      guard let self = self else { return }
      let load = EnqueuedMomentLoad(issue: issue, files: files, isPdf: isPdf)
      self.loadPreviewsLock.with { [weak self] in  self?.loadPreviewsStack.push(load) }
      
      self.debug("enqueue download \(files.count) Issue files for \(issue.date.issueKey)")
      self.loadPreviewsGroup.enter()
      self.loadPreviewsSemaphore.wait()
      
      let next = self.loadPreviewsStack.last
      self.loadPreviewsLock.with { [weak self] in
        _ = self?.loadPreviewsStack.popLast()
      }
      /*
      WARNING: Go offline, scroll to unknown issues, go online the issues stay in Stack and wount be downloaded!
      
      */
      
      guard let next = next else {
        self.loadPreviewsGroup.leave()
        self.loadPreviewsSemaphore.signal()
        return
      }
      
      let issue = next.issue
      let isPdf = next.isPdf
      let files = next.files
      
      self.debug("do download \(files.count) Issue files for \(issue.date.issueKey)")
      self.feederContext.dloader
        .downloadIssueFiles(issue: issue, files: files) {[weak self] err in
          self?.debug("done download \(files.count) Issue files for \(issue.date.issueKey)")
          let img = self?.storedImage(issue: issue, isPdf: isPdf)
          if img == nil {
            self?.debug("something went wrong: downloaded file did not exist!")
            self?.loadFaildPreviews.append(issue)
          }
          Notification.send(Const.NotificationNames.issueUpdate,
                            content: issue.date,
                            sender: self)
          self?.loadPreviewsGroup.leave()
          self?.loadPreviewsSemaphore.signal()
        }
    }
  }
  
  func storedImage(issue: StoredIssue, isPdf: Bool) -> UIImage? {
    return feederContext.storedFeeder?.momentImage(issue: issue,
                                                  isPdf: isPdf,
                                                  usePdfAlternative: false)
  }
  
  func updateIssue(issue:StoredIssue){
    self.issues[issue.date.issueKey] = issue
  }
  
  
  /// refresh data model, reloads active collectionView
  /// - Parameters:
  ///   - collectionView: cv to reload animated
  ///   - verticalCv: is vertical (tiles) or horizointal (carousel)
  /// - Returns: true if new issues available and reload, false if not
  func reloadPublicationDates(refresh collectionView: UICollectionView,
                              verticalCv: Bool) -> Bool {
    guard let newPubDates = feed.publicationDates else { return false }
    debug("before: \(publicationDates.count) after: \(newPubDates.count)")
  
    if publicationDates.count != newPubDates.count {
      Notification.send(Const.NotificationNames.checkForNewIssues,
                        content: FetchNewStatusHeader.status.loadPreview,
                        error: nil,
                        sender: self)
    }
    ///Warning Work with Issue Keys not with PublicationDates for performance reasons
    ///insert/update 4 of 3770 Publication Datees took < 50s in Debugging on intel mac
    ///with String Keys only 4s
    let newDates = newPubDates.map{ $0.date.issueKey }
    let oldDates = publicationDates.map{ $0.date.issueKey }
    
    var insertIp: [IndexPath] = []
    var movedIp: [IndexPathMoved] = []
    var usedOld: [String] = []
    
    ///find added and move items indexPaths
    for (nIdx, newElm) in newDates.enumerated() {
      var found = false
      for (oIdx, oldElm) in oldDates.enumerated() {
        if newElm == oldElm {
          if nIdx != oIdx {
            movedIp.append(IndexPathMoved(from:IndexPath(row: oIdx, section: 0),
                                          to:IndexPath(row: nIdx, section: 0)))
          }
          usedOld.append(oldElm)
          found = true;
          break;
        }
      }
      if found == false {
        insertIp.append(IndexPath(row: nIdx, section: 0))
      }
    }
    
    ///find removed items indexPaths
    var deletedIp: [IndexPath] = []
    for (idx, oldElm) in oldDates.enumerated() {
      if usedOld.contains(oldElm) == false {
        deletedIp.append(IndexPath(row: idx, section: 0))
      }
    }
    
    if insertIp.count == 0, movedIp.count == 0, deletedIp.count == 0 {
      return false
    }
    
    
    let offset
    = verticalCv
    ? collectionView.contentSize.height - collectionView.contentOffset.y
    : collectionView.contentSize.width - collectionView.contentOffset.x
    
    ///Update Issue Carousel
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    
    collectionView.performBatchUpdates({
      if insertIp.count > 0 {
        collectionView.insertItems(at: insertIp)
      }
      if deletedIp.count > 0 {
        collectionView.deleteItems(at: deletedIp)
      }
      for pair in movedIp {
        collectionView.moveItem(at: pair.from, to: pair.to)
      }
      ///updateData
      publicationDates = newPubDates
    }, completion: {_ in
      collectionView.contentOffset
      = verticalCv
      ? CGPointMake(0, collectionView.contentSize.height - offset)
      : CGPointMake(collectionView.contentSize.width - offset, 0)
      CATransaction.commit()
    })
    ///inform sender to refresh other collectionView
    return true
  }
    
  /// Initialize with FeederContext
  public init(feederContext: FeederContext) {
    self.feederContext = feederContext
    self.feed = feederContext.defaultFeed
    self.publicationDates = feed.publicationDates ?? []
    
    issues = StoredIssue.issuesInFeed(feed: feed).reduce(into: [String: StoredIssue]()) {
      $0[$1.date.issueKey] = $1
    }
    super.init()
    
    ///Update downloaded Issue Reference
    Notification.receive("issue"){ [weak self] notif in
      guard let issue = notif.object as? StoredIssue else { return }
      print("update issue after download for: \(issue.date.issueKey)")
      self?.updateIssue(issue: issue)
    }
    ///Update downloaded Issue Reference
    Notification.receive("issueStructure"){ [weak self] notif in
      guard let error = notif.error as? DownloadError else { return }
      self?.handleDownloadError(error: error)
    }
    
    Notification.receive(Const.NotificationNames.feederReachable) {[weak self] _ in
      #warning("ToDo resume latest loadPreviewStack...send online")
      self?.debug("LoadingDates: \(self?.loadingDates)")
      self?.debug("loadPreviewsStack: \(self?.loadPreviewsStack)")
      self?.debug("feeder is reachable")
//      for i in self?.loadFaildPreviews ?? [] {
//        self?.apiLoadMomentImages(for: i, isPdf: self?.isFacsimile ?? false)
//      }
      if let ll = self?.lastLoadFailed {
        ///TODO!!!
        #warning("todo check!")
        self?.apiLoadPreview(for: ll.date, count: ll.count)
      }
    }
    
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.checkForNewIssues(force: false)
    }
  }
  
  private var lc = LoadCoordinator()
}

// MARK: - extension Check for New PublicationDates (Issues)
extension IssueOverviewService {
  
  /// check for new issues from pull to refresh (force == true)
  /// and app will enter foreground
  /// - Parameter force: ensure check
  func checkForNewIssues(force: Bool) {
    if force == false && isCheckingForNewIssues {
      return
    }
    
    ///only check after 5pm  on app resume (usually new issue comes after 6pm)
    if !force && Date().timeIntervalSince(feederContext.latestPublicationDate?.startOfDay ?? Date()) < 3600*18 {
      log("no need to check for new Issue due latest issue is from today, its too early")
      return
    }
    
    ///only check every 5 Minutes on app resume
    if !force &&  Date().timeIntervalSince(lastUpdateCheck) < 5*60 {
      log("no need to check for new Issue due last auto check was just now")
      return
    }
    
    guard feederContext.isConnected else {
      Notification.send(Const.NotificationNames.checkForNewIssues,
                        content: FetchNewStatusHeader.status.offline,
                        error: nil,
                        sender: self)
      return
    }
    
    if !force {
      ///update status Header
      Notification.send(Const.NotificationNames.checkForNewIssues,
                        content: FetchNewStatusHeader.status.fetchNewIssues,
                        error: nil,
                        sender: self)
    }
    
    isCheckingForNewIssues = true
    
    updatePublicationDates(feed: feederContext.defaultFeed)
  }
    
  /// check api for new publicationDates (Issues)
  /// ensure feeder is connected otherwise request will fail
  /// - Parameter feed: feed to update
  public func updatePublicationDates(feed: Feed) {
    log("update")

    feederContext.gqlFeeder.feederStatus { [weak self] result in
      
      self?.isCheckingForNewIssues = false
      
      if let err = result.error() {
        self?.debug(err.description)
        let status = self?.feederContext.isConnected == false
        ? FetchNewStatusHeader.status.offline
        : FetchNewStatusHeader.status.downloadError
        Notification.send(Const.NotificationNames.checkForNewIssues, content: status, error: nil, sender: self)
        return
      }
      
      self?.lastUpdateCheck = Date()
      
      guard let gqlFeederStatus = result.value(),
            let self = self,
            let sFeed = self.feederContext.storedFeeder?.feeds[0] as? StoredFeed,
            let gqlFeed = gqlFeederStatus.feeds.first,
            let gqlPubDates = gqlFeed.publicationDates,
            gqlPubDates.count > 0 else {
        ///usually we have 1 date due request with todays and latest date return todys date again
        self?.debug("no new data")
        Notification.send(Const.NotificationNames.checkForNewIssues,
                          content: FetchNewStatusHeader.status.none,
                          error: nil,
                          sender: self)
        return
      }
      let oldCnt = feed.publicationDates?.count ?? 0
      _ = StoredPublicationDate.persist(publicationDates: gqlPubDates, inFeed: sFeed)
      let newCnt = feed.publicationDates?.count ?? 0
      if oldCnt == newCnt {
        Notification.send(Const.NotificationNames.checkForNewIssues,
                          content: FetchNewStatusHeader.status.none,
                          error: nil,
                          sender: self)
        return
      }
      ArticleDB.save()
      log("persist: \(newCnt - oldCnt) publicationDates")
      Notification.send(Const.NotificationNames.checkForNewIssues, content: FetchNewStatusHeader.status.loadPreview, error: nil, sender: self)
      Notification.send(Const.NotificationNames.publicationDatesChanged)
    }
  }
}


extension IssueOverviewService {
  /// Inspect download Error and show it to user
  func handleDownloadError(error: Error?) {
    self.debug("Err: \(error?.description ?? "-")")
    func showDownloadErrorAlert() {
      let message = """
                    Beim Laden der Ausgabe ist ein Fehler aufgetreten.
                    Bitte versuchen Sie es zu einem späteren Zeitpunkt
                    noch einmal.
                    Sie können bereits heruntergeladene Ausgaben auch
                    ohne Internet-Zugriff lesen.
                    """
      OfflineAlert.message(title: "Warnung", message: message)
    }
    #warning("1st ok next at download handle error!!")
    if let err = error as? FeederError {
      feederContext.handleFeederError(err){}
    }
    else if let err = error as? DownloadError, let err2 = err.enclosedError as? FeederError {
      feederContext.handleFeederError(err2){}
    }
    else if let err = error as? DownloadError {
      if err.handled == false {  showDownloadErrorAlert() }
      self.debug(err.enclosedError?.description ?? err.description)
    }
    else if let err = error {
      self.debug(err.description)
      showDownloadErrorAlert()
    }
    else {
      self.debug("unspecified download error")
      showDownloadErrorAlert()
    }
  }
}

extension IssueOverviewService {
  func exportMoment(issue: Issue) {
    if let feeder = feederContext.gqlFeeder,
        let fn = feeder.momentImageName(issue: issue, isCredited: true) {
      let file = File(fn)
      let ext = file.extname
      let dialogue = ExportDialogue<Any>()
      let name = "\(issue.feed.name)-\(issue.date.isoDate(tz: feeder.timeZone)).\(ext ?? "")"
      dialogue.present(item: file.url, subject: name)
    }
  }
}

/// A Helper to select next loads
fileprivate class LoadCoordinator: NSObject, DoesLog {
  fileprivate var loadingDates: [String] = []
  fileprivate var nextDates: [Date] = []
  
  var next: Date? {
    reduceNextIfNeeded()
    return nextDates.popLast()
  }
  
  ///Theory: fast scrolling in List for 3 years, prevent load of 200 Issues, only load 30 most relevant issues
  func reduceNextIfNeeded(){
    if nextDates.count < 30 { return }
    nextDates = nextDates[nextDates.endIndex - 20 ..< nextDates.endIndex].sorted()
  }
}

fileprivate extension NSLock {

    @discardableResult
    func with<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}
