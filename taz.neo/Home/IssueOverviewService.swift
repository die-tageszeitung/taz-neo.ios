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
 
 
 */
class IssueOverviewService: NSObject, DoesLog {

  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  var loading = false
  //  var loadMoreDates:[Date] = [:]
  
  internal var feederContext: FeederContext
  var feed: StoredFeed

  public private(set) var issueDates: [Date]
  private var issues: [Date:StoredIssue] = [:]
  
  func momentImage(issue: Issue?, isPdf: Bool) -> UIImage? {
    guard let issue else { return nil }
    let img = feederContext.storedFeeder.momentImage(issue: issue, isPdf: isPdf)
    print("img: \(img)")
    return img
  }
  
  func image(for index: Int, isPdf: Bool? = nil) -> UIImage? {
    let isPdf = isPdf ?? isFacsimile
    return momentImage(issue: getIssue(at: index), isPdf: isPdf)
  }
  
  func date(at index: Int) -> Date? {
    return issueDates.valueAt(index)
  }

  func issue(at date: Date) -> StoredIssue? {
    return issues[date]
  }
  
  var dbload = false
  
  func getIssue(at index: Int) -> Issue? {
    if index + 3 > issues.count && dbload == false {
      dbload = true
      if let lastIssue = issues.sorted(by: { $0.0 > $1.0 }).last?.key as? Date {
        let sIssues = StoredIssue.issuesInFeed(feed: feed, count: 10, fromDate: lastIssue)
        for issue in sIssues {
          issues[issue.date] = issue
        }
      }
      dbload = false
    }
    
    
    guard let date = date(at: index) else { return nil }
    guard let issue = issues[date] else {
      loadOverviews(fromDate: date)
      return nil
    }
    return issue
  }
  
  func loadOverviews(fromDate: Date){
    onThread {[weak self] in
      self?.loadOverviews1(fromDate: fromDate)
    }
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
  
  func showIssue(at date: Date, pushToNc: UINavigationController){
    guard let issue = issue(at: date) else {
      error("no issue available to open at date: \(date.short)")
      #warning("Load Data and open later!?")
      return
    }
    #warning("Refactor IssueInfo must be a init Property in ContentVC to not have the strong/optional reference here")
    issueInfo = IssueDisplayService(feederContext: feederContext,
                                        issue: issue)
    issueInfo?.showIssue(pushToNc: pushToNc)
  }
  
  var issueInfo:IssueDisplayService?
  
  func loadOverviews1(fromDate: Date){
    guard feederContext.isConnected else {
      debug("TBD Fehler offline")
      
      return
    }
    guard !loading else { return }
    loading = true
    
    self.feederContext.gqlFeeder.issues(feed: feed,
                                        date: fromDate,
                                        count: 10,
                                        isOverview: true,isPages: true,
                                        returnOnMain: true) {[weak self] res in
      guard let self else { return }
      if let issues = res.value() {
        for issue in issues {
          let si = StoredIssue.get(date: issue.date, inFeed: self.feed)
          if si.count < 1 {
            StoredIssue.persist(object: issue)
            onThread {[weak self] in
              self?.dlFile(issue: issue)
            }
          }
          
          //#warning("ToDo 0.9.4+: Missing Update of an stored Issue")
          ///in old app timestamps are compared!
          ///What if Overview new MoTime but compleete Issue is in DB and User is in Issue to read!!
          /// if si.first?.moTime != issue.moTime ...
          /// an update may result in a crash
        }
                  ArticleDB.save()
        //          let sissues = StoredIssue.issuesInFeed(feed: sfeed,
        //                                                 count: count,
        //                                                 fromDate: fromDate)
        //          for issue in sissues { self.downloadIssue(issue: issue, isAutomatically: isAutomatically) }
      }
      //        else {
      //          if let err = res.error() as? FeederError {
      //            self.handleFeederError(err) {
      //              self.getOvwIssues(feed: feed, count: count, fromDate: fromDate, isAutomatically: isAutomatically)
      //            }
      //          }
      //          else {
      //            let res: Result<Issue,Error> = .failure(res.error()!)
      //            self.notify("issueOverview", result: res)
      //          }
      //          return
    }
    self.loading = false
  }
  
  func dlFile(issue: Issue){
    let dir = issue.dir
    var file: [FileEntry] = []
    if let f = isFacsimile ? issue.pageOneFacsimile : issue.moment.images.first {
      if f.exists(inDir: dir.path) { debug("Do something") ; return}
      file.append(f)
    }
   
    //check if in temp Dir?
    self.feederContext.dloader.downloadIssueFiles(issue: issue, files: file) {[weak self] err in
      guard let sissue = issue as? StoredIssue else {
        self?.error("Issue is not a Stored Issue")
        return
      }
      self?.debug("downloaded")
      self?.issues[issue.date] = sissue
    }
  }
  
  func setup(){
//    #warning("un-init need to be implemented!")
//    Notification.receive("issueOverview") { [weak self] notif in
//      if let err = notif.error {
//        self?.debug("Error: \(err)")
//        if let errIssue = notif.sender as? Issue {
//          self?.addIssue(issue: errIssue, isError: true)
//        }
//      }
//      else if let issue = notif.content as? Issue {
//        self?.addIssue(issue: issue)
//      }
//    }
    let sIssues = StoredIssue.issuesInFeed(feed: feed, count: 10)
    for issue in sIssues {
      issues[issue.date] = issue
    }
//    load()

  }
  
//  func load(fromDate:Date){
//    if loadMoreDates.isEmpty == false {
//      loadMoreDates.append(fromDate)
//      return
//    }
//
//    if loadMore { return}
//    loadMore = true
//    feederContext.getOvwIssues(feed: feed,
//                               count: 10, fromDate: Date(),
//                               isAutomatically: false)
//  }
  
//  func loadNext(){
//    /**
//
//     fc: load 10 Datum +/- 10 => no response
//
//     schnelles scrollen anzeigen => dann in overview reingehen
//
//     ...Es wird scheinbar immer Moment + PDF geladen, egal was ich anzeige.
//     durch laden von nur einem von beiden kann dl um 50% beschleunigt werden
//
//
//     */
//    let date = loadMoreDates.popLast()
//
//    if feederContext.isConnected {
//      self.gqlFeeder.issues(feed: sfeed, date: fromDate, count: min(count, 20),
//                            isOverview: true) { res in
//
//
//      }
//    }
//  }
      
  
  func addIssue(issue: StoredIssue, isError: Bool = false){
    if let oldIssue = issues[issue.date] {
      debug("overwriting \(oldIssue) with: \(issue)")
    }
    issues[issue.date] = issue
  }
  
  /// Initialize with FeederContext
  public init(feederContext: FeederContext) {
    self.feederContext = feederContext
    self.feed = feederContext.defaultFeed
    issueDates = feed.publicationDates?.dates.sorted().reversed() ?? []
    super.init()
    setup()
  }
}
