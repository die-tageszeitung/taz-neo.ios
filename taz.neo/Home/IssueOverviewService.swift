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
 
 Next Steps:
 open issue
 download button
 
 goto date
 
 
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
typealias IssueCellData = (date: Date, issue:StoredIssue?, image: UIImage?)

/// using Dates short String Representation for store and find issues for same date, ignore time
fileprivate extension Date { var key : String { short } }

class IssueOverviewService: NSObject, DoesLog {
  
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  let loadPreviewsQueue = DispatchQueue(label: "apiLoadPreviewQueue",qos: .userInitiated)
  
  internal var feederContext: FeederContext
  var feed: StoredFeed
  
  public private(set) var issueDates: [Date]
  public var firstIssueDate: Date { feed.firstIssue }
  public var lastIssueDate: Date { feed.lastIssue }
  private var issues: [String:StoredIssue]
  
  
  /// cell data to display issue cell in caroussel or tiles
  /// start download for issuePreview if no data available
  /// start download for image if no image available
  /// - Parameter index: index for requested cell
  /// - Returns: cell data if any with date, issue if locally available, image if locally available
  func cellData(for index: Int) -> IssueCellData? {
    guard let date = date(at: index) else {
      error("No Entry for: \(index), This should not be requested")
      return nil
    }
    guard let issue = issue(at: date) else {
      apiLoadPreview(for: date)
      return IssueCellData(date: date, issue: nil, image: nil)
    }
    let img = self.storedImage(issue: issue, isPdf: isFacsimile)
    if img == nil { apiLoadMomentImages(for: issue, isPdf: isFacsimile) }
    return IssueCellData(date: issue.date, issue: issue, image: img)
  }
  
  func date(at index: Int) -> Date? {
    return issueDates.valueAt(index)
  }
  
  func nextIndex(for date: Date) -> Int {
    return issueDates.firstIndex(where: { $0 <= date }) ?? 0
  }
  
  var carousselUpdateStatusButton: DownloadStatusButton?
  var carousselActiveDownloadIssue: StoredIssue?
  
  func download(issueAtIndex: Int?, updateStatusButton: DownloadStatusButton?) {
    updateStatusButton?.indicator.downloadState = .waiting
    guard let idx = issueAtIndex,
        let issue = issue(at: idx),
          hasDownloadableContent(issue: issue) else {
      self.log("not downloading for idx: \(issueAtIndex ?? -1)")
      return
    }
    updateStatusButton?.indicator.percent = 0.0
    
    self.carousselUpdateStatusButton = updateStatusButton
    self.carousselActiveDownloadIssue = issue
    
    feederContext.getCompleteIssue(issue: issue,
                                   isPages: self.isFacsimile,
                                   isAutomatically: false)
  }
  
  func issueDownloadState(at index: Int) -> DownloadStatusIndicatorState {
    guard let d = date(at: index) else { return .notStarted }
    guard let issue = issue(at: d) else { return .notStarted }
    if issue.isDownloading { return .process }
    return feederContext.needsUpdate(issue: issue,toShowPdf: isFacsimile)
    ? .notStarted
    : .done
  }
  
  func issue(at date: Date) -> StoredIssue? {
    return issues[date.key]
  }
  
