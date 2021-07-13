//
//  SectionVC.swift
//
//  Created by Norbert Thies on 14.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import SafariServices
import NorthLib

/// The Section view controller managing a collection of Section pages
open class SectionVC: ContentVC, ArticleVCdelegate, SFSafariViewControllerDelegate {
  
  private var articleVC: ArticleVC?
  private var lastIndex: Int?
  public var sections: [Section] = []
  public var section: Section? { 
    if let i = index, i < sections.count { return sections[i] }
    return nil
  }
  public var article2section: [String:[Section]] = [:]
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
  
  private var initialSection: Int?
  private var initialArticle: Int?
  
  public override var delegate: IssueInfo! {
    didSet { if oldValue == nil { self.setup() } }
  }
  
  /// Perform slider animations?
  static var showAnimations = true

  /// Is top VC
  public var isVisibleVC: Bool {
    if let nvc = navigationController {
      return self == nvc.visibleViewController
    }
    else { return false }
  }
  public func displaySection(index: Int) {
    if index != self.index {
      debug("Section change to Section #\(index), previous: " +
        "\(self.index?.description ?? "[undefined]")" )
      if let curr = currentWebView { curr.scrollToTop() }
      self.index = index
    }    
  }
  
  private func showArticle(url: URL? = nil, index: Int? = nil) {
    if let avc = articleVC {
      if let url = url { avc.gotoUrl(url: url) }
      else if let index = index { avc.index = index }
      if let nvc = navigationController {
        if avc != nvc.topViewController {
          avc.writeTazApiCss{
            avc.reloadAllWebViews()
          }
          nvc.pushViewController(avc, animated: true)
        }
      }
    }
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    articleVC?.viewWillTransition(to: size, with: coordinator)
  }
  
  public func linkPressed(from: URL?, to: URL?) {
    guard let to = to else { return }
    let fn = to.lastPathComponent
    let top = navigationController?.topViewController
    debug("*** Action: Link pressed from: \(from?.lastPathComponent ?? "[undefined]") to: \(fn)")
    if to.isFileURL {
      if article2sectionHtml[fn] != nil {
        lastIndex = nil
        showArticle(url: to)
      }    
      else {
        for s in self.sections {
          if fn == s.html.name { 
            self.gotoUrl(url: to) 
            if top == articleVC {
              navigationController?.popViewController(animated: true)
            }
          }
        }
      }
    }
    else {
      #if INTERNALBROWSER
        let isInternal = true
      #else
        let isInternal = false
      #endif
      if let scheme = to.scheme,
         isInternal && (scheme == "http" || scheme == "https") {
        let svc = SFSafariViewController(url: to)
        svc.delegate = self
        svc.preferredControlTintColor = Const.Colors.darkTintColor
        svc.preferredBarTintColor = Const.Colors.darkToolbar
        navigationController?.pushViewController(svc, animated: true)
      }
      else {
        self.debug("Calling application for: \(to.absoluteString)")
        if UIApplication.shared.canOpenURL(to) {
          UIApplication.shared.open(to, options: [:], completionHandler: nil)
        }
        else {
          error("No application or no permission for: \(to.absoluteString)")
        }
      }

    }
  }
  
  public func closeIssue() {
    self.navigationController?.popViewController(animated: false)
  }
  
  func setup() {
    guard let delegate = self.delegate else { return }
    self.sections = delegate.issue.sections ?? []
    var contents: [Content] = sections
    if let imp = delegate.issue.imprint { contents += imp }
    super.setup(contents: contents, isLargeHeader: true)
    article2section = issue.article2section
    article2sectionHtml = issue.article2sectionHtml
    contentTable?.onSectionPress { [weak self] sectionIndex in
      if sectionIndex < self!.sections.count {
        self?.debug("*** Action: Section \(sectionIndex) (\(self!.sections[sectionIndex])) in Slider pressed")
      }
      else { 
        self?.debug("*** Action: \"Impressum\" in Slider pressed")
      }
      self?.slider?.close()
      self?.displaySection(index: sectionIndex)
    }
    contentTable?.onImagePress { [weak self] in
      self?.debug("*** Action: Moment in Slider pressed")
      self?.slider?.close()
      self?.closeIssue()
    }
    onDisplay { [weak self] (secIndex, oview) in
      guard let self = self else { return }
      self.debug("onDisplay: \(secIndex)")
      self.setHeader(secIndex: secIndex)
      if self.isVisibleVC { 
        self.issue.lastSection = self.index
        self.issue.lastArticle = nil 
      }
    }
    super.showImageGallery = false
    articleVC = ArticleVC(feederContext: feederContext)
    articleVC?.delegate = self
    whenLinkPressed { [weak self] (from, to) in
      self?.linkPressed(from: from, to: to)
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
    header.subTitle = issue.date.gLowerDate(tz: feeder.timeZone)
    if index == 0 { header.isLargeTitleFont = true }
    else { header.isLargeTitleFont = false }
    header.hide(false)
  }
  
  // Reload Section and Article
  override open func reload() {
    articleVC?.reload()
    super.reload()
  }
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    self.index = initialSection ?? 0
  }
  
//  public override func applyStyles() {
//    super.applyStyles()
//  }
  
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if let iart = initialArticle {
      delay(seconds: 1.0) { [weak self] in
        self?.showArticle(index: iart)
      }
      initialArticle = nil
      SectionVC.showAnimations = false
    }
    if SectionVC.showAnimations {
      SectionVC.showAnimations = false
      delay(seconds: 1.5) {
        self.slider?.open() { _ in
          delay(seconds: 1.5) {
            self.slider?.close() { _ in
              self.slider?.blinkButton()
            }
          }
        }
      }
    }
  }
   
  /// Initialize with FeederContext
  public init(feederContext: FeederContext, atSection: Int? = nil, 
              atArticle: Int? = nil) {
    initialSection = atSection
    initialArticle = atArticle
    super.init(feederContext: feederContext)
    let sec: String = (atSection == nil) ? "nil" : "\(atSection!)"
    let art: String = (atArticle == nil) ? "nil" : "\(atArticle!)"
    debug("new SectionVC: section=\(sec), article=\(art)")
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - SFSafariViewControllerDelegate protocol
  
  public func safariViewControllerDidFinish(_ svc: SFSafariViewController) {
    navigationController?.popViewController(animated: true)
  }

} // SectionVC


