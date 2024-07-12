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
  
  fileprivate var pdfDownloadDelegate:PdfDownloadDelegate?
  
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

// MARK: - NewPdfModel
class NewPdfModel : PdfModel, DoesLog, PdfDownloadDelegate {
  func size(forItem atIndex: Int) -> CGSize {
    if let item = self.item(atIndex: atIndex),
       let pdfPageImage = item as? ZoomedPdfPageImage,
       let page = pdfPageImage.pageReference,
       page.type == .double {
      return panoPageSize ?? PdfDisplayOptions.Overview.fallbackPageSize
    }
    return singlePageSize
  }
  
  
  public func pageIndexForLink(_ link: String) -> Int? {
    let p = images as? [ZoomedPdfPageImage]
    return p?.firstIndex(where: { $0.pageReference?.pdf?.fileName == link }) ?? nil
  }
  
  public func pageIndexForArticle(_ article: Article) -> Int? {
    let p = images as? [ZoomedPdfPageImage]
    return p?.firstIndex(where: { zoomedPdfPageImage in
      zoomedPdfPageImage.pageReference?.frames?
        .first(where: { $0.link?.lastPathComponent == article.path.lastPathComponent}) != nil
    }) ?? nil
  }
  
  private var whenScrolledHandler : WhenScrolledHandler?
  public func whenScrolled(minRatio: CGFloat, _ closure: @escaping (CGFloat) -> ()) {
    whenScrolledHandler = (minRatio, closure)
  }
  
  var title: String?
  var count: Int { get {return images.count}}
  var index: Int = 0
  var issueInfo:IssueInfo?
    
  var defaultRawPageSize: CGSize?
  var singlePageSize: CGSize = .zero
  var panoPageSize: CGSize?
  
  func item(atIndex: Int) -> ZoomedPdfImageSpec? {
    return images.valueAt(atIndex)
  }
  
  var images : [ZoomedPdfImageSpec] = []
  
  var pageMeta : [Int:String] = [:]
  
  var imageSizeMb : UInt64 {
    get{
      var totalSize:UInt64 = 0
      for case let img as ZoomedPdfImage in self.images {
        log("page: \(img.pdfPageIndex ?? -1) size:\(img.image?.mbSize ?? 0)")
        totalSize += UInt64(img.image?.mbSize ?? 0)
      }
      return totalSize
    }
  }
  
  func downloadPdf(_ page: Page, finishedCallback: @escaping ((Bool) -> ())) {
    guard let issueInfo = self.issueInfo, let pdf = page.pdf else { finishedCallback(false); return }
    issueInfo.dloader.downloadIssueFiles(issue: issueInfo.issue,
                                         files: [pdf]) { error in
      finishedCallback(error==nil)
    }
  }
  
  public func thumbnail(atIndex: Int, finishedClosure: ((UIImage?)->())?) -> UIImage? {
    guard let pdfImg = self.item(atIndex: atIndex) as? ZoomedPdfPageImage else {
      return nil
    }
    if let waitingImage = pdfImg.waitingImage {
      return waitingImage
    }
    
    let height = singlePageSize.height
    
    if pdfImg.pdfPage == nil,
       let issueInfo = issueInfo,
       let pageRefPdf = pdfImg.pageReference?.pdf
    {
      //PDF Page Download is needed first
      issueInfo.dloader.downloadIssueFiles(issue: issueInfo.issue, files: [pageRefPdf]) { (_) in
        PdfRenderService.render(item: pdfImg,
                                height: height*UIScreen.main.scale,
                                screenScaled: true,
                                backgroundRenderer: true){ img in
          pdfImg.waitingImage = img
          finishedClosure?(img)
        }
      }
    }
    else {
      PdfRenderService.render(item: pdfImg,
                              height: height*UIScreen.main.scale,
                              screenScaled: true,
                              backgroundRenderer: true){ img in
        pdfImg.waitingImage = img
        finishedClosure?(img)
      }
    }
    return nil
  }
  
