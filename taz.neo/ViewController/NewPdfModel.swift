//
//  NewPdfModel.swift
//  taz.neo
//
//  Created by Ringo Müller on 24.06.26.
//  Copyright © 2026 taz. All rights reserved.
//
import NorthLib
import UIKit

struct ListData {
    var page: Page
    var pageName: String? ///optional, empty if not first page of a ressort 
    var articles: [Article]
}

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
  var listData: [ListData] = []
  
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
  
  /// due Advertisement/Anzeigen mostly have wrong Pagina (mostly "Seite 2" due copy in BAckend
  /// we do not show original pagina for anzeigen, we hide it
  public func pageTitle(at idx: Int) -> String? {
    if pageIndex2article[idx]?.count == 0 { return nil }
    guard let page = (item(atIndex: idx)  as? ZoomedPdfPageImage)?.pageReference else { return nil }
    return "Seite \(page.pagina ?? "")"
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
  
  func itemsInListSection(_ section: Int) -> Int {
    guard let data = listData.valueAt(section) else { return 0 }
    return data.articles.count + 1
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
    var pageIndex = 0
    
    var pageName2articles: [String: [Article]] = [:]
    for article in articles {
        for pname in article.pageNames ?? [] {
            pageName2articles[pname, default: []].append(article)
        }
    }
    listData = []
    var lastPageName: String?
    let lastPage = issue.pages?.last
    for page in issue.pages ?? [] {
      let item = ZoomedPdfPageImage(page:page, issueDir: issueDir)
      item.fullScreenPageHeight = fullscreenPageHeight
      item.pdfDownloadDelegate = self
      self.images.append(item)
      
      var filteredPageArticles: [Article] = []
      if let pageFileName = page.pdf?.fileName,
         let pageArticles = pageName2articles[pageFileName] {
        let filteredArticles = pageArticles.filter { article in
          !addedArticles.contains(where: { $0.serverId == article.serverId })
        }
        filteredPageArticles.append(contentsOf: filteredArticles)
        addedArticles.append(contentsOf: filteredArticles)
      }
      if page.pdf?.fileName == lastPage?.pdf?.fileName,
        let imprint = issue.imprint {
        filteredPageArticles.append(imprint)
      }
      
      let itm = ListData(page: page,
                         pageName: page.title == lastPageName ? nil : page.title,
                         articles: filteredPageArticles)
      listData.append(itm)

      pageName2pageIndex[page.pdf?.name ?? "-"] = pageIndex
      pageIndex2article[pageIndex] = filteredPageArticles
      pageIndex2page[pageIndex] = page
      
      pageIndex += 1
      lastPageName = page.title
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

