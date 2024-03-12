//
//  LMdSliderDataModel.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.01.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit


/// datamodel for lmd slider/content table
class LMdSliderDataModel: IssueInfo {
  var feederContext: FeederContext
  var issue: Issue
  
  /// pageIndex-article relation; **WARNING** only contain pages where article start,
  /// no comercial pages no continued article pages
  /// pageIndex start at 0 if 3 pages missing e.g. n-th pahe Index is n+3 page
  var pageIndex2article: [Int:[Article]] = [:]
  /// pageIndex-page relation; **WARNING** only contain pages where article start,
  /// no comercial pages no continued article pages
  var pageIndex2page: [Int:Page] = [:]
  
  var pageName2pageIndex: [String:Int] = [:]
  
  func facsimile(for page: Page?) -> UIImage? {
    return page?.facsimile?.image(dir: issue.dir)
  }
  
  init(feederContext: FeederContext, issue: Issue){
    self.issue = issue
    self.feederContext = feederContext
    
    let articles = issue.allArticles
    var addedArticles: [Article] = []//Prevent listing on later page
    var idx = 0
    for page in issue.pages ?? [] {
      pageName2pageIndex[page.pdf?.name ?? "-"] = idx
      var arts: [Article] = []
      for article in articles {
        for case let pname in article.pageNames ?? [] where pname == page.pdf?.fileName {
          if addedArticles.contains(where: {$0.html?.name == article.html?.name }) { continue }
          arts.append(article)
          addedArticles.append(article)
        }
      }
      if arts.count == 0 { continue }//Prevent Comercial Pages in Slider
      pageIndex2article[idx] = arts
      pageIndex2page[idx] = page
      idx += 1
    }
  }
}
