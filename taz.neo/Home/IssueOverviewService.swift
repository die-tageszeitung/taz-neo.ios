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
  let loadPreviewsGroup = DispatchGroup()
  let loadPreviewsSemaphore = DispatchSemaphore(value: 3)
  
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
      apiLoadPreview(for: date, count: 6)
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
  
  /// Date keys which are currently loading the preview
  var loadingDates: [String] = []
  
//  /// Date keys which are currently loading the preview
//  var loadingDates: [String] = []
  
  func checkForNewIssues() {
    apiLoadPreview(for: nil, count: 3)
  }

  func apiLoadPreview(for date: Date?, count: Int) {
    if let date, issue(at: date) != nil {
      debug("Already loaded: \(date.key) skip loading")
      return
    }
    
    let d1 = date ?? Date.init(timeIntervalSince1970: 0)
    
    if loadingDates.contains(where: { return $0==d1.key}) {
      debug("Already loading: \(date?.key ?? "latest"), skip loading")
      return
    }
    
    var count = count
    
    let availableIssues = issues.map({ $0.value.date.key })
    var currentLoadingDates: [String] = []
    
    if let date {
      for i in 0...count {
        var d = date
        d.addDays(-i)
        if availableIssues.contains(d.key) { count = i+1; break }
        if loadingDates.contains(d.key) { count = i+1; break }
        currentLoadingDates.append(d.key)
      }
    } else {
      currentLoadingDates.append(d1.key)
    }
    
    addToLoading(currentLoadingDates)
    
    debug("Load Issues for: \(date?.short ?? "-"), count: \(count)")
    
    self.feederContext.gqlFeeder.issues(feed: feed,
                                        date: date,
                                        count: count,
                                        isOverview: true,
                                        returnOnMain: true) {[weak self] res in
      guard let self = self else { return }
      var newIssues: [StoredIssue] = []
      self.debug("Finished load Issues for: \(date?.short ?? "-"), count: \(count)")
      let start = Date()
      if let issues = res.value() {
        for issue in issues {
          newIssues.append(StoredIssue.persist(object: issue))
        }
        self.log("Finished load Issues for: \(date?.short ?? "-") DB Update duration: \(Date().timeIntervalSince(start))s on Main?: \(Thread.isMain)")
        ArticleDB.save()
        for si in newIssues {
          self.issues[si.date.key] = si
          Notification.send(Const.NotificationNames.issueUpdate,
                            content: si.date,
                            sender: self)
        }
        if date == nil {
          Notification.send(Const.NotificationNames.reloadIssueList)
        }
      }
      else {
        self.log("error in preview load from \(date?.short ?? "-") count: \(count)")
      }
      self.removeFromLoading(currentLoadingDates)
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
  
  
  func getCompleteIssue(issue: Issue) {
    guard let sIssue = issue as? StoredIssue else { return }
    feederContext.getCompleteIssue(issue: sIssue,
                                   isPages: self.isFacsimile,
                                   isAutomatically: false)
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
      self.debug("enqueue download \(files.count) Issue files for \(issue.date.key)")
      self.loadPreviewsGroup.enter()
      self.loadPreviewsSemaphore.wait()
      self.debug("do download \(files.count) Issue files for \(issue.date.key)")
      self.feederContext.dloader
        .downloadIssueFiles(issue: issue, files: files) {[weak self] err in
          self?.debug("done download \(files.count) Issue files for \(issue.date.key)")
          let img = self?.storedImage(issue: issue, isPdf: isPdf)
          if img == nil {
            self?.debug("something went wrong: downloaded file did not exist!")
          }
          let icd = IssueCellData(date: issue.date, issue: issue, image: img)
          ///Danger
          Notification.send(Const.NotificationNames.issueUpdate,
                            content: issue.date,
                            sender: self)
          self?.loadPreviewsGroup.leave()
          self?.loadPreviewsSemaphore.signal()
        }
      
    }
  }
  
  func storedImage(issue: StoredIssue, isPdf: Bool) -> UIImage? {
    return feederContext.storedFeeder.momentImage(issue: issue,
                                                  isPdf: isPdf,
                                                  usePdfAlternative: false)
  }
  
  func updateIssue(issue:StoredIssue){
    self.issues[issue.date.key] = issue
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
    Notification.receive(Const.NotificationNames.reloadIssueDates) {[weak self] _ in
      if let newDates = self?.feed.publicationDates?.dates.sorted() {
        self?.issueDates = newDates.reversed()
      }
    }
    setupCarousselProgressButton()
  }
  
  private var lc = LoadCoordinator()
}

fileprivate typealias LoadingParams = (startDate: Date?, count: Int)


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
