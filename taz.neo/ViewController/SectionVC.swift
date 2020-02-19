//
//  SectionVC.swift
//
//  Created by Norbert Thies on 14.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// The protocol used to communicate with calling VCs
public protocol SectionVCdelegate {
  var feeder: Feeder { get }
  var issue: Issue! { get }
  var dloader: Downloader { get }
}

/// The Section view controller managing a collection of Section pages
open class SectionVC: ContentVC, ArticleVCdelegate {
  private var articleVC: ArticleVC?  
  public var sections: [Section] = []
  public var section: Section? { 
    if let i = index, i < sections.count { return sections[i] }
    return nil
  }
  private var article2sectionHtml: [String:[String]] = [:]
  public var article: Article? {
    didSet {
      guard let art = article else { return }
      self.index = article2index(art: art)
    }
  }
  public var delegate: SectionVCdelegate? {
    didSet { self.setup() }
  }
  
  func setup() {
    guard let delegate = self.delegate else { return }
    self.sections = delegate.issue.sections ?? []
    var contents: [Content] = sections
    if let imp = delegate.issue.imprint { contents += imp }
    super.setup(feeder: delegate.feeder, issue: delegate.issue, contents: contents, 
                dloader: delegate.dloader, isLargeHeader: true)
    article2sectionHtml = issue.article2sectionHtml
    contentTable?.onSectionPress { [weak self] sectionIndex in
      self?.index = sectionIndex
    }
    contentTable?.onImagePress { [weak self] in
      self?.index = 0
    }
    onDisplay { [weak self] secIndex in
      self?.setHeader(secIndex: secIndex)
    }
    articleVC = ArticleVC()
    articleVC?.delegate = self
    whenLinkPressed { [weak self] (from, to) in
      self?.articleVC?.gotoUrl(url: to)
      self?.navigationController?.pushViewController(self!.articleVC!, 
                                                     animated: false)
    }
    self.index = 0
  }
  
  // Return nearest section index containig given Article
  func article2index(art: Article) -> Int {
    if let sects = article2sectionHtml[art.html.fileName] {
      if let s = section, sects.contains(s.html.fileName) { return index! }
      else {
        let fn = sects[0]
        for i in 0 ..< sections.count {
          if fn == sections[i].html.fileName { return i }
        }
      }
    }
    return 0
  }
    
  // Define Header elements
  func setHeader(secIndex: Int) {
    header.title = contents[secIndex].title ?? ""
    header.subTitle = issue.date.gLowerDateString(tz: feeder.timeZone)
  }
    
} // SectionVC


