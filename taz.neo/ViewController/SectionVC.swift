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
  
  open var sectionPath:[String]? {
    guard let section = section,
          let sectFileName = section.html?.name else { return nil}
    return ["issue", self.feederContext.feedName, self.issue.date.ISO8601, "section", sectFileName]
  }
  
  public private(set) var articleVC: ArticleVC?
  
  ///ButtonSlider Content, shared with ArticleVC
  public lazy var contentTable: NewContentTableVC = {
    let ct = NewContentTableVC()
    ct.feeder = feeder
    ct.issue = issue
    ct.image = feeder.momentImage(issue: issue)
    
    ct.onArticlePress{[weak self] article in
      guard let self = self else { return }
      let url = article.dir.url.absoluteURL.appendingPathComponent(article.html?.name ?? "")
      self.linkPressed(from: nil, to: url)
      self.slider?.close()
      self.articleVC?.slider?.close()
    }
    ct.onSectionPress { [weak self] sectionIndex in
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
    ct.onImagePress { [weak self] in
      self?.debug("*** Action: Moment in Slider pressed")
      self?.slider?.close()
      let issueDate = self?.issue.date
      self?.closeIssue()
      Notification.send(Const.NotificationNames.gotoIssue, content: issueDate , sender: self)
    }
    
    return ct
  }()

  #warning("Remove no more needed")
  private var lastIndex: Int?
  public var sections: [Section] = []
  public var section: Section? { sections.valueAt(index) }
  public var article2section: [String:[Section]] = [:]
  private var article2sectionHtml: [String:[String]] = [:]
  public var article: Article? {
    didSet {
      guard let art = article else { return }
      let secIndex = article2index(art: art)
      if secIndex != lastIndex {
        displaySection(index: secIndex)
      }
      lastIndex = secIndex
    }
  }
  /// Only change header title according to section title
  public var isStaticHeader = false
  
  private var initialSection: Int?
  private var initialArticle: Int?
  
  override var reopenArticleDocName: String? {
    set { articleVC?.reopenArticleDocName = newValue }
    get { articleVC?.reopenArticleDocName }
  }
  override var reopenArticleScrollPos: CGFloat? {
    set { articleVC?.reopenArticleScrollPos = newValue }
    get { articleVC?.reopenArticleScrollPos }
  }
  
  public override var delegate: IssueInfo! {
    didSet { if oldValue == nil { self.setup() } }
  }

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
        "\(self.index)" )
      if let curr = currentWebView { curr.scrollToTop() }
      self.scrollTo(index: index)
    }
  }
  
  func showArticle(_ article: Article, animated: Bool = true) {
    guard let i = issue.indexOf(article: article) else { return }
    showArticle(index: i, animated: animated)
  }
  
  private func showArticle(url: URL? = nil, index: Int? = nil, animated: Bool = true) {
    guard let avc = articleVC else { return }
    if let url = url { avc.gotoUrl(url: url) }
    else if let index = index { avc.gotoIndex(index: index) }
    
    if let nvc = navigationController,
       avc != nvc.topViewController {
      avc.view.doLayout()
      avc.writeTazApiCss()
      avc.toolBar.show(show:true, animated: false)
      avc.header.show(show: true, animated: false)
      nvc.pushViewController(avc, animated: animated)
    }
  }
  
  func sectionIfAudio(atIndex: Int?) -> Section?{
    if self.navigationController == nil { return nil }//Prevent Crash on not released old sectVC @see commit
    if let idx = atIndex,
       let section = contents.valueAt(idx) as? Section,
       section.type == .podcast,
       section.audioItem != nil {
      return section
    }
    return nil
  }
  
  public func linkPressed(from: URL?, to: URL?) {
    guard let to = to else { return }
    
    if to.isFileURL == false, let section = sectionIfAudio(atIndex: index) {
      ArticlePlayer.singleton.play(sectionAudio: section)
      return
    }
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
          to.openLinkAndTrackAdIfNeeded()
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
  
  func updatePlayButton(){
    if let section = sectionIfAudio(atIndex: index) {
      self.playButton.isHidden = false
      self.onPlay { _ in section.toggleAudio() }
      updateAudioButton()///set correct state of play button
    }
    else {
      self.playButton.isHidden = true
      self.onPlay(closure: nil)
    }
    self.updateAudioInWebview()
  }
  
  private var firstDisplayed = false
  override func persistReadProgress() { persistReadProgress(sectIdx: nil, force: false) }
  
  func persistReadProgress(sectIdx: Int? = nil, force: Bool = false) {
    guard firstDisplayed else { return }
    guard force || self.isVisibleVC else { return }
    guard delegate.issue.isBookmarkIssue == false else { return }
    guard let sect = sections.valueAt(sectIdx ?? index) else { return }
    issue.setLastRead(content: sect, pageIndex: nil, scrollPosition: nil)
  }
    
  func activateWebview(webView:WebView){
    ///WARNING: tazApi is may not available yet!
    let js = """
      window.dispatchEvent(new Event('native:webview:didBecomeVisible'));
    """
    Task { try? await webView.jsexec(js) }
  }

    
  func setup() {
    guard let delegate = self.delegate else { return }
    self.sections = delegate.issue.sections ?? []
    var contents: [Content] = sections
    if let imp = delegate.issue.imprint { contents += imp }
    super.setup(contents: contents, isLargeHeader: true)
    article2section = issue.article2section
    article2sectionHtml = issue.article2sectionHtml
    
    whenLoaded {[weak self] wv in
      guard wv == self?.currentWebView else { return }
      self?.activateWebview(webView: wv)
      self?.updateAudioInWebview()
    }
    onDisplay { [weak self] (secIndex, optionalView) in
      guard let self = self else { return }
      self.contentTable.setActive(row: nil, section: secIndex)
      self.debug("onDisplay: \(secIndex) webview: \(optionalView.debugDescription)")
      self.setHeader(secIndex: secIndex)
      self.updatePlayButton()
      persistReadProgress(sectIdx: secIndex)
      self.firstDisplayed = true
      if let wv = optionalView?.mainView as? WebView {
        self.activateWebview(webView: wv)
      }
    }
    super.showImageGallery = false
    articleVC = ArticleVC(feederContext: feederContext)
    articleVC?.delegate = self
    articleVC?.header.onTitle { [weak self] _ in
      self?.debug("*** Action: ToSection pressed")
      guard let aDelegate = self?.articleVC?.delegate as? ArticleVCdelegate,
            let art = self?.articleVC?.article else { return }
      let sIdx = aDelegate.article2index(art: art)
      self?.scrollTo(index: sIdx)
      self?.articleVC?.navigationController?.popViewController(animated: true)
    }
    whenLinkPressed { [weak self] (from, to) in
      self?.log("=> SectVC when...\(from?.absoluteString.lastPathComponent ?? "-") to: \(to?.absoluteString.lastPathComponent ?? "-")")
      if self?.navigationController?.topViewController != self {
        self?.log("WARNING :: Prevent double tap on open issue to schow article and then pop to section")
        return
      }
      LinkBusiness.handleLinkPressed(from: from, to: to,
                                     with: self)
    }
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      #warning("Error: off-Screen rendered/loaded Sections wount update bookmark state")
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
      if (self?.issue as? StoredIssue)?.safeDate ?? nil == nil { return }
      guard nIssue.date.issueKey == self?.issue.date.issueKey else { return }
      if nIssue.sections?.count == self?.issue.sections?.count
      && nIssue.allArticles.count == self?.issue.allArticles.count { return }
      self?.setup()
    }
    header.isWochentaz = issue.isWeekend
  }
  
  override var currentAudioContent: Content? {
    self.sectionIfAudio(atIndex: index)
  }
  
  // Return nearest section index containing given Article
  public func article2index(art: Article) -> Int {
    if let fileName = art.html?.fileName,
        let sects = article2sectionHtml[fileName] {
      if let s = section, let fn = s.html?.fileName, sects.contains(fn) { return index }
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
      ///@Refactor: Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value
      ///StoredSection.type.getter
      ///Particular Download? => STOP?=> Account unexpired => Tap on Issue => Crash
      let hideItems
      = section.type == .advertisement || section.type == .podcast
      self.slider?.collapsedButton = hideItems
      
      if hideItems {
        header.title = section.title ?? ""
        header.show(show: false, animated: true)
        toolBar.show(show:false, animated: true)
        hideHelpButton()
        return
      }
    }
    
    header.title = content?.title ?? ""
    if !isStaticHeader {
      header.subTitle = issue.validityDateText(timeZone: feeder.timeZone)
      header.titletype = secIndex == 0 ? .section0 : .section
      
      let issueDateText = issue.issueDateAccessibilityText
      header.shouldGroupAccessibilityChildren = true
      header.accessibilityLabel
      = secIndex == 0
      ? (header.title ?? "") + ", " + issueDateText
      : header.title
    }
    else {
      header.accessibilityLabel = header.title
    }
    header.show(show: true, animated: true)
    toolBar.show(show:true, animated: true)
    showHelpButton()
  }
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    slider = MyButtonSlider(slider: contentTable, into: self)
    setupSlider()

    self.showImageGallery = false
    if let sect = initialSection { self.scrollTo(index: sect) }
    
    scrollViewDidScroll{[weak self] offset in
      self?.header.scrollViewDidScroll(offset)
    }
    
    scrollViewDidEndDragging{[weak self] offset in
      self?.header.scrollViewDidEndDragging(offset)
    }
    
    scrollViewWillBeginDragging{[weak self] offset in
      self?.header.scrollViewWillBeginDragging(offset)
    }
    Rating.issueOpened()
  }
  
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    persistReadProgress()
    if let iart = initialArticle {
      self.scrollView.isHidden = true
      articleVC?.view.doLayout()
      self.showArticle(index: iart, animated: false)
      initialArticle = nil
      self.header.isHidden = false
      onMainAfter(1.0) {[weak self] in
        self?.scrollView.isHidden = false
      }
    }
    else {
      toolBar.show(show: true, animated: true)
    }
  }
  
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.header.isHidden = false
    guard let wv = currentWebView else { return }
    self.activateWebview(webView: wv)
  }
  
  //Declaration 'releaseOnDisappear()' cannot override more than one superclass declaration
  open override func releaseOnDisappear() {
    articleVC?.cleanup()
    articleVC = nil
    cleanup()
    super.releaseOnDisappear()
  }
   
  /// Initialize with FeederContext
  public init(feederContext: FeederContext,
              atSection: Int? = nil,
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

//// MARK: - ContentVC Accessibility
extension SectionVC {
  @objc override var nextItemAccessibilityLabel: String? {
    guard index < self.sections.count else { return nil }
    return "Nächstes Ressort: \(self.sections.valueAt(index + 1)?.title ?? "")"
  }
  
  @objc override var prevItemAccessibilityLabel: String? {
    guard index > 0 else { return nil }
    return "Vorheriges Ressort: \(self.sections.valueAt(index + -1)?.title ?? "")"
  }
}
