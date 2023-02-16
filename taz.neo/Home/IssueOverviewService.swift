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
 - load more issues
 - switch pdf/issue
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
  private var issues: [String:StoredIssue]
  
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
  
  func issue(at date: Date) -> StoredIssue? {
    return issues[date.key]
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
  
  func XXXapiLoadIssue(for date: Date) {
    
    
    let (start, count) = loadParameter(for: date)
    var lds:[String] = []
    for i in 0...count {
      var d = date
      d.addDays(-i)
      lds.append(d.key)
    }

    guard count > 0 else {
      return
    }
    
    guard lds.count > 0 else {
      return
    }
    
    //remember which issue Overviews are loaded currently
    loadingDates.append(contentsOf: lds)
    
    //skip if offline
#warning("Mybe improve here!")
    guard feederContext.isConnected else { return }
    
    log(">> Load \(count) Issues from: \(start.short)")
    
    self.feederContext.gqlFeeder.issues(feed: feed,
                                        date: start,
                                        count: count,
                                        isOverview: isFacsimile,
                                        returnOnMain: true) {[weak self] res in
      guard let self = self else { return }
      if let issues = res.value() {
        for issue in issues {
          let si = StoredIssue.persist(object: issue)
          self.issues[issue.date.key] = si
        }
        ArticleDB.save()
        for issue in issues {
          Notification.send(Const.NotificationNames.issueUpdate,
                            content: issue.date,
                            sender: self)
        }
      }
      else {//handle failures
          //Try again
        //handle offline?
      }
    }
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
    
    debug("Load Issues for: \(params.startDate), count: \(params.count)")
    
    self.feederContext.gqlFeeder.issues(feed: feed,
                                        date: params.startDate,
                                        count: params.count,
                                        isOverview: false,
                                        returnOnMain: true) {[weak self] res in
      guard let self = self else { return }
      self.debug("Finished load Issues for: \(params.startDate), count: \(params.count)")
      if let issues = res.value() {
        for issue in issues {
          let si = StoredIssue.persist(object: issue)
          self.issues[issue.date.key] = si
          Notification.send(Const.NotificationNames.issueUpdate,
                            content: issue.date,
                            sender: self)
        }
        ArticleDB.save()
      }
      else {
        self.log("error in preview load from \(params.startDate) count: \(params.count)")
      }
      self.apiLoadNext()
    }
  }
  
  func apiLoadNext(){
    guard let next = lc.next else { return }
    apiLoadPreview(for: next, isAutoEnqueued: true)
  }
  
  
  func getIssue(at index: Int) -> StoredIssue? {
    if index + 3 > issues.count {
      if let lastIssue = issues.sorted(by: { $0.0 > $1.0 }).last?.key as? Date {
        let sIssues = StoredIssue.issuesInFeed(feed: feed)
        for issue in sIssues {
          issues[issue.date.key] = issue
        }
      }
    }
    
    
    guard let date = date(at: index) else { return nil }
    guard let issue = issues[date.key] else {
#warning("ASYNC TODO")
      //      loadOverviews(fromDate: date, isPdf: isFacsimile)
      return nil
    }
    return issue
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
  
  
  

  //
  //  func loadOverviews(fromDate: Date, isPdf: Bool) async -> [UIImage]?{
  //
  //  }
  
  //  func loadOverview(fromDate: Date, isPdf: Bool) async -> [UIImage]?{
  //    do {
  //      return try await withCheckedThrowingContinuation { continuation in
  //        loadOverview(fromDate: fromDate, isPdf: isPdf) { result in
  //          continuation.resume(with: result)
  //        }
  //      }
  //    }
  //    catch {
  //      return nil
  //    }
  //  }
  
  //  func loadOverview2(fromDate: Date, isPdf: Bool) async -> [UIImage]?{
  //    return nil
  ////    return try await withCheckedThrowingContinuation { continuation in
  ////      loadOverview(fromDate: fromDate, isPdf: isPdf) { result in
  ////        continuation.resume(with: result)
  ////      }
  ////    }
  ////    catch {
  ////      return nil
  ////    }
  //  }
  
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

  }
  
//  func addIssue(issue: StoredIssue, isError: Bool = false){
//    if let oldIssue = issues[issue.date] {
//      debug("overwriting \(oldIssue) with: \(issue)")
//    }
//    issues[issue.date] = issue
//  }
  
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
