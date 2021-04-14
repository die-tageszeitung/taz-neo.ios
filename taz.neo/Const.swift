//
//  Const.swift
//
//  Created by Norbert Thies on 07.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// Some Constants
public struct Const {
  
  /// Filenames
  struct Filename {
    /// Some resource filenames
    static let dataPolicy = "welcomeSlidesDataPolicy.html"
    static let welcomeSlides = "welcomeSlides.html"
    static let revocation = "welcomeRevocation.html"
    static let terms = "welcomeTerms.html"
  } // Filename
  
  
  /// Names for NSNotifications
  /// @ToDo discuss and may change: NorthLib.Notification.swift => recive, send(message:String...
  /// to: send(notification:NSNotification.Name
  /// and here: static let articleLoaded = NSNotification.Name("NotificationName.articleLoaded")
  struct NotificationNames {
    /// Some resource filenames
    static let articleLoaded = "NotificationName.articleLoaded"
    static let removeLoginRefreshDataOverlay = "NotificationName.removeLoginRefreshDataOverlay"
    static let viewSizeTransition = "NotificationName.viewSizeTransition"
    
  } // Filename
  
  /// Various color values
  struct Colors {
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
      static let ForegroundLight = UIColor.lightGray
      static let ForegroundHeavy = UIColor.darkGray
    }
    
    struct Dark {
      static let CTBackground = darkSecondaryBG
      static let CTSection = darkSecondaryText
      static let CTArticle = UIColor.rgb(0xacace0)
      static let CTDate = UIColor.white
      static let HBackground = darkSecondaryBG
      static let HText = darkSecondaryText
      static let ForegroundLight = UIColor.darkGray
      static let ForegroundHeavy = UIColor.lightGray
    }
    
    
    
    struct iOSLight {
      static let label = UIColor.rgb(0x000000) // The color for text labels that contain primary content
      static let secondaryLabel = UIColor.rgb(0x3C3C43).withAlphaComponent(0.60) // The color for text labels that contain secondary content
      static let tertiaryLabel = UIColor.rgb(0x3C3C43).withAlphaComponent(0.30) // The color for text labels that contain tertiary content
      static let quaternaryLabel = UIColor.rgb(0x3C3C43).withAlphaComponent(0.18) // The color for text labels that contain quaternary content
      static let systemFill = UIColor.rgb(0x787880).withAlphaComponent(0.20) // An overlay fill color for thin and small shapes
      static let secondarySystemFill = UIColor.rgb(0x787880).withAlphaComponent(0.16) // An overlay fill color for medium-size shapes
      static let tertiarySystemFill = UIColor.rgb(0x767680).withAlphaComponent(0.12) // An overlay fill color for large shapes
      static let quaternarySystemFill = UIColor.rgb(0x747480).withAlphaComponent(0.08) // An overlay fill color for large areas that contain complex content
      static let placeholderText = UIColor.rgb(0x3C3C43).withAlphaComponent(0.30) // The color for placeholder text in controls or text views
      static let systemBackground = UIColor.rgb(0xFFFFFF) // The color for the main background of your interface
      static let secondarySystemBackground = UIColor.rgb(0xF2F2F7) // The color for content layered on top of the main background
      static let tertiarySystemBackground = UIColor.rgb(0xFFFFFF) // The color for content layered on top of secondary backgrounds
      static let _tertiarySystemBackgroundDown = UIColor.rgb(0xE2E2E7)// The color for content layered on top of quaternary backgrounds e.g. active/down states
      static let systemGroupedBackground = UIColor.rgb(0xF2F2F7) // The color for the main background of your grouped interface
      static let secondarySystemGroupedBackground = UIColor.rgb(0xFFFFFF) // The color for content layered on top of the main background of your grouped interface
      static let tertiarySystemGroupedBackground = UIColor.rgb(0xF2F2F7) // The color for content layered on top of secondary backgrounds of your grouped interface
      static let separator = UIColor.rgb(0x3C3C43).withAlphaComponent(0.29) // The color for thin borders or divider lines that allows some underlying content to be visible
      static let opaqueSeparator = UIColor.rgb(0xC6C6C8) // The color for borders or divider lines that hides any underlying content
      static let link = UIColor.rgb(0x007AFF) // The color for links
      static let darkText = UIColor.rgb(0x000000) // The nonadaptable system color for text on a light background
      static let lightText = UIColor.rgb(0xFFFFFF).withAlphaComponent(0.60) // The nonadaptable system color for text on a dark background
      static let tintColor = UIColor.rgb(0x007AFF) // The tint color to apply to the button title and image
    }
    
