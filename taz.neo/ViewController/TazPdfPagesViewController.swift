//
//  TazPdfPagesViewController.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 18.11.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//


/**
 ***REFACTOR URGENTLY NEEDED!!!**
 - structure/architecture for PDF-Slider-ArticleVC-Slider relation
 - separate classes in this file!
 - Refactor Model, we have 3 ZoomedPdfPageImage (ZoomedPdfImage, OptionalImageItem, ZoomedPdfImageSpec), NewPdfModel (PdfModel), IssueInfo
 - try to find common protocoll or inheritance also for contentTableVC, NewContentTable, LMdSliderContentVC and TazPdfPagesViewController
 */

import Foundation
import NorthLib
import PDFKit

protocol PdfDownloadDelegate {
  func downloadPdf(_ page:Page, finishedCallback: @escaping ((Bool)->()))
}

// MARK: - ZoomedPdfPageImage
/// A ZoomedPdfPageImage handles PageReference (Page) PDF Files with their first PDF Page
/// - usually they have only 1 Page
public class ZoomedPdfPageImage: ZoomedPdfImage {
  public override var pageType : PdfPageType {
    get { 
      switch pageReference?.type {
      case .double:
        return . double
      case .right:
        return .right
      default:
        return .left
      }
    }
    set {}
  }
  var pageReference : Page?
  var issueDir : Dir?
  open override var pageTitle: String? {
    get {
      return pageReference?.title
    }
    set {}
  }
  open override var pdfPage: PDFPage? {
    get {
      if let doc = pageReference?.pdfDocument(inIssueDir: issueDir), doc.pageCount > 0 {
        return doc.page(at: 0)
      }
      return nil
    } 
  }
  
  var pdfDownloadDelegate:PdfDownloadDelegate?
  
  public override func renderFullscreenImageIfNeeded(finishedCallback: ((Bool) -> ())?) {
    
    if pdfPage == nil,
       let downloadDelegate = pdfDownloadDelegate,
       let page = self.pageReference {
      downloadDelegate.downloadPdf(page) { success in
        if success == false { finishedCallback?(false); return }
        super.renderFullscreenImageIfNeeded(finishedCallback: finishedCallback)
      }
    }
    super.renderFullscreenImageIfNeeded(finishedCallback: finishedCallback)
  }
  
  convenience init(page:Page, issueDir : Dir?) {
    self.init()
    self.issueDir = issueDir
    self.pageReference = page
    self.sectionTitle = "\(page.type)"
  }
}

// MARK: - TazPdfPagesViewController
/// Provides functionallity to interact between PdfOverviewCollectionVC and Pages with PdfPagesCollectionVC
open class TazPdfPagesViewController : PdfPagesCollectionVC, ArticleVCdelegate, UIStyleChangeDelegate {
  
  @Default("autoHideToolbar")
  var autoHideToolbar: Bool
  
  private var hideOnScroll: Bool {
    if UIScreen.isIpadRegularHorizontalSize {
      return false
    }
    if autoHideToolbar == false {
      return false
    }
    if ArticlePlayer.singleton.isOpen {
      return false
    }
    if issue.status == .reduced {
      return false
    }
    return true
  }
  
  public var section: Section?
  
  public var sections: [Section]
  
  @Default("smartBackFromArticle")
  var smartBackFromArticle: Bool
  
  public var article: Article? {
    didSet {
      if smartBackFromArticle == false { return }
      guard let mod = self.pdfModel as? NewPdfModel else { return }
      guard let art = article else { return }
      let i = mod.pageIndexForArticle(art)
      self.index = i
      #if LMD
      childArticleVC?.header.title = "Seite \((i ?? 0) + 1)"
      #endif
    }
  }
  ///reference to pushed child vc, if any
  var childArticleVC: ArticleVcWithPdfInSlider
  
  public var article2section: [String : [Section]]
  public func displaySection(index: Int) { log("displaySection not implemented")}
  
