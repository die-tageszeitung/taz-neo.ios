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
    static let passwordCheckJs = "tazPasswordSpec.js"
  } // Filename
  
  
  /// Names for NSNotifications
  /// @ToDo discuss and may change: NorthLib.Notification.swift => receive, send(message:String...
  /// to: send(notification:NSNotification.Name
  /// and here: static let articleLoaded = NSNotification.Name("NotificationName.articleLoaded")
  struct NotificationNames {
    /// Some resource filenames
    static let checkForNewIssues = "NotificationName.checkForNewIssues"
    static let publicationDatesChanged = "NotificationName.publicationDatesChanged"
    static let feederReachable = "NotificationName.feederReachable"
    static let feederUnreachable = "NotificationName.feederUnreachable"
    static let issueUpdate = "NotificationName.issueUpdate"
    static let articleLoaded = "NotificationName.articleLoaded"
    static let removeLoginRefreshDataOverlay = "NotificationName.removeLoginRefreshDataOverlay"
    static let viewSizeTransition = "NotificationName.viewSizeTransition"
    static let traitCollectionDidChange = "NotificationName.traitCollectionDidChange"
    static let expiredAccountDateChanged = "NotificationName.expiredAccountDateChanged"
    static let logoutUserDataDeleted = "NotificationName.LogoutUserDataDeleted"
    static let authenticationSucceeded = "Const.NotificationNames.authenticationSucceeded"
    static let bookmarkChanged = "Const.NotificationNames.bookmarkChanged"
    
  } // Filename
  
  /// Various color values
  struct Colors {
    
    static let fabBackground: UIColor = UIColor.rgb(0x363636).withAlphaComponent(0.8)
    
    ///Variable Colors, depending light/darkmode
    static var opacityBackground: UIColor { Const.SetColor.CTBackground.color.withAlphaComponent(0.9) }
    ///Static/Constant Colors
    static let darkPrimaryBG: UIColor = UIColor.rgb(0x0)
    static let darkSecondaryBG: UIColor = UIColor.rgb(0x1c1c1e)
    static let darkSeparator: UIColor = UIColor.rgb(0x545458)
    static let darkPrimaryText: UIColor =  UIColor.rgb(0xffffff)
    static let darkSecondaryText: UIColor = UIColor.rgb(0xebebf5)
    static let appIconGrey: UIColor = darkSecondaryText //UIColor.rgb(0x9c9c9c)
    static let iconButtonInactive: UIColor = UIColor.rgb(0x9c9c9c)
    static let iconButtonActive: UIColor = appIconGrey
    
    static let foundTextHighlight: UIColor = UIColor.rgb(0xffff88)
    static let ciColor: UIColor =  UIColor.rgb(0xd50d2e)
    static let radioGreen: UIColor =  UIColor.rgb(0x2ca400)
    
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
      static let HBackground = UIColor.black
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
    case ios_opaque(iOS_Opaque)
    enum iOS_Opaque {
      case closeXcircleBackground
      case closeX
    }
    case taz(taz_Custom)
    enum taz_Custom {
      case textFieldBackground
      case textDisabled
      case textFieldPlaceholder
      case textFieldClear
      case textFieldText
      case textIconGray
      case secondaryBackground
    }
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
        return Defaults.darkMode ? set.dark ??  set.light : set.light
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
          return (UIColor.white,UIColor.black,nil,nil)
        case .HText:
          return (UIColor.black, Const.Colors.darkSecondaryText,nil,nil)
        case .Test://Rainbow: use to test Light/Darkmode with lightHigh & darkHigh
          return (UIColor.red, UIColor.green, UIColor.blue,UIColor.magenta)
        case .CIColor:
          return (Const.Colors.ciColor,nil,nil,nil)
        case .ios_opaque(.closeX):
          return (UIColor.rgb(0x5D5E63), UIColor.rgb(0xB8B8C1), nil, nil)
        case .ios_opaque(.closeXcircleBackground):
          return (UIColor.rgb(0xE9E9EB), UIColor.rgb(0x39393D), nil, nil)
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
        case .taz(.textFieldBackground):
          return (UIColor.rgb(0xF0F0F0), UIColor.rgb(0x1c1c1c), nil, nil)
        case .taz(.textFieldText):
          return (UIColor.rgb(0x1F1F1F), UIColor.rgb(0xF0F0F0), nil, nil)
        case .taz(.textDisabled): fallthrough
        case .taz(.textFieldPlaceholder):
          return (UIColor.rgb(0xA6A6A6), UIColor.rgb(0x505050), nil, nil)
        case .taz(.textFieldClear):
          return (UIColor.rgb(0x9C9C9C), UIColor.rgb(0x9C9C9C), nil, nil)
        case .taz(.textIconGray):
          return (UIColor.rgb(0x565656), UIColor.rgb(0x929292), nil, nil)
        case .taz(.secondaryBackground):
          return (UIColor.rgb(0xDEDEDE), UIColor.rgb(0x323232), nil, nil)
          
      }
    }
  } // SetColors
  
  
  /// Various font values
  struct Fonts {
    ///Helper to print all Bundled woff Fonts from Bundled Ressources (copied to files folder)
    static func printBundledFonts(type: String = "woff", in dir: String = "files"){
      for  font in Bundle.main.paths(forResourcesOfType: type, inDirectory: dir) {
        let name = URL(fileURLWithPath: font).deletingPathExtension().lastPathComponent
        print("found font: \(name).woff")
      }
    }
    
    static var quaTextRegularI: String? = UIFont.register(name: "QuaText-RegularItalic", type: "woff", subDir: "files")
    static var quaTextRegular: String? = UIFont.register(name: "QuaText-Regular", type: "woff", subDir: "files")
    static var quaTextB: String? = UIFont.register(name: "QuaText-Bold", type: "woff", subDir: "files")
    static var quaTextBi: String? = UIFont.register(name: "QuaText-BoldItalic", type: "woff", subDir: "files")
    /// *WARNING* Cannot use bundled Aktiv Grotesk fonts from Ressources, due just one font variant will be loaded,
    /// Hacky Workaround sleep(1) then load the other Problem is: multiple fonts have same generic font names
    /// from UIFont extension NorthLib -> register(data: Data)
    ///  print("try to register font: \(String(describing: cgFont.postScriptName)) (\(String(describing: cgFont.fullName))
    ///  with \(cgFont.numberOfGlyphs) Glyphes") ...print error if any
    ///  1st:
    /// output:. try to register font: Optional(font0000000028494075) (Optional(.) with 3753 Glyphes
    ///   2nd:
    ///   Failed to register font Error: Optional(Swift.Unmanaged<__C.CFErrorRef>(_value: Error Domain=com.apple.CoreText.CTFontManagerErrorDomain Code=105 "Could not register the CGFont '<CGFont (0x600002bd0a00): font0000000028494197>'" UserInfo={NSDescription=Could not register the CGFont '<CGFont (0x600002bd0a00): font0000000028494197>', CTFailedCGFont=<CGFont (0x600002bd0a00): font0000000028494197>}))
    ///   Error is Font already loaded
    /// With sleep or debugging we have different font names:
    /// try to register font: Optional(font0000000028494075) (Optional(.) with 3753 Glyphes
    /// try to register font: Optional(font000000002849411a) (Optional(.) with 3753 Glyphes
    /// Idea to solve: at first use default font, try to load real font later
//    static var titleFontName: String? = UIFont.register(name: "AktivGrotesk_W_Bd", type: "woff", subDir: "files")
//    static var contentFontName: String? = UIFont.register(name: "AktivGrotesk_W_Rg", type: "woff", subDir: "files")
    ///**SIMPLE SOLUTION FOR THE MOMENT** Use old way!
    static var titleFontName: String? = UIFont.register(name: "Aktiv Grotesk Bold")
    static var contentFontName: String? = UIFont.register(name: "Aktiv Grotesk")
    
    static var contentTableFontName = titleFontName
    static var contentTextFont = quaTextRegular

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
    
    /// The font to use in content tables
    static func contentTextFont(size: CGFloat) -> UIFont
    { return font(name: contentTextFont, size: size) }
    
    static var contentFont: UIFont = contentFont(size: Size.DefaultFontSize)
    static var boldContentFont: UIFont = titleFont(size: Size.DefaultFontSize)
  } // Fonts
  
  struct Size {
    static let TextViewPadding = CGFloat(10.0)
    static let MiniPageNumberFontSize = CGFloat(12)
    static let DefaultFontSize = CGFloat(16)
    static let SmallerFontSize = CGFloat(14)
    static let LargeTitleFontSize = CGFloat(34)
    static let TitleFontSize = CGFloat(25)
    static let SubtitleFontSize = CGFloat(21)
    static let DottedLineHeight = CGFloat(2.4)
    static let DefaultPadding = CGFloat(15.0)
    static let NewTextFieldHeight = CGFloat(40.0)
    static let TextFieldHeight = CGFloat(36.0)//Default Height of Search Controllers Text Input
    static let TextFieldPadding = SmallPadding
    static let SmallPadding = CGFloat(10.0)
    static let TinyPadding = CGFloat(5.0)
    static let ContentTableFontSize = CGFloat(22.0)
    static let ContentTableRowHeight = CGFloat(30.0)
    
    static let ContentSliderMaxWidth = 420.0
  }
  
  struct Insets {
    static let Small = UIEdgeInsets(top: 0,
                                    left: Const.Size.SmallPadding,
                                    bottom: 0,
                                    right: -Const.Size.SmallPadding)
    static let Default = UIEdgeInsets(top: 0,
                                    left: Const.Size.DefaultPadding,
                                    bottom: 0,
                                    right: -Const.Size.DefaultPadding)
    static let NegDefault = UIEdgeInsets(top: 0,
                                    left: -Const.Size.DefaultPadding,
                                    bottom: 0,
                                    right: Const.Size.DefaultPadding)
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
  
  /// Various Shadow values
  struct Shadow {
    static let Color = UIColor.black.cgColor
    static let Offset = CGSize(width: 2, height: 2)
    static let Radius:CGFloat = 4
    struct Dark {
      static let Opacity:Float = 0.75
    }
    struct Light {
      static let Opacity:Float = 0.25
    }
  }
  
  /// Various Shadow values
  struct Dist {
    static let margin: CGFloat = 12.0
  }
  
} // Const