    struct iOSDark {
      static let label = UIColor.rgb(0xFFFFFF)// The color for text labels that contain primary content
      static let secondaryLabel = UIColor.rgb(0xEBEBF5).withAlphaComponent(0.60)// The color for text labels that contain secondary content
      static let tertiaryLabel = UIColor.rgb(0xEBEBF5).withAlphaComponent(0.30)// The color for text labels that contain tertiary content
      static let quaternaryLabel = UIColor.rgb(0xEBEBF5).withAlphaComponent(0.18)// The color for text labels that contain quaternary content
      static let systemFill = UIColor.rgb(0x787880).withAlphaComponent(0.36)// An overlay fill color for thin and small shapes
      static let secondarySystemFill = UIColor.rgb(0x787880).withAlphaComponent(0.32)// An overlay fill color for medium-size shapes
      static let tertiarySystemFill = UIColor.rgb(0x767680).withAlphaComponent(0.24)// An overlay fill color for large shapes
      static let quaternarySystemFill = UIColor.rgb(0x767680).withAlphaComponent(0.18)// An overlay fill color for large areas that contain complex content
      static let placeholderText = UIColor.rgb(0xEBEBF5).withAlphaComponent(0.30)// The color for placeholder text in controls or text views
      static let systemBackground = UIColor.rgb(0x000000)// The color for the main background of your interface
      static let secondarySystemBackground = UIColor.rgb(0x1C1C1E)// The color for content layered on top of the main background
      static let tertiarySystemBackground = UIColor.rgb(0x2C2C2E)// The color for content layered on top of secondary backgrounds
      static let _tertiarySystemBackgroundDown = UIColor.rgb(0x3C3C3E)// The color for content layered on top of quaternary backgrounds e.g. active/down states
      static let systemGroupedBackground = UIColor.rgb(0x000000)// The color for the main background of your grouped interface
      static let secondarySystemGroupedBackground = UIColor.rgb(0x1C1C1E)// The color for content layered on top of the main background of your grouped interface
      static let tertiarySystemGroupedBackground = UIColor.rgb(0x2C2C2E)// The color for content layered on top of secondary backgrounds of your grouped interface
      static let separator = UIColor.rgb(0x545458).withAlphaComponent(0.60)// The color for thin borders or divider lines that allows some underlying content to be visible
      static let opaqueSeparator = UIColor.rgb(0x38383A)// The color for borders or divider lines that hides any underlying content
      static let link = UIColor.rgb(0x0984FF)// The color for links
      static let darkText = UIColor.rgb(0x000000)// The nonadaptable system color for text on a light background
      static let lightText = UIColor.rgb(0xFFFFFF).withAlphaComponent(0.60)// The nonadaptable system color for text on a dark background
      static let tintColor = UIColor.rgb(0x0A84FF)// The tint color to apply to the button title and image
    }
  } // Colors
  
  // MARK: - Color Helper to use iOS Build in Dark/LightMode
  //Its an Ambient/Set Color depending UserInterfaceStyle (dark/light)
  //and accessibilityContrast (default/height)
  enum SetColor{
    case CTBackground
    case CTSection
    case CTArticle
    case ForegroundLight
    case ForegroundHeavy
    case CTDate
    case HBackground
    case HText
    case Test
    case CIColor
    case ios(iOS_SystemColors)
    enum iOS_SystemColors {
      case label
      case secondaryLabel
      case tertiaryLabel
      case quaternaryLabel
      case systemFill
      case secondarySystemFill
      case tertiarySystemFill
      case quaternarySystemFill
      case placeholderText
      case systemBackground
      case secondarySystemBackground
      case tertiarySystemBackground
      case systemGroupedBackground
      case secondarySystemGroupedBackground
      case tertiarySystemGroupedBackground
      case separator
      case opaqueSeparator
      case link
      case darkText
      case lightText
      case tintColor
      case _tertiarySystemBackgroundDown
    }
      
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
          return Defaults.darkMode ? set.dark ??  set.light : set.light
        }
      }
    }
    
    fileprivate typealias ColorSet = ( light: UIColor, dark: UIColor?, lightHigh: UIColor?, darkHigh: UIColor?)
    
    fileprivate func colors(name: SetColor) -> ColorSet {
      switch name {
        case .CTBackground:
          return (UIColor.white, Const.Colors.darkSecondaryBG,nil,nil)
        case .CTSection:
          return (Const.Colors.ciColor, Const.Colors.darkSecondaryText,nil,nil)
        case .ForegroundLight:
          return (Const.Colors.Light.ForegroundLight, Const.Colors.Dark.ForegroundLight,nil,nil)
        case .ForegroundHeavy:
          return (Const.Colors.Light.ForegroundHeavy, Const.Colors.Dark.ForegroundHeavy,nil,nil)
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
        case .ios(.label):
          return (Const.Colors.iOSLight.label, Const.Colors.iOSDark.label, nil, nil)
        case .ios(.secondaryLabel):
          return (Const.Colors.iOSLight.secondaryLabel, Const.Colors.iOSDark.secondaryLabel, nil, nil)
        case .ios(.tertiaryLabel):
          return (Const.Colors.iOSLight.tertiaryLabel, Const.Colors.iOSDark.tertiaryLabel, nil, nil)
        case .ios(.quaternaryLabel):
          return (Const.Colors.iOSLight.quaternaryLabel, Const.Colors.iOSDark.quaternaryLabel, nil, nil)
        case .ios(.systemFill):
          return (Const.Colors.iOSLight.systemFill, Const.Colors.iOSDark.systemFill, nil, nil)
        case .ios(.secondarySystemFill):
          return (Const.Colors.iOSLight.secondarySystemFill, Const.Colors.iOSDark.secondarySystemFill, nil, nil)
        case .ios(.tertiarySystemFill):
          return (Const.Colors.iOSLight.tertiarySystemFill, Const.Colors.iOSDark.tertiarySystemFill, nil, nil)
        case .ios(.quaternarySystemFill):
          return (Const.Colors.iOSLight.quaternarySystemFill, Const.Colors.iOSDark.quaternarySystemFill, nil, nil)
        case .ios(.placeholderText):
          return (Const.Colors.iOSLight.placeholderText, Const.Colors.iOSDark.placeholderText, nil, nil)
        case .ios(.systemBackground):
          return (Const.Colors.iOSLight.systemBackground, Const.Colors.iOSDark.systemBackground, nil, nil)
        case .ios(.secondarySystemBackground):
          return (Const.Colors.iOSLight.secondarySystemBackground, Const.Colors.iOSDark.secondarySystemBackground, nil, nil)
        case .ios(.tertiarySystemBackground):
          return (Const.Colors.iOSLight.tertiarySystemBackground, Const.Colors.iOSDark.tertiarySystemBackground, nil, nil)
        case .ios(._tertiarySystemBackgroundDown):
          return (Const.Colors.iOSLight._tertiarySystemBackgroundDown, Const.Colors.iOSDark._tertiarySystemBackgroundDown, nil, nil)
        case .ios(.systemGroupedBackground):
          return (Const.Colors.iOSLight.systemGroupedBackground, Const.Colors.iOSDark.systemGroupedBackground, nil, nil)
        case .ios(.secondarySystemGroupedBackground):
          return (Const.Colors.iOSLight.secondarySystemGroupedBackground, Const.Colors.iOSDark.secondarySystemGroupedBackground, nil, nil)
        case .ios(.tertiarySystemGroupedBackground):
          return (Const.Colors.iOSLight.tertiarySystemGroupedBackground, Const.Colors.iOSDark.tertiarySystemGroupedBackground, nil, nil)
        case .ios(.separator):
          return (Const.Colors.iOSLight.separator, Const.Colors.iOSDark.separator, nil, nil)
        case .ios(.opaqueSeparator):
          return (Const.Colors.iOSLight.opaqueSeparator, Const.Colors.iOSDark.opaqueSeparator, nil, nil)
        case .ios(.link):
          return (Const.Colors.iOSLight.link, Const.Colors.iOSDark.link, nil, nil)
        case .ios(.darkText):
          return (Const.Colors.iOSLight.darkText, Const.Colors.iOSDark.darkText, nil, nil)
        case .ios(.lightText):
          return (Const.Colors.iOSLight.lightText, Const.Colors.iOSDark.lightText, nil, nil)
        case .ios(.tintColor):
          return (Const.Colors.iOSLight.tintColor, Const.Colors.iOSDark.tintColor, nil, nil)
      }
    }
  } // SetColors

  
  /// Various font values
  struct Fonts {
    static var defaultFontSize = CGFloat(16)
    
    static var contentFontName: String? = UIFont.register(name: "Aktiv Grotesk")
    static var contentTableFontName: String? = titleFontName
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
    
    /// The font to use in content tables
    static func contentTableFont(size: CGFloat) -> UIFont
    { return font(name: contentTableFontName, size: size) }

  } // Fonts
  
  struct Size {
    static let TextViewPadding = CGFloat(10.0)
    static let MiniPageNumberFontSize = CGFloat(12)
    static let DefaultFontSize = CGFloat(16)
    static let LargeTitleFontSize = CGFloat(34)
    static let SmallTitleFontSize = CGFloat(20)
    static let DottedLineHeight = CGFloat(2.4)
    static let DefaultPadding = CGFloat(15.0)
    static let TextFieldPadding = CGFloat(10.0)
    static let ContentTableFontSize = CGFloat(23.0)
    static let ContentTableRowHeight = CGFloat(30.0)
  }
  
  /// Adjusted Sizes for tiny Displays (iPhone 5s/SE1, iPod 7G)
  struct ASize {
    static let TextViewPadding = UIWindow.size.width < 370 ? CGFloat(8) : CGFloat(10.0)
    static let MiniPageNumberFontSize = UIWindow.size.width < 370 ? CGFloat(11) : CGFloat(12)
    static let DefaultFontSize = UIWindow.size.width < 370 ? CGFloat(14) : CGFloat(16)
    static let LargeTitleFontSize = UIWindow.size.width < 370 ? CGFloat(30) : CGFloat(34)
    static let SmallTitleFontSize = UIWindow.size.width < 370 ? CGFloat(18) : CGFloat(20)
    static let DottedLineHeight = CGFloat(2.4)
    static let DefaultPadding = UIWindow.size.width < 370 ? CGFloat(13.0) : CGFloat(15.0)
    static let TextFieldPadding = UIWindow.size.width < 370 ? CGFloat(9.0) : CGFloat(10.0)
  }
} // Const


public extension UILabel {
  /// set content font with default font size and return self (for chaining)
  ///  @todo may respect dark/light mode with param ignore dark/lightMode
  /// - Returns: self
  func contentFont() -> UILabel {
    self.font = Const.Fonts.contentFont(size: Const.Fonts.defaultFontSize)
    return self
  }
  
  /// set content title font with default font size and return self (for chaining)
  /// - Returns: self
  func titleFont() -> UILabel {
    self.font = Const.Fonts.titleFont(size: Const.Size.LargeTitleFontSize)
    return self
  }
  
  func black() -> UILabel {
    self.textColor = UIColor.black
    return self
  }
  
  func white() -> UILabel {
    self.textColor = UIColor.white
    return self
  }
  
  func center() -> UILabel {
    self.textAlignment = .center
    return self
  }
  
  convenience init(_ _text : String, _numberOfLines : Int = 0) {
    self.init()
    text = _text
    numberOfLines = _numberOfLines
  }
}
