//
//  ArticleVC.swift
//
//  Created by Norbert Thies on 14.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib
import WebKit

/// The protocol used to communicate with calling VCs
public protocol ArticleVCdelegate: IssueInfo {
  var section: Section? { get }
  var sections: [Section] { get }
  var article: Article? { get set }
  func article2index(art: Article) -> Int
  var article2section: [String:[Section]] { get }
  func displaySection(index: Int)
  func linkPressed(from: URL?, to: URL?)
  func closeIssue()
}

public extension ArticleVCdelegate {
  func article2index(art: Article) -> Int { return -1}
}

/// The Article view controller managing a collection of Article pages
open class ArticleVC: ContentVC, ContextMenuItemPrivider {
  public var menu: MenuActions?{
    return article?.contextMenu()
  }

  @Default("multiColumnOnboardingAnswered")
  var multiColumnOnboardingAnswered: Bool
  
  @Default("smartBackFromArticle")
  var smartBackFromArticle: Bool
  
  @Default("animateArticleSectionChange")
  var animateArticleSectionChange: Bool
  
  lazy var contentTablePlaceholder = UIViewController()
  
  var needValidAboToShareText: String {
    if feederContext.isAuthenticated == false {
      return "Sie müssen angemeldet sein, um Texte zu teilen!"
    }
    //otherwise: Defaults.expiredAccount
    return "Sie benötigen ein gültiges Abonnement, um Texte zu teilen!"
  }
  
  public var articles: [Article] = []
  public var article: Article? { articles.valueAt(index) }
  
  public override var delegate: IssueInfo! {
    didSet {
      if delegate == nil { return }
      guard let _ = delegate as? ArticleVCdelegate else {
        fatal("ArticleVC.delegate must be of type ArticleVCdelegate")
        return
      }
      if oldValue == nil { self.setup() } 
    }
  }
  
  public weak var adelegate: ArticleVCdelegate? {
    get { delegate as? ArticleVCdelegate }
    set { delegate = newValue }
  }
  
//  / Remove Article from page collection
  func delete(article: Article) {
    //not delete articles without filename
    guard let name = article.html?.name, name.length > 0 else { return }
    if let idx = articles.firstIndex(where: { $0.html?.name == name }) {
      articles.remove(at: idx)
      deleteContent(at: idx)
    }
  }
  
//  / Insert Article into page collection
  func insert(article: Article) {
    //not insert articles without filename
    guard let name = article.html?.name, name.length > 0 else { return }
    // only insert new Article
    guard articles.firstIndex(where: { $0.html?.name == name }) == nil
    else { return }
    
    if let idx = delegate.issue.allArticles.firstIndex(where: { $0.html?.name == name }) {
      ///print(">>> Insert article: \(article.title ?? "-") at index: \(idx) / \(articles.count - 1 )")
      articles.insert(article, at: max(0, min(idx, articles.count - 1)))
      insertContent(content: article, at: max(0, min(idx, contents.count - 1)))
    }
  }
  
  func displayBookmark(art: Article) {
    var bbHidden = true
    if let aDel = adelegate {
      #warning("ISSUE WAS NIL! SAVE IT")
      bbHidden = art.html?.isEqualTo(aDel.issue.imprint?.html) ?? false
    }
    bookmarkButton.isHidden = bbHidden
    
    if art.hasBookmark {
      bookmarkButton.buttonView.name = "star-fill"
      bookmarkButton.accessibilityLabel = "Lesezeichen: gesetzt"
    }
    else {
      bookmarkButton.buttonView.name = "star"
      bookmarkButton.accessibilityLabel = "Lesezeichen: setzen"
    }
  }
  
  override var currentAudioContent: Content? {
    self.article
  }
  
  var playButtonContextMenu: ContextMenu?
  
  func setup() {
    playButtonContextMenu
    = ContextMenu(view: playButton.buttonView,
                  smoothPreviewForImage: true)
    playButtonContextMenu?.itemPrivider = self
    
    if self.adelegate?.issue.isBookmarkIssue == true,
        let arts = self.adelegate?.issue.allArticles {
      self.articles = (arts as? [StoredArticle])?.bookmarkOrder() ?? arts
    }
    else if let arts = self.adelegate?.issue.allArticles {
      self.articles = arts
    }
    super.setup(contents: articles, isLargeHeader: false)
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      guard let self = self else {return}
      if let cart = msg.sender as? StoredArticle,
         let art = self.article,
         art.serverId != nil,
         cart.serverId == art.serverId {
         self.displayBookmark(art: art)
      }
    }
    