public extension UIView {
  @discardableResult
  func shadow() -> UIView {
    self.layer.shadowOpacity = Defaults.darkMode ? Const.Shadow.Dark.Opacity : Const.Shadow.Light.Opacity
    self.layer.shadowOffset = Const.Shadow.Offset
    self.layer.shadowRadius = Const.Shadow.Radius
    self.layer.shadowColor = Const.Shadow.Color
    return self
  }
}

extension UILabel {
  /// set content font with default font size and return self (for chaining)
  ///  @todo may respect dark/light mode with param ignore dark/lightMode
  /// - Returns: self
  @discardableResult
  func contentFont(size: CGFloat = Const.Size.DefaultFontSize) -> UILabel {
    self.font = Const.Fonts.contentFont(size: size)
    return self
  }
  
  /// set bold content font with default font size and return self (for chaining)
  ///  @todo may respect dark/light mode with param ignore dark/lightMode
  /// - Returns: self
  @discardableResult
  func boldContentFont(size: CGFloat = Const.Size.DefaultFontSize) -> UILabel {
    self.font = Const.Fonts.titleFont(size: size)
    return self
  }
  
  /// set content title font with default font size and return self (for chaining)
  /// - Returns: self
  @discardableResult
  func titleFont(size: CGFloat = Const.Size.LargeTitleFontSize) -> UILabel {
    self.font = Const.Fonts.titleFont(size: size)
    return self
  }
  
