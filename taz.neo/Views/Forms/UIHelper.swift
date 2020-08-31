//
// UIHelper.swift
//
// Created by Ringo Müller-Gromes on 31.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//
//  This file implements some UIView helper

import UIKit
import NorthLib

// MARK: - Color Helper to use iOS Build in Dark/LightMode
enum TazColor{
  case CTBackground
  case CTSection
  case CTArticle
  case CTDate
  case HBackground
  case HText
  case Test
  case CIColor
  
  var color : UIColor {
    get{
      let set = colors(name: self)
      if #available(iOS 13, *) {
        return UIColor { (traitCollection: UITraitCollection) -> UIColor in
          switch(traitCollection.userInterfaceStyle,
                 traitCollection.accessibilityContrast)
          {
            case (.dark, .high): return ((set.darkHigh != nil) ? set.darkHigh : set.dark) ?? set.light
            case (.dark, _):     return set.dark ?? set.light
            case (_, .high):     return  set.lightHigh ?? set.light
            default:             return set.light
          }
        }
      }
      else {
        return set.light
      }
    }
  }
  
  fileprivate typealias ColorSet = ( light: UIColor, dark: UIColor?, lightHigh: UIColor?, darkHigh: UIColor?)
  
  fileprivate func colors(name: TazColor) -> ColorSet {
    switch name {
      case .CTBackground:
        return (UIColor.white, Const.Colors.darkSecondaryBG,nil,nil)
      case .CTSection:
        return (Const.Colors.ciColor, Const.Colors.darkSecondaryText,nil,nil)
      case .CTArticle:
        return (UIColor.darkGray, UIColor.rgb(0xacace0),nil,nil)
      case .CTDate:
        return (UIColor.black, UIColor.white,nil,nil)
      case .HBackground:
        return (UIColor.white, Const.Colors.darkSecondaryBG,nil,nil)
      case .HText:
        return (UIColor.black, Const.Colors.darkSecondaryText,nil,nil)
      case .Test://Rainbow: use to test Light/Darkmode with lightHigh & darkHigh
        return (UIColor.red, UIColor.green, UIColor.blue,UIColor.magenta)
      case .CIColor:
        return (Const.Colors.ciColor,nil,nil,nil)
    }
  }
}
