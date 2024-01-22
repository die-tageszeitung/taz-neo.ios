//
//  CvSectionSeperator.swift
//  lmd.neo
//
//  Created by Ringo Müller on 17.01.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthUIKit


/// seperator for collectionview cells, final width is set with layout
class CvSeperator: UICollectionReusableView {

  let border = UIView()
  
  func setup(){
    self.addSubview(border)
    border.centerY(dist: -3)
    border.backgroundColor = .black
    border.pinHeight(0.7)
    pin(border.left, to: self.left)
    pin(border.right, to: self.right)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}
