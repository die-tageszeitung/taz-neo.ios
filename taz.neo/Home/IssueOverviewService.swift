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
  func cellData(for index: Int, maxPreviewLoadCount: Int) -> IssueCellData? {
    guard let publicationDate = date(at: index) else {
      error("No Entry for: \(index), This should not be requested")
      return nil
    }
    guard let issue = issue(at: publicationDate.date) else {
      apiLoadIssueOverview(for: publicationDate.date, count: maxPreviewLoadCount)
      log("request preview for: \(index) date: \(publicationDate.date.short)")
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
    
    let needUpdate = feederContext.needsUpdate(issue: issue, toShowPdf: isFacsimile)
    log("issue for \(index) date: \(d.date) is \(needUpdate ? "notStarted" : "done")")
    return needUpdate ? .notStarted : .done
  }
  
  func issue(at date: Date) -> StoredIssue? {
    return issues[date.issueKey]
  }
  
  func issue(at index: Int) -> StoredIssue? {
    guard let date = publicationDates.valueAt(index) else { return nil }
    let issue = issue(at: date.date)
    if let issue = issue, (issue.sections?.count ?? 0 == 0 || issue.allArticles.count == 0) {
      debug("Issue: \(issue.date.short) has \(issue.sections?.count ?? 0) Ressorts and \(issue.allArticles.count) articles.")
      debug("Issue isComplete: \(issue.isComplete), isReduced: \(issue.isReduced) isOvwComplete: \(issue.isOvwComplete) isDownloading: \(issue.isDownloading) isOverview: \(issue.isOverview)")
      debug("This may fail!")
      apiLoadIssueOverview(for: date.date, count: 1)
    } else {
      //update Issue
      apiLoadIssueOverview(for: date.date, count: 1)
    }
    return issue
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
  var lastUpdateCheck = Date().addingTimeInterval(-checkOnResumeEvery)///set to init time to simplify; on online app start auto check is done and on reconnect
  static let checkOnResumeEvery:TimeInterval = 5*60
  
  func removeFromLoad(date: Date){
    additionallyRemoveFromLoading.append(date.issueKey)
    loadFaildPreviews.removeAll(where: { $0.date.issueKey == date.issueKey })
  }
  
  ///Optimized load previews
  ///e.g. called on jump to date + ipad need to load date +/- 5 issues
  ///or on scrolling need to load date + 5..10 issues
  ///           5 or 10 5= more stocking because next laod needed //// 10 increased loading time **wrong beause images are loaded asyc in another thread!**
  func apiLoadIssueOverview(for date: Date, count: Int) {
    
    if loadingDates.contains(where: { return $0==date.issueKey}) {
      debug("Already loading: \(date.issueKey), skip loading")
      return
    }
    
    let availableIssues = issues.map({ $0.value.date.issueKey })
    var currentLoadingDates: [Date] = []
    
    var start:Date?
    var end:Date?
    
    ///set the optimized request, do not load dates twice
    for i in -count/2...0 {//-3,-2,-1,0,1,2,3
      
      if i == 0 {
        if start == nil { start = date }
        if end == nil { end = date }
        break
      }
      
      var fd = date
      fd.addDays(i)
      if start != nil
          && !(availableIssues.contains(fd.issueKey) || loadingDates.contains(fd.issueKey)){
        start = fd
      }
      
      var td = date
      td.addDays(-i)
      if end != nil
          && !(availableIssues.contains(td.issueKey) || loadingDates.contains(td.issueKey)){
        end = fd
      }
      
      if start != nil && end != nil { break }
    }

    guard let start = start, let end = end else { error("Logic error");return }///LogicError
    
    var i = 0
    while true {
      var d = start
      d.addDays(i)
      currentLoadingDates.append(d)
      i += 1
      if d == end { break }
    }
     
    let sCurrentLoadingDates = currentLoadingDates.map{$0.issueKey}
    addToLoading(sCurrentLoadingDates)
    
    self.feederContext.gqlFeeder.issues(feed: feed,
                                        date: start,
                                        count: i,
                                        isOverview: true,
                                        returnOnMain: true) {[weak self] res in
      guard let self = self else { return }
      var newIssues: [StoredIssue] = []
      self.debug("Finished load Issues for: \(date.short), count: \(count)")
      
      if let err = res.error() as? FeederError {
        self.handleDownloadError(error: err)
      } else if let err = res.error() as? URLError {
        ///offline
        self.debug("failed to load \(err)")
        self.lastLoadFailed = FailedLoad(date, count)
      } else if let err = res.error(){
        self.debug("failed to load \(err)")
        ///unknown
      }
      if let issues = res.value() {
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
        }
        self.log("Finished load Issues for: \(date.short) DB Update duration: \(Date().timeIntervalSince(start))s on Main?: \(Thread.isMain)")
        ArticleDB.save()
        for si in newIssues {
          self.updateIssue(issue: si, loadImageIfNeeded: true, notify: true)
        }
      }
      self.removeFromLoading(sCurrentLoadingDates)
    }
  }
  
  func hasDownloadableContent(issue: Issue) -> Bool {
    guard let sIssue = issue as? StoredIssue else { return true }
    return feederContext.needsUpdate(issue: sIssue,toShowPdf: isFacsimile)
  }
  
  var additionallyRemoveFromLoading: [String] = []
  func removeFromLoading(_ dates: [String]){
    var datesToRemove:[String] = dates
    if additionallyRemoveFromLoading.count > 0 {
      datesToRemove.append(contentsOf: additionallyRemoveFromLoading)
      additionallyRemoveFromLoading = []
    }
    
    loadingDates
    = loadingDates.enumerated().filter { !datesToRemove.contains($0.element) }.map { $0.element }
  }
  
  func addToLoading(_ dates: [String]){
    loadingDates.append(contentsOf: dates)
  }
  
  func continueFaildPreviewLoad(){
    if loadFaildPreviews.count == 0 { return }
    log("continue load for: \(loadFaildPreviews.count) failed preview loads")
    let issuesToLoad = loadFaildPreviews
    loadFaildPreviews = []
    for issue in issuesToLoad {
      apiLoadMomentImages(for: issue, isPdf: isFacsimile)
    }
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
          if img != nil && err == nil {
            issue.isOvwComplete = true
            ArticleDB.save()
            Notification.send(Const.NotificationNames.issueUpdate,
                              content: issue.date,
                              sender: self)
          }
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
  
  func updateIssue(issue:StoredIssue, loadImageIfNeeded: Bool, notify: Bool){
    if self.storedImage(issue: issue, isPdf: isFacsimile) == nil {
      apiLoadMomentImages(for: issue, isPdf: isFacsimile)
    } else {
      Notification.send(Const.NotificationNames.issueUpdate,
                        content: issue.date,
                        sender: self)
    }
    self.issues[issue.date.issueKey] = issue
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
    
//    if insertIp.count + movedIp.count + usedOld.count > 10 {
//    if insertIp.count + usedOld.count > 10 {
//      ///sledge hammer option, probably not needed due just 1 insert at index 2?
//      ///better compare counts?
//      publicationDates = newPubDates
//      collectionView.reloadData()
//      return true
//    }
    
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
      self?.continueFaildPreviewLoad()
    }
  }
  
  private var lc = LoadCoordinator()
}

// MARK: - extension Check for New PublicationDates (Issues)
extension IssueOverviewService {
  
  /// check for new issues from pull to refresh (force == true)
  /// and app will enter foreground
  /// - Parameter force: ensure check
  func checkForNewIssues() {
    feederContext.checkForNewIssues()
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
