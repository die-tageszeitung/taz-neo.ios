//
//  LMdSliderCVFlowLayout.swift
//  taz.neo
//
//  Created by Ringo Müller on 24.06.26.
//  Copyright © 2026 taz. All rights reserved.
//

import UIKit
import NorthLib

///  layout for 2 column self sizing collection view
///  layout is created initially with evaluateLayout and
///  needed to be re-evaluated on content change or collection views size change
class PdfMenuListFlowLayout: UICollectionViewFlowLayout, DoesLog {
  
  fileprivate var cachedAttributes = [UICollectionViewLayoutAttributes]()
  
  override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes, withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
    return false //use pre-calculated layout!
  }
  
  
  /// helper to get offset for given cell to set scrollposition
  /// - Parameter indexPath: for searched element
  /// - Returns: offset of given item
  func offset(forItemAt indexPath: IndexPath) -> CGFloat? {
    return cachedAttributes.first { attr in
      return attr.indexPath.section == indexPath.section
      && attr.indexPath.row == indexPath.row
    }?.frame.origin.y
    ///FYI the simplier: cachedAttributes.valueAt(indexPath.item)?.frame.origin.y
    ///is not working, returns cell 0-0 for e.g. indexPath 13-0
    ///seams that indexPath item is not set correctly in that call
  }
    
  public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    guard cachedAttributes.count > 0 else {
      evaluateLayout(force: true)
      return nil
    }
    var attributesArray = [UICollectionViewLayoutAttributes]()
    for attributes in cachedAttributes {
      if attributes.frame.intersects(rect) {
        attributesArray.append(attributes)
      }
    }
    return attributesArray
  }
  
  override func layoutAttributesForDecorationView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return super.layoutAttributesForDecorationView(ofKind: elementKind, at: indexPath)
  }
  
  public func evaluateLayout(force: Bool) {
    if force {
      cachedAttributes = []
      customContentSize = nil
    }
    if cachedAttributes.count > 0 { return }
    guard let collectionView = collectionView,
          let cvc = collectionView.dataSource as? NewPdfOverviewCollectionVC else { return }
    
    var leftYOffset = self.sectionInset.top
    var rightYOffset = self.sectionInset.top
    
    let cvWidth = oldBounds?.width ?? collectionView.frame.size.width
    let leftCellWidth = cvWidth * Const.Size.taz.Slider.xLeft
    
    let rightCellWidth = cvWidth - leftCellWidth - sectionInset.left - sectionInset.right - minimumInteritemSpacing
    let rightCellXOffset = leftCellWidth + sectionInset.left + minimumInteritemSpacing
    
    guard collectionView.numberOfSections > 0 else { return }
    
    
    for sect in 0..<collectionView.numberOfSections {
      var maxOffset = max(leftYOffset, rightYOffset)
      
      let separatorAttr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader.self,
                                                           with: IndexPath(row: 0, section: sect))
      separatorAttr.frame = CGRect(x: 0, y: maxOffset, width: cvWidth - 30, height: 60)
      maxOffset += 60
      cachedAttributes.append(separatorAttr)
      
      leftYOffset = maxOffset
      rightYOffset = maxOffset
      
      for row in 0..<collectionView.numberOfItems(inSection: sect) {
        let ip = IndexPath(row: row, section: sect)
        
        if row > 1 {
          let separatorAttr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter.self,
                                                               with: ip)
          separatorAttr.frame = CGRect(x: rightCellXOffset, y: rightYOffset, width: cvWidth - rightCellXOffset - 15, height: 40)
          rightYOffset += 40
          cachedAttributes.append(separatorAttr)
        }
        
        let attr = UICollectionViewLayoutAttributes(forCellWith: ip)
        
        if row == 0 {
          // 📌 Linke Zelle (Bildzelle) → feste Höhe basierend auf Seitenverhältnis 1.34x Breite
          let cellWidth = leftCellWidth
          let cellHeight = cellWidth / Const.Size.LmdPageAspect + 30.0 //additional Space for label
          attr.frame = CGRect(origin: CGPoint(x: self.sectionInset.left, y: leftYOffset),
                              size: CGSize(width: cellWidth, height: cellHeight))
          leftYOffset += cellHeight
        } else {
          // 📌 Rechte Zelle (Artikelzelle) → dynamische Höhe über `systemLayoutSizeFitting`
          let prototypeCell = LMdPageArticleCell(frame: .zero)
          prototypeCell.article = cvc.pdfModel.articleAt(indexPath: ip)
          
          let fittingSize = prototypeCell.systemLayoutSizeFitting(
            CGSize(width: rightCellWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
          )
          
          attr.frame = CGRect(origin: CGPoint(x: rightCellXOffset, y: rightYOffset),
                              size: fittingSize)
          rightYOffset += fittingSize.height
        }
        
        cachedAttributes.append(attr)
      }
    }
    customContentSize
    = CGSize(width: rightCellXOffset + rightCellWidth + sectionInset.right,
             height:  max(leftYOffset, rightYOffset) + sectionInset.bottom)
  }
  
  var customContentSize: CGSize?
  
  override var collectionViewContentSize: CGSize {
    return customContentSize ?? super.collectionViewContentSize
  }
  
  var oldBounds:CGRect?
  
  
  public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    guard let oldBounds = oldBounds else {
      oldBounds = newBounds
      return true
    }
    let shouldInvalidate = abs(oldBounds.width.rounded() - newBounds.width.rounded()) > 1
    if shouldInvalidate {
      self.oldBounds = newBounds
      evaluateLayout(force: true)
    }
    return shouldInvalidate
  }
}
