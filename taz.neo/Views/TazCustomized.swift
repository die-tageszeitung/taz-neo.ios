//
//  TazCustomized.swift
//  taz.neo
//
//  Created by Ringo Müller on 25.11.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib

public extension ButtonControl {
  
  @discardableResult
  func tazX(_ isUpdate:Bool = false) -> Self {
    guard let bv = self as? Button<CircledXView> else { return self }
    bv.buttonView.circleColor = Const.SetColor.ios(.secondarySystemFill).color
    bv.buttonView.color = Const.SetColor.ios(.secondaryLabel).color
    bv.buttonView.activeColor = Const.SetColor.ios(.secondaryLabel).color.withAlphaComponent(0.1)
    if isUpdate ==  true { return self }
    self.pinHeight(35)
    self.pinWidth(35)
    bv.buttonView.isCircle = true
    bv.buttonView.innerCircleFactor = 0.5
    return self
  }
  
  @discardableResult
  func tazButton(_ isUpdate:Bool = false) -> Self {
    guard let bv = self as? Button<TextView> else { return self }
    bv.buttonView.circleColor = Const.SetColor.ios(.secondarySystemFill).color
    bv.buttonView.label.textColor = Const.SetColor.ios(.secondaryLabel).color
    bv.buttonView.color = Const.SetColor.ios(.secondaryLabel).color
    bv.buttonView.activeColor = Const.SetColor.ios(.secondaryLabel).color.withAlphaComponent(0.1)
    if isUpdate ==  true { return self }
    self.pinSize(CGSize(width: 28, height: 28), priority: .defaultHigh)
    bv.buttonView.isCircle = true
    bv.buttonView.font
    = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)//16
    return self
  }
}