  init(issueInfo:IssueInfo?) {
    guard let issueInfo = issueInfo,
          let pages = issueInfo.issue.pages
          else { return }
    let issue = issueInfo.issue
    self.issueInfo = issueInfo
    let issueDir = issueInfo.feeder.issueDir(issue: issue)
    
    /// Use Page 1 Facsimile PDF CropBox  @see: PdfRenderService.swift -> extension PDFPage -> var frame
    let rawPageSize:CGSize
      = issue.pageOneFacsimilePdfPage?.frame?.size
      ?? PdfDisplayOptions.Overview.fallbackPageSize
    
    let fullscreenPageHeight = UIScreen.main.bounds.width * rawPageSize.height / rawPageSize.width
    
    for page in pages {
      let item = ZoomedPdfPageImage(page:page, issueDir: issueDir)
      item.fullScreenPageHeight = fullscreenPageHeight
      item.pdfDownloadDelegate = self
      self.images.append(item)
    }
    
    self.defaultRawPageSize = rawPageSize
    let panoPageWidth
      = PdfDisplayOptions.Overview.sliderWidth
      - 2*PdfDisplayOptions.Overview.sideSpacing
    let singlePageWidth
      = (panoPageWidth - PdfDisplayOptions.Overview.interItemSpacing)/2
    let pageHeight = singlePageWidth * rawPageSize.height / rawPageSize.width
    self.singlePageSize = CGSize(width: singlePageWidth,
                                 height: pageHeight)
    self.panoPageSize = CGSize(width: panoPageWidth,
                               height: pageHeight)
  }
}