  func issue(at index: Int) -> StoredIssue? {
    /* WTF? 
    if index + 3 > issues.count {
      if let lastIssue = issues.sorted(by: { $0.0 > $1.0 }).last?.key as? Date {
        let sIssues = StoredIssue.issuesInFeed(feed: feed)
        for issue in sIssues {
          issues[issue.date.key] = issue
        }
      }
    }
*/
    guard let date = issueDates.valueAt(index) else { return nil }
    return issue(at: date)
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
  
  var loadingDates: [String] = []
  
  func checkForNewIssues() {
    log("ToDo, check for new Issues")
  }
  
  
  /// server request data
  /// calculates which is the newest to request issue date from server and how many are to load
  /// limit is max 20
  /// lookup in loades issues and loadingDates
  /// - Parameter date: date to lookup
  /// - Returns: date for server request and limit
  func loadParameter(for date: Date) -> (Date, Int) {
    var start: Date?
    var count = 0
    for i in -10...10 {
      var d = date
      d.addDays(-i)
      if !issueDates.contains(d) { continue }//ignore future and not existing dates
      if issue(at: d.key) != nil {
        //skip its loaded
        if start == nil { continue } //before Date
        else { break } //after date, limit fount
      }
      if loadingDates.contains(d.key) {
        //skip its loading
        if start == nil { continue } //before Date
        else { break } //after date, limit fount
      }
      if start == nil { start = d }
      count += 1
    }
    return (start ?? date , count)
  }
   
  func apiLoadPreview(for date: Date, isAutoEnqueued:Bool = false) {
    if isAutoEnqueued && issue(at: date) != nil {
      debug("Already loaded: \(date.key) skip loading")
      apiLoadNext()
      return
    }
    
    guard let params = loadingParameters(date: date) else {
      debug("No valid Loading for: \(date.key); isAutoEnqueued: \(isAutoEnqueued) skip loading")
      apiLoadNext()
      return
    }
    
    debug("Load Issues for: \(params.startDate.short), count: \(params.count)")
    
    self.feederContext.gqlFeeder.issues(feed: feed,
                                        date: params.startDate,
                                        count: params.count,
                                        isOverview: false,
                                        returnOnMain: true) {[weak self] res in
      guard let self = self else { return }
      var newIssues: [StoredIssue] = []
      self.debug("Finished load Issues for: \(params.startDate.short), count: \(params.count)")
      let start = Date()
      if let issues = res.value() {
        for issue in issues {
          newIssues.append(StoredIssue.persist(object: issue))
        }
        self.log("Finished load Issues for: \(params.startDate.short) DB Update duration: \(Date().timeIntervalSince(start))s on Main?: \(Thread.isMain)")
        ArticleDB.save()
        for si in newIssues {
          self.issues[si.date.key] = si
          Notification.send(Const.NotificationNames.issueUpdate,
                            content: si.date,
                            sender: self)
        }
      }
      else {
        self.log("error in preview load from \(params.startDate.short) count: \(params.count)")
      }
      self.apiLoadNext()
    }
  }
  
  func apiLoadNext(){
    guard let next = lc.next else { return }
    apiLoadPreview(for: next, isAutoEnqueued: true)
  }
  
  func hasDownloadableContent(issue: Issue) -> Bool {
    guard let sIssue = issue as? StoredIssue else { return true }
    return feederContext.needsUpdate(issue: sIssue,toShowPdf: isFacsimile)
  }
  
  func getCompleteIssue(issue: Issue) {
    guard let sIssue = issue as? StoredIssue else { return }
    feederContext.getCompleteIssue(issue: sIssue,
                                   isPages: self.isFacsimile,
                                   isAutomatically: false)
  }
  
  
  
  
  func apiLoadMomentImages(for issue: StoredIssue, isPdf: Bool){
    loadPreviewsQueue.async {[weak self] in
      self?.apiLoadMomentImagesQ(for:issue, isPdf: isPdf)
    }
  }
  #warning("TODO ENSURE MAX 5 PARALLEL DOWNLOADS NOT THHIS WAY!!")
  func apiLoadMomentImagesQ(for issue: StoredIssue, isPdf: Bool) {
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
//    onThread {
      //check if in temp Dir?
      self.feederContext.dloader
        .downloadIssueFiles(issue: issue, files: files) {[weak self] err in
          let img = self?.storedImage(issue: issue, isPdf: isPdf)
          if img == nil {
            self?.debug("something went wrong: downloaded file did not exist!")
          }
          let icd = IssueCellData(date: issue.date, issue: issue, image: img)
          Notification.send(Const.NotificationNames.issueUpdate,
                            content: issue.date,
                            sender: self)
        }
//    }
  }
  
  
  func storedImage(issue: StoredIssue, isPdf: Bool) -> UIImage? {
    return feederContext.storedFeeder.momentImage(issue: issue,
                                                  isPdf: isPdf,
                                                  usePdfAlternative: false)
  }
  
  func updateIssue(issue:StoredIssue){
    self.issues[issue.date.key] = issue
  }
  
  func setup(){
    setupCarousselProgressButton()
  }
  
  func setupCarousselProgressButton(){
    Notification.receive("issueProgress", closure: { [weak self] notif in
      guard let self,
      let btn = self.carousselUpdateStatusButton,
      let issue = self.carousselActiveDownloadIssue,
      (notif.object as? Issue)?.date == issue.date else { return }
      if let (loaded,total) = notif.content as? (Int64,Int64) {
        let percent = Float(loaded)/Float(total)
        if percent > 0.05 {
          btn.indicator.downloadState = .process
          btn.indicator.percent = percent
        }
        if percent == 1.0 {
          self.carousselUpdateStatusButton = nil
          self.carousselActiveDownloadIssue = nil
        }
      }
    })
  }
    
  /// Initialize with FeederContext
  public init(feederContext: FeederContext) {
    self.feederContext = feederContext
    self.feed = feederContext.defaultFeed
    issueDates = feed.publicationDates?.dates.sorted().reversed() ?? []
    
    issues = StoredIssue.issuesInFeed(feed: feed).reduce(into: [String: StoredIssue]()) {
      $0[$1.date.key] = $1
    }
    super.init()
    setup()
  }
  
  private var lc = LoadCoordinator()
}

fileprivate typealias LoadingParams = (startDate: Date, count: Int)


/// A Helper to select next loads
fileprivate class LoadCoordinator: NSObject, DoesLog {
  fileprivate var loadingDates: [String] = []
  fileprivate var nextDates: [Date] = []
//  var isLoading: Bool = false {
//    didSet {
//      //In Case of Errors allow another Loader after 10s
//      if isLoading == false { return }
//      onThreadAfter(10.0) {[weak self] in
//        self?.isLoading = false
//      }
//    }
//  }
  
  var next: Date? {
    reduceNextIfNeeded()
    return nextDates.popLast()
  }
  
  ///Theory: fast scrolling in List for 3 years, prevent load of 200 Issues, only load 30 most relevant issues
  func reduceNextIfNeeded(){
    if nextDates.count < 30 { return }
    nextDates = nextDates[nextDates.endIndex - 20 ..< nextDates.endIndex].sorted()
  }
  
//  func remove(_ datesToRemove: [Date]){
//    let keysToRemove = datesToRemove.enumerated().compactMap{$1.key}
//    loadingDates
//    = loadingDates.enumerated().compactMap{ keysToRemove.contains($1.key) ? nil : $1 }
//  }
}

fileprivate extension IssueOverviewService {
  /// Helper to create API Load Parameters
  /// prevents to load a issue overview twice
  /// helps to enqueue load overview requests
  /// - Parameter date: date for requested issue
  /// - Returns: load params for api call or nil if load not needed
  func loadingParameters(date: Date)->LoadingParams?{
    if lc.loadingDates.contains(where: { d in return d == date.key }) {
      debug("Already loading: \(date.key) skip loading")
      return nil
    }
    //API params from date and count
    var start: Date?
    var count = 0
    var loadingDates:[String] = []
    
    for i in -10...30 {
      var d = date
      d.addDays(-i)
      if !issueDates.contains(d) { continue }//ignore future and not existing dates
      if issue(at: d.key) != nil ||  lc.loadingDates.contains(d.key) {
        //skip its loaded
        if start == nil { continue } //before Date
        else { break } //after date, limit fount
      }
      if start == nil { start = d }
      count += 1
      loadingDates.append(d.key)
      if count >= 10 { break }//do not load more than 20 Issue Previews at once
    }
    
    guard let start = start else { return nil }
    if count == 0 { return nil }//impossible
    lc.loadingDates.append(contentsOf: loadingDates)
    return LoadingParams(startDate: start, count: count)
  }
}