  // MARK: - linkPressed
  public func linkPressed(from: URL?, to: URL?) {
    guard let to = to else { return }
    let fn = to.lastPathComponent
    let top = navigationController?.topViewController
    debug("*** Action: Link pressed from: \(from?.lastPathComponent ?? "[undefined]") to: \(fn)")
    if let avc = top as? ArticleVC,
      to.isFileURL,
      issue.article2sectionHtml[fn] != nil {
      avc.gotoUrl(url:to)
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
  
  func page(for art: Article) -> Page? {
    func _page1(for art: Article) -> Page? {
      self.issue.pages?.first { page in
        page.frames?.first(where: { $0.link?.lastPathComponent == art.path.lastPathComponent}) != nil
      }
    }
    func _page2(for art: Article) -> Page? {
      for pageName in art.pageNames ?? [] {
        return issue.pages?.first(where: { $0.pdf?.name == pageName })
      }
      return nil
    }
    
    
    if let directPage = _page2(for: art){ return directPage }
    
    guard let artFilename = art.html?.name,
          let sections = article2section[artFilename] else { return nil }
    
    for sect in sections {
      guard art.sectionTitle == sect.title else { continue }
      for art in sect.articles ?? [] {
        guard let page = _page2(for: art) else { continue }
        return page
      }
    }
    return nil
  }
  
  public func closeIssue() {
    self.navigationController?.popViewController(animated: false)
  }
  
  public var feederContext: FeederContext
  
  public var issue: Issue
  
  public func resetIssueList() {
    print("TODO: resetIssueList")
  }
  
  var sliderContentController : UIViewController?
  var slider:MyButtonSlider?
  
  @Default("isPdfPageMode")
  public var isPdfPageMode: Bool
  
  @Default("articleFromPdf")
  public var articleFromPdf: Bool
  
  @Default("doubleTapToZoomPdf")
  public var doubleTapToZoomPdf: Bool
  
  @Default("fullPdfOnPageSwitch")
  public var fullPdfOnPageSwitch: Bool
 
  // MARK: - updateMenuItems
  func updateMenuItems(updatedSizeIsLandscape: Bool? = nil){
    self.menuItems = [
      ("Artikelansicht",
       articleFromPdf ? "checkmark" : "",
       { [weak self] _ in
        guard let self = self else { return }
        self.articleFromPdf = !self.articleFromPdf
        self.updateMenuItems()
       }),
      ("Zoom per Doppel Tap",
       doubleTapToZoomPdf ? "checkmark" : "",
       { [weak self] _ in
        guard let self = self else { return }
        self.doubleTapToZoomPdf = !self.doubleTapToZoomPdf
        self.updateMenuItems()
       })
    ]
    
    if App.isAlpha {
      self.menuItems.insert((title: "Zoom 1:1 (⍺)",
                             icon: "1.magnifyingglass",
                             
                             
                             closure: { [weak self] _ in
        if let ziv = self?.currentView as? ZoomedImageView  {
          ziv.scrollView.setZoomScale(1.0, animated: true)
        }
      }), at: 0)
    }

    if updatedSizeIsLandscape == nil && UIWindow.isLandscape
    || updatedSizeIsLandscape != nil && updatedSizeIsLandscape ?? false {
      self.menuItems.append((title: "Breite einpassen",
                            icon: fullPdfOnPageSwitch ? "" : "checkmark",
                            closure: {[weak self] _ in self?.changePageHandling()}))
      self.menuItems.append((title: "ganze Seite",
                            icon: fullPdfOnPageSwitch ? "checkmark" : "",
                            closure: {[weak self] _ in self?.changePageHandling()}))
    }
    
    (self.currentView as? ZoomedImageViewSpec)?.menu.menu = self.menuItems
  }
  
  func changePageHandling(){
    self.fullPdfOnPageSwitch = !self.fullPdfOnPageSwitch
    self.updateMenuItems()
    if let ziv = self.currentView as? ZoomedImageView {
      onMainAfter {   [weak self] in
        self?.applyPageLayout(ziv)
      }
    }
  }
  
  public var toolBar = ContentToolbar()
  
  open override var preferredStatusBarStyle: UIStatusBarStyle {
    return isPdfPageMode || Defaults.darkMode ?  .lightContent : .darkContent
    ///former: return App.isLMD ? .darkContent : .lightContent
  }
  
  
  // MARK: - init
  public init(issueInfo:IssueInfo) {
    Log.minLogLevel = .Debug
    let pdfModel = NewPdfModel(issueInfo: issueInfo)
    
    var title
    = issueInfo.issue.validityDateText(timeZone: issueInfo.feeder.timeZone)
    title = title.replacingOccurrences(of: ", ", with: ",\n")
    title = title.replacingOccurrences(of: "Woche ", with: "Woche\n")
    pdfModel.title = title
    
    self.sections = issueInfo.issue.sections ?? []
    self.article2section = issueInfo.issue.article2section
    self.feederContext = issueInfo.feederContext
    self.issue = issueInfo.issue
    
    childArticleVC = ArticleVcWithPdfInSlider(feederContext: issueInfo.feederContext)
    
    super.init(data: pdfModel, useTopGradient: App.isTAZ)
    hidesBottomBarWhenPushed = true
    
    childArticleVC.delegate = self
    childArticleVC.header.onTitle { [weak self] _ in
      self?.debug("*** Action: Header back to Page pressed")
      if let art = self?.childArticleVC.article,
         let page = self?.page(for: art),
         let idx = self?.issue.pages?.firstIndex(where: { $0.pdf?.fileName == page.pdf?.fileName }){
           self?.index = idx
      }
      ///old:  let idx = pdfModel.pageIndexForArticle(art)
      self?.childArticleVC.navigationController?.popViewController(animated: true)
    }
    
    let sliderCtrl = NewPdfOverviewCollectionVC(pdfModel: pdfModel)
    sliderCtrl.menuHeaderView.listenButton.onTapping { [weak self] _ in
      self?.tapPlayInSlider()
    }
    self.updateMenuAudioButton()
    
    sliderContentController = sliderCtrl
    
    self.onTap { [weak self] (oimg, x, y) in
      guard let self = self else { return }
      
      if let section = (oimg as? ZoomedPdfPageImage)?.pageReference?.sectionAudio {
        section.toggleAudio()
        return
      }
      if self.articleFromPdf == false { return }
      guard let zpdfi = oimg as? ZoomedPdfPageImage else { return }
      guard let link = zpdfi.pageReference?.tap2link(x: Float(x), y: Float(y)),
            let path = zpdfi.issueDir?.path else { return }
      self.openArticle(name: link, path: path, reopenArticleScrollPos: nil)
   
    }
  }
  
  var playingCurrentSection: Bool {
    return ArticlePlayer.singleton.isPlaying
    && ArticlePlayer.singleton.currentPlayingContent?.html?.sha256 ==
    sectionAudio()?.html?.sha256
  }
  
  var playingCurrentIssue: Bool {
    ArticlePlayer.singleton.currentPlayingContent?.primaryIssue?.date.issueKey
    == self.issue.date.issueKey
  }
  
  func updateAudioButtons(){
    audioButton?.buttonView.name = playingCurrentSection ? "audio-active" : "audio"
    updateMenuAudioButton()
  }
   
  private func updateMenuAudioButton(){
    guard let listenButton = (sliderContentController as? NewPdfOverviewCollectionVC)?.menuHeaderView.listenButton else { return }
    updateListenButton(for: listenButton)
  }
    
  private func updateListenButton(for target:IconLabelButton){
    let playing = playingCurrentIssue && ArticlePlayer.singleton.isPlaying
    target.label.text = "Ausgabe hören"
    target.imageView.image = UIImage(named: playing  ? "audio-active" : "audio")
  }
    
  func openArticle(name: String?, path: String?, reopenArticleScrollPos: CGFloat?){
    guard let pdfModel = pdfModel as? NewPdfModel else { return }
    guard pdfModel.issueInfo != nil else { return }
    guard let name = name else { return }
    guard let path = path else { return }
    
    if let url = URL(string: name), UIApplication.shared.canOpenURL(url) {
      url.openLinkAndTrackAdIfNeeded()
      return
    }
    else if let pageIdx = pdfModel.pageIndexForLink(name) {
      self.collectionView.scrollToIndex(pageIdx,animated: true)
      return
    }
    
    childArticleVC.reopenArticleDocName = name
    childArticleVC.reopenArticleScrollPos = reopenArticleScrollPos
    let artFile = File(dir: path, fname: name)
    ///check if article file exists, otherwise log and return => do not open wrong article
    guard artFile.exists || File(dir: path, fname: name.replacingOccurrences(of: ".html", with: ".public.html")).exists else {
      log("article file \(name) did not exist in \(path.lastPathComponent)")
      return
    }
    childArticleVC.gotoUrl(path: path, file: name)
    if childArticleVC.navigationController != nil { return }
    self.navigationController?.pushViewController(childArticleVC, animated: true)
  }
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func accessibilityPerformEscape() -> Bool {
    self.navigationController?.popViewController(animated: true)
    return true
  }
  
  // MARK: - viewDidLoad
  open override func viewDidLoad() {
    super.viewDidLoad()
    self.cellVerticalScrollIndicatorInsets = UIEdgeInsets(top: 10,
                                                  left: 0,
                                                  bottom:10,
                                                  right: 0)
    self.cellHorizontalScrollIndicatorInsets = UIEdgeInsets(top: 10,
                                                  left: 0,
                                                  bottom:-UIWindow.bottomInset,
                                                  right: 0)
    
    xButton.isHidden = true
    (sliderContentController as? NewPdfOverviewCollectionVC)?.clickCallback = { [weak self] (pdfModel, art) in
      guard let self = self else { return }
      self.slider?.close()
      self.childArticleVC.slider?.close()
      if let art {
        openArticle(name: art.html?.name, path: issue.dir.path, reopenArticleScrollPos: nil)
        return
      }
      guard let newIndex = pdfModel?.currentPage else { return }
      self.collectionView.scrollToIndex(newIndex)
      Usage.track(Usage.event.drawer.action_tap.Page)
      if navigationController?.viewControllers.last != self {
        _ = navigationController?.popToViewController(self, animated: true)
      }
    }
    
    onDisplay { [weak self]  (idx, _) in
      let isFromScroll = true
      if let issue = self?.issue, idx > 0 || isFromScroll {
        issue.setLastRead(content: nil, pageIndex: idx, scrollPosition: nil)
      }
      if let pi = self?.pdfModel?.item(atIndex:idx) as? ZoomedPdfPageImage,
         let issueDate = self?.issue.date.ISO8601,
         let page = pi.pageReference,
         let adIdList = page.adIdList {
        for adIdentifier in adIdList {
          Usage.track(Usage.event.advertisement.pageAdShown
                      , name: "\(issueDate)/Seite \(page.pagina ?? "\(idx)")/\(adIdentifier)")

        }
      }
      self?.updateSlider(index: idx)
      self?.updateAudioButtons()
    }
    
    setupToolbar()
    if let sliderContentController = sliderContentController {
      setupSlider(sliderContent: sliderContentController)
    }
    self.view.backgroundColor = Const.SetColor.HomeBackground.dynamicColor
    self.collectionView.backgroundColor = Const.SetColor.HomeBackground.dynamicColor
    registerForStyleUpdates()
    Rating.issueOpened()
    Notification.receive(Const.NotificationNames.audioPlaybackStateChanged) { [weak self] _ in
      self?.updateAudioButtons()
    }
    
    onRightTap {[weak self] in
      ///No scrolling with voiceover, it did not work!
      if UIAccessibility.isVoiceOverRunning { return false }
      guard let ziv = self?.currentView as? ZoomedImageView else {
        return false
      }
      ///If zoomed in, zoom out
      if ziv.scrollView.zoomScale - 0.1 > self?.afterPageLayoutDoneZoomFactor ?? 0 {
        UIView.animate(withDuration: 0.1) {[weak self] in
          self?.applyPageLayout(ziv)
        }
        return true
      }
      ///if scrollable to right, scroll to right
      if ziv.scrollView.contentOffset.x + ziv.scrollView.frame.size.width + 2
          < ziv.scrollView.contentSize.width {
        ziv.scrollView.setContentOffset(CGPoint(x: ziv.scrollView.contentSize.width - ziv.scrollView.frame.size.width,
                                                y: ziv.scrollView.contentOffset.y),
                                        animated: true)
        ziv.scrollView.flashScrollIndicators()
        return true
      }
      //handle index change
      return false
    }
    
    onLeftTap {[weak self] in
      ///No scrolling with voiceover, it did not work!
      if UIAccessibility.isVoiceOverRunning { return false }
      guard let ziv = self?.currentView as? ZoomedImageView else {
        return false
      }
      ///If zoomed in, zoom out
      if ziv.scrollView.zoomScale - 0.1 > self?.afterPageLayoutDoneZoomFactor ?? 0 {
        UIView.animate(withDuration: 0.1) {[weak self] in
          self?.applyPageLayout(ziv)
        }
        return true
      }
      ///if scrollable to right, scroll to left
      if ziv.scrollView.contentOffset.x - 2 > 0 {
        ziv.scrollView.setContentOffset(CGPoint(x: 0,
                                                y: ziv.scrollView.contentOffset.y),
                                        animated: true)
        ziv.scrollView.flashScrollIndicators()
        return true
      }
      //handle index change
      return false
    }
  }
  
  private var afterPageLayoutDoneZoomFactor: CGFloat = 0.0
  
  // MARK: - setupSlider
  func setupSlider(sliderContent:UIViewController){
    slider = MyButtonSlider(slider: sliderContent, into: self)
    guard let slider = slider else { return }
    let logo = App.isTAZ ? "logo" : "logoLMD"
    slider.setImage( UIImage(named: logo),
                      menuImage: UIImage(named: "BurgerMenu")?.withTintColor(.white, renderingMode: .alwaysOriginal),
                      closeImage: UIImage(named: "closeX")?.withTintColor(.white, renderingMode: .alwaysOriginal))
    slider.button.accessibilityLabel = "Inhalt"
    slider.button.backgroundColor = Const.SetColor.CIColor.color
    slider.buttonAlpha = 1.0
    slider.closedBottonImageOffsetX = 0.0
    slider.sliderView.clipsToBounds = false
    slider.onOpen{ _ in
      Usage.track(Usage.event.drawer.action_open.Open, name: "Logo Tap")
      Notification.send(Const.NotificationNames.helpProviderChanged)
    }
    slider.onClose{[weak self] _ in
      guard self?.navigationController?.topViewController == self else { return }
      Notification.send(Const.NotificationNames.helpProviderChanged)
    }
    slider.button.additionalTapOffset = 20
  }
  
  func updateSlider(index: Int){
    #if LMD
    guard let sliderContentVc
            = sliderContentController
            as? LMdSliderContentVC
    else { return }
    let page = issue.pages?.valueAt(index)
    sliderContentVc.currentPage = page
    (childArticleVC?.sliderContent as? LMdSliderContentVC)?.currentPage = page
    #endif
  }
  
  var lastWindowSize: CGSize?
  
  open override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    lastWindowSize = UIWindow.size
  }
  
  // MARK: - viewWillAppear
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.pageControl?.layer.shadowColor = UIColor.lightGray.cgColor
    self.pageControl?.layer.shadowRadius = 3.0
    self.pageControl?.layer.shadowOffset = CGSize(width: 0, height: 0)
    self.pageControl?.layer.shadowOpacity = 1.0
    self.pageControl?.pageIndicatorTintColor = UIColor.white
    self.pageControl?.currentPageIndicatorTintColor = Const.SetColor.CIColor.color
    
    updateSlidersWidth(self.view.frame.size)
    slider?.button.isHidden = false
    self.updateMenuItems()
    //PDF>Article>Rotate>PDF: fix layout pos
    if lastWindowSize == nil || lastWindowSize == UIWindow.size { return }
    guard let ziv = self.currentView as? ZoomedImageView else { return }
    onMainAfter{[weak self] in
      self?.applyPageLayout(ziv)
    }
  }
  