// MARK: - TazPdfPagesViewController
/// Provides functionallity to interact between PdfOverviewCollectionVC and Pages with PdfPagesCollectionVC
open class TazPdfPagesViewController : PdfPagesCollectionVC, ArticleVCdelegate, UIStyleChangeDelegate{
  
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
  var childArticleVC: ArticleVcWithPdfInSlider?
  
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
        UIApplication.shared.open(to, options: [:], completionHandler: nil)
      }
      else {
        error("No application or no permission for: \(to.absoluteString)")
      }
    }
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
  
  override public var preferredStatusBarStyle: UIStatusBarStyle {
    return App.isLMD ? .darkContent : .lightContent
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
    
    
    if let count = issueInfo.issue.pages?.count,
       let lastIndex = issueInfo.issue.lastPage,
       lastIndex < count {
      pdfModel.index = lastIndex
    }
    
    self.sections = issueInfo.issue.sections ?? []
    self.article2section = issueInfo.issue.article2section
    self.feederContext = issueInfo.feederContext
    self.issue = issueInfo.issue
    super.init(data: pdfModel, useTopGradient: App.isTAZ)
    
    hidesBottomBarWhenPushed = true
    
    #if LMD
    sliderContentController = createLmdSliderChildController(issueInfo: issueInfo)
    #else
    sliderContentController = createTazSliderChildController(pdfModel: pdfModel)
    #endif
    
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
      self.openArticle(name: link, path: path)
   
    }
  }
  
  func openArticle(name: String?, path: String?){
    guard let pdfModel = pdfModel as? NewPdfModel else { return }
    guard let issueInfo = pdfModel.issueInfo else { return }
    guard let name = name else { return }
    guard let path = path else { return }
    
    if let url = URL(string: name), UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
      return
    }
    else if let pageIdx = pdfModel.pageIndexForLink(name) {
      self.collectionView?.scrollto(pageIdx,animated: true)
      return
    }
    #if LMD
    let articleSliderContentController = createLmdSliderChildController(issueInfo: issueInfo)
    #else
    let articleSliderContentController = createTazSliderChildController(pdfModel: pdfModel)
    #endif
       
    let articleVC = ArticleVcWithPdfInSlider(feederContext: issueInfo.feederContext,
                                             sliderContent: articleSliderContentController)
    
    articleVC.delegate = self
    articleVC.gotoUrl(path: path, file: name)
    #if LMD
    articleSliderContentController.header.imageView.onTapping{[weak self] _ in
      self?.childArticleVC?.slider?.close()
      self?.navigationController?.popViewController(animated: true)
    }
    articleSliderContentController.header.pageLabel.onTapping{[weak self] _ in
      self?.childArticleVC?.slider?.close()
      self?.navigationController?.popViewController(animated: true)
    }
    articleSliderContentController.header.issueLabel.onTapping{[weak self] _ in
      self?.childArticleVC?.slider?.close()
      self?.navigationController?.popToRootViewController(animated: true)
    }
    #else
    articleSliderContentController.clickCallback = { [weak self] (_, pdfModel) in
      Usage.track(Usage.event.drawer.action_tap.Page)
      if let newIndex = pdfModel?.index {
        self?.collectionView?.index = newIndex
      }
      articleVC.slider?.close(animated: true) { [weak self] _ in
        self?.navigationController?.popViewController(animated: true)
      }
    }
    #endif
    
    self.navigationController?.pushViewController(articleVC, animated: true)
    self.childArticleVC = articleVC
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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
    (sliderContentController as? PdfOverviewCollectionVC)?.clickCallback = { [weak self] (_, pdfModel) in
      guard let self = self else { return }
      guard let newIndex = pdfModel?.index else { return }
      self.collectionView?.index = newIndex
      self.slider?.close()
      Usage.track(Usage.event.drawer.action_tap.Page)
    }
    
    onDisplay { [weak self]  (idx, _, _) in
      self?.issue.lastPage = idx
      self?.updateSlider(index: idx)
      ArticleDB.save()
    }
    
    setupToolbar()
    if let sliderContentController = sliderContentController {
      setupSlider(sliderContent: sliderContentController)
    }
    self.view.backgroundColor = Const.SetColor.HomeBackground.dynamicColor
    self.collectionView?.backgroundColor = Const.SetColor.HomeBackground.dynamicColor
    registerForStyleUpdates()
    Rating.issueOpened()
    Notification.receive(Const.NotificationNames.audioPlaybackStateChanged) { [weak self] _ in
      self?.audioButton?.buttonView.name
      = ArticlePlayer.singleton.isPlaying
      && ArticlePlayer.singleton.currentContent?.html?.sha256 ==
      self?.sectionAudio()?.html?.sha256
      ? "audio-active"
      : "audio"
    }
    
    onRightTap {[weak self] in
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
    if App.isLMD { slider?.openShiftRatio = 0.95 }
    guard let slider = slider else { return }
    let logo = App.isTAZ ? "logo" : "logoLMD"
    slider.sliderView.clipsToBounds = false
    slider.image = UIImage.init(named: logo)
    slider.image?.accessibilityLabel = "Inhalt"
    slider.buttonAlpha = 1.0
    slider.button.additionalTapOffset = 50
    slider.close()
    #if LMD
    (sliderContent as? LMdSliderContentVC)?.header.imageView.onTapping{[weak self] _ in
      self?.slider?.close()
    }
    (sliderContent as? LMdSliderContentVC)?.header.pageLabel.onTapping{[weak self] _ in
      self?.slider?.close()
    }
    (sliderContent as? LMdSliderContentVC)?.header.issueLabel.onTapping{[weak self] _ in
      self?.navigationController?.popViewController(animated: true)
    }
    #endif
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
    onDisplay { [weak self] (_, optionalView, _) in
      let sectionAudio = self?.sectionAudio()
      self?.toolBar.setToolbar(sectionAudio == nil ? 0 : 1)
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
  
  open override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    if parent == nil {
      if let nModel = self.pdfModel as? NewPdfModel {
        nModel.images = []
      }
      self.pdfModel = nil
      sliderContentController = nil
      slider = nil
    }
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
  
  private var shareButton: Button<ImageView>?
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
                       subject: "\(origin) vom \(self.issue.date.short) Seite \(page)")
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
    _ = toolBar.addImageButton(name: "home",
                               onPress: onHome,
                               direction: .right,
                               atToolbars: [0,1],
                               accessibilityLabel: "Übersicht")
    _ = toolBar.addImageButton(name: "chevron-left",
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
  func createTazSliderChildController(pdfModel: PdfModel) -> PdfOverviewCollectionVC {
    let ctrl = PdfOverviewCollectionVC(pdfModel:pdfModel)
    ctrl.cellLabelFont = Const.Fonts.titleFont(size: 12)
    ctrl.titleCellLabelFont = Const.Fonts.contentFont(size: 12)
    ctrl.cellLabelLinesCount = 2
    ctrl.collectionView.backgroundColor = Const.Colors.darkSecondaryBG
    return ctrl
  }
  
  #if LMD
  func createLmdSliderChildController(issueInfo: IssueInfo) -> LMdSliderContentVC {
    let ctrl = LMdSliderContentVC()
    ctrl.dataSource
    = LMdSliderDataModel(feederContext: issueInfo.feederContext,
                         issue: issueInfo.issue)
    #warning("USED TO CREATE ART CTRL PAGE PRESS IS WRONGLY CONFIGURED HERE!")
    ///...but will be overwritten in articleVC
    ctrl.onPagePress {[weak self] page in
      self?.slider?.close()
      
      if let index = issueInfo.issue.pages?.firstIndex(where: { p in
        return p.pdf?.name == page.pdf?.name
      }){
        self?.collectionView?.index = index
      }
      
    }
    ctrl.onArticlePress{[weak self] article in
      self?.slider?.close()
      if self?.articleFromPdf == false {
        var pageIndex: Int?
        let pages:[Page] = self?.issue.pages ?? []
        for (index, page) in pages.enumerated() {
          if (article.pageNames ?? []).contains(page.pdf?.name ?? "---") {
            pageIndex = index
            break
          }
        }
        if let i = pageIndex {
          self?.collectionView?.index = i
        }
        return
      }
      self?.openArticle(name: article.html?.name, path: article.primaryIssue?.dir.path)
    }
    return ctrl
  }
  #endif
}

extension TazPdfPagesViewController: ScreenTracking {
  private var pagina: String { page()?.pagina ?? "\((index ?? -2) + 1)"}
  public var screenUrl: URL? {
    return URL(path: "issue/\(self.feederContext.feedName)/\(self.issue.date.ISO8601)/pdf/\(pagina)")
  }
  
  public var screenTitle: String? {  return "PDF Page: \(pagina)"}
  public var trackingScreenOnAppear: Bool { false }
}

// MARK: - Class ArticleVcWithPdfInSlider
class ArticleVcWithPdfInSlider : ArticleVC {
  
  var sliderContent: UIViewController?
  
  public init(feederContext: FeederContext, sliderContent:UIViewController) {
    self.sliderContent = sliderContent
    super.init(feederContext: feederContext)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    transitionNextCollection = newCollection
    super.willTransition(to: newCollection, with: coordinator)
    ///On size class change this is called before viewWillTransition(to size... remember for calculations
  }
  
  var transitionNextCollection: UITraitCollection?
  
  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateSlidersWidth(size)
  }
  
  func updateSlidersWidth(_ newParentSize : CGSize? = nil){
    guard sliderContent != nil else { return }
    let width = (newParentSize ?? self.view.frame.size).sliderWidth(for: transitionNextCollection?.horizontalSizeClass)
    transitionNextCollection = nil
    (slider as? MyButtonSlider)?.ocoverage = width
  }
  
  override func setupSlider() {
    if let sContent = self.sliderContent {
      slider = MyButtonSlider(slider: sContent, into: self)
      if App.isLMD { (slider as? MyButtonSlider)?.openShiftRatio = 0.95 }
      guard let slider = slider else { return }
      let logo = App.isTAZ ? "logo" : "logoLMD"
      slider.sliderView.clipsToBounds = false
      slider.image = UIImage.init(named: logo)
      slider.image?.accessibilityLabel = "Inhalt"
      slider.buttonAlpha = 1.0
      slider.button.additionalTapOffset = 50
      slider.close()
    }
    #if LMD
    if let lmdSliderContentVc = self.sliderContent as? LMdSliderContentVC {
      lmdSliderContentVc.onArticlePress{[weak self] article in
        self?.collectionView?.index = article.index
        self?.slider?.close()
      }
      lmdSliderContentVc.onPagePress {[weak self] page in
        self?.slider?.close()
        
        if let index = self?.issue.pages?.firstIndex(where: { p in
          return p.pdf?.name == page.pdf?.name
        }){
          (self?.navigationController?.viewControllers.penultimate as? TazPdfPagesViewController)?.collectionView?.index = index
          self?.navigationController?.popViewController(animated: true)
        }
      }
    }
    #endif
    super.setupSlider()
    applyStyles()
  }
  
  override func setHeader(artIndex: Int) {
    #if LMD
    guard let lmdSliderContentVc = self.sliderContent as? LMdSliderContentVC else { return }
    header.title = "Seite \(lmdSliderContentVc.currentPage?.pagina ?? "")"
    #else
    super.setHeader(artIndex: artIndex)
    #endif
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupSlider()//not called with contentTable set
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    slider?.close()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if self.parentViewController != nil { return }
    (slider as? MyButtonSlider)?.hideContentAnimated()
    self.releaseOnDisappear()
    #if LMD
    (self.sliderContent as? LMdSliderContentVC)?.dataSource = nil
    #endif
    self.slider = nil
    self.delegate = nil
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    #if LMD
    (sliderContent as? LMdSliderContentVC)?.currentArticle = self.article
    updateHeader()
    #endif
    updateSlidersWidth(self.view.frame.size)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    slider?.button.showAnimated()
  }
  
  override func willMove(toParent parent: UIViewController?) {
    super.willMove(toParent: parent)
    if parent == nil {
      slider?.button.hideAnimated{[weak self] in
        ///if didMove is done slider is nil so this has no effect
        ///if didMove not happen slider is still there => back canceled
        onMain(after: 0.4){ [weak self] in
          self?.slider?.button.isHidden = false
        }
      }
      self.slider?.close()
    }
  }
  
  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    if parent == nil {
      if let thumbCtrl = self.sliderContent as? PdfOverviewCollectionVC {
        thumbCtrl.clickCallback = nil
      }
      NotificationCenter.default.removeObserver(self)
      contentTable = nil
      sliderContent = nil
      delegate = nil
      self.slider = nil
      self.settingsBottomSheet = nil
    }
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
    if horizontalSizeClass ?? UIWindow.keyWindow?.traitCollection.horizontalSizeClass
        == .compact {
      return self.width
    }
    return min(self.width, Const.Size.ContentSliderMaxWidth)
  }
}
