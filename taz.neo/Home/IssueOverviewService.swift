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
 outsources FeederContext helper to get rid of the EierLegendeWollMilchSau
  
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
  var timer: Timer?
  var skipNextTimer = false
  
  public private(set) var publicationDates: [PublicationDate]
  
  public var firstIssueDate: Date { feed.firstIssue }
  public var lastIssueDate: Date { feed.lastIssue }
  
  func issue(at date: Date) -> StoredIssue? {
    return issues[date.issueKey]
  }
  
  private var issues: [String:StoredIssue]
  
  private var requestedRemoteItems: [String:Date] = [:]
  private var loadingIssues:[String:Date] = [:]
  private var loadingImages:[String:Date] = [:]
  private var requestedItemsSyncQueue
  = DispatchQueue(label: "IssueOverviewService.LoadingItems")
  
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
    print(">> request cell data for \(publicationDate.date.issueKey)")
    let issue = issue(at: publicationDate.date)
    var img: UIImage?
    
    if let issue = issue {
      img = self.storedImage(issue: issue, isPdf: isFacsimile)
    }

    if issue == nil || img == nil {
      skipNextTimer = true
      addToLoadFromRemote(date: publicationDate.date)
    }
        
    return IssueCellData(date: publicationDate, issue: issue, image: img)
  }
  
  func addToLoadFromRemote(date: Date) {
    if requestedRemoteItems[date.issueKey] != nil { return }
    print("Add issue to load for: \(date.issueKey)")
    requestedItemsSyncQueue.async { [weak self] in
      self?.requestedRemoteItems[date.issueKey] = date
    }
  }
  
  
  @discardableResult
  /// removed a date from current loading items
  /// - Parameter date: date to remove
  /// - Returns: bool if removed, false if already removed (used to notify cells)
  func removeFromLoadFromRemote(date: Date, verifyImageAvailable: Bool = false) -> Bool {
    if requestedRemoteItems[date.issueKey] == nil { return false }
    print(">>x> removeFromLoadFromRemote: \(date.issueKey) onlyIfIssuea: \(verifyImageAvailable)")
    if verifyImageAvailable,
       let issue = issue(at: date),
       self.storedImage(issue: issue, isPdf: isFacsimile) == nil {
      print(">>x> NOT removed FromLoadFromRemote: \(date.issueKey) due issue is there but no image")
      return false
    }
    requestedItemsSyncQueue.async { [weak self] in
      self?.requestedRemoteItems[date.issueKey] = nil
    }
    return true
  }
  
  func checkLoad2(){
    if skipNextTimer == false {
      loadMissingIfPossible()
    }
    skipNextTimer  = false
  }
  
  private func loadMissingIfPossible(){
    guard self.requestedRemoteItems.count > 0 else { return }
    requestedItemsSyncQueue.async { [weak self] in
      print(">> load missing #1: \(self?.requestedRemoteItems.keys)")
      let dates = self?.requestedRemoteItems.values.sorted()
      var missingIssues:[Date] = []
      for date in dates ?? [] {
        if let issue = self?.issue(at: date) {
          self?.updateIssue(issue: issue)
        } else if self?.loadingIssues[date.issueKey] == nil {
          missingIssues.append(date)
        }
      }
      guard let oldest = missingIssues.first,
            let newest = missingIssues.last else { return }
      ///ignoring public holidays and sundays, need to add 1 to load itself or the next one
      let days = 1 + (newest.timeIntervalSinceReferenceDate - oldest.timeIntervalSinceReferenceDate)/(3600*24)
      onThread {[weak self] in
        self?.apiLoadIssueOverview(for: newest, count: Int(days.nextUp))
      }
      
    }
  }
  
  private func issue(at index: Int) -> StoredIssue? {
    guard let publicationDate = date(at: index) else { return nil }
    return issue(at: publicationDate.date)
  }
  
  private func hasDownloadableContent(issue: Issue) -> Bool {
    guard let sIssue = issue as? StoredIssue else { return true }
    return feederContext.needsUpdate(issue: sIssue,toShowPdf: isFacsimile)
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
  
  func date(at index: Int) -> PublicationDate? {
    return publicationDates.valueAt(index)
  }
  
  func nextIndex(for date: Date) -> Int {
    return publicationDates.firstIndex(where: { $0.date <= date }) ?? 0
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
    
    let needUpdate = feederContext.needsUpdate(issue: issue, toShowPdf: isFacsimile)
    log("issue for \(index) date: \(d.date) is \(needUpdate ? "notStarted" : "done")")
    return needUpdate ? .notStarted : .done
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

  var lastUpdateCheck = Date().addingTimeInterval(-checkOnResumeEvery)///set to init time to simplify; on online app start auto check is done and on reconnect
  static let checkOnResumeEvery:TimeInterval = 5*60
  
  
  
  ///Optimized load previews
  ///e.g. called on jump to date + ipad need to load date +/- 5 issues
  ///or on scrolling need to load date + 5..10 issues
  ///           5 or 10 5= more stocking because next laod needed //// 10 increased loading time **wrong beause images are loaded asyc in another thread!**
  ///           **ATTENTION** LIMIT IS CURRENTLY 40!
  func apiLoadIssueOverview(for date: Date, count: Int) {
    var count = count
    if count < 1 { count = 1 }
    else if count >= 10 { count = 10 }//API Limit is currently 20
    print(">> load issues from: \(date.issueKey) count: \(count)")
    
    var d = date
    var lds:[String] = []
    for i in 0...count {
      d.addDays(1)
      lds.append(d.issueKey)
      loadingIssues[d.issueKey] = d
    }
        
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
            let sIssue = StoredIssue.persist(object: issue)
            newIssues.append(sIssue)
          }
          loadedDates.append(issue.date)
        }
        ArticleDB.save()
        #warning("20 issues may take a long time!")
        self.log("Finished load&persist Issues for: \(date.issueKey) count: \(count) DB Update duration: \(Date().timeIntervalSince(start))s")
        for si in newIssues {
          self.updateIssue(issue: si)
        }
      }
      requestedItemsSyncQueue.async { [weak self] in
        for sdate in lds { self?.loadingIssues[sdate] = nil }
      }
    }
  }
  
  //STEP 2
  func apiLoadMomentImages(for issue: StoredIssue, isPdf: Bool) {
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
    
    if dlFiles.count == 0 {
      self.debug("no file to download for Issue \(issue.date.issueKey)")
      self.notifyIssueOwvAvailable(issue: issue)
      return
    }
    self.debug("do download \(dlFiles.count) Issue files for \(issue.date.issueKey)")
    self.feederContext.dloader
      .downloadIssueFiles(issue: issue, files: files) {[weak self] err in
        self?.debug("done download \(files.count) Issue files for \(issue.date.issueKey) 7XßC3")
        let img = self?.storedImage(issue: issue, isPdf: isPdf)
        if img != nil && err == nil {
          self?.notifyIssueOwvAvailable(issue: issue)
        }
        else {
          var msg = "something went wrong:"
          msg += img == nil ? " downloaded file did not exist!" : ""
          msg += err != nil ? " Error: \(String(describing: err))" : ""
          msg += " for: \(issue.date.issueKey) 7XßC3"
          self?.log(msg)
        }
      }
  }
  
  func storedImage(issue: StoredIssue, isPdf: Bool) -> UIImage? {
    return feederContext.storedFeeder?.momentImage(issue: issue,
                                                  isPdf: isPdf,
                                                  usePdfAlternative: false)
  }
  
  #warning("MY REFACTOR")
  func updateIssue(issue:StoredIssue){
    if Thread.isMainThread == false {
      onMain {[weak self] in self?.updateIssue(issue: issue) }
      return
    }
    if self.storedImage(issue: issue, isPdf: isFacsimile) == nil {
      apiLoadMomentImages(for: issue, isPdf: isFacsimile)
    } else {
      notifyIssueOwvAvailable(issue: issue)
    }
    self.issues[issue.date.issueKey] = issue
  }
  
  func notifyIssueOwvAvailable(issue:StoredIssue){
    if removeFromLoadFromRemote(date: issue.date, verifyImageAvailable: true) {
      guard let pDate = publicationDates.first(where: { $0.date == issue.date }) else {
        error("Not found the given Publication Date. This Should not happen!")
        return
      }
      ///notify only if still  requested
      let img = self.storedImage(issue: issue, isPdf: isFacsimile)
     
      let data = IssueCellData(date: pDate,
                               issue: issue,
                               image: img)
      ensureMain {
        Notification.send(Const.NotificationNames.issueUpdate,
                          content: data)
      }
    }
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
    
    ///Update downloaded Issue Reference
    Notification.receive("issue"){ [weak self] notif in
      self?.updateIssues()
    }
    ///Update downloaded Issue Reference
    Notification.receive("issueStructure"){ [weak self] notif in
      self?.updateIssues()
    }
    
    Notification.receive("issueOverview") { [weak self] notif in
      self?.updateIssues()
    }
    
    Notification.receive(Const.NotificationNames.feederReachable) {[weak self] _ in
      self?.updateIssues()
//      self?.continueFaildPreviewLoad()
    }
    
    Notification.receive(Const.NotificationNames.issueMomentRequired) {[weak self] notif in
      if let issue = notif.content as? StoredIssue {
        self?.apiLoadMomentImages(for: issue, isPdf: self?.isFacsimile ?? false)
      }
      else {
//        self?.continueFaildPreviewLoad()
      }
    }
    
    self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: {[weak self] _ in
      self?.checkLoad2()
     })
  }
  
  private var lc = LoadCoordinator()
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
