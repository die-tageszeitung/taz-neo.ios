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


class NewPdfModel : PdfModel, DoesLog {
  
  func size(forItem atIndex: Int) -> CGSize {
    if let item = self.item(atIndex: atIndex),
       let pdfPageImage = item as? ZoomedPdfPageImage,
       let page = pdfPageImage.pageReference,
       page.type == .double {
      return panoPageSize ?? PdfDisplayOptions.Overview.fallbackPageSize
    }
    return singlePageSize ?? PdfDisplayOptions.Overview.fallbackPageSize
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
  
  func pageTitle(forItem atIndex: Int) -> String? {
    guard let item = images.valueAt(atIndex),
          let pdf = item as? ZoomedPdfPageImage,
          let page = pdf.pageReference else {
          return nil//"Seite:\(atIndex)"
    }
    return page.title
  }
}

class TazPdfViewController : PdfViewController{
  
  public var toolBar = OverviewContentToolbar()
  
  convenience init(issueInfo:IssueInfo?) {
    self.init(NewPdfModel(issueInfo: issueInfo))
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.addMenuItem(title: "PDF Ansicht beenden", icon: "eye.slash") { [weak self] title in
      self?.dismiss(animated: true)
    }
    self.iosHigher13?.addMenuItem(title: "Abbrechen", icon: "multiply.circle") { (_) in }
    
    setupToolbar()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let pageController = self.pageController {
      pageController.pageControl?.layer.shadowColor = UIColor.lightGray.cgColor
      pageController.pageControl?.layer.shadowRadius = 3.0
      pageController.pageControl?.layer.shadowOffset = CGSize(width: 0, height: 0)
      pageController.pageControl?.layer.shadowOpacity = 1.0
      pageController.pageControl?.pageIndicatorTintColor = UIColor.white
      pageController.pageControl?.currentPageIndicatorTintColor = Const.SetColor.CIColor.color
      pageController.menuItems = self.menuItems
    }
    
    if let thumbCtrl = self.thumbnailController {
      thumbCtrl.menuItems = self.menuItems
      thumbCtrl.cellLabelFont = Const.Fonts.contentFont(size: 8)
      var insets = UIWindow.keyWindow?.safeAreaInsets ?? UIEdgeInsets.zero
      insets.bottom += toolBar.totalHeight
      thumbCtrl.collectionView.contentInset = insets
    }
  }
  
  /// Define the menu to display on long touch of a MomentView
  public var menuItems: [(title: String, icon: String, closure: (String)->())] = []

  /// Add an additional menu item
  public func addMenuItem(title: String, icon: String, closure: @escaping (String)->()) {
    menuItems += (title: title, icon: icon, closure: closure)
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

//extension TazPdfViewController : UICollectionViewDelegate {
//  
//}


