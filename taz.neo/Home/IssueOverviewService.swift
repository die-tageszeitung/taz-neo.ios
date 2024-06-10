//
//  DataService.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.01.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib
import Foundation

typealias IssueCellData = (key: String,
                           date: PublicationDate,
                           issue:StoredIssue?,
                           image: UIImage?,
                           downloadState: DownloadStatusIndicatorState)
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
  
  internal var feederContext: FeederContext
  var feed: StoredFeed
  
  var ovwHelper = LoadOverviewHelperBusiness()
  
  public private(set) var publicationDates: [PublicationDate]
  
  public var firstIssueDate: Date { feed.firstIssue }
  public var lastIssueDate: Date { feed.lastIssue }
  
  func issue(at date: Date) -> StoredIssue? {
    return issues[date.issueKey]
  }
  
  private var issues: [String:StoredIssue]
  ///in hard tests due massive parallel write and read (timer, scrolling on Home, whatever) the app crashed with a own async DispatchQueue
  ///thats why this is moved to main thread now, since then no more chrashes
  private var requestedRemoteItems: [String:Date] = [:]
  private var loadingIssueData:[String:Date] = [:]
  ///loading issue images can happen on any thread (hopefully)
  ///but needs to sync (no async) with its queue (the theory)
  private var loadingIssueImages:[String] = []
  private var requestedloadingIssueImagesSyncQueue
  = DispatchQueue(label: "IssueOverviewService.requestedloadingIssueImagesSyncQueue")
  
  /// cell data to display issue cell in caroussel or tiles
  /// enqueue download for issuePreview if no data available
  /// enqueue download for image if no image available
  /// - Parameter index: index for requested cell
  /// - Returns: cell data if any with date, issue if locally available, image if locally available
  func cellData(for index: Int) -> IssueCellData? {
    guard let publicationDate = date(at: index) else {
      error("No Entry for: \(index), This should not be requested")
      return nil
    }
    let issue = issue(at: publicationDate.date)
    var img: UIImage?
    let key = publicationDate.date.key(pdf: isFacsimile)
    
    if let issue = issue {
      img = self.storedImage(issue: issue, isPdf: isFacsimile)
    }

    if issue == nil || img == nil {
      addToLoadFromRemote(key:key, date: publicationDate.date)
    }
    
    return IssueCellData(key: key,
                         date: publicationDate,
                         issue: issue,
                         image: img,
                         downloadState: downloadState(for: issue)
    )
  }
  
  func addToLoadFromRemote(key: String, date: Date) {
    self.requestedRemoteItems[key] = date
  }
  
  /// removed a date from current loading items
  /// - Parameter date: date to remove
  func removeFromLoadFromRemote(key: String) {
    self.requestedRemoteItems[key] = nil
  }
    
  private func loadMissingItems(){
    if feederContext.isConnected == false { return }
    guard self.requestedRemoteItems.count > 0 else { return }
    var missingIssues:[Date] = []
    for (key, date) in self.requestedRemoteItems {
      if let issue = self.issue(at: date) {
        self.updateIssue(issue: issue, isPdf: key.suffix(1) == "P")
      } else if self.loadingIssueData[date.issueKey] == nil {
        missingIssues.append(date)
      }
    }
    missingIssues = missingIssues.sorted()
    guard let oldest = missingIssues.first,
          let newest = missingIssues.last else { return }
    ///ignoring public holidays and sundays, need to add 1 to load itself or the next one
    let days = 1 + (newest.timeIntervalSinceReferenceDate - oldest.timeIntervalSinceReferenceDate)/(3600*24)
    onThread {[weak self] in
      self?.apiLoadIssueOverview(for: newest, count: Int(days.nextUp))
    }
  }
  
  private func hasDownloadableContent(issue: Issue, withAudio: Bool) -> Bool {
    guard let sIssue = issue as? StoredIssue else { return true }
    if sIssue.isAudioComplete == false && withAudio == true { return true }
    return feederContext.needsUpdate(issue: sIssue,toShowPdf: isFacsimile)
  }
  
  @discardableResult
  func download(issueAt date: Date, withAudio: Bool) -> StoredIssue? {
    guard let issue = issue(at: date),
          hasDownloadableContent(issue: issue, withAudio: withAudio) else {
      self.log("not downloading issue from: \(date.issueKey)")
      return nil
    }
    feederContext.getCompleteIssue(issue: issue,
                                   isPages: self.isFacsimile,
                                   isAutomatically: false, 
                                   withAudio: withAudio)
    return issue
  }
  
  func date(at index: Int) -> PublicationDate? {
    return publicationDates.valueAt(index)
  }
  
  func nextIndex(for date: Date) -> Int {
    return publicationDates.firstIndex(where: { $0.date <= date }) ?? 0
  }
  
  func downloadState(for issue: StoredIssue?) -> DownloadStatusIndicatorState {
    guard let issue = issue else { return .waiting}
    if issue.isDownloading { return .process }
    
    let needUpdate = feederContext.needsUpdate(issue: issue, toShowPdf: isFacsimile)
    return needUpdate ? .notStarted : .done
  }
  
  /// Load Issue Data for DB and also loads Images if still required
  /// - Parameters:
  ///   - date: newest date to request from API
  ///   - count: additionally count of issues
  func apiLoadIssueOverview(for date: Date, count: Int) {
    self.debug("Start load Issues for: \(date.issueKey), count: \(count)")
    var count = count
    if count < 1 { count = 1 }
    else if count >= 10 { count = 10 }//API Limit is currently 20
    var d = date
    var lds:[String] = []
    for _ in 0...count*feederContext.defaultFeed.cycle.multiplicator {
      if loadingIssueData[d.issueKey] != nil { break }//prevent load same issue multiple times
      lds.append(d.issueKey)
      loadingIssueData[d.issueKey] = d
      d.addDays(1)
    }
    
    if lds.count == 0 { return }//prevent multiple times enqueued same item 
    
    count = max(1, lds.count/feederContext.defaultFeed.cycle.multiplicator)//prevent load same issue multiple times
    
    self.feederContext.gqlFeeder.issues(feed: feed,
                                        date: date,
                                        count: count,
                                        isOverview: true,
                                        returnOnMain: true) {[weak self] res in
      guard let self = self else { return }
      var newIssues: [StoredIssue] = []
      self.debug("Finished load Issues for: \(date.issueKey), count: \(count)")
      
      if let err = res.error() as? FeederError {
        self.handleDownloadError(error: err)
      } else if let err = res.error() as? URLError {
        ///offline
        self.debug("failed to load \(err)")
      } else if let err = res.error(){
        self.debug("failed to load \(err)")
        ///unknown
      }
      if let issues = res.value() {
        var loadedDates:[Date] = []
        let start = Date()
        for issue in issues {
          let si = StoredIssue.get(date: issue.date, inFeed: feed)
          if let sIssue = si.first {
            newIssues.append(sIssue)
          }
          else {
            (issue as? GqlIssue)?.isOverview = true
            let sIssue = StoredIssue.persist(object: issue)
            newIssues.append(sIssue)
          }
          loadedDates.append(issue.date)
        }
        ArticleDB.save()
        self.debug("Finished load&persist Issues for: \(date.issueKey) count: \(count) DB Update duration: \(Date().timeIntervalSince(start))s")
        for si in newIssues {
          self.updateIssue(issue: si, isPdf: isFacsimile)
        }
      }
      self.ovwHelper.currentOverviewErrorResponse = res.error()
      for sdate in lds { self.loadingIssueData[sdate] = nil }
    }
  }
    
  /// helper to load moment image/pdf for given issue
  /// - Parameters:
  ///   - issue: load files for this issue
  ///   - isPdf: load pdf facsimile or moment
  func apiLoadMomentImages(for issue: StoredIssue, isPdf: Bool) {
    let key = issue.key(pdf: isPdf)
    if loadingIssueImages.contains(key) { return }
    
    //wait here for a moment if needed!
    requestedloadingIssueImagesSyncQueue.sync { [weak self] in
      self?.loadingIssueImages.append(key)
    }
    debug("load for: \(issue.date.issueKey)")
    let dir = issue.dir
    var files: [FileEntry] = []
    
    if isPdf, let f = issue.pageOneFacsimile {
      files = [f]
    }
    else if !isPdf, issue.moment.carouselFiles.count > 0 {
      files = issue.moment.carouselFiles
    }
    var dlFiles: [FileEntry] = []
    for f in files { if f.exists(inDir: dir.path) == false { dlFiles.append(f)}}
    
    
    if dlFiles.count == 0 && isPdf {
      ///It seams on last Execution there was missing the convert from PDF to jpg, do it now
      (issue.pages?.first as? StoredPage)?.facsimile = nil
      _ = (issue.pages?.first as? StoredPage)?.facsimile
    }
    
    if dlFiles.count == 0 {
      self.debug("no file to download for Issue \(issue.date.issueKey)")
      self.notifyIssueOwvAvailable(issue: issue, key: key)
      self.requestedloadingIssueImagesSyncQueue.sync { [weak self] in
        self?.loadingIssueImages.removeAll{$0 == key}
      }
      return
    }
    self.debug("do download \(dlFiles.count) Issue files for \(issue.date.issueKey)")
    self.feederContext.dloader
      .downloadIssueFiles(issue: issue, files: files) {[weak self] err in
        self?.debug("done download \(files.count) Issue files for \(issue.date.issueKey) 7XßC3")
        let img = self?.storedImage(issue: issue, isPdf: isPdf)
        if img != nil && err == nil {
          self?.notifyIssueOwvAvailable(issue: issue, key: key)
        }
        else {
          var msg = "something went wrong:"
          msg += img == nil ? " downloaded file did not exist!" : ""
          msg += err != nil ? " Error: \(String(describing: err))" : ""
          msg += " for: \(issue.date.issueKey) 7XßC3"
          self?.log(msg)
        }
        ///if everything works as expected this is the place to remove, in case of errors
        ///otherwise remove must be done before succes notification send...or debug again
        self?.requestedloadingIssueImagesSyncQueue.sync { [weak self] in
          self?.loadingIssueImages.removeAll{$0 == key}
        }
      }
  }
  
  func storedImage(issue: StoredIssue, isPdf: Bool) -> UIImage? {
    return feederContext.storedFeeder?.momentImage(issue: issue,
                                                  isPdf: isPdf,
                                                  usePdfAlternative: false)
  }
  
  func updateIssue(issue:StoredIssue, isPdf: Bool){
    if self.storedImage(issue: issue, isPdf: isPdf) == nil {
      apiLoadMomentImages(for: issue, isPdf: isPdf)
    } else {
      notifyIssueOwvAvailable(issue: issue, key: issue.key(pdf: isFacsimile))
    }
    self.issues[issue.date.issueKey] = issue
  }
  
  func notifyIssueOwvAvailable(issue:StoredIssue, key: String){
    removeFromLoadFromRemote(key:key)
    guard let pDate = publicationDates.first(where: { $0.date == issue.date }) else {
      error("Not found the given Publication Date. This Should not happen!")
      return
    }
    ///notify only if still  requested
    let img = self.storedImage(issue: issue, isPdf: isFacsimile)
    
    let data = IssueCellData(key: key,
                             date: pDate,
                             issue: issue,
                             image: img,
                             downloadState: downloadState(for: issue))
    Notification.send(Const.NotificationNames.issueUpdate,
                      content: data)
  }
  
  /// refresh data model, reloads active collectionView
  /// - Parameters:
  ///   - collectionView: cv to reload animated
  ///   - verticalCv: is vertical (tiles) or horizointal (carousel)
  /// - Returns: true if new issues available and reload, false if not
  func reloadPublicationDates(refresh collectionView: UICollectionView?,
                              verticalCv: Bool) -> Bool {
    guard let newPubDates = feed.publicationDates else { return false }
    
    guard let collectionView = collectionView else {
      ///Skip Reload if home is still not presended
      if newPubDates.count > self.publicationDates.count {
        self.publicationDates = newPubDates
      }
      return false
    }
    
    
    debug("before: \(publicationDates.count) after: \(newPubDates.count)")
  
    if publicationDates.count != newPubDates.count {
      Notification.send(Const.NotificationNames.checkForNewIssues,
                        content: FetchNewStatusHeader.status.loadPreview,
                        error: nil,
                        sender: self)
    }
    
    if abs(newPubDates.count - publicationDates.count) > 10 {
      publicationDates = newPubDates
      collectionView.reloadData()
      return true
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
    
  func updateIssues(){
    issues =
    (feed.issues as? [StoredIssue])?.reduce(into: [String: StoredIssue]()) {
      $0[$1.date.issueKey] = $1
    } ?? [:]
  }
    
  /// Initialize with FeederContext
  public init(feederContext: FeederContext) {
    self.feederContext = feederContext
    self.feed = feederContext.defaultFeed
    self.publicationDates = feed.publicationDates ?? []
    issues =
    (feed.issues as? [StoredIssue])?.reduce(into: [String: StoredIssue]()) {
      $0[$1.date.issueKey] = $1
    } ?? [:]
    super.init()
    self.ovwHelper.sender = self//required for notification send
    $isFacsimile.onChange {[weak self] _ in
      guard let mode = self?.isFacsimile.mode,
            let keys = self?.requestedRemoteItems.keys,
            keys.count > 0 else { return }
      onMain {[weak self] in
        for key in keys {
          if key.suffix(1) != mode {
            self?.requestedRemoteItems[key] = nil
          }
        }
      }
    }
    
    ///Update downloaded Issue Reference
    Notification.receive("issue"){ [weak self] notif in
      guard let err = notif.userInfo!["error"] as? Error else { return }
      Notification.send("issueProgress",
                        content: DownloadStatusIndicatorState.notStarted,
                        sender: notif.object)
    }
    ///Update downloaded Issue Reference
    Notification.receive("issueStructure"){ notif in
      guard let err = notif.userInfo!["error"] as? Error else { return }
      Notification.send("issueProgress",
                        content: DownloadStatusIndicatorState.notStarted,
                        sender: notif.object)
    }
    
    Notification.receive("issueOverview") { [weak self] notif in
      self?.updateIssues()
    }
    
    Notification.receive("issueDelete") { [weak self] notif in
      guard let issueDate = notif.content as? Date else { return }
      self?.issues[issueDate.issueKey] = nil
    }
    
    Notification.receive(Const.NotificationNames.feederReachable) {[weak self] _ in
      self?.updateIssues()
    }
    self.ovwHelper.onTimer{ [weak self] in
      self?.loadMissingItems()
    }
  }
}

// MARK: - extension Check for New PublicationDates (Issues)
extension IssueOverviewService {
  
  /// check for new issues from pull to refresh (force == true)
  /// and app will enter foreground
  /// - Parameter force: ensure check
  func checkForNewIssues() {
    feederContext.checkForNewIssues(force: true)
  }
}

extension IssueOverviewService {
  /// Inspect download Error and show it to user
  func handleDownloadError(error: Error?) {
    self.debug("Err: \(error?.description ?? "-")")
    func showDownloadErrorAlert() {
      OfflineAlert.show(type: .issueDownload)
    }
    if let err = error as? FeederError {
      err.handle()
    }
    else if let err = error as? DownloadError, let err2 = err.enclosedError as? FeederError {
      err2.handle()
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
  func exportMoment(issue: Issue, sourceView: UIView?) {
    if let feeder = feederContext.gqlFeeder,
        let fn = feeder.momentImageName(issue: issue, isCredited: true, isPdf: isFacsimile) {
      let file = File(fn)
      let ext = file.extname
      let dialogue = ExportDialogue<Any>()
      let name = "\(issue.feed.name)-\(issue.date.isoDate(tz: feeder.timeZone)).\(ext ?? "")"
      dialogue.present(item: file.url, view: sourceView, subject: name)
      isFacsimile
      ? Usage.xtrack.share.faksimilelePage(issue: issue, pagina: "1")
      : Usage.xtrack.share.issueMoment(issue)
    }
  }
}

fileprivate extension Bool {
  var mode:String { self ? "P" : "M"}
}

fileprivate extension Issue {
  func key(pdf:Bool)->String{
    return self.date.key(pdf: pdf)
  }
}

fileprivate extension Date {
  func key(pdf:Bool)->String{
    return self.issueKey + pdf.mode
  }
}


fileprivate extension Device {
  //iPhone SE 1 Requested Speed Level: 2,  2 CPUs, 2013 MB RAM, is in *Normal* Power Mode (waitDuration: 0.9, parallelRequests: 3)
  //iPhone 7    Requested Speed Level: 2,  2 CPUs, 2000 MB RAM, is in *Normal* Power Mode (waitDuration: 0.9, parallelRequests: 3)
  //iPhone 7    Requested Speed Level: 1,  2 CPUs, 2000 MB RAM, is in *Low* Power Mode (waitDuration: 1.0, parallelRequests: 2)
  //iPhone 11   Requested Speed Level: 6,  6 CPUs, 3851 MB RAM, is in *Normal* Power Mode (waitDuration: 0.6, parallelRequests: 4)
  // parallelRequests are not used currently
  
  /// Return Parameters for optimized Remote Requests for IssueOverview Service
  /// Not so many parallel requests on slow devices, and not so often
  static var requestTimerInterval: TimeInterval{
    switch Self.speedLevel{
      case 1: return 0.5
      case 2: return 0.3
      case 3: return 0.2
      default: return 0.1
    }
  }
  
  /// evaluates speed level of current device from 1...6
  private static var speedLevel: Int {
    var level = 1
    let _cpuCount = Self.cpuCount
    let _ramMB = Self.ramMB
    let _lowPower = Self.lowPower
    
    if _cpuCount > 5 { level += 2 }
    else if _cpuCount > 3 { level += 1 }
    //1..3
    if _ramMB > 3500 { level += 2 }
    else if _ramMB > 2500 { level += 1 }
    //1..5
    if _lowPower == false { level += 1 }
    //1..6
    //print("Requested Speed Level: \(level),  \(_cpuCount) CPUs, \(_ramMB) MB RAM, is in \(_lowPower ? "*Low*" : "*Normal*") Power Mode")
    return level
  }
  private static var cpuCount: Int { ProcessInfo.processInfo.processorCount }
  private static var ramMB: UInt64 { ProcessInfo.processInfo.physicalMemory/(1024*1024) }
  private static var lowPower: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled == true }
}


fileprivate extension PublicationCycle {
  var multiplicator: Int {
    switch self {
      case .daily: return 1;
      case .weekly: return 7;
      case .monthly: return 30;
      case .yearly: return 365;
      case .quarterly: return 91;
      case .unknown: return 1;
    }
  }
}

class LoadOverviewHelperBusiness: DoesLog {
  // MARK: - Timer
  var timer: Timer?
  var sender: IssueOverviewService?
  
  func onTimer(_ closure: (()->())?){  timerHandler = closure  }
  
  private var timerHandler: (()->())? {
    didSet {
      timer?.invalidate()
      timer = nil
      guard timerHandler != nil else { return }
      self.timer
      = Timer.scheduledTimer(withTimeInterval: Device.requestTimerInterval,
                             repeats: true,
                             block: {[weak self] _ in
        guard self?.canHandleTimer() == true else { return }
        self?.timerHandler?()
      })
    }
  }
  
  // MARK: - Errors
  private var ovwGraphQlErrorCount = 0 { didSet {}}
  private var ovwGraphQlErrorAlertInterval = 5
  private var lastOvwGraphQlErrorAlertAtCount = 0
  private var isShowingFetchOvwDisableAlert = false
  
  var currentOverviewErrorResponse:Error? {
    didSet {
      guard let err = currentOverviewErrorResponse else {
        ovwGraphQlErrorCount = 0
        return
      }
      
      if err is GraphQlError {
        ovwGraphQlErrorCount +=  1
        showFetchOvwDisableAlertIfNeeded()
      }
    }
  }
  
  func showFetchOvwDisableAlertIfNeeded(_ force: Bool = false){
    guard !isShowingFetchOvwDisableAlert else { return }
    if ovwGraphQlErrorCount
        < lastOvwGraphQlErrorAlertAtCount + ovwGraphQlErrorAlertInterval { return }
    guard TazAppEnvironment.sharedInstance.isErrorReporting == false else { return }
    TazAppEnvironment.sharedInstance.isErrorReporting = true
    isShowingFetchOvwDisableAlert = true
    lastOvwGraphQlErrorAlertAtCount = ovwGraphQlErrorCount
    
    let cancelAction = UIAlertAction(title: "Weiter versuchen",
                                     style: .default) {[weak self] _ in
      TazAppEnvironment.sharedInstance.isErrorReporting = false
      self?.isShowingFetchOvwDisableAlert = false
      self?.log("FetchOvwDisableAlert...retry")
    }
    let stopAction = UIAlertAction(title: "Abruf anhalten",
                                   style: .destructive){[weak self] _ in
      self?.log("FetchOvwDisableAlert...STOP")
      self?.timer?.invalidate()
      self?.timer = nil
      TazAppEnvironment.sharedInstance.isErrorReporting = false
      self?.isShowingFetchOvwDisableAlert = false
      Notification.send(Const.NotificationNames.checkForNewIssues,
                        content: FetchNewStatusHeader.status.stoppedLoadOvw,
                        error: nil,
                        sender: self?.sender)
    }
    
    Alert.message(title: "Wiederholter Fehler",
                  message: "Beim Abruf der Daten für die Ausgabenübersicht kam es wiederholt zum einem Fehler.\nMöchten Sie das Abrufen der Daten für die Ausgabenübersicht bis zum Neustart der App anhalten?\nSie können noch auf lokal vorhandene Daten zugreifen.",
                  actions: [stopAction, cancelAction] )
  }
  
  var skipCount = 0
  var skipCountTarget = 0
  
  // MARK: - skip timer for load...
  func updateSkipCounts(){
    let timerIntervall = max(timer?.timeInterval ?? 0.1, 0.5)//>=0.1
    switch ovwGraphQlErrorCount {
      case 0: skipCountTarget = 0;
      case 1..<5: skipCountTarget = Int(5/timerIntervall) ///5s = 100 for 0.1 timeIntervall
      case 6..<15: skipCountTarget = Int(15/timerIntervall) ///15s = 100 for 0.1 timeIntervall
      default: skipCountTarget = Int(20/timerIntervall)
    }
  }
  
  func canHandleTimer()->Bool{
    if ovwGraphQlErrorCount == 0 { return true }///probably not required
    if TazAppEnvironment.sharedInstance.isErrorReporting { return false }
    if isShowingFetchOvwDisableAlert { return false }
    ///In case of ovw GraphQL Errors slow down server requests
    if skipCount < skipCountTarget {
      skipCount += 1
      return false
    }
    skipCount = 0
    return true
  }
}