    /// do not add this in onDosplay otherwise it is called multiple times after swipe/scroll
    self.atEndOfContent { [weak self] isAtEnd in
      self?.handleAtEndOfContent(isAtEnd: isAtEnd)
    }
    
    self.onBookmark { [weak self] _ in
      guard let art = self?.article else { return }
      Bookmarks.toggle(article: art)
    }
    
    self.onPlay { [weak self] _ in
      guard let art = self?.article,
            let issue = self?.issue,
      art.canPlayAudio else { return }
      art.toggleAudio(issue: issue)
    }
    
    ArticlePlayer.singleton.onEnd { [weak self] err in
      self?.playButton.buttonView.name = "audio"
      if let err = err {
        self?.debug("Failed on end with err: \(err)")
      }
    }
    
    onDisplay { [weak self] (idx, ov) in
      guard let self = self else { return }
      guard let art = self.articles.valueAt(idx) else {
        ///prevent crash on search result login on 2nd or later load more results
        log("fail to access artikel at index: \(idx)  when only \(self.articles.count) exist")
        return
      }
      #if TAZ //Tom Stuff
      if art is VirtualArticle {
        bookmarkButton.isHidden = true
        updateAudioButton()
        shareButton.isHidden = true
        textSettingsButton.isHidden = true
        self.setHeader(artIndex: idx)
        self.currentWebView?.baseDir = art.baseURL
        return
      }
      #endif
      shareButton.isHidden = false
      textSettingsButton.isHidden = false

      if self.smartBackFromArticle {
        self.adelegate?.article = art
      }
      self.setHeader(artIndex: idx)
      issue.setLastRead(content: art, pageIndex: nil, scrollPosition: nil)
      /**Do not persist last Article here anymore,  due it overwrites the scroll Position**/
      //if !self.issue.isBookmarkIssue {}
      if art.canPlayAudio {
        updateAudioButton()
        updateAudioInWebview()
      }
      playButton.isHidden = !art.canPlayAudio
      self.displayBookmark(art: art)///hide bookmarkbutton for imprint!
      self.debug("on display: \(idx), article \(art.html?.name ?? "-"):\n\(art.title ?? "Unknown Title")")
    } ///eof: onDisplay
    whenLinkPressed { [weak self] (from, to) in
      LinkBusiness.handleLinkPressed(from: from, to: to,
                                     with: self?.adelegate)
    }
    whenLoaded {[weak self] _ in
      Notification.send(Const.NotificationNames.articleLoaded)
      guard let self = self,
            let art = self.articles.valueAt(self.index),
            art.canPlayAudio else { return }
      self.updateAudioInWebview()
    }
    header.titletype = .article
    header.isWochentaz = issue.isWeekend
    header.animateOnTitleChange = animateArticleSectionChange
  }
  
  var articleForLastRead: Article? {
    guard delegate != nil,
          let article = self.article,
          article is VirtualArticle == false, //Not for TOM'S'
          adelegate?.issue.isBookmarkIssue == false else {
      return nil
    }
    return article
  }
  
  override func persistReadProgress() {
    guard let art = articleForLastRead,
          let wv = self.currentWebView as WebView? else { return }
    issue.setLastRead(content: art, pageIndex: nil, scrollPosition: wv.scrollProgress)
  }
  
  func handleAtEndOfContent(isAtEnd: Bool){
    ///**FORMER:** art.primaryIssue?.isReduced == true
    /// did not work for Issue Independent Bookmarks in Bookmarks Article View
    guard isAtEnd,
    let art = self.article,
    art.isReducedArticle else { return }
   
    if TazAppEnvironment.sharedInstance.shouldAuthenticate {
      ///show Login OR Expired Form
      self.feederContext.authenticate()
      return
    }
    
    /// TazAppEnvironment.sharedInstance.hasValidAuth ...should no be demo
    if TazAppEnvironment.sharedInstance.feederContext?.isConnected == false {
      Toast.show(Localized("error_download"))
    }
  }

  // Define Header elements
  #warning("ToDo: Refactor get HeaderField with Protocol! (ArticleVC, SectionVC...)")
  func setHeader(artIndex: Int) {
    guard let nextArticle = articles.valueAt(artIndex) else {
      header.title = ""
      return
    }
    #if TAZ
    let tazTomVirtualArticle = nextArticle is VirtualArticle
    #else
    let tazTomVirtualArticle = App.isTAZ ///false, but supress "Will never be executed" warning 2 lines later
    #endif
    if tazTomVirtualArticle {
      header.title = nextArticle.title
      header.pageNumber = nil
      header.accessibilityLabel = "Karikatur: \(nextArticle.title ?? "")"
      header.accessibilityHint = nil
      header.accessibilityValue = nil
    }
    else if adelegate?.issue.isBookmarkIssue == true {
      let idx = articles.firstIndex {$0.serverId == nextArticle.serverId } ?? -2
      ///ensure old value is overwritten to not show wrong section
      header.title = nextArticle.sectionTitle ?? "" ///empty placeholder required to prevent jumping header ui
      header.titletype = .search
      header.subTitle = "Ausgabe \(nextArticle.issueDate?.short ?? "")"
      header.pageNumber = "\(idx+1) von \(articles.count)"
      header.accessibilityLabel = "Leseliste: \(header.pageNumber ?? "") aus \(header.subTitle ?? "") - \(nextArticle.title ?? "")"
      header.accessibilityHint = nil
      header.accessibilityValue = nil
    }
    else if let name = nextArticle.html?.name {
      if let sections = adelegate?.article2section[name],
         sections.count > 0 {
        let section = sections[0]
        if let title = section.title, let articles = section.articles {
          var i = 0
          for a in articles {
            if a.html?.name == nextArticle.html?.name { break }
            i += 1
          }
          if let st = nextArticle.sectionTitle { header.title = st }
          else { header.title = "\(title)" }
          //Exchange Labels if ArticleVC comes from Facsimile
          if let page = (adelegate as? TazPdfPagesViewController)?.page(for: nextArticle),
              let pagina = page.pagina {
            if let i = Int(pagina), i < 10 {
              header.title = String(format: "%02d", i)
            }
            else {
              header.title = pagina
            }
            header.pageNumber = "\(title)"
          }
          else {
            header.pageNumber = "\(i+1)/\(articles.count)"
          }
          sectionVCsContentTable?.setActive(row: i,
                                  section: adelegate?.article2index(art: nextArticle))
          header.accessibilityLabel = "\(nextArticle.sectionTitle ?? "") \(i+1)/\(articles.count): \(nextArticle.title ?? "")"
          header.accessibilityHint = "Tippen um zur Ressortübersicht \(nextArticle.sectionTitle ?? "") zurückzukehren. "
          header.accessibilityValue = "Artikel \(i+1) von \(issue.allArticles.count)"
        }
      }
      else if nextArticle.title != nil,
              nextArticle.html?.isEqualTo(adelegate?.issue.imprint?.html) == true,
              nextArticle.sectionTitle == nil {
        header.title = nextArticle.title
        header.pageNumber = nil
        header.accessibilityLabel = nextArticle.title
        header.accessibilityHint = nil
        header.accessibilityValue = nil
      }
      header.updateFonts()
    }
  }
  
  // Export/Share article
  public func exportArticle() {
    guard let art = self.article else { return }
    export(article: art)
  }
  
  /// Releases resources when the parent view controller is about to be dismissed.
  ///
  /// This is required for flows where the parent controller is not reused
  /// (e.g. when opened from SectionVC or PDF), to avoid keeping unnecessary
  /// references or resources alive.
  ///
  /// In cases like "Leseliste" or "Search", cleanup is not required because
  /// theese parent controllers are root controllers of the TabBarController
  /// and remain in memory for reuse.
  override func cleanup() {
    articles = []
    (delegate as? IssueDisplayService)?.continueReadingCtrl = nil
    (adelegate as? IssueDisplayService)?.continueReadingCtrl = nil
    delegate = nil
    adelegate = nil
    playButtonContextMenu?.itemPrivider = nil
    self.playButtonContextMenu = nil
    super.cleanup()
  }
    
  public override func viewWillAppear(_ animated: Bool) {
    /// Set Content Table if needed
    if self.navigationController?.viewControllers.first is BookmarkTVC { /*NO CONTENT TABLE*/}
    else if self is ArticleVcWithPdfInSlider { /*NO CONTENT TABLE*/}
    else if let sectionSlider = (self.adelegate as? SectionVC)?.slider {
      /// **exchange  Content Table from SectionVC**
      self.slider?.exchangeSliderContent(from: sectionSlider)
    }
    super.viewWillAppear(animated)
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if let sectionSlider = (self.adelegate as? SectionVC)?.slider {
      self.slider?.exchangeSliderContent(from: sectionSlider)
    }
    persistReadProgress()
  }
  
  private var sectionVCsContentTable: NewContentTableVC? {
    return (self.adelegate as? SectionVC)?.contentTable
  }
 
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    onShare { [weak self] _ in
      guard let self = self else { return }
      self.debug("*** Action: Share Article")
      if self.article?.isShareable == false && feeder.hasValidAbo == false {
        Usage.track(Usage.event.dialog.SharingNotPossible)
        Alert.actionSheet(message: self.needValidAboToShareText,
                          actions: UIAlertAction.init( title: self.feederContext.isAuthenticated ? "Weitere Informationen" : "Anmelden",
                                                       style: .default ){ [weak self] _ in
          self?.feederContext.authenticate()
        })
      } else {
        self.exportArticle()
      }
    }
    
    let suche = UIMenuItem(title: "Suche", action: #selector(search))
    UIMenuController.shared.menuItems = [suche]
    showMultiColumnOnboardingIfNeeded()
    ///ensure article is perstisted, also on recall same article after art>sect>art
    guard delegate != nil else { return }
    issue.setLastRead(content: self.articles.valueAt(index), pageIndex: nil, scrollPosition: nil)
  }
  
  public override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    UIMenuController.shared.menuItems = nil
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    if self is ArticleVcWithPdfInSlider || issue.isBookmarkIssue {
      /*NO CONTENT TABLE*/
    }
    else {
      slider = MyButtonSlider(slider: contentTablePlaceholder, into: self)
      setupSlider()
    }
  }
  
} // ArticleVC

