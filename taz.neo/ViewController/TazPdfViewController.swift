//
//  TazPdfViewController.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 18.11.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import PDFKit

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
      return pageReference?.pdfDocument(inIssueDir: issueDir)?.page(at: 0)
    }
  }
  
  convenience init(page:Page, issueDir : Dir?) {
    self.init()
    self.issueDir = issueDir
    self.pageReference = page
    self.sectionTitle = "\(page.type)"
  }
}

// MARK: - NewPdfModel
class NewPdfModel : PdfModel, DoesLog {
  
  func size(forItem atIndex: Int) -> CGSize {
    if let item = self.item(atIndex: atIndex),
       let pdfPageImage = item as? ZoomedPdfPageImage,
       let page = pdfPageImage.pageReference,
       page.type == .double {
      return panoPageSize ?? PdfDisplayOptions.Overview.fallbackPageSize
    }
    return singlePageSize
  }
  
  private var whenScrolledHandler : WhenScrolledHandler?
  public func whenScrolled(minRatio: CGFloat, _ closure: @escaping (CGFloat) -> ()) {
    whenScrolledHandler = (minRatio, closure)
  }
  
  
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
  
  public func thumbnail(atIndex: Int, finishedClosure: ((UIImage?)->())?) -> UIImage? {
    guard let pdfImg = self.item(atIndex: atIndex) as? ZoomedPdfPageImage else {
      return nil
    }
    if let waitingImage = pdfImg.waitingImage {
      return waitingImage
    }
    
    let height = singlePageSize.height - PdfDisplayOptions.Overview.labelHeight
    
    if pdfImg.pdfPage == nil,
       let issueInfo = issueInfo,
       let pageRef = pdfImg.pageReference
    {
      //PDF Page Download is needed first
      issueInfo.dloader.downloadIssueFiles(issue: issueInfo.issue, files: [pageRef.pdf]) { (_) in
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
    
    for page in pages {
      let item = ZoomedPdfPageImage(page:page, issueDir: issueDir)
      #warning("TODO: put the handler to image not to view like now!")
      ///TODO: hide bar on pdf fullscreen view..
      ///item.whenScrolling!?
      self.images.append(item)
    }
    
    /// Use Page 1 Facsimile PDF CropBox  @see: PdfRenderService.swift -> extension PDFPage -> var frame
    let rawPageSize:CGSize
      = issue.pageOneFacsimilePdfPage?.frame?.size
      ?? PdfDisplayOptions.Overview.fallbackPageSize
    
    self.defaultRawPageSize = rawPageSize
    let panoPageWidth
      = PdfDisplayOptions.Overview.sliderWidth
      - 2*PdfDisplayOptions.Overview.sideSpacing
    let singlePageWidth
      = (panoPageWidth - PdfDisplayOptions.Overview.interItemSpacing)/2
    let pageHeight = singlePageWidth * rawPageSize.height / rawPageSize.width
    self.singlePageSize = CGSize(width: singlePageWidth,
                                 height: pageHeight + PdfDisplayOptions.Overview.labelHeight)
    self.panoPageSize = CGSize(width: panoPageWidth,
                               height: pageHeight + PdfDisplayOptions.Overview.labelHeight)
  }
}

// MARK: - TazPdfPagesViewController
/// Provides functionallity to interact between PdfOverviewCollectionVC and Pages with PdfPagesCollectionVC
open class TazPdfPagesViewController : PdfPagesCollectionVC, ArticleVCdelegate{
  public var section: Section?
  
  public var sections: [Section]
  
  public var article: Article?
  
  public var article2section: [String : [Section]]
  
  public func displaySection(index: Int) {
    print("TODO: displaySection")
  }
  
  public func linkPressed(from: URL?, to: URL?) {
    print("TODO: linkPressed")
  }
  
  public func closeIssue() {
    print("TODO: closeIssue")
  }
  
  public var feederContext: FeederContext
  
  public var issue: Issue
  
  public func resetIssueList() {
    print("TODO: resetIssueList")
  }
  
  var thumbnailController : PdfOverviewCollectionVC?
  var slider:ButtonSlider?
  
  public var toolBar = OverviewContentToolbar()
  
  override public var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  public init(issueInfo:IssueInfo?) {
    let pdfModel = NewPdfModel(issueInfo: issueInfo)
    Log.minLogLevel = .Debug
    self.sections = issueInfo?.issue.sections ?? []
    article2section = ["":[]]
    feederContext = issueInfo!.feederContext
    self.issue = issueInfo!.issue
    super.init(data: pdfModel)
    
    thumbnailController = PdfOverviewCollectionVC(pdfModel:pdfModel)
    self.onTap { [weak self] (oimg, x, y) in
      guard let self = self else { return }
      guard let zpdfi = oimg as? ZoomedPdfPageImage else { return }
      guard let frames = zpdfi.pageReference?.frames else { return }
      for frame in frames  {
        if frame.isInside(x: Float(x), y: Float(y)),
           let link = frame.link,
           let path = zpdfi.issueDir?.path,
           let feederContext = issueInfo?.feederContext
        {
          let childThumbnailController = PdfOverviewCollectionVC(pdfModel:pdfModel)
          let articleVC = ArticleVcWithPdfInSlider(feederContext: feederContext,
                                                   sliderContent: childThumbnailController)
          childThumbnailController.clickCallback = { [weak self] (_, pdfModel) in
            if let newIndex = pdfModel?.index {
              self?.collectionView?.index = newIndex //prefered!!
              print("tazpdfIndex: \(self?.pdfModel?.index) artVcIndex: \(newIndex)")
            }
            articleVC.slider.close()
            self?.navigationController?.popViewController(animated: true)
          }
          articleVC.delegate = self
          articleVC.gotoUrl(path: path, file: link)
          self.navigationController?.pushViewController(articleVC, animated: true)
        }
      }
    }
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    xButton.isHidden = true
    guard let thumbnailController = thumbnailController else {return }
    thumbnailController.clickCallback = { [weak self] (_, pdfModel) in
      guard let self = self else { return }
      guard let newIndex = pdfModel?.index else { return }
//      self.collectionView?.scrollto(newIndex, animated: false)
//      self.pdfModel?.index = newIndex
      self.collectionView?.index = newIndex //prefered!!
      self.slider?.close()
    }
    setupSlider(sliderContent: thumbnailController)
    setupToolbar()
  }
  
  /// SideMenu
  func setupSlider(sliderContent:UIViewController){
    slider = ButtonSlider(slider: sliderContent, into: self)
    guard let slider = slider else { return }
    slider.image = UIImage.init(named: "logo")
    /// WARNING set Image changes the coverage Ratio!!
    slider.coverageRatio = PdfDisplayOptions.Overview.sliderCoverageRatio
    slider.image?.accessibilityLabel = "Inhalt"
    slider.buttonAlpha = 1.0
    slider.hideButtonOnClose = true
    slider.button.additionalTapOffset = 50
    slider.button.layer.shadowOpacity = 0.25
    slider.button.layer.shadowOffset = CGSize(width: 2, height: 2)
    slider.button.layer.shadowRadius = 4
    slider.button.layer.shadowColor = Const.SetColor.CTDate.color.cgColor
    slider.close()
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.pageControl?.layer.shadowColor = UIColor.lightGray.cgColor
    self.pageControl?.layer.shadowRadius = 3.0
    self.pageControl?.layer.shadowOffset = CGSize(width: 0, height: 0)
    self.pageControl?.layer.shadowOpacity = 1.0
    self.pageControl?.pageIndicatorTintColor = UIColor.white
    self.pageControl?.currentPageIndicatorTintColor = Const.SetColor.CIColor.color
    self.menuItems = self.menuItems
    
    if let thumbCtrl = self.thumbnailController {
      thumbCtrl.menuItems = self.menuItems
      thumbCtrl.cellLabelFont = Const.Fonts.titleFont(size: 7)
      thumbCtrl.cellLabelLinesCount = 2
      var insets = UIWindow.keyWindow?.safeAreaInsets ?? UIEdgeInsets.zero
      insets.bottom += toolBar.totalHeight
      thumbCtrl.collectionView.contentInset = insets
    }
  }
  
  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    slider?.close()
  }
  
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Notification.send(Const.NotificationNames.articleLoaded)
  }
  
  func setupToolbar() {
    //the button tap closures
    let onHome:((ButtonControl)->()) = { [weak self] _ in
      self?.navigationController?.popViewController(animated: true)
    }
    
    //the buttons and alignments
    _ = toolBar.addImageButton(name: "home",
                           onPress: onHome,
                           direction: .right,
                           accessibilityLabel: "Übersicht"
                           )
    
    //the toolbar setup itself
    toolBar.applyDefaultTazSyle()
    toolBar.pinTo(self.view)
  }
}

class ArticleVcWithPdfInSlider : ArticleVC {
  
  var sliderContent: UIViewController
  
  public init(feederContext: FeederContext, sliderContent:UIViewController) {
    self.sliderContent = sliderContent
    super.init(feederContext: feederContext)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func setupSlider() {
    self.slider = ButtonSlider(slider: sliderContent, into: self)
    super.setupSlider()
  }
  
  override func willMove(toParent parent: UIViewController?) {
    if parent == nil {
      self.slider.close()
    }
    super.willMove(toParent: parent)
  }
}
