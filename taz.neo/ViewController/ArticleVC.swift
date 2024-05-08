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
  
    
  var hasValidAbo: Bool {feederContext.isAuthenticated && !Defaults.expiredAccount}
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
    let all = delegate.issue.allArticles
    if let idx = all.firstIndex(where: { $0.html?.name == name }) {
      articles.insert(article, at: idx)
      insertContent(content: article, at: idx)
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
  
  func toggleBookmark(art: StoredArticle?) {
    guard let art = art else { return }
    var msg: String
    var completion:((Bool)->())? = nil
    
    if art.hasBookmark {
      msg = "Der Artikel wurde aus ihrer Leseliste entfernt.<br/>Löschen rückgängig durch Antippen"
      completion = { wasTapped in
        guard wasTapped else { return }
        art.hasBookmark = true
        Toast.show("Löschen wurde wiederrufen!")
      }
    }
    else { msg = "Der Artikel wurde in ihrer Leseliste gespeichert." }
    Toast.show("<h3>\(art.title ?? "")</h3>\(msg)",
               minDuration: 0,
               completion: completion)
    art.hasBookmark.toggle()
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
    
    if let arts = self.adelegate?.issue.allArticles {
      self.articles = arts
    }
    super.setup(contents: articles, isLargeHeader: false)
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      guard let self = self else {return}
      if let cart = msg.sender as? StoredArticle,
         let art = self.article,
         cart.html?.name == art.html?.name {
         self.displayBookmark(art: art)
      }
    }
    Notification.receive(Const.NotificationNames.audioPlaybackStateChanged) { [weak self] _ in
      self?.updateAudioButton()
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
      textSettingsButton.isHidden = false

      if self.smartBackFromArticle {
        self.adelegate?.article = art
      }
      self.shareButton.isHidden = self.hasValidAbo && art.onlineLink?.isEmpty != false
      self.setHeader(artIndex: idx)
      self.issue.lastArticle = idx
      if self.issue is BookmarkIssue == false {
        LastReadBusiness.persist(lastArticle: art, page: nil, in: self.issue)
      }
      let player = ArticlePlayer.singleton
      if art.canPlayAudio {
        updateAudioButton()
        self.onPlay { [weak self] _ in
          guard let self = self else { return }
          art.toggleAudio(issue: self.issue)
        }
      }
      else { self.onPlay(closure: nil) }
      player.onEnd { [weak self] err in
        self?.playButton.buttonView.name = "audio"
        guard let err = err else { return }
      }
      self.onBookmark { [weak self] _ in
        guard let self = self else { return }
        self.toggleBookmark(art: art as? StoredArticle)
      }
      ///     && (feederContext.isAuthenticated == false || Defaults.expiredAccount) bookmarks finally did not refresh
      if art.primaryIssue?.isReduced == true {
        self.atEndOfContent() { [weak self] isAtEnd in
          if isAtEnd { self?.feederContext.authenticate() }
        }
      }
      self.displayBookmark(art: art)///hide bookmarkbutton for imprint!
      self.debug("on display: \(idx), article \(art.html?.name ?? "-"):\n\(art.title ?? "Unknown Title")")
      showCoachmarkIfNeeded()
    }
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
    whenLoaded {
      Notification.send(Const.NotificationNames.articleLoaded)
    }
    header.onTitle { [weak self] _ in
      self?.debug("*** Action: ToSection pressed")
      self?.navigationController?.popViewController(animated: true)
    }
    header.titletype = .article
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
       
          
          if section is BookmarkSection {
            header.titletype = .search
            header.subTitle = "Ausgabe \(art.issueDate.short)"
            header.pageNumber = "\(i+1) von \(articles.count)"
          }
          else {
            header.pageNumber = "\(i+1)/\(articles.count)"
          }
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
    }
  }
  
  @available(iOS 14.0, *)
  private func exportPdf(article art: Article, from button: UIView? = nil) {
    if let webView = currentWebView {
      webView.pdf { data in
        guard let data = data else { return }
        let dialogue = ExportDialogue<Data>()
        let altText = "\(art.teaser ?? "")\n\(art.onlineLink!)"
        dialogue.present(item: data, altText: altText, onlineLink: art.onlineLink, view: button,
                         subject: art.title)
      }
    }
  }

  // Export/Share article
  public static func exportArticle(article: Article?, artvc: ArticleVC? = nil, 
                                   from button: UIView? = nil) {
    
    let img = article?.images?.first?.image(dir: artvc?.delegate.issue.dir)
    
    if let art = article,
       let link = art.onlineLink,
       !link.isEmpty{
          let dialogue = ExportDialogue<Any>()
        dialogue.present(item: link,
                       altText: nil,
                       onlineLink: link,
                       view: button,
                       subject: art.title,
                       image: img)
    }
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
      self?.navigationController?.popViewController(animated: false)
      self?.adelegate?.closeIssue()
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
    if self.parent is BookmarkNC { /*NO CONTENT TABLE*/}
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
      CoachmarksBusiness.shared.deactivateCoachmark(Coachmarks.Article.share)
      self.debug("*** Action: Share Article")
      if (self.article?.onlineLink ?? "").isEmpty {
        Usage.track(Usage.event.dialog.SharingNotPossible)
        Alert.actionSheet(message: self.needValidAboToShareText,
                          actions: UIAlertAction.init( title: self.feederContext.isAuthenticated ? "Weitere Informationen" : "Anmelden",
                                                       style: .default ){ [weak self] _ in
          self?.feederContext.authenticate()
        })
      } else {
        if self.issue is SearchResultIssue {
          Usage.xtrack.share.searchHit(article: self.article)
        }
        else {
          Usage.xtrack.share.article(article: self.article)
        }
        ArticleVC.exportArticle(article: self.article, artvc: self, from: self.shareButton)
      }
    }
    
    let suche = UIMenuItem(title: "Suche", action: #selector(search))
    UIMenuController.shared.menuItems = [suche]
    showMultiColumnOnboardingIfNeeded()
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
        log("No valid Selection for Search: \(selectedText)")
        return
      }
      Notification.send(Const.NotificationNames.searchSelectedText,
                        content: txt,
                        error: nil,
                        sender: self)
    })
  }
}

extension ArticleVC: CoachmarkVC {
  
  public var viewName: String { Coachmarks.Article.typeName }
  
  public func targetView(for item: CoachmarkItem) -> UIView? {
    guard let item = item as? Coachmarks.Article else { return nil }
    
    switch item {
      case .audio:
        return playButton.buttonView
      case .share:
        return shareButton.buttonView
      case .font:
        return textSettingsButton.buttonView
    }
  }
}


extension ArticleVC {
  private static var dialogAlreadyShown = false
  
  func showMultiColumnOnboardingIfNeeded(){
    guard self.issue.isReduced == false else { return }
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
    guard let img = UIImage(named: "BundledResources/MultiColumn.jpeg")else {
      log("Bundled MultiColumn.png not found!")
      return nil
    }
    return img
  }()
  
  var declineButton = Padded.Button(type: .newBlackOutline, title: Localized("multicol_onboarding_btn_decline"))
  var activateButton = Padded.Button(type: .newBlack, title: Localized("multicol_onboarding_btn_activate"))
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
