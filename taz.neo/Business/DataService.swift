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
class DataService: NSObject, DoesLog {
  
  var pdf = false
  
  var loading = false
  //  var loadMoreDates:[Date] = [:]
  
  var feederContext: FeederContext
  var feed: StoredFeed
  var issueDates: [Date]
  
  var issues: [Date:Issue] = [:]
  
  func image(for index: Int) -> UIImage? {
    guard let date = issueDates.valueAt(index) else { return nil }
    guard let issue = issues[date] else {
      loadOverviews(fromDate: date)
      return nil
    }
    return feederContext.storedFeeder.momentImage(issue: issue, isPdf: false)
  }
  
  func loadOverviews(fromDate: Date){
    onThread {[weak self] in
      self?.loadOverviews1(fromDate: fromDate)
    }
  }
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
                                        isOverview: true,
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
    if let f = pdf ? issue.pageOneFacsimile : issue.moment.images.first {
      if f.exists(inDir: dir.path) { debug("Do something") ; return}
      file.append(f)
    }
   
    //check if in temp Dir?
    self.feederContext.dloader.downloadIssueFiles(issue: issue, files: file) {[weak self] err in
      self?.debug("downloaded")
      self?.issues[issue.date] = issue
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
    let sIssues = StoredIssue.issuesInFeed(feed: feed)
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
      
  
  func addIssue(issue: Issue, isError: Bool = false){
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
