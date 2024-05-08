//
//  LastReadBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 08.05.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

public class LastReadBusiness: NSObject, DoesLog{

  @Default("articleFileName")
  private var articleFileName: String {
    didSet {
      
    }
  }
  
//  @Default("mediaSyncId") ..iis an optional try not to use!
//  private var mediaSyncId: Int
  
  @Default("lastReadPage")
  private var page: Int
  
  @Default("lastReadIssueDate")
  private var issueDate: Date
  
  @Default("lastReadChanged")
  private var lastReadChanged: String
  
  private var device: String = "diesem Gerät"
  
  private static let sharedInstance = LastReadBusiness()
  
  static func persist(lastArticle: Article?, page: Int?, in issue:Issue){
    if let art = lastArticle, let page = page {
      sharedInstance.issueDate = issue.date
      sharedInstance.page = page
      sharedInstance.articleFileName = art.path.lastPathComponent
      sharedInstance.lastReadChanged = UsTime.now.toString()
    }
    else if let art = lastArticle {
      sharedInstance.issueDate = issue.date
      sharedInstance.page = -1
      sharedInstance.articleFileName = art.path.lastPathComponent
      sharedInstance.lastReadChanged = UsTime.now.toString()
    }
    else if let page = page {
      sharedInstance.issueDate = issue.date
      sharedInstance.page = page
      sharedInstance.articleFileName = ""
      sharedInstance.lastReadChanged = UsTime.now.toString()
    }
  }
  
  static func getLast(for issue: Issue) -> (lastArticle: Article?, page: Int?, changed: UsTime?){
    if issue.date != sharedInstance.issueDate {
      return (nil, nil, nil)
    }
    var lastArticle:Article?
    
    let fn = sharedInstance.articleFileName
    if fn.length > 0 {
      lastArticle = issue.allArticles.first { art in
        art.path.lastPathComponent == fn
      }
    }
    
    let page:Int? = sharedInstance.page >= 0 ? sharedInstance.page : nil
    return (lastArticle, page, UsTime(sharedInstance.lastReadChanged))
  }
  
  func sync(){
    //todo: read server data
    // save local data if newer
    //sync on app start
    //sync on reconnect
    //persist on enter background
    //sync on enter foregrond ...if last sync is > 60s?
  }
}
