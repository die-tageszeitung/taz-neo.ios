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
  var searchHitDate: Date?
  
  override func setHeader(artIndex: Int) {
    super.setHeader(artIndex: artIndex)
    header.titleLabel.textAlignment = .right
    self.isLargeHeader = false
    if let searchVc = adelegate as? SearchController,
       let hit = searchVc.searchItem.searchHitList?.valueAt(artIndex)
    {
      header.title = hit.sectionTitle ?? ""
      header.subTitle = "Ausgabe \(hit.date.short)"
      searchHitDate = hit.date
    } else {
      searchHitDate = nil
    }
    
    header.pageNumber = "\(artIndex+1) von \(maxResults)"
    
    if artIndex >= articles.count - 1 {
      searchClosure?()
    }
  }
  
  var searchContents: [SearchArticle] = [] {
    didSet {
      super.articles = searchContents
      super.contents = searchContents
      let curls: [ContentUrl] = searchContents.map { cnt in
        ContentUrl(content: cnt) { [weak self] curl in
          guard let this = self else { return }
          let url = cnt.originalIssueBaseURL ?? cnt.baseURL
          ///Not Download Article HTML use it from SearchHit, it has highlighting for search term
          let additionalFiles = curl.content.files.filter{ $0.name != cnt.html?.name }
          this.dloader.downloadSearchHitFiles(files: additionalFiles, baseUrl: url) { err in
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
    header.titletype = .search
    header.subTitleLabel.onTapping { [weak self] _ in
      guard let date = self?.searchHitDate else { return }
      if date < self?.feed.firstIssue ?? Date() {
        Toast.show("Die Ausgabe vom \(date.short) ist leider nicht im Archiv verfügbar.")
        return
      }
      Notification.send(Const.NotificationNames.gotoIssue, content: date, sender: self)
    }
  }
}


