//
//  PdfMenuLayout.swift
//  taz.neo
//
//  Unified layout for list and page overview modes, supporting sections for each page, dynamic heights, panorama/left/right pages, headers, separator views, and animated transitions on mode switch. Uses PdfModel for all data and mirrors cache/batching from legacy layouts.
//

import UIKit
import NorthUIKit

class PdfMenuLayout: UICollectionViewFlowLayout {
  
  enum Mode {
    case list
    case pages
  }
  
  // MARK: - Public
  var mode: Mode = .list {
    didSet {
      guard oldValue != mode else { return }
      invalidateLayout()
    }
  }
  
  public var singlePageItemSize:CGSize = .zero
  public var panoPageItemSize:CGSize = .zero
  public var collectionViewWidth:CGFloat = 0
  
  let singlePageRatio:CGFloat
  let pdfModel: NewPdfModel
  
  // Layout cache
  private var cachedPageAttributes: [IndexPath:UICollectionViewLayoutAttributes] = [:]
  private var cachedListCellAttributes: [IndexPath:UICollectionViewLayoutAttributes] = [:]
  private var cachedListHeaderAttributes: [UICollectionViewLayoutAttributes] = []
  private var pageContentSize: CGSize = .zero
  private var listContentSize: CGSize = .zero
  
  // Layout constants
  private let headerHeight: CGFloat = 40.0
  private let separatorHeight: CGFloat = 0.5
  private let sectionInsets = UIEdgeInsets(top: 0, left: 16, bottom: 10, right: 15)
  private let minInteritemSpacing: CGFloat = 16.0
  private let maxLabelHeight: CGFloat = 28
  
  override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    return true
  }
  
  override var collectionViewContentSize: CGSize { mode == .list ? listContentSize : pageContentSize }
  
  let pageInterItemSpacing = PdfDisplayOptions.Overview.interItemSpacing - 0.5//fix misscalculation bug
  
  
  func preparePageLayout(){
    guard let collectionView else { return }
    cachedPageAttributes.removeAll()
    
    let spacing = self.pageInterItemSpacing
    let panoItemWidth
    = collectionView.bounds.inset(by: collectionView.layoutMargins).width
    - self.sectionInset.left
    - self.sectionInset.right
    let singleItemWidth =  max(1, panoItemWidth/2 - spacing/2)
    let itemHeight = singleItemWidth * singlePageRatio + 20.0 ///+ labelHeight!
    singlePageItemSize = CGSize(width: singleItemWidth, height: itemHeight)
    panoPageItemSize = CGSize(width: panoItemWidth, height: itemHeight)
    let rowHeight = itemHeight + self.minimumLineSpacing
    var yOffset = self.sectionInset.top
    let xLeft = self.sectionInset.left + collectionView.layoutMargins.left
    /// UI:  |-sectionInset.left-[cell]-spacing-[cell]-sectionInset.right-|
    let xRight = singleItemWidth + spacing + xLeft
    var prevPageType : PageType?
    
    var currentSection = 0
    for sectionContent in pdfModel.sectionContent {
      let indexPath = IndexPath(row: 0, section: currentSection)
      let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
      switch (prevPageType, sectionContent.page.type) {
        case (.left, .right):
          attributes.frame = CGRect(origin: CGPoint(x: xRight, y: yOffset), size: singlePageItemSize)
        case (_, .double):
          yOffset += rowHeight
          attributes.frame = CGRect(origin: CGPoint(x: xLeft, y: yOffset), size: panoPageItemSize)
        case (.right, .right):
          yOffset += rowHeight
          attributes.frame = CGRect(origin: CGPoint(x: xRight, y: yOffset), size: singlePageItemSize)
        default:
          if currentSection == 0 {
            ///**Using Header for title page, hide page**
            attributes.frame = .zero
            yOffset -= rowHeight
          }
          else {
            yOffset += rowHeight
            attributes.frame = CGRect(origin: CGPoint(x: xLeft, y: yOffset), size: singlePageItemSize)
          }
      }
      prevPageType = sectionContent.page.type
      cachedPageAttributes[indexPath] = attributes
      currentSection += 1
    }
    pageContentSize = CGSize(width: collectionView.bounds.size.width,
                             height: yOffset + rowHeight)
    ///This was the AI-generated code
    /*
     if mode == .pages {
     // Single section, all pages are items
     for row in 0..<pdfModel.count {
     let ip = IndexPath(item: row, section: 0)
     let attr = UICollectionViewLayoutAttributes(forCellWith: ip)
     // Use 2-column or pano logic
     let isPano = pdfModel.item(atIndex: row)?.pageType == .double
     let cellWidth: CGFloat = isPano ? width : (width - minInteritemSpacing) / 2
     let cellHeight: CGFloat = cellWidth * 1.4 // Estimate aspect
     let x: CGFloat = isPano ? sectionInsets.left : (row % 2 == 0 ? sectionInsets.left : sectionInsets.left + cellWidth + minInteritemSpacing)
     attr.frame = CGRect(x: x, y: yOffset, width: cellWidth, height: cellHeight)
     cachedAttributes[ip] = attr
     if isPano || row % 2 == 1 {
     yOffset += cellHeight + minInteritemSpacing
     }
     }
     contentSize = CGSize(width: cv.bounds.width, height: yOffset + sectionInsets.bottom)
     */
  }
  
  
  func prepareListLayout(){
    guard let collectionView else { return }
    cachedListCellAttributes.removeAll()
    cachedListHeaderAttributes = []

    var yOffset = 0.0
    
    let cvWidth = collectionView.frame.size.width
    let leftCellWidth = cvWidth * Const.Size.taz.Slider.xLeft
    
    let rightCellWidth = cvWidth - leftCellWidth - sectionInset.left - sectionInset.right - minimumInteritemSpacing
    let rightCellXOffset = leftCellWidth + sectionInset.left + minimumInteritemSpacing
    let pageCellWidth = leftCellWidth
    let pageCellHeight = pageCellWidth / Const.Size.LmdPageAspect + 30.0 //additional Space for label
    
    guard collectionView.numberOfSections > 0 else { return }
    
    var currentSection = 0
    for sectionContent in pdfModel.sectionContent {
      yOffset += self.sectionInset.top
      /// **Section Header**
      let separatorAttr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader.self, with: IndexPath(row: 0, section: currentSection))
      separatorAttr.frame = CGRect(x: 0, y: yOffset, width: cvWidth - 30, height: 60)
      yOffset += 60
      cachedListHeaderAttributes.append(separatorAttr)
      
      /// **left cell, Page Image**
      let pageCellIndexPath = IndexPath(row: 0, section: currentSection)
      let pageCellAttributes = UICollectionViewLayoutAttributes(forCellWith: pageCellIndexPath)
      pageCellAttributes.frame = CGRect(origin: CGPoint(x: self.sectionInset.left, y: yOffset),
                          size: CGSize(width: pageCellWidth, height: pageCellHeight))
      cachedListCellAttributes[pageCellIndexPath] = pageCellAttributes
      
      /// **right cells, article cells**
      var row = 1
      var articleCellsOffset = 0.0
      for art in sectionContent.articles {
        let artCellIndexPath = IndexPath(row: row, section: currentSection)
        let artCellAttributes = UICollectionViewLayoutAttributes(forCellWith: artCellIndexPath)
        
        /// dynamic cell height calculation by `systemLayoutSizeFitting`
        let prototypeCell = PdfArticleCell(frame: .zero)
        prototypeCell.article = art
        let fittingSize = prototypeCell.systemLayoutSizeFitting(
          CGSize(width: rightCellWidth, height: UIView.layoutFittingCompressedSize.height),
          withHorizontalFittingPriority: .required,
          verticalFittingPriority: .fittingSizeLevel
        )
        artCellAttributes.frame
        = CGRect(origin: CGPoint(x: rightCellXOffset,
                                 y: yOffset + articleCellsOffset),
                 size: fittingSize)
        cachedListCellAttributes[artCellIndexPath] = artCellAttributes
        articleCellsOffset += fittingSize.height
        row += 1
      }
      yOffset += max(pageCellHeight, articleCellsOffset)
      currentSection += 1
    }
    listContentSize
    = CGSize(width: collectionView.bounds.width, height: yOffset)