  @discardableResult
  internal func color(_ color: Const.SetColor) -> UILabel {
    self.textColor = color.color
    return self
  }
  
  @discardableResult
  func black() -> UILabel {
    self.textColor = UIColor.black
    return self
  }
  
  @discardableResult
  func ciColor() -> UILabel {
    self.textColor = Const.Colors.ciColor
    return self
  }
  
  @discardableResult
  func linkColor() -> UILabel {
    self.textColor =  Const.SetColor.ios(.link).color
    return self
  }
  
  @discardableResult
  func labelColor() -> UILabel {
    self.textColor =  Const.SetColor.ios(.label).color
    return self
  }
  
  @discardableResult
  func white() -> UILabel {
    self.textColor = UIColor.white
    return self
  }
  
  /// sets the TextColor for the Label and return self for chaining
  /// - Parameter textColor to set
  /// - Returns: self
  @discardableResult
  func set(textColor: UIColor) -> UILabel {
    self.textColor = textColor
    return self
  }
  
  @discardableResult
  func center() -> UILabel {
    self.textAlignment = .center
    return self
  }
  
  @discardableResult
  func align(_ side: NSTextAlignment) -> UILabel {
    self.textAlignment = side
    return self
  }
  
  internal convenience init(_ _text : String,
                   _numberOfLines : Int = 0,
                   type: tazFontType = .content,
                   color: Const.SetColor = .ios(.label),
                   align: NSTextAlignment = .natural) {
    self.init()
    text = _text
    numberOfLines = _numberOfLines
    switch type {
      case .bold:
        self.font = Const.Fonts.titleFont(size: Const.Size.DefaultFontSize)
      case .content:
        self.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
      case .small:
        self.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
      case .title:
        self.font = Const.Fonts.titleFont(size: Const.Size.LargeTitleFontSize)
      case .contentText:
        self.font = Const.Fonts.contentTextFont(size: Const.Size.DefaultFontSize)
    }
    self.textColor = color.color
    self.textAlignment = align
    
  }
}

