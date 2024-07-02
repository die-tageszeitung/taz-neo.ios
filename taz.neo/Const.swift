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
  
  struct Urls {
    ///former
    //static let faqUrl = URL(string: "https://blogs.taz.de/app-faq/")
    ///new foreward url's
    ///Source Mail Ralf 3.5.23
    /// dl.taz.de/faq && https://dl.monde-diplomatique.de/faq
    #if LMD
    static let faqUrl = lmdFaqUrl
    #else
    static let faqUrl = tazFaqUrl
    #endif
    static let tazFaqUrl
    = URL(string: "https://dl.taz.de/faq")
    static let lmdFaqUrl
    = URL(string: "https://dl.monde-diplomatique.de/faq")
  }
  
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
    static let audioPlaybackStateChanged = "Const.NotificationNames.audioPlaybackStateChanged"
    static let audioPlaybackFinished = "Const.NotificationNames.audioPlaybackFinished"
    static let gotoIssue = "Const.NotificationNames.gotoIssue"
    static let gotoSettings = "Const.NotificationNames.gotoSettings"
    static let gotoArticleInIssue = "Const.NotificationNames.gotoArticleInIssue"
    static let searchSelectedText = "Const.NotificationNames.searchSelectedText"
    
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
    static let appIconGrey: UIColor = UIColor.rgb(0x9c9c9c)
    static let appIconGreyActive: UIColor = darkSecondaryText
    #if LMD
    static let foundTextHighlight: UIColor = UIColor.rgb(0x71FF01)
    #else
    static let foundTextHighlight: UIColor = UIColor.rgb(0xffff88)
    #endif
    static let ciColor: UIColor =  UIColor.rgb(0xd50d2e)
    static let radioGreen: UIColor =  UIColor.rgb(0x2ca400)
    
    static let darkToolbar = darkSecondaryBG
    static let darkTintColor = darkSecondaryText
    
    #if LMD
    struct LMd {
      static let ci: UIColor =  UIColor.rgb(0x3B88A7)
      static let bgGrey: UIColor =  UIColor.rgb(0xF0F0ED)
    }
    #endif
    
    struct Light {
      static let CTBackground = UIColor.white
      static let CTArticle = UIColor.darkGray
      static let HBackground = UIColor.white
      static let HText = UIColor.black
      #if LMD
        static let HomeBackground = UIColor.rgb(0xd9d9d3)//LMD-background-darker
        static let HomeText = UIColor.rgb(0x1f1f1f)//LMD-offblack
        static let MenuBackground = UIColor.rgb(0xf0f0ed)//--LMD-background
      #else
        static let HomeBackground = UIColor.black
        static let HomeText = appIconGrey
        static let MenuBackground = UIColor.white//Const.SetColor.HBackground.color
      #endif
      static let Taz_BackgroundForms = UIColor.rgb(0xEBEBEB)
      static let Taz_Notifications_error = UIColor.rgb(0xFF1919)
      static let Taz_Notifications_errorText = UIColor.rgb(0xC01111)
      static let Taz_Text_DisabledX = UIColor.rgb(0x6A6A6A)
    }
    struct Dark {
      static let CTBackground = darkSecondaryBG
      static let CTArticle = UIColor.rgb(0xacace0)
      static let HBackground = UIColor.black
      static let HText = darkSecondaryText
      #if LMD
        static let HomeBackground = UIColor.rgb(0xd9d9d3)//LMD-background-darker
        static let HomeText = UIColor.rgb(0x1f1f1f)//LMD-offblack
        static let MenuBackground = UIColor.rgb(0x121212)//LMD-Android-Dark-Theme-background
      #else
        static let HomeBackground = UIColor.black
        static let HomeText = appIconGrey
        static let MenuBackground = UIColor.black
      #endif
      static let Taz_BackgroundForms = UIColor.rgb(0x353535)
      static let Taz_Notifications_error = UIColor.rgb(0xFF1919)
      static let Taz_Notifications_errorText = UIColor.rgb(0xE3E3E3)
      static let Taz_Text_Disabled = UIColor.rgb(0xA6A6A6)
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
    case CTArticle
    case HBackground
    case HomeBackground
    case HomeText
    case MenuBackground
    case HText
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
      case shade
      case primaryForeground
      case primaryBackground
      case secondaryBackground
      case buttonBackground
      case buttonActiveBackground
      case buttonForeground
      case buttonActiveForeground
    }
    case taz2(taz2_Custom)//new taz colors
    enum taz2_Custom {
      case backgroundForms
      case notifications_error
      case notifications_errorText
      case text_disabled
      case text_icon_grey
      case text
      case closeX
      case closeX_background
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
        return UITraitCollection.current.accessibilityContrast == .high 
        ? Defaults.darkMode ? set.darkHigh ?? set.dark : set.lightHigh ?? set.light
        : Defaults.darkMode ? set.dark : set.light
      }
    }
    
    /// using a color that responds to `userInterfaceStyle` trait changes
    var dynamicColor : UIColor {
      get{
        let set = colors(name: self)
        return UITraitCollection.current.accessibilityContrast == .high
        ? UIColor(light: set.lightHigh ?? set.light, dark: set.darkHigh ?? set.dark)
        : UIColor(light: set.light, dark: set.dark)
      }
    }
    
    var brightColor : UIColor {
      get{
        return colors(name: self).light
      }
    }
    
    fileprivate typealias ColorSet = ( light: UIColor, dark: UIColor, lightHigh: UIColor?, darkHigh: UIColor?)
    
    fileprivate func colors(name: SetColor) -> ColorSet {
      switch name {
        case .CTBackground:
          return (UIColor.white, Const.Colors.darkSecondaryBG,nil,nil)
        case .CTArticle:
          return (UIColor.darkGray, UIColor.rgb(0xacace0),nil,nil)
        case .HBackground:
          return (UIColor.white,UIColor.black,nil,nil)
        case .HText:
          return (UIColor.black, Const.Colors.darkSecondaryText,nil,nil)
        case .CIColor:
          #if LMD
          return (Const.Colors.LMd.ci,nil,nil,nil)
          #else
          return (Const.Colors.ciColor,Const.Colors.ciColor,nil,nil)
          #endif
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
        case .taz2(.text_disabled): fallthrough
        case .taz(.textFieldPlaceholder):
          return (UIColor.rgb(0x6A6A6A), UIColor.rgb(0xA6A6A6), nil, nil)
        case .taz(.textFieldClear):
          return (UIColor.rgb(0x9C9C9C), UIColor.rgb(0x9C9C9C), nil, nil)
        case .taz2(.text_icon_grey): fallthrough
        case .taz(.textIconGray):
          return (UIColor.rgb(0x565656), UIColor.rgb(0xbdbdbd), nil, nil)
        case .taz(.primaryBackground):
          return (.white, .black, nil, nil)
        case .taz(.primaryForeground)://same: .taz(.buttonForeground):
          return (.black, .white, nil, nil)
        case .taz(.shade):
          return (.black, UIColor.rgb(0x9C9C9C), nil, nil)
        case .taz(.secondaryBackground):
          return (UIColor.rgb(0xDEDEDE), UIColor.rgb(0x323232), nil, nil)
        case .taz(.buttonBackground):
          //derived from and Figma f4f4f4 > ios(.secondarySystemBackground) is 0xF2F2F7 0x1C1C1E
          return (UIColor.rgb(0xF4F4F4), UIColor.rgb(0x101010), nil, nil)
        case .taz(.buttonForeground):
          return (.black, .white, nil, nil)
        case .taz(.buttonActiveBackground):
          return (.black, .white, nil, nil)
        case .taz(.buttonActiveForeground):
          return (.white, .black, nil, nil)
        case .HomeBackground:
          return (Const.Colors.Light.HomeBackground, Const.Colors.Dark.HomeBackground,nil,nil)
        case .HomeText:
          return (Const.Colors.Light.HomeText, Const.Colors.Dark.HomeText,nil,nil)
        case .MenuBackground:
          return (Const.Colors.Light.MenuBackground, Const.Colors.Dark.MenuBackground,nil,nil)
        case .taz2(.backgroundForms):
          return (Const.Colors.Light.Taz_BackgroundForms, Const.Colors.Dark.Taz_BackgroundForms, nil, nil)
        case .taz2(.notifications_error):
          return (Const.Colors.Light.Taz_Notifications_error, Const.Colors.Dark.Taz_Notifications_error, nil, nil)
        case .taz2(.notifications_errorText):
          return (Const.Colors.Light.Taz_Notifications_errorText, Const.Colors.Dark.Taz_Notifications_errorText, nil, nil)
        case .taz2(.closeX):
          return (UIColor.rgb(0x3C3C43), UIColor.rgb(0xB3B3B5), nil, nil)
        case .taz2(.closeX_background):
          return (UIColor.rgb(0xE0E0E0), UIColor.rgb(0x48484A), nil, nil)
        case .taz2(.text):
          return (UIColor.rgb(0x1f1f1f), UIColor.rgb(0xe3e3e3), UIColor.rgb(0x000000), UIColor.rgb(0xffffff))
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
    static var lmdArnhem: String? = UIFont.register(name: "ArnhemPro-Blond", type: "woff", subDir: "files")
    static var lmdArnhemItalic: String? = UIFont.register(name: "ArnhemPro-BlondItalic", type: "woff", subDir: "files")
    static var lmdArnhemBold: String? = UIFont.register(name: "ArnhemPro-Bold", type: "woff", subDir: "files")
    static var lmdArnhemBoldItalic: String? = UIFont.register(name: "ArnhemPro-BoldItalic", type: "woff", subDir: "files")
    static var lmdBenton: String? = UIFont.register(name: "BentonSans-Regular", type: "woff", subDir: "files")
    static var lmdBentonItalic: String? = UIFont.register(name: "BentonSans-Italic", type: "woff", subDir: "files")
    static var lmdBentonBold: String? = UIFont.register(name: "BentonSans-Bold", type: "woff", subDir: "files")
    static var lmdBentonBoldItalic: String? = UIFont.register(name: "BentonSans-BoldItalic", type: "woff", subDir: "files")
    static var americanTypewriterFontName: String = "AmericanTypewriter-CondensedBold"
    static var knileLight: String? = UIFont.register(name: "knile-light-webfont", type: "woff", subDir: "files")
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
    #if LMD
    static var contentFontName: String? = lmdBenton
    static var titleFontName: String? = lmdBentonBold
    #else
    static var contentFontName: String? = UIFont.register(name: "Aktiv Grotesk")
    static var titleFontName: String? = UIFont.register(name: "Aktiv Grotesk Bold")
    #endif
    
    static var contentTableFontName = titleFontName
    static var contentTextFont = quaTextRegular

    static func font(name: String?, size: CGFloat) -> UIFont {
      var font: UIFont? = nil
      if let name = name { font = UIFont(name: name, size: size) }
      if font == nil { font = UIFont.systemFont(ofSize: size) }
      return font!
    }
    
    /// The font to use for content
    static func contentFont(size: CGFloat = 30.0) -> UIFont
    { return font(name: contentFontName, size: size) }
    
    /// The font to use in titles
    static func titleFont(size: CGFloat) -> UIFont
    { return font(name: titleFontName, size: size) }
    
    /// The font to use in content tables
    static func contentTableFont(size: CGFloat) -> UIFont
    { return font(name: contentTableFontName, size: size) }
    
    /// The font to use in content tables
    static func contentTextFont(size: CGFloat = Const.Size.DefaultFontSize) -> UIFont
    { return font(name: contentTextFont, size: size) }
    
    /// The font to use in modals
    static func marketingHeadFont(size: CGFloat = 30.0) -> UIFont
    { return font(name: knileLight, size: size) }
    
    static var contentFont: UIFont = contentFont(size: Size.DefaultFontSize)
    static var boldContentFont: UIFont = titleFont(size: Size.DefaultFontSize)
  } // Fonts
  
  struct Size {
    static let TextViewPadding = SmallPadding
    static let TextFieldPadding = SmallPadding
    static let MiniPageNumberFontSize = CGFloat(12)
    static let DefaultFontSize = CGFloat(16)
    static let DefaultButtonFontSize = CGFloat(17)
    static let SmallerFontSize = CGFloat(14)
    static let LargeTitleFontSize = CGFloat(34)
    static let TitleFontSize = CGFloat(25)
    static let SubtitleFontSize = CGFloat(21)
    static let DT_Head_extrasmall = CGFloat(20.5)
    static let DottedLineHeight = CGFloat(2.4)
    static let DefaultPadding = CGFloat(15.0)
    static let TabletSidePadding = CGFloat(35.0)
    static let TabletFormMinWidth = CGFloat(550.0)
    static let BiggerPadding = CGFloat(20.0)
    static let NewTextFieldHeight = CGFloat(40.0)
    static let TextFieldHeight = CGFloat(36.0)//Default Height of Search Controllers Text Input
    static let SmallPadding = CGFloat(10.0)
    static let TinyPadding = CGFloat(5.0)
    static let ContentTableFontSize = CGFloat(22.0)
    static let ContentTableRowHeight = CGFloat(30.0)
    #if LMD
    static let ButtonHeight = CGFloat(45.0)
    #else
    static let ButtonHeight = CGFloat(34.0)
    #endif
    
    
    static let ContentSliderMaxWidth = 420.0
    struct LMd {
      struct Slider {
        static let xLeft = 0.20//left Scale Factor 0.3*SliderWidth
        //NOT NEEDED static let xRight = 0.77//right Scale Factor 1-xLeft*SliderWidth
      }
    }
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
    static let DefaultAll = UIEdgeInsets(top: Const.Size.DefaultPadding,
                                    left: Const.Size.DefaultPadding,
                                    bottom: -Const.Size.DefaultPadding,
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
  
  /// Various Shadow values??
  struct Dist {
    static let margin: CGFloat = 12.0
  }
  
  struct Dist2 {
    /// small dist beetween related elements e.g. Image and Caption
    static let s5: CGFloat = 5.0
    /// small dist beetween related elements e.g. Headline and Subhead or same types of objects
    static let s10: CGFloat = 10.0
    /// medium dist to seperate components wich are not related together; e.g. top/left/right margin; inner elements
    static let m15: CGFloat = 15.0
    /// medium dist to seperate components wich are not related together; e.g. Image/Head; Text/Info, Buttons
    static let m20: CGFloat = 20.0
    /// medium dist to seperate components wich are not related together; e.g. Form Fields
    static let m25: CGFloat = 25.0
    /// medium dist to seperate components wich are not related together; e.g. before Buttons; between caption and Headline
    static let m30: CGFloat = 30.0
    ///biggest dist at end of content
    static let l: CGFloat = 40.0
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
  
  /// set americanTypewriter font with default font size and return self (for chaining)
  /// - Returns: self
  @discardableResult
  func americanTypewriter(size: CGFloat = Const.Size.DefaultFontSize) -> UILabel {
    self.font = Const.Fonts.font(name: Const.Fonts.americanTypewriterFontName, size: size)
    return self
  }
  
  /// set lmd  ArnhemPro  font with default font size and return self (for chaining)
  ///  @todo may respect dark/light mode with param ignore dark/lightMode
  /// - Returns: self
  @discardableResult
  func lmdArnhem(bold:Bool = false, italic: Bool = false, size: CGFloat = Const.Size.DefaultFontSize) -> UILabel {
    switch (bold, italic) {
      case (false, false):
        self.font = Const.Fonts.font(name: Const.Fonts.lmdArnhem, size: size)
      case (false, true):
        self.font = Const.Fonts.font(name: Const.Fonts.lmdArnhemItalic, size: size)
      case (true, false):
        self.font = Const.Fonts.font(name: Const.Fonts.lmdArnhemBold, size: size)
      case (true, true):
        self.font = Const.Fonts.font(name: Const.Fonts.lmdArnhemBoldItalic, size: size)
    }
    return self
  }
  
  /// set lmd  Benton  font with default font size and return self (for chaining)
  ///  @todo may respect dark/light mode with param ignore dark/lightMode
  /// - Returns: self
  @discardableResult
  func lmdBenton(bold:Bool = false, italic: Bool = false, size: CGFloat = Const.Size.DefaultFontSize) -> UILabel {
    switch (bold, italic) {
      case (false, false):
        self.font = Const.Fonts.font(name: Const.Fonts.lmdBenton, size: size)
      case (false, true):
        self.font = Const.Fonts.font(name: Const.Fonts.lmdBentonItalic, size: size)
      case (true, false):
        self.font = Const.Fonts.font(name: Const.Fonts.lmdBentonBold, size: size)
      case (true, true):
        self.font = Const.Fonts.font(name: Const.Fonts.lmdBentonBoldItalic, size: size)
    }
    return self
  }

  /// set content title font with default font size and return self (for chaining)
  /// - Returns: self
  @discardableResult
  func titleFont(size: CGFloat = Const.Size.LargeTitleFontSize) -> UILabel {
    self.font = Const.Fonts.titleFont(size: size)
    return self
  }
  
  /// set font to marketing head knile with its default font size of 30 and return self (for chaining)
  /// - Returns: self
  @discardableResult
  func marketingHead(size: CGFloat = 30) -> UILabel {
    self.font = Const.Fonts.marketingHeadFont(size: size)
    return self
  }
  
  @discardableResult
  internal func color(_ color: UIColor) -> UILabel {
    self.textColor = color
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
  func centerText() -> UILabel {
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
    var font: UIFont
    switch type {
      case .bold:
        font = Const.Fonts.titleFont(size: Const.Size.DefaultFontSize)
      case .content:
        font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
      case .small:
        font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
      case .title:
        font = Const.Fonts.titleFont(size: Const.Size.LargeTitleFontSize)
      case .contentText:
        font = Const.Fonts.contentTextFont(size: Const.Size.DefaultFontSize)
    }
    self.init()
    text = _text
    numberOfLines = _numberOfLines
    self.font = font
    self.textColor = color.color
    self.textAlignment = align
  }
  
  internal convenience init(_ _text : String,
                   _numberOfLines : Int = 0,
                   font: UIFont,
                   color: Const.SetColor = .ios(.label),
                   align: NSTextAlignment = .natural) {
    self.init()
    text = _text
    numberOfLines = _numberOfLines
    self.font = font
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
