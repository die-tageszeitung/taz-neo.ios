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
    static let CTDate = CTArticle
    static let HBackground = UIColor.white
    static let HText = UIColor.black
  }
  
  struct Dark {
    static let CTBackground = darkSecondaryBG
    static let CTSection = darkSecondaryText
    static let CTArticle = UIColor.rgb(0xacace0)
    static let CTDate = CTArticle
    static let HBackground = darkSecondaryBG
    static let HText = darkSecondaryText
  }
  
} // AppColors

/// Various App specific font values
public struct AppFonts {
  
  /// The font to use for content
  static func contentFont(size: CGFloat) -> UIFont {
    UIFont(name: "Aktiv Grotesk", size: size) ??
      UIFont.systemFont(ofSize: size)
  }
  
  /// The font to use in titles
  static func titleFont(size: CGFloat) -> UIFont {
    UIFont(name: "Aktiv Grotesk Bold", size: size) ??
      UIFont.boldSystemFont(ofSize: size)
  }
  
}