//MARK: - Context Menu Actions
extension ArticleVC {
  @objc func search() {
    self.currentWebView?.evaluateJavaScript("window.getSelection().toString()", completionHandler: {[weak self] selectedText, err in
      guard let self = self else {return}
      if let e = err { self.log(e.description)}
      //#warning("ToDo: 0.9.4+ Implement Search")
      guard let txt = selectedText as? String, txt.length > 2 else {
        log("No valid Selection for Search: \(String(describing: selectedText))")
        return
      }
      Notification.send(Const.NotificationNames.searchSelectedText,
                        content: txt,
                        error: nil,
                        sender: self)
    })
  }
}

extension ArticleVC {
  private static var dialogAlreadyShown = false
  
  func showMultiColumnOnboardingIfNeeded(){
    ///issue comes from delegate and may be unset on deinit; so check it before use it
    guard self.delegate != nil, self.issue.isReduced == false else { return }
    guard multiColumnOnboardingAnswered == false else { return }
    guard Device.isIpad else { return }
    guard UIDevice.isLandscape else { return }
    guard traitCollection.horizontalSizeClass == .regular else { return }
    guard Self.dialogAlreadyShown == false else { return }
    guard UIAccessibility.isVoiceOverRunning == false else { return }
    guard multiColumnModeLandscape == false else { return }
    Self.dialogAlreadyShown = true
    showMultiColumnOnboarding()
  }
  private func showMultiColumnOnboarding(){
    let mcoVc = MultiColumnOnboarding()
    mcoBottomSheet = BottomSheet2(slider:mcoVc , into: self)
    mcoBottomSheet?.handle?.isHidden = true
    mcoBottomSheet?.onX {[weak self] in
      self?.mcoBottomSheet?.close()
    }
    mcoBottomSheet?.xButton.tazX()
    mcoBottomSheet?.updateMaxWidth(defaultWidth: 620)
    mcoBottomSheet?.sliderView.backgroundColor = Const.SetColor.taz(.primaryBackground).color
    /*
    let s = mcoVc.view.sizeThatFits(CGSize(width: mcoVc.view.frame.size.width, height: 3000))
    print(">>>sizeThatFits w: \(mcoVc.view.frame.size.width) is: \(s)")
    mcoBottomSheet?.coverage = s.height + 30*/
    mcoBottomSheet?.coverage = 525
    mcoBottomSheet?.open()
    mcoVc.contentView.declineButton.addTarget(self,
                                        action: #selector(declineButtonPressed),
                                        for: .touchUpInside)
    mcoVc.contentView.activateButton.addTarget(self,
                                        action: #selector(activateButtonPressed),
                                        for: .touchUpInside)
  }
  
