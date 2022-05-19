//
//  TazCustomized.swift
//  taz.neo
//
//  Created by Ringo Müller on 25.11.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public extension ButtonControl {
  
  @discardableResult
  func tazX(_ isUpdate:Bool = false) -> Self{
    return self.circleIconButton(isUpdate, symbol: "xmark")
  }
  
  @discardableResult
  func circleIconButton(_ isUpdate:Bool = false, symbol: String? = nil) -> Self {
    guard let bv = self as? Button<ImageView> else { return self }
    bv.buttonView.imageView.tintColor = Const.SetColor.ios(.secondaryLabel).color
    bv.buttonView.color = Const.SetColor.ios(.secondaryLabel).color
    bv.buttonView.activeColor = Const.SetColor.ios(.secondaryLabel).color.withAlphaComponent(0.1)
    bv.layer.backgroundColor = Const.SetColor.ios(.secondarySystemFill).color.cgColor
    if isUpdate ==  true { return self }
    let circleRadius: CGFloat = 30.0
    bv.buttonView.pinAspect = false
    bv.buttonView.symbol = symbol
    bv.buttonView.hinset = 0.28
    self.pinSize(CGSize(width: circleRadius, height: circleRadius))
    bv.layer.cornerRadius = circleRadius/2
    return self
  }
  
}