//    = CGSize(width: rightCellXOffset + rightCellWidth + sectionInset.right,
//             height: yOffset + sectionInset.bottom)
    
    /** AI Generated code
     for section in 0..<(pdfModel.sectionContent.count) {
     let headerIp = IndexPath(item: 0, section: section)
     // Header
     let headerAttr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, with: headerIp)
     headerAttr.frame = CGRect(x: sectionInsets.left, y: yOffset, width: width, height: headerHeight)
     cachedHeaders[headerIp] = headerAttr
     yOffset += headerHeight
     let nRows = pdfModel.itemsInListSection(section)
     for row in 0..<nRows {
     let ip = IndexPath(item: row, section: section)
     let attr = UICollectionViewLayoutAttributes(forCellWith: ip)
     if row == 0 {
     // Page image
     let imageWidth = width * 0.48
     let cellHeight = imageWidth / 0.64 + maxLabelHeight
     attr.frame = CGRect(x: sectionInsets.left, y: yOffset, width: imageWidth, height: cellHeight)
     yOffset += cellHeight + minInteritemSpacing
     } else {
     // Article cell: dynamic height (estimate here, should be improved by delegate)
     let cellHeight: CGFloat = 80.0
     attr.frame = CGRect(x: sectionInsets.left, y: yOffset, width: width, height: cellHeight)
     yOffset += cellHeight + 4.0
     }
     cachedAttributes[ip] = attr
     }
     // Separator
     //                let sepAttr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, with: headerIp)
     //                sepAttr.frame = CGRect(x: sectionInsets.left, y: yOffset, width: width, height: separatorHeight)
     //                cachedSeparators[headerIp] = sepAttr
     //                yOffset += separatorHeight
     }
     contentSize = CGSize(width: cv.bounds.width, height: yOffset)
     */
  }
  
  override func prepare() {
    super.prepare()
    preparePageLayout()
    prepareListLayout()
  }
  
  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    var attrs: [UICollectionViewLayoutAttributes] = []
    if mode == .list {
      for attr in cachedListCellAttributes.values where attr.frame.intersects(rect) { attrs.append(attr) }
      for attr in cachedListHeaderAttributes where attr.frame.intersects(rect) { attrs.append(attr) }
    }
    else {
      for attr in cachedPageAttributes.values where attr.frame.intersects(rect) { attrs.append(attr) }
    }
    return attrs
  }
  
  override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    mode == .list ? cachedListCellAttributes[indexPath] : cachedPageAttributes[indexPath]
  }
  
  override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    if mode == .list,
       elementKind == UICollectionView.elementKindSectionHeader {
      return cachedListHeaderAttributes[indexPath.section]
    }
    return nil
  }
  
  public init(pdfModel: NewPdfModel) {
    self.pdfModel = pdfModel
    self.singlePageRatio = max(1.2, pdfModel.singlePageSize.height/pdfModel.singlePageSize.width)
    super.init()
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