  @objc func declineButtonPressed(sender: UIButton) {
    multiColumnOnboardingAnswered = true
    mcoBottomSheet?.close()
  }
  
  @objc func activateButtonPressed(sender: UIButton) {
    multiColumnOnboardingAnswered = true
    multiColumnModeLandscape = true
    edgeTapToNavigate = true
    Notification.send(globalStylesChangedNotification)
    updateTapArea()
    mcoBottomSheet?.close()
    ensureToolbarInFrontOfTapButtons()
  }
  
  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    if UIDevice.isPortrait { mcoBottomSheet?.close() }
  }
}

class MultiColumnOnboarding: UIViewController {
  
  lazy var contentView = MultiColumnOnboardingView()
    
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(contentView)
    pin(contentView, to: self.view)
  }
}

class MultiColumnOnboardingView: UIView {
  var title = UILabel(Localized("multicol_onboarding_title")).marketingHead()
  var text = UILabel(Localized("multicol_onboarding_text"), _numberOfLines: 0).contentFont()
  var iv = UIImageView()
  
  lazy var spacer: UIView = {
    let s = UIView(frame: CGRectZero)
    s.setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
    return s
  }()
  
  lazy var buttonsStack: UIStackView = {
    let s = UIStackView()
    s.axis = .horizontal
    s.distribution = .fillEqually
    s.spacing = 18.0
    s.addArrangedSubview(declineButton)
    s.addArrangedSubview(activateButton)
    return s
  }()
  
