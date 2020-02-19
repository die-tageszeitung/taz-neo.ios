//
//  ArticleVC.swift
//
//  Created by Norbert Thies on 14.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// The protocol used to communicate with calling VCs
public protocol ArticleVCdelegate {
  var feeder: Feeder { get }
  var issue: Issue { get }
  var dloader: Downloader! { get }
  var section: Section? { get }
  var index: Int? { get set }
  var article: Article? { get set }
}

/// The Article view controller managing a collection of Article pages
open class ArticleVC: ContentVC {
    
  public var articles: [Article] = []
  public var article: Article { return articles[index ?? 0] }
  public var delegate: ArticleVCdelegate? {
    didSet { self.setup() }
  }
  
  func setup() {
    guard let delegate = self.delegate else { return }
    self.articles = delegate.issue.allArticles
    super.setup(feeder: delegate.feeder, issue: delegate.issue, contents: articles, 
                dloader: delegate.dloader, isLargeHeader: false)
    contentTable?.onSectionPress { [weak self] sectionIndex in
      self?.delegate?.index = sectionIndex
      self?.navigationController?.popViewController(animated: false)
    }
    contentTable?.onImagePress { [weak self] in
      self?.delegate?.index = 0
      self?.navigationController?.popViewController(animated: false)
    }
    onDisplay { [weak self] artIndex in
      self?.delegate?.article = self?.articles[artIndex]
      self?.setHeader(artIndex: artIndex)
    }
    self.index = 0
  }
    
  // Define Header elements
  func setHeader(artIndex: Int) {
    if let section = delegate?.section {
      header.title = section.title ?? ""
    }
  }
    
} // ArticleVC


