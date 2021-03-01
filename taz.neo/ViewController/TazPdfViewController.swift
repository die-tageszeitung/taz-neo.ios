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
  open override var page: PDFPage? {
    get {
      guard let pageRef = pageReference else { return nil }
      var path = ""
      if let id = issueDir {
        path = id.path + "/"
      }
      return PDFDocument(url: File(path + pageRef.pdf.fileName).url)?.page(at: 0)
    }
  }
  
  convenience init(page:Page, issueDir : Dir?) {
    self.init()
    self.issueDir = issueDir
    self.pageReference = page
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
  
  init(issueInfo:IssueInfo?) {
    guard let issueInfo = issueInfo,
          let pages = issueInfo.issue.pages
          else { return }
    let issueDir = issueInfo.feeder.issueDir(issue: issueInfo.issue)
    
    for pdfPage in pages {
      print("in Model add Page of type: \(pdfPage.type)")
      let item = ZoomedPdfPageImage(page:pdfPage, issueDir: issueDir)
      self.images.append(item)
      item.sectionTitle = "\(pdfPage.type)"
    }
    
    guard let rawPageSize = self.images.first?.page?.frame?.size,
          rawPageSize.width > 0 else { return }
    
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
open class TazPdfPagesViewController : PdfPagesCollectionVC{
  var thumbnailController : PdfOverviewCollectionVC?
  var slider:ButtonSlider?
  
  public var toolBar = OverviewContentToolbar()
  
  override public var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  public init(issueInfo:IssueInfo?) {
    if let issueInfo = issueInfo {
      issueInfo.dloader.downloadIssueFiles(issue: issueInfo.issue, files: issueInfo.issue.facsimiles ?? []) { (err) in
        print(">>>*** Download Facsmiles Done with Error?: \(err)")
      }
    }
    let pdfModel = NewPdfModel(issueInfo: issueInfo)
    Log.minLogLevel = .Debug
    super.init(data: pdfModel)
    thumbnailController = PdfOverviewCollectionVC(pdfModel:pdfModel)
    self.onTap { (oimg, x, y) in
      guard let zpdfi = oimg as? ZoomedPdfImage else { return }
      print("On item at Index: \(zpdfi.pdfPageIndex ?? -1) tapped at: \(x)/\(y)")
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
    slider.button.layer.shadowOpacity = 0.25
    slider.button.layer.shadowOffset = CGSize(width: 2, height: 2)
    slider.button.layer.shadowRadius = 4
//    header.leftIndent = 8 + slider.visibleButtonWidth
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
  
  open override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    print("cleanup   ...TODO?")

//    if isBeingDismissed {
//      print("cleanup")
//      ///Cleanup
//      for ctrl in self.children {
//        ctrl.removeFromParent()
//      }
//      images = []
//      collectionView = nil
//      thumbnailController?.clickCallback = nil
////      thumbnailController?.pdfModel = nil
//      thumbnailController?.menuItems = []
//      thumbnailController?.removeFromParent()
//      thumbnailController = nil
//      pdfModel = nil
//    }
  }
  
  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    slider?.close()
  }
  
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
//    self.collectionView?.useSelfReuse = true
  }
  
  func setupToolbar() {
    //the button tap closures
    let onHome:((ButtonControl)->()) = {   [weak self] _ in
      self?.dismiss(animated: true)
      self?.navigationController?.popViewController(animated: true)
    }
    
    let onPDF:((ButtonControl)->()) = {   [weak self] control in
      self?.dismiss(animated: true)
    }
    
    //the buttons and alignments
    _ = toolBar.addImageButton(name: "Home",
                           onPress: onHome,
                           direction: .left,
                           symbol: "house", //the prettier symbol ;-)
                           accessibilityLabel: "Übersicht"
//                           vInset: 0.2,hInset: 0.2 //needed if old symbol used
                           )
    toolBar.addSpacer(.left)
    _ = toolBar.addImageButton(name: "PDF",
                           onPress: onPDF,
                           direction: .right,
                           symbol: "iphone.homebutton",
                           accessibilityLabel: "Zeitungsansicht",
                           hInset: 0.15
    )
    
    //the toolbar setup itself
    toolBar.setButtonColor(Const.Colors.darkTintColor)
    toolBar.backgroundColor = Const.Colors.darkToolbar
    toolBar.pinTo(self.view)
    
//    if let thumbCtrl = self.thumbnailController {
//      thumbCtrl.whenScrolled(minRatio: 0.01){ [weak self] ratio in
//        if ratio < 0 { self?.toolBar.hide()}
//        else { self?.toolBar.hide(false)}
//      }
//    }
    
//    if let pageController = self.pageController {
//      pageController.collectionView?.delegate = self
//    }
  }
}