  open override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    transitionNextCollection = newCollection
    super.willTransition(to: newCollection, with: coordinator)
    ///On size class change this is called before viewWillTransition(to size... remember for calculations
  }
  
  var transitionNextCollection: UITraitCollection?
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateSlidersWidth(size)
    updateMenuItems(updatedSizeIsLandscape: size.width > size.height)
  }
  
  func updateSlidersWidth(_ newParentSize : CGSize? = nil){
    guard sliderContentController != nil else { return }
    let width = (newParentSize ?? self.view.frame.size).sliderWidth(for: transitionNextCollection?.horizontalSizeClass)
    transitionNextCollection = nil
    slider?.ocoverage = width
  }
  
  
  // MARK: - setupViewProvider
  open override func setupViewProvider(){
    super.setupViewProvider()
    onDisplay { [weak self] (idx, optionalView) in
      ///sectionAudio e.g. for bundestalk
      let sectionAudio = self?.sectionAudio()
      self?.toolBar.setToolbar(sectionAudio == nil ? 0 : 1)
      (self?.sliderContentController as? OldPdfOverviewCollectionVC)?.activeIndex = idx
      self?.slider?.showMenuImage = true
      
      guard let ziv = optionalView as? ZoomedImageView,
            let pdfImg = ziv.optionalImage as? ZoomedPdfImageSpec else { return }
      ziv.menu.menu = self?.menuItems ?? []
      ziv.scrollView.contentInset = .zero //no more need bottom inset
      if ziv.imageView.image == nil
      {
        ziv.optionalImage = pdfImg
        ziv.imageView.image = pdfImg.image
        if pdfImg.image != nil { self?.applyPageLayout(ziv)}
        pdfImg.renderFullscreenImageIfNeeded { [weak self] success in
          self?.handleRenderFinished(success, ziv)
        }
      }
      else {
        self?.applyPageLayout(ziv)
      }

      ziv.whenZoomed {   [weak self] zoomedIn in
        if self?.hideOnScroll == false {
          self?.toolBar.show(show:true, animated: true)
          return
        }
        self?.toolBar.show(show:!zoomedIn, animated: true)
        #warning("Did not work on initial PAGE!!!")
        self?.slider?.showMenuImage = zoomedIn
      }
      self?.toolBar.show(show:true, animated: true)
    }
  }

  func applyPageLayout(_ ziv:ZoomedImageView){
    guard let pdfImg = ziv.optionalImage as? ZoomedPdfImageSpec else {
      ziv.invalidateLayout()
      return
    }
    
    if UIWindow.isPortrait, pdfImg.pageType == .double {
      //isPortrait && double => fitHeight
      ziv.zoomToFitHeight()
      
    }
    else if UIWindow.isPortrait {
      //isPortrait && !double => fitWidth
      ziv.invalidateLayout()
    }
    else if self.fullPdfOnPageSwitch {
      //Landscape && fullPage Setting => fitHeight
      ziv.zoomToFitHeight()
    }
    else if pdfImg.pageType == .double  {
      //Landscape && !fullPage Setting && double Page => fitWidth of half Page
      ziv.zoomToFitHalfWidth()
    }
    else {
      //Landscape && !fullPage Setting && single Page => fitWidth
      ziv.zoomToFitWidth()
    }
    ziv.scrollToTopLeft()///otherwise page is centered also horizontally @see Portrait && Doublepage
    
    afterPageLayoutDoneZoomFactor = ziv.scrollView.zoomScale
    ///afterPageLayoutDoneZoomFactor
  }
  
  public override func handleRenderFinished(_ success:Bool, _ ziv:ZoomedImageView){
    if success == false { return }
    onMain { [weak self] in
      self?.applyPageLayout(ziv)
    }
  }
  
  open override func willMove(toParent parent: UIViewController?) {
    super.willMove(toParent: parent)
    if parent == nil {
      sliderContentController?.view.isHidden = true
      slider?.button.hideAnimated{[weak self] in
        ///if didMove is done slider is nil so this has no effect
        ///if didMove not happen slider is still there => back canceled
        onMain(after: 0.4){ [weak self] in
          self?.slider?.button.isHidden = false
          self?.sliderContentController?.view.isHidden = false
        }
      }
      self.slider?.close()
    }
  }
  
  open override func releaseOnDisappear(){
    if let nModel = self.pdfModel as? NewPdfModel {
      nModel.images = []
    }
    childArticleVC.releaseOnDisappear()
//    childArticleVC.sliderContent = nil
    childArticleVC.slider?.cleanup()
    childArticleVC.slider = nil
    childArticleVC.delegate = nil
    childArticleVC.header.onTitle {_ in }
    self.pdfModel = nil
    (sliderContentController as? OldPdfOverviewCollectionVC)?.cleanup()
    sliderContentController = nil
    slider = nil
    super.releaseOnDisappear()
  }

  // MARK: - viewDidAppear
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Notification.send(Const.NotificationNames.articleLoaded)
    slider?.button.showAnimated()
  }
  
  // MARK: - UIStyleChangeDelegate
  public func applyStyles() {
    slider?.sliderView.shadow()
    slider?.button.shadow()
  }
  
  var shareButton: Button<ImageView>?
  var backButton: Button<ImageView>?
  var homeButton: Button<ImageView>?
  ///sectionAudio Button only used in state 1 e.g. for bundestalk
  private var audioButton: Button<ImageView>?
  
  // MARK: - setupToolbar
  func setupToolbar() {
    //the button tap closures
    let onHome:((ButtonControl)->()) = { [weak self] _ in
      self?.navigationController?.popViewController(animated: true)
    }
    
    let onShare:((ButtonControl)->()) = { [weak self] _ in
      guard let self = self,
            let i = self.index,
            let pi = self.pdfModel?.item(atIndex:i) as? ZoomedPdfPageImage,
            let page = pi.pageReference?.pagina,
            let url = pi.pageReference?.pdfDocument(inIssueDir: self.issue.dir)?.documentURL else { return }
      let filename = "taz_\(self.issue.date.filename)_S-\(page).pdf"
      let tempUrl = NSTemporaryDirectory() + filename
      _ = File(url).copy(to:tempUrl, isOverwrite: true)
      let tmpFile = File(dir: NSTemporaryDirectory(), fname: filename).url
      
      let dialogue = ExportDialogue<Any>()
      let origin = App.isLMD ? "LMd" : "taz"
      dialogue.present(item: tmpFile,
                       view: self.shareButton ?? self.toolBar,
                       subject: "\(origin) vom \(self.issue.date.short) Seite \(page)",
                       image: UIImage(named: App.appIcon(size: "60x60")))
     Usage.xtrack.share.faksimilelePage(issue: issue, pagina: page)
    }
    
    let onPlay:((ButtonControl)->()) = { [weak self] _ in
      guard let self = self,
            let i = self.index,
            let pi = self.pdfModel?.item(atIndex:i) as? ZoomedPdfPageImage,
            let sectionAudio = pi.pageReference?.sectionAudio
      else { return }
      sectionAudio.toggleAudio()
    }
    
    //the buttons and alignments
    homeButton = toolBar.addImageButton(name: "home",
                               onPress: onHome,
                               direction: .right,
                               atToolbars: [0,1],
                               accessibilityLabel: "Übersicht")
    backButton = toolBar.addImageButton(name: "chevron-left",
                               onPress: onHome,
                               direction: .left,
                               atToolbars: [0,1],
                               accessibilityLabel: "Zurück",
                               width: 35,
                               height: 40,
                               contentMode: .right)
    
    shareButton = toolBar.addImageButton(name: "share",
                               onPress: onShare,
                               direction: .center,
                               atToolbars: [0,1],
                               accessibilityLabel: "Teilen")
    ///sectionAudio in state 1 e.g. for bundestalk
    toolBar.addSpacer(.center, atToolbars: [1])
    audioButton = toolBar.addImageButton(name: "audio",
                               onPress: onPlay,
                               direction: .center,
                                         atToolbars: [1],
                               accessibilityLabel: "Wiedergabe")

    
    //the toolbar setup itself
    toolBar.applyDefaultTazSyle()
    toolBar.pinTo(self.view)
    
    if let pc = self.pageControl, let sv = pc.superview {
      for constraint in sv.constraints {
        if constraint.firstItem as? UIView == pc,
           constraint.firstAnchor.isKind(of: NSLayoutYAxisAnchor.self) {
          constraint.isActive = false
        }
      }
      pin(pc.bottom, to: toolBar.top, dist: -10, priority: .required)
    }
    
    self.whenScrolled(minRatio: 0.01) { [weak self] ratio in
      if ratio < 0 {
        if self?.hideOnScroll == false { return }
        self?.toolBar.show(show:false, animated: true)}
      else { self?.toolBar.show(show:true, animated: true)}
    }
  }
}

