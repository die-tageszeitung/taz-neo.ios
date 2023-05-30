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
typealias IssueCellData = (date: PublicationDate, issue:StoredIssue?, image: UIImage?)
typealias EnqueuedMomentLoad = (issue: StoredIssue, files: [FileEntry], isPdf: Bool)

/// using Dates short String Representation for store and find issues for same date, ignore time
extension Date { var issueKey : String { short } }

class IssueOverviewService: NSObject, DoesLog {
  
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  let loadPreviewsQueue = DispatchQueue(label: "apiLoadPreviewQueue",qos: .userInitiated)
  let loadPreviewsGroup = DispatchGroup()
  let loadPreviewsLock = NSLock()
  var loadPreviewsStack: [EnqueuedMomentLoad] = []
  let loadPreviewsSemaphore = DispatchSemaphore(value: 3)
  
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
  
//  /// Date keys which are currently loading the preview
//  var loadingDates: [String] = []
  
  
  @discardableResult
  /// checks for new issues, if not currently doing this
  /// - Returns: true if check will be executed; false if check is still in progress
  func checkForNewIssues2() -> Bool {
    let key = Date.init(timeIntervalSince1970: 0).issueKey
    if loadingDates.contains(where: { return $0==key}) {
      return false
    }
    apiLoadPreview(for: nil, count: 3)
    return true
  }
  
  
  var isCheckingForNewIssues = false
  
  func checkForNewIssues() -> Bool{
    if isCheckingForNewIssues { return false }
    feederContext.updatePublicationDates(feed: feederContext.defaultFeed)
    return true
  }

  func apiLoadPreview(for date: Date?, count: Int) {
//    feederContext.
    if let date, issue(at: date) != nil {
      debug("Already loaded: \(date.issueKey) skip loading")
      return
    }
    
    if let date = date, loadingDates.contains(where: { return $0==date.issueKey}) {
      debug("Already loading: \(date.issueKey), skip loading")
      return
    }
    
    var count = count
    
    let availableIssues = issues.map({ $0.value.date.issueKey })
    var currentLoadingDates: [Date] = []
    
    if let date {
      for i in -count/2...count/2 {
        var d = date
        d.addDays(-i)
        if availableIssues.contains(d.issueKey) { count = i+1; break }
        if loadingDates.contains(d.issueKey) { count = i+1; break }
        currentLoadingDates.append(d)
      }
    }
    
    let date = currentLoadingDates.first ?? date
    count = currentLoadingDates.count > 0 ? currentLoadingDates.count : count
    let sCurrentLoadingDates = currentLoadingDates.map{$0.issueKey}
    addToLoading(sCurrentLoadingDates)
    
    debug("Load Issues for: \(date?.short ?? "newest"), count: \(count)")
    
    self.feederContext.gqlFeeder.issues(feed: feed,
                                        date: date,
                                        count: count,
                                        isOverview: true,
                                        returnOnMain: true) {[weak self] res in
      guard let self = self else { return }
      var newIssues: [StoredIssue] = []
      self.debug("Finished load Issues for: \(date?.short ?? "-"), count: \(count)")
      
      if let err = res.error() as? FeederError {
        self.handleDownloadError(error: err)
      }
      #warning("ToDo handle Error issue!!! NEWNEW")
      if let issues = res.value() {
        let start = Date()
        for issue in issues {
          newIssues.append(StoredIssue.persist(object: issue))
        }
        self.log("Finished load Issues for: \(date?.short ?? "-") DB Update duration: \(Date().timeIntervalSince(start))s on Main?: \(Thread.isMain)")
        ArticleDB.save()
        var loadedDates:[Date] = []
        for si in newIssues {
          self.updateIssue(issue: si)
          Notification.send(Const.NotificationNames.issueUpdate,
                            content: si.date,
                            sender: self)
          if date == nil {
            loadedDates.append(si.date)
          }
        }
        if date == nil {
          self.addLatestDates(dates: loadedDates)
        }
      }
      self.removeFromLoading(sCurrentLoadingDates)
    }
  }
  
  /// Ensute probybly new downloaded issue previews are in issueDatesArray, send reload is some added
  func addLatestDates(dates: [Date]) {
    #warning("TODO")
    log("WARNING TODO")
//    var allDates = self.issueDates
//    allDates.append(contentsOf: dates)
//    allDates = allDates.sorted().reversed()
//    if self.issueDates.count == allDates.count { return }
//    Notification.send(Const.NotificationNames.reloadIssueList)
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
      self.loadPreviewsLock.with { [weak self] in  _ = self?.loadPreviewsStack.popLast() }
      
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
    return feederContext.storedFeeder.momentImage(issue: issue,
                                                  isPdf: isPdf,
                                                  usePdfAlternative: false)
  }
  
  func updateIssue(issue:StoredIssue){
    self.issues[issue.date.issueKey] = issue
  }
    
  /// Initialize with FeederContext
  public init(feederContext: FeederContext) {
    self.feederContext = feederContext
    self.feed = feederContext.defaultFeed
    #warning("ensure sorted!")

    publicationDates = feed.publicationDates ?? []
    
    issues = StoredIssue.issuesInFeed(feed: feed).reduce(into: [String: StoredIssue]()) {
      $0[$1.date.issueKey] = $1
    }

    super.init()
    log("WARNING ENSURE SORTED PUB DATES se above")
#warning("ensure reload after update!")
log("WARNING ensure reload after update")
//    Notification.receive(Const.NotificationNames.reloadIssueDates) {[weak self] _ in
//      if let newDates = self?.feed.publicationDates?.dates.sorted() {
//        self?.issueDates = newDates.reversed()
//        Notification.send(Const.NotificationNames.reloadIssueList)
//      }
//    }
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
  }
  
  private var lc = LoadCoordinator()
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
//    self.isDownloading = false
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


fileprivate extension NSLock {

    @discardableResult
    func with<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}
