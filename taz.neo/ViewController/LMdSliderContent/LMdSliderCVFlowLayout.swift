//
//  LMdSliderCVFlowLayout.swift
//  lmd.neo
//
//  Created by Ringo Müller on 11.01.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

///  layout for 2 column self sizing collection view
///  layout is created initially with evaluateLayout and
///  needed to be re-evaluated on content change or collection views size change
class LMdSliderCVFlowLayout: UICollectionViewFlowLayout, DoesLog {
  
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
      let cvc = collectionView.dataSource as? LMdSliderContentVC else { return }
    
    var leftYOffset = self.sectionInset.top
    var rightYOffset = self.sectionInset.top
    
    let cvWidth = oldBounds?.width ?? collectionView.frame.size.width
    let leftCellWidth = cvWidth * 0.3
    
    let rightCellWidth
    = cvWidth - leftCellWidth
    - sectionInset.left - sectionInset.right - minimumInteritemSpacing
    let rightCellXOffset 
    = leftCellWidth + sectionInset.left + minimumInteritemSpacing
    
    guard collectionView.numberOfSections > 0 else { return }
    
    for sect in 0...(collectionView.numberOfSections ) - 1 {
      var max = max(leftYOffset, rightYOffset)
      
      if sect > 0 {
        let seperatorAttr
        = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader.self,
                                           with: IndexPath(row: 0, section: sect))
        seperatorAttr.frame = CGRect(x: 15, y: max, width: cvWidth - 30, height: 40)
        max += 40
        cachedAttributes.append(seperatorAttr)
      }
      
      leftYOffset = max
      rightYOffset = max
      for row in 0...collectionView.numberOfItems(inSection: sect) - 1 {
        let ip = IndexPath(row: row, section: sect)
        
        if row > 1 {
          let seperatorAttr
          = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader.self,
                                             with: ip)
          seperatorAttr.frame = CGRect(x: rightCellXOffset, y: rightYOffset, width: cvWidth - rightCellXOffset - 15 , height: 40)
          rightYOffset += 40
          cachedAttributes.append(seperatorAttr)
        }
        
        
        guard let cell = cvc.collectionView(collectionView,
                                            cellForItemAt: ip) as? LMdSliderCell else { continue }
        let attr = UICollectionViewLayoutAttributes(forCellWith: ip)
        if row == 0 {
          attr.frame = CGRect(origin: CGPoint(x: self.sectionInset.left, y: leftYOffset),
                              size:  cell.fittingSizeFor(width: leftCellWidth))
          leftYOffset += attr.frame.size.height
        } else {
          attr.frame = CGRect(origin: CGPoint(x: rightCellXOffset, y: rightYOffset),
                              size:  cell.fittingSizeFor(width: rightCellWidth))
          rightYOffset += attr.frame.size.height
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
