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
  
  @Default("tabbarInSection")
  var tabbarInSection: Bool
  
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
  /// Only change header title according to section title
  public var isStaticHeader = false
  
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
  
  func showArticle(_ article: Article, animated: Bool = true) {
    guard let i = article.index else { return }
    showArticle(index: i, animated: animated)
  }
  
  private func showArticle(url: URL? = nil, index: Int? = nil, animated: Bool = true) {
    if let avc = articleVC {
      if let url = url { avc.gotoUrl(url: url) }
      else if let index = index { avc.index = index }
      if let nvc = navigationController {
        if avc != nvc.topViewController {
          avc.view.doLayout()
          avc.writeTazApiCss()
          avc.toolBar.show(show:true, animated: false)
          avc.header.show(show: true, animated: false)
          nvc.pushViewController(avc, animated: animated)
        }
      }
    }
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
          if fn == s.html?.name {
            self.gotoUrl(url: to) 
            if top == articleVC {
              navigationController?.popViewController(animated: true)
            }
          }
        }
      }
    }
    else {
      /// Previously INTERNALBROWSER Compiler Flags
      /// May should be Config Default Feature Toggle, or removed
      let isInternal = App.isAvailable(.INTERNALBROWSER)
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
    self.articleVC?.releaseOnDisappear()
    self.releaseOnDisappear()
  }
  
  func setup() {
    guard let delegate = self.delegate else { return }
    self.sections = delegate.issue.sections ?? []
    var contents: [Content] = sections
    if let imp = delegate.issue.imprint { contents += imp }
    super.setup(contents: contents, isLargeHeader: true)
    article2section = issue.article2section
    article2sectionHtml = issue.article2sectionHtml
    onDisplay { [weak self] (secIndex, oview) in
      guard let self = self else { return }
      self.contentTable?.setActive(row: nil, section: secIndex)
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
      /** FIX wrong Article shown (most errors on iPad, some also on Phone)
          after re-enter app due wired Scroll Pos change
          @see:  https://developer.apple.com/forums/thread/47100
          unfortunately is our behaviour quite complex, a simple return in viewWillTransition...
          destroys the layout or raise other errors
          so this is currently the most effective solution
       **/
      if UIApplication.shared.applicationState != .active { return }
      self?.linkPressed(from: from, to: to)
    }
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      if let art = msg.sender as? StoredArticle {
        guard let name = art.html?.name.nonPublic() else { return }
        let js = """
          if (typeof tazApi.onBookmarkChange === "function") {
            tazApi.onBookmarkChange("\(name)", \(art.hasBookmark));
          }
        """
        Task { [weak self] in
          try? await self?.currentWebView?.jsexec(js) 
        }
      }
    }
    Notification.receiveOnce("issue", from: issue) { [weak self] notif in
      guard let nIssue = notif.content as? Issue else { return }
      guard self?.delegate != nil && self?.delegate.issue != nil else { return }
      guard nIssue.date.issueKey == self?.issue.date.issueKey else { return }
      if nIssue.sections?.count == self?.issue.sections?.count
      && nIssue.allArticles.count == self?.issue.allArticles.count { return }
      self?.setup()
    }
  }
  
  /// Delete Article from ArticleVC
  func deleteArticle(_ art: Article) {
    article2section = issue.article2section
    article2sectionHtml = issue.article2sectionHtml
    articleVC?.delete(article: art)
  }
  
  /// Insert Article into ArticleVC
  func insertArticle(_ art: Article) {
    article2section = issue.article2section
    article2sectionHtml = issue.article2sectionHtml
    articleVC?.insert(article: art)
  }
  
  // Return nearest section index containing given Article
  public func article2index(art: Article) -> Int {
    if let fileName = art.html?.fileName,
        let sects = article2sectionHtml[fileName] {
      if let s = section, let fn = s.html?.fileName, sects.contains(fn) { return index! }
      else {
        let fn = sects[0]
        for i in 0 ..< sections.count {
          if fn == sections[i].html?.fileName { return i }
        }
      }
    }
    return 0
  }
    
  // Define Header elements including menu slider
  func setHeader(secIndex: Int) {
    let content = contents.valueAt(secIndex)
    
    if let section = content as? Section {
      self.slider?.collapsedButton = section.type == .advertisement
      
      if section.type == .advertisement {
        header.title = section.title ?? ""
        header.show(show: false, animated: true)
        toolBar.show(show:false, animated: true)
        return
      }
    }
    
    header.title = content?.title ?? ""
    if !isStaticHeader {
      header.subTitle = issue.validityDateText(timeZone: feeder.timeZone)
      header.titletype = index == 0 ? .section0 : .section
    }
    header.show(show: true, animated: true)
    toolBar.show(show:true, animated: true)
  }
  
  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    articleVC?.invalidateLayoutNeededOnViewWillAppear = true
  }
  
  public override func setupSlider() {
    super.setupSlider()
    contentTable?.onArticlePress{[weak self] article in
      guard let self = self else { return }
      let url = article.dir.url.absoluteURL.appendingPathComponent(article.html?.name ?? "")
      self.linkPressed(from: nil, to: url)
      self.slider?.close()
      self.articleVC?.slider?.close()
    }
    contentTable?.onSectionPress { [weak self] sectionIndex in
      guard let self = self else { return }
      if sectionIndex < self.sections.count {
        self.debug("*** Action: Section \(sectionIndex) (\(self.sections[sectionIndex])) in Slider pressed")
      }
      else {
        self.debug("*** Action: \"Impressum\" in Slider pressed")
      }
      self.slider?.close()
      self.articleVC?.slider?.close()
      self.articleVC?.navigationController?.popViewController(animated: true)
      self.displaySection(index: sectionIndex)
    }
    contentTable?.onImagePress { [weak self] in
      self?.debug("*** Action: Moment in Slider pressed")
      self?.slider?.close()
      self?.closeIssue()
    }
  }
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    if !(self is BookmarkSectionVC){
      contentTable = NewContentTableVC()
    }
    self.showImageGallery = false
    self.index = initialSection ?? 0
    
    scrollViewDidScroll{[weak self] offset in
      self?.header.scrollViewDidScroll(offset)
    }
    
    scrollViewDidEndDragging{[weak self] offset in
      self?.header.scrollViewDidEndDragging(offset)
    }
    
    scrollViewWillBeginDragging{[weak self] offset in
      self?.header.scrollViewWillBeginDragging(offset)
    }
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let iart = initialArticle {
      articleVC?.view.doLayout()
      self.showArticle(index: iart, animated: false)
      SectionVC.showAnimations = false
      initialArticle = nil
      self.header.isHidden = true
      self.collectionView?.isHidden = true
    }
  }
  
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.header.isHidden = false
    self.collectionView?.isHidden = false
    if SectionVC.showAnimations && issue.sections?.count ?? 0 > 1 {
      SectionVC.showAnimations = false
      delay(seconds: 1.5) {
        self.slider?.open() {_ in
          delay(seconds: 1.5) {[weak self] in
            self?.slider?.close()
          }
        }
      }
    }
  }
  
  open override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    if parent == nil { releaseOnDisappear() }
  }
  ///Declaration 'releaseOnDisappear()' cannot override more than one superclass declaration
  open override func releaseOnDisappear() {
    articleVC?.releaseOnDisappear()
    articleVC = nil
    super.releaseOnDisappear()
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
    if tabbarInSection {
      toolBar.isHidden = true
      hidesBottomBarWhenPushed = false
    }
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - SFSafariViewControllerDelegate protocol
  
  public func safariViewControllerDidFinish(_ svc: SFSafariViewController) {
    navigationController?.popViewController(animated: true)
  }

} // SectionVC