enum tazFontType { case title, small, bold, content, contentText }




extension UIButton {
  
  static let tazButtonHeight: CGFloat = 44
  
  @discardableResult
  /// Primary "Call To Action" Button, sets default styles
  /// - Parameter text: buttons text for normal state
  /// - Returns: button itself for chaining
  func primary_CTA(_ text: String? =  nil) -> Self {
    setDefaults()
    self.layer.backgroundColor = Const.Colors.ciColor.cgColor
    self.titleLabel?.boldContentFont()
    self.setTitleColor(UIColor.white, for: .normal)
    if let t = text {
      self.setTitle(t, for: .normal)
    }
    return self
  }
  
  
  @discardableResult
  /// Secondary "Call To Action" Button, sets default styles
  /// - Parameter text: buttons text for normal state
  /// - Returns: button itself for chaining
  func secondary_CTA(_ text: String? =  nil) -> Self {
    setDefaults()
    self.layer.backgroundColor = UIColor.clear.cgColor
    self.addBorder(Const.Colors.ciColor,  1.5)
    self.titleLabel?.contentFont()
    self.setTitleColor(Const.Colors.ciColor, for: .normal)
    if let t = text {
      self.setTitle(t, for: .normal)
    }
    return self
  }
  
  private func setDefaults(){
    self.pinHeight(UIButton.tazButtonHeight)
    self.layer.cornerRadius = UIButton.tazButtonHeight/2
  }
}


extension UITextField {
  @discardableResult
  func defaultStyle(placeholder: String? =  nil, cornerRadius: CGFloat = 18) -> Self {
    if let p = placeholder {
      self.attributedPlaceholder = NSAttributedString(
        string: p,
        attributes: [NSAttributedString.Key.foregroundColor: Const.SetColor.ios(.tertiaryLabel).color])
    }
    self.backgroundColor = Const.SetColor.ios(.quaternarySystemFill).color
    self.layer.cornerRadius = cornerRadius
    self.layer.masksToBounds = true
    return self
  }
}
