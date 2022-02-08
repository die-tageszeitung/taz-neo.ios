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
  func tazX(_ isUpdate:Bool = false) -> Self{
    return self.circleIconButton(isUpdate, symbol: "xmark")
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
  
  @discardableResult
  func circleIconButton(_ isUpdate:Bool = false, symbol: String? = nil) -> Self {
    guard let bv = self as? Button<ImageView> else { return self }
    bv.buttonView.imageView.tintColor = Const.SetColor.ios(.secondaryLabel).color
    bv.buttonView.color = Const.SetColor.ios(.secondaryLabel).color
    bv.buttonView.activeColor = Const.SetColor.ios(.secondaryLabel).color.withAlphaComponent(0.1)
    bv.layer.backgroundColor = Const.SetColor.ios(.secondarySystemFill).color.cgColor
    if isUpdate ==  true { return self }
    let circleRadius: CGFloat = 30.0
    bv.buttonView.symbol = symbol
    self.pinSize(CGSize(width: circleRadius, height: circleRadius))
    bv.buttonView.useExternalImageSetup = true
    //Fallback Image Size is Different
    bv.buttonView.imageView.iosLower13?.pinSize(CGSize(width: 14, height: 14))
    bv.layer.cornerRadius = circleRadius/2
    return self
  }
  
}
