//
//  SearchResultArticleVc.swift
//  taz.neo
//
//  Created by Ringo Müller on 24.03.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

// MARK: - SearchResultArticleVc
class SearchResultArticleVc : ArticleVC {
  
  /// CSS Margins for Articles and Sections
  public class override var topMargin: CGFloat { return 75 }
  
  var navigationBarHiddenRestoration:Bool?
  var maxResults:Int = 0
  var searchClosure: (()->())?
  
  override func setHeader(artIndex: Int) {
    super.setHeader(artIndex: artIndex)
    header.titleLabel.textAlignment = .right
    self.isLargeHeader = false
    if let searchVc = adelegate as? SearchController,
       let hit = searchVc.searchItem.searchHitList?.valueAt(artIndex)
    {
      header.title = hit.sectionTitle ?? ""
      header.subTitle = "Ausgabe \(hit.date.short)"
    }
    
    header.pageNumber = "\(artIndex+1) von \(maxResults)"
    
    if artIndex >= articles.count - 1 {
      searchClosure?()
    }
  }
  
  var searchContents: [Article] = [] {
    didSet {
      super.articles = searchContents
      super.contents = searchContents
      let curls: [ContentUrl] = contents.map { cnt in
        ContentUrl(content: cnt) { [weak self] curl in
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

  override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      self.navigationController?.setNavigationBarHidden(true, animated: false)
  }
  
  override func setup() {
    super.setup()
    self.isLargeHeader = true
    onHome { [weak self] _ in
      guard let mainTabVC = self?.navigationController?.parent as? MainTabVC else { return }
      mainTabVC.selectedIndex = 0
    }
    atEndOfContent() { [weak self] isAtEnd in
      if self?.feederContext.isAuthenticated == false || Defaults.expiredAccount {
        if isAtEnd { self?.feederContext.authenticate() }
      }
    }
    header.titleAlignment = .left
  }
}

