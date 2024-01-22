//
//  _LMdSliderCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.01.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit


/// helper for self sizing collectionview cells
protocol LMdSliderCell where Self: UICollectionViewCell {}

extension LMdSliderCell {
  func fittingSizeFor(width: CGFloat) -> CGSize{
    return contentView.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                                               withHorizontalFittingPriority: .required,
                                               verticalFittingPriority: .fittingSizeLevel)
  }
}