  lazy var image: UIImage? = {
    guard let img = UIImage(named: "BundledResources\(App.isTAZ ? "" : "LMd")/MultiColumn.jpeg")else {
      log("Bundled MultiColumn.jpeg not found!")
      return nil
    }
    return img
  }()
  
  var declineButton = Padded.Button(type: .outline, title: Localized("multicol_onboarding_btn_decline"))
  var activateButton = Padded.Button(title: Localized("multicol_onboarding_btn_activate"))
  private func setup() {
    self.addSubview(title)
    self.addSubview(iv)
    self.addSubview(text)
    self.addSubview(buttonsStack)
    self.addSubview(spacer)
    let pad = 33.0
    pin(title, to: self, dist: pad, exclude: .bottom)
    
    title.setContentHuggingPriority(.defaultHigh, for: .vertical)
    text.setContentHuggingPriority(.defaultHigh, for: .vertical)
    
    iv.image = image
    iv.contentMode = .scaleAspectFit
    
    pin(iv.top, to: title.bottom, dist: pad)
    pin(text.top, to: title.bottom, dist: 18)
    pin(buttonsStack.top, to: text.bottom, dist: 18)
    pin(spacer.top, to: text.bottom, dist: pad)
    pin(spacer.bottom, to: self.bottomGuide())
    
    pin(iv.left, to: self.left, dist: pad)
    pin(text.right, to: self.right, dist: -pad)
    pin(text.left, to: iv.right, dist: 18.0)
    
    iv.pinWidth(to: declineButton.width)
    iv.pinHeight(to: text.height, factor: 0.9)
    
    pin(buttonsStack.left, to: self.left, dist: pad)
    pin(buttonsStack.right, to: self.right, dist: -pad)
    backgroundColor = Const.SetColor.taz(.primaryBackground).color
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}

extension WebView {
  
  var scrollProgress: CGFloat {
    let contentSize = scrollView.contentSize
    let boundsSize = scrollView.bounds.size
    let offset = scrollView.contentOffset
    
    if Defaults.multiColumnMode {
      guard contentSize.width > boundsSize.width else { return 0.0 }
      let progress = offset.x / (contentSize.width - boundsSize.width)
      debug(">>> getScrollProgressH \(clamp(progress)) forOffset: \(offset.x), csWidth: \(contentSize.width), bsWidth: \(boundsSize.width)")
      return clamp(progress)
    } else {
      guard contentSize.height > boundsSize.height else { return 0.0 }
      let progress = (offset.y) / contentSize.height
      debug(">>> getScrollProgressV \(clamp(progress)) forOffset: \(offset.y), csHeight: \(contentSize.height), bsHeight: \(boundsSize.height)")
      return clamp(progress)
    }
  }
  
  private func clamp(_ value: CGFloat) -> CGFloat {
    return min(max(value, 0.0), 1.0)
  }
}

//// MARK: - ContentVC Accessibility
extension ArticleVC {
  @objc override var nextItemAccessibilityLabel: String? {
    guard index < self.articles.count - 1 else { return nil }
    return "Nächster Artikel: \(self.articles.valueAt(index + 1)?.accessibilityTitle ?? "")"
  }
  
  @objc override var prevItemAccessibilityLabel: String? {
    guard index > 0 else { return nil }
    return "Vorheriger Artikel: \(self.articles.valueAt(index + -1)?.accessibilityTitle ?? "")"
  }
}
