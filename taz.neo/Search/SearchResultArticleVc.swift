//
//  SearchResultArticleVc.swift
//  taz.neo
//
//  Created by Ringo Müller on 24.03.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit

// MARK: - SearchResultArticleVc
class SearchResultArticleVc : ArticleVC {
  var navigationBarHiddenRestoration:Bool?
  var maxResults:Int = 0
  var searchClosure: (()->())?
  
  override func setHeader(artIndex: Int) {
    super.setHeader(artIndex: artIndex)

    if let searchVc = adelegate as? SearchController,
       let hit = searchVc.searchItem.searchHitList?.valueAt(artIndex)
    {
      header.pageNumber = "\(artIndex+1)/\(maxResults)"
      header.title
      = (hit.sectionTitle ?? "")
      + (hit.sectionTitle != nil ? " - " : "vom: ")
      + hit.date.short
    }
    else {
      header.pageNumber = "\(artIndex+1)/\(maxResults)"
    }
    
    if artIndex >= articles.count - 1 {
      searchClosure?()
    }
  }
  
  var searchContents: [Article] = [] {
    didSet {
      super.articles = searchContents
      super.contents = searchContents
      let path = feeder.issueDir(issue: issue).path
      let curls: [ContentUrl] = contents.map { cnt in
        ContentUrl(path: path, issue: issue, content: cnt) { [weak self] curl in
          guard let this = self else { return }
          this.dloader.downloadIssueData(issue: this.issue, files: curl.content.files) { err in
            if err == nil { curl.isAvailable = true }
          }
        }
      }
      displayUrls(urls: curls)
    }
  }
  
  override func setupSlider() {}
  
  override func willMove(toParent parent: UIViewController?) {
    super.willMove(toParent: parent)
    navCtrl = navigationController
  }

  var navCtrl:UINavigationController?
  
  override func didMove(toParent parent: UIViewController?) {
    if parent == nil {
      navCtrl?.isNavigationBarHidden = false
      navCtrl = nil
    }
    super.didMove(toParent: parent)
  }
}


