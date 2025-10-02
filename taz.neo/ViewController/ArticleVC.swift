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
  
  var needValidAboToShareText: String {
    if feederContext.isAuthenticated == false {
      return "Sie müssen angemeldet sein, um Texte zu teilen!"
    }
    //otherwise: Defaults.expiredAccount
    return "Sie benötigen ein gültiges Abonnement, um Texte zu teilen!"
  }
  
  public var articles: [Article] = []
  public var article: Article? { 
    if let i = index { return articles.valueAt(i) }
    return nil
  }
  
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
  
  /// Remove Article from page collection
  func delete(article: Article) {
    //not delete articles without filename
    guard let name = article.html?.name, name.length > 0 else { return }
    if let idx = articles.firstIndex(where: { $0.html?.name == name }) {
      articles.remove(at: idx)
      deleteContent(at: idx)
    }
  }
  
  /// Insert Article into page collection
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
      bbHidden = art.html?.isEqualTo(aDel.issue.imprint?.html) ?? false
    }
    bookmarkButton.isHidden = bbHidden
    
    if art.hasBookmark { self.bookmarkButton.buttonView.name = "star-fill" }
    else { self.bookmarkButton.buttonView.name = "star" }
  }
  
  func updateAudioButton(){
    self.playButton.buttonView.name
    = ArticlePlayer.singleton.isPlaying
    && ArticlePlayer.singleton.currentContent?.html?.sha256 == self.article?.html?.sha256
    ? "audio-active"
    : "audio"
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
    Notification.receive(Const.NotificationNames.audioPlaybackStateChanged) { [weak self] _ in
      self?.updateAudioButton()
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
    
    onDisplay { [weak self] (idx, _, _) in
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
      issue.setLastRead(pageIndex: nil, articleIndex: idx, sectionIndex: nil, scrollPosition: nil)
      /**Do not persist last Article here anymore,  due it overwrites the scroll Position**/
      //if !self.issue.isBookmarkIssue {}
      if art.canPlayAudio {
        updateAudioButton()
      }
      playButton.isHidden = !art.canPlayAudio
      self.displayBookmark(art: art)///hide bookmarkbutton for imprint!
      self.debug("on display: \(idx), article \(art.html?.name ?? "-"):\n\(art.title ?? "Unknown Title")")
    } ///eof: onDisplay
    whenLinkPressed { [weak self] (from, to) in
      /** FIX wrong Article shown (most errors on iPad, some also on Phone)
          after re-enter app due wired Scroll Pos change
          @see:  https://developer.apple.com/forums/thread/47100
          unfortunately is our behaviour quite complex, a simple return in viewWillTransition...
          destroys the layout or raise other errors
          so this is currently the most effective solution
       **/
      if UIApplication.shared.applicationState != .active { return }
      self?.adelegate?.linkPressed(from: from, to: to)
    }
    whenLoaded { _ in
      Notification.send(Const.NotificationNames.articleLoaded)
    }
    header.titletype = .article
    header.isWochentaz = issue.isWeekend
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
    
    issue.setLastRead(pageIndex: nil,
                      articleIndex: articles.firstIndex(where: { $0.html?.name == art.html?.name }) ?? 0,
                      sectionIndex: nil,
                      scrollPosition: wv.scrollProgress)
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
    #if TAZ
    let tazTomVirtualArticle = article is VirtualArticle
    #else
    let tazTomVirtualArticle = App.isTAZ ///false, but supress "Will never be executed" warning 2 lines later
    #endif

    if tazTomVirtualArticle {
      header.title = article?.title
      header.pageNumber = nil
    }
    else if adelegate?.issue.isBookmarkIssue == true {
      let idx = articles.firstIndex {$0.serverId == article?.serverId } ?? -2
      if let st = article?.sectionTitle { header.title = st }
      header.titletype = .search
      header.subTitle = "Ausgabe \(article?.issueDate?.short ?? "")"
      header.pageNumber = "\(idx+1) von \(articles.count)"
    }
    else if let art = article, let name = art.html?.name {
      if let sections = adelegate?.article2section[name],
         sections.count > 0 {
        let section = sections[0]
        if let title = section.title, let articles = section.articles {
          var i = 0
          for a in articles {
            if a.html?.name == article?.html?.name { break }
            i += 1
          }
          if let st = art.sectionTitle { header.title = st }
          else { header.title = "\(title)" }
          header.pageNumber = "\(i+1)/\(articles.count)"
          contentTable?.setActive(row: i,
                                  section: adelegate?.article2index(art: art))
        }
      }
      else if art.title != nil,
              art.html?.isEqualTo(adelegate?.issue.imprint?.html) == true,
              art.sectionTitle == nil {
        header.title = art.title
        header.pageNumber = nil
      }
      header.updateFonts()
    }
  }
  
  // Export/Share article
  public func exportArticle() {
    guard let art = self.article else { return }
    export(article: art)
  }
  
  public override func setupSlider() {
    super.setupSlider()
    contentTable?.onArticlePress{[weak self] article in
      guard let self = self else { return }
      let url = article.dir.url.absoluteURL.appendingPathComponent(article.html?.name ?? "")
      self.adelegate?.linkPressed(from: nil, to: url)
      self.slider?.close()
    }
    contentTable?.onSectionPress { [weak self] sectionIndex in
      guard let self = self, let adelegate = self.adelegate else { return }
      if sectionIndex >= adelegate.sections.count {
        self.debug("*** Action: Impressum pressed")
      }
      else {
        self.debug("*** Action: Section \(sectionIndex) " +
          "(delegate.sections[sectionIndex])) in Slider pressed")
      }
      self.adelegate?.displaySection(index: sectionIndex)
      self.slider?.close()
      self.navigationController?.popViewController(animated: false)
    }
    contentTable?.onImagePress { [weak self] in
      self?.debug("*** Action: Moment in Slider pressed")
      self?.slider?.close()
      let issueDate = self?.issue.date
      self?.adelegate?.closeIssue()
      Notification.send(Const.NotificationNames.gotoIssue, content: issueDate , sender: self)
    }
  }
  
  open override func releaseOnDisappear(){
    contentTable = nil
    articles = []
    delegate = nil
    playButtonContextMenu?.itemPrivider = nil
    self.playButtonContextMenu = nil
    super.releaseOnDisappear()
  }
    
  public override func viewWillAppear(_ animated: Bool) {
    if self.invalidateLayoutNeededOnViewWillAppear {
      self.collectionView?.isHidden = true
    }
    else if self.navigationController?.viewControllers.first is BookmarkTVC { /*NO CONTENT TABLE*/}
    else if self is ArticleVcWithPdfInSlider { /*NO CONTENT TABLE*/}
    else if self.contentTable == nil {
      self.contentTable = NewContentTableVC()
    }
    super.viewWillAppear(animated)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    if self.invalidateLayoutNeededOnViewWillAppear {
      self.invalidateLayoutNeededOnViewWillAppear = false
      self.collectionView?.collectionViewLayout.invalidateLayout()
      self.collectionView?.fixScrollPosition()
      self.collectionView?.showAnimated()
    }
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
    issue.setLastRead(pageIndex: nil, articleIndex: index, sectionIndex: nil, scrollPosition: nil)
  }
  
  public override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    UIMenuController.shared.menuItems = nil
  }
} // ArticleVC

//MARK: - Context Menu Actions
extension ArticleVC {
  @objc func search() {
    self.currentWebView?.evaluateJavaScript("window.getSelection().toString()", completionHandler: {[weak self] selectedText, err in
      guard let self = self else {return}
      if let e = err { self.log(e.description)}
      //#warning("ToDo: 0.9.4+ Implement Search")
      guard let txt = selectedText as? String, txt.length > 3 else {
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
    guard multiColumnModeLandscape == false else { return }
    Self.dialogAlreadyShown = true
    showMultiColumnOnboarding()
  }
  private func showMultiColumnOnboarding(){
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
