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
  var issue: Issue { get }
  var dloader: Downloader { get }
}

/// The Section view controller managing a collection of Section pages
open class SectionVC: ContentVC, ArticleVCdelegate {
  private var articleVC: ArticleVC?
  private var lastIndex: Int?
  public var sections: [Section] = []
  public var section: Section? { 
    if let i = index, i < sections.count { return sections[i] }
    return nil
  }
  private var article2sectionHtml: [String:[String]] = [:]
  public var article: Article? {
    didSet {
      guard let art = article else { return }
      let secIndex = article2index(art: art)
      if let lidx = lastIndex, secIndex != lidx {
        displaySection(index: secIndex)
      }
      lastIndex = secIndex
    }
  }
  
  public var delegate: SectionVCdelegate? {
    didSet { if oldValue == nil { self.setup() } }
  }
  
  /// Perform slider animations?
  static var showAnimations = true

  public func displaySection(index: Int) {
    if index != self.index {
      debug("Section change to Section #\(index), previous: " +
        "\(self.index?.description ?? "[undefined]")" )
      if let curr = currentWebView { curr.scrollToTop() }
      self.index = index
    }    
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
      if sectionIndex < self!.sections.count {
        self?.debug("*** Action: Section \(sectionIndex) (\(self!.sections[sectionIndex])) in Slider pressed")
      }
      else { 
        self?.debug("*** Action: \"Impressum\" in Slider pressed")
      }
      self?.slider.close()
      self?.displaySection(index: sectionIndex)
    }
    contentTable?.onImagePress { [weak self] in
      self?.debug("*** Action: Moment in Slider pressed")
      self?.slider.close()
      self?.displaySection(index: 0)
    }
    onDisplay { [weak self] (secIndex) in
      self?.setHeader(secIndex: secIndex)
    }
    articleVC = ArticleVC()
    articleVC?.delegate = self
    whenLinkPressed { [weak self] (from, to) in
      self?.debug("*** Action: Link pressed from: \(from.lastPathComponent) " 
        + "to: \(to.lastPathComponent)")
      self?.lastIndex = nil
      self?.articleVC?.gotoUrl(url: to)
      self?.navigationController?.pushViewController(self!.articleVC!, 
                                                     animated: false)
    }
  }
  
  // Return nearest section index containing given Article
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
    header.hide(false)
  }
  
  // Reload Section and Article
  override open func reload() {
    articleVC?.reload()
    super.reload()
  }
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    self.index = 0
  }
  
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if SectionVC.showAnimations {
      SectionVC.showAnimations = false
      delay(seconds: 1.5) {
        self.slider.open() { _ in
          delay(seconds: 1.5) {
            self.slider.close() { _ in
              self.slider.blinkButton()
            }
          }
        }
      }
    }
  }
    
} // SectionVC


