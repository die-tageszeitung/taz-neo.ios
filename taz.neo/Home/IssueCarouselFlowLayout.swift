//
//  IssueCarouselFlowLayout.swift
//  taz.neo
//
//  Created by Ringo Müller on 07.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

class IssueCarouselFlowLayout: CarouselFlowLayout {
  public override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
    var offsetAdjustment = CGFloat.greatestFiniteMagnitude
    let horizontalOffset = proposedContentOffset.x + collectionView!.contentInset.left
    let targetRect = CGRect(x: proposedContentOffset.x, y: 0, width: collectionView!.bounds.size.width, height: collectionView!.bounds.size.height)
    let layoutAttributesArray = super.layoutAttributesForElements(in: targetRect)
    layoutAttributesArray?.forEach({ (layoutAttributes) in
      let itemOffset = layoutAttributes.frame.origin.x
      if fabsf(Float(itemOffset - horizontalOffset)) < fabsf(Float(offsetAdjustment)) {
        offsetAdjustment = itemOffset - horizontalOffset
      }
    })
    return CGPoint(x: proposedContentOffset.x + offsetAdjustment, y: proposedContentOffset.y)
  }
}