// MARK: - Helper for Content slider
extension TazPdfPagesViewController {
  func tapPlayInSlider(){
    if playingCurrentIssue {
      ArticlePlayer.singleton.close()
      return
    }
    ArticlePlayer.singleton.play(issue: issue,
               startFromArticle: nil,
               enqueueType: .replaceCurrent)
    Usage.track(Usage.event.drawer.action_tap.PlayIssue)
  }
}

extension TazPdfPagesViewController: ScreenTracking {
  private var pagina: String { page()?.pagina ?? "\((index ?? -2) + 1)"}
  public var screenUrl: URL? {
    guard index != nil else { return nil }///prevent initial track on idx -1
    return URL(path: "issue/\(self.feederContext.feedName)/\(self.issue.date.ISO8601)/pdf/\(pagina)")
  }
  
  public var screenTitle: String? {  return "PDF Page: \(pagina)"}
  public var trackingScreenOnAppear: Bool { false }
}

// MARK: - Class ArticleVcWithPdfInSlider
class ArticleVcWithPdfInSlider : ArticleVC {
  
  open override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    transitionNextCollection = newCollection
    super.willTransition(to: newCollection, with: coordinator)
    ///On size class change this is called before viewWillTransition(to size... remember for calculations
  }
  
  var transitionNextCollection: UITraitCollection?
  
