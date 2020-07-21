//
//  Colors.swift
//
//  Created by Norbert Thies on 07.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

/// Various App specific color values
public struct AppColors {
  static let darkPrimaryBG = UIColor.rgb(0x0)
  static let darkSecondaryBG = UIColor.rgb(0x1c1c1e)
  static let darkSeparator = UIColor.rgb(0x545458)
  static let darkPrimaryText = UIColor.rgb(0xffffff)
  static let darkSecondaryText = UIColor.rgb(0xebebf5)
  static let ciColor = UIColor.rgb(0xd50d2e)
  
  static let darkToolbar = darkSecondaryBG
  static let darkTintColor = darkSecondaryText
  
  struct Light {
    static let CTBackground = UIColor.white
    static let CTSection = ciColor
    static let CTArticle = UIColor.darkGray
    static let CTDate = UIColor.black
    static let HBackground = UIColor.white
    static let HText = UIColor.black
  }
  
  struct Dark {
    static let CTBackground = darkSecondaryBG
    static let CTSection = darkSecondaryText
    static let CTArticle = UIColor.rgb(0xacace0)
    static let CTDate = UIColor.white
    static let HBackground = darkSecondaryBG
    static let HText = darkSecondaryText
  }
  
} // AppColors


enum TazColor{
  case CTBackground
  case CTSection
  case CTArticle
  case CTDate
  case HBackground
  case HText
  case Test
  
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
      return (UIColor.white, AppColors.darkSecondaryBG,nil,nil)
    case .CTSection:
      return (AppColors.ciColor, AppColors.darkSecondaryText,nil,nil)
    case .CTArticle:
      return (UIColor.darkGray, UIColor.rgb(0xacace0),nil,nil)
    case .CTDate:
      return (UIColor.black, UIColor.white,nil,nil)
    case .HBackground:
      return (UIColor.white, AppColors.darkSecondaryBG,nil,nil)
    case .HText:
      return (UIColor.black, AppColors.darkSecondaryText,nil,nil)
    case .Test:
      return (UIColor.red, UIColor.green, UIColor.blue,UIColor.magenta)
    }
  }
}

/// Various App specific font values
public struct AppFonts {
  
  static var contentFontName: String? = UIFont.register(name: "Aktiv Grotesk")
  static var titleFontName: String? = UIFont.register(name: "Aktiv Grotesk Bold")
  
  static func font(name: String?, size: CGFloat) -> UIFont {
    var font: UIFont? = nil
    if let name = name { font = UIFont(name: name, size: size) }
    if font == nil { font = UIFont.systemFont(ofSize: size) }
    return font!
  }
  
  /// The font to use for content
  static func contentFont(size: CGFloat) -> UIFont 
    { return font(name: contentFontName, size: size) }
  
  /// The font to use in titles
  static func titleFont(size: CGFloat) -> UIFont
    { return font(name: titleFontName, size: size) }
  
}
