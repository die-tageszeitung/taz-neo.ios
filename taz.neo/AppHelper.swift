//
//  AppHelper.swift
//  taz.neo
//
//  Created by Ringo Müller on 22.11.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib

extension UIApplication {
  
  /// helper to get human readable application state
  public var stateDescription : String {
    switch self.applicationState {
      case .active:
        return "active"
      case .background:
        return "active"
      case .inactive:
        return "inactive"
      default:
        return "unknown with raw: \(self.applicationState.rawValue)"
    }
  }
}

/// List of upcomming Features
/// showBottomTilesAnimation is a ConfigVariable


/// Helpers to chain functionallity depending on current App Alpha|Beta|Release
/// usage.eg:   self.view.ifAlphaApp?.addGestureRecognizer(reportLPress3)
public extension NSObject{
  var ifAlphaApp : Self?{
    get{
      if App.isAlpha { return self }
      return nil
    }
  }
  var ifBetaApp : Self?{
    get{
      if App.isBeta { return self }
      return nil
    }
  }
  var ifReleaseApp : Self?{
    get{
      if App.isRelease { return self }
      return nil
    }
  }
}


public extension App {
  /// Is the alpha App
  static var isAlpha: Bool = {
    return bundleIdentifier == BuildConst.tazBundleIdentifierAlpha
  }()
  
  enum Feature { case  PDFEXPORT, INTERNALBROWSER, SEARCH_CONTEXTMENU}
  
  
  /// Is the beta App
  static var isBeta: Bool = {
    return bundleIdentifier == BuildConst.tazBundleIdentifierBeta
  }()
  
  /// Is this  the App Store App
  static var isRelease: Bool = {
    return bundleIdentifier == BuildConst.tazBundleIdentifierStore
  }()
  
  
  /// get app info ()
  static var appInfo:String {
    let appTitle = App.isAlpha ? "Alpha" : App.isBeta ? "Beta" : "taz"
    return "\(appTitle) (v) \(App.version)-\(App.buildNumber)"
  }
  
  /// get current auth info (tazID & logged In status)
  /// - Parameter feederContext: source for info
  /// - Returns: formated string with requested info
  static func authInfo(with feederContext: FeederContext) -> String {
    let authInfo = feederContext.isAuthenticated ? "angemeldet" : "NICHT ANGEMELDET"
    return "\(authInfo), taz-ID: \(DefaultAuthenticator.getUserData().id ?? "-")"
  }
  
  /// Get info is new Features are available
  /// Previously used Compiler Flags, unfortunatly they are harder to find within Source Code Search
  /// and dependecy to Alpha App Versions must be set for each Build
  /// - Parameter feature: Feature to check
  /// - Returns: true if Feature is Available
  static func isAvailable(_ feature: App.Feature) -> Bool {
    switch feature {
      case .INTERNALBROWSER:
        return isAlpha //Only in Alpha Versions
      case .PDFEXPORT:
        return isAlpha //Only in Alpha Versions
      case .SEARCH_CONTEXTMENU:
        return isAlpha //Only in Alpha Versions
    }
  }
}

extension BuildConst {
  static var tazBundleIdentifierAlpha: String { "de.taz.taz.neo" }
  static var tazBundleIdentifierBeta: String { "de.taz.taz.beta" }
  static var tazBundleIdentifierStore: String { "de.taz.taz.2" }
}