//  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//    super.viewWillTransition(to: size, with: coordinator)
//    updateSlidersWidth(size)
//  }
  
//  func updateSlidersWidth(_ newParentSize : CGSize? = nil){
//    guard sliderContent != nil else { return }
//    let width = (newParentSize ?? self.view.frame.size).sliderWidth(for: transitionNextCollection?.horizontalSizeClass)
//    transitionNextCollection = nil
//    slider?.ocoverage = width
//  }
//  
//  override func setupSlider() {
//    if let sContent = self.sliderContent {
//      slider = MyButtonSlider(slider: sContent, into: self)
//    }
//    super.setupSlider()
//    applyStyles()
//  }
  
  override func setHeader(artIndex: Int) {
    #if LMD
    guard let lmdSliderContentVc = self.sliderContent as? LMdSliderContentVC else { return }
    header.title = "Seite \(lmdSliderContentVc.currentPage?.pagina ?? "")"
    #else
    if let menu = self.slider?.slider as? NewPdfOverviewCollectionVC,
    let art = article,
    let pageIndex = menu.pdfModel.pageIndexForArticle(art)
    {
      menu.pdfModel.currentPage = pageIndex
      menu.updateSelection()
    }
    super.setHeader(artIndex: artIndex)
    #endif
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    ensureToolbarInFrontOfTapButtons()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupSlider()
    header.isFromFacsimile = true
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    slider?.close()
  }
}

fileprivate extension Page {
  var sectionAudio: Section? { audioItem?.content?.first as? Section }
}

fileprivate extension TazPdfPagesViewController {
  func page(_ index: Int? = nil) -> Page?{
    if let idx = index ?? self.index {
      return (self.pdfModel?.item(atIndex:idx)
              as? ZoomedPdfPageImage)?.pageReference
    }
    return nil
  }
  func sectionAudio(_ index: Int? = nil) -> Section? {
    return page(index)?.sectionAudio
  }
}

fileprivate extension CGSize {
  func sliderWidth(for horizontalSizeClass: UIUserInterfaceSizeClass? = nil) -> CGFloat {
    let offset: CGFloat = App.isLMD ? 14.0 : 28.0
    return min(self.width, Const.Size.ContentSliderMaxWidth + offset) - offset
  }
}

#if LMD
extension Article {
  var index: Int? {
    return self.primaryIssue?.allArticles.firstIndex(where: { art in art.isEqualTo(otherArticle: self) })
  }
  
}
#endif
