//
//  NewPdfModel.swift
//  taz.neo
//
//  Created by Ringo Müller on 24.06.26.
//  Copyright © 2026 taz. All rights reserved.
//
import NorthLib
import UIKit

// MARK: - NewPdfModel
class NewPdfModel : PdfModel, DoesLog, PdfDownloadDelegate {

  /// pageIndex-article relation; **WARNING** only contain pages where article start,
  /// no comercial pages no continued article pages
  /// pageIndex start at 0 if 3 pages missing e.g. n-th pahe Index is n+3 page
  var pageIndex2article: [Int:[Article]] = [:]
  /// pageIndex-page relation; **WARNING** only contain pages where article start,
  /// no comercial pages no continued article pages
  var pageIndex2page: [Int:Page] = [:]
  var pageName2pageIndex: [String:Int] = [:]
  
  func size(forItem atIndex: Int) -> CGSize {
    if let item = self.item(atIndex: atIndex),
       let pdfPageImage = item as? ZoomedPdfPageImage,
       let page = pdfPageImage.pageReference,
       page.type == .double {
      return panoPageSize ?? PdfDisplayOptions.Overview.fallbackPageSize
    }
    return singlePageSize
  }
  
  func page(at idx: Int) -> Page? {
    return pageIndex2page[idx]
  }
  
  func page2(at idx: Int) -> Page? {
    return (item(atIndex: idx)  as? ZoomedPdfPageImage)?.pageReference
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
  var count: Int { images.count }
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
  
  func articleAt(indexPath: IndexPath) -> Article? {
    pageIndex2article[indexPath.section]?.valueAt(indexPath.row-1)
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
    
    let articles = issue.allArticles
    var addedArticles: [Article] = []//Prevent listing on later page
    var idx = 0
    for page in issue.pages ?? [] {
      let item = ZoomedPdfPageImage(page:page, issueDir: issueDir)
      item.fullScreenPageHeight = fullscreenPageHeight
      item.pdfDownloadDelegate = self
      self.images.append(item)
      
      pageName2pageIndex[page.pdf?.name ?? "-"] = idx
      var arts: [Article] = []
      for article in articles {
        for case let pname in article.pageNames ?? [] where pname == page.pdf?.fileName {
          if addedArticles.contains(where: {$0.html?.name == article.html?.name }) { continue }
          arts.append(article)
          addedArticles.append(article)
        }
      }
      if arts.count == 0 { continue }//Prevent Comercial Pages in Slider
      pageIndex2article[idx] = arts
      pageIndex2page[idx] = page
      idx += 1
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
