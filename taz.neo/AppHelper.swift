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

extension App {
  /// Is the alpha App
  public static var isAlpha: Bool = {
    return bundleIdentifier == BuildConst.tazBundleIdentifierAlpha
  }()
  
  /// Is the beta App
  public static var isBeta: Bool = {
    return bundleIdentifier == BuildConst.tazBundleIdentifierBeta
  }()
  
  /// Is this  the App Store App
  public static var isRelease: Bool = {
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
  public static func isAvailable(_ feature: Feature) -> Bool {
    switch feature {
      case .INTERNALBROWSER:
        return isAlpha //Only in Alpha Versions
      case .PDFEXPORT:
        return isAlpha //Only in Alpha Versions
    }
  }
}

extension BuildConst {
  static var tazBundleIdentifierAlpha: String { "de.taz.taz.neo" }
  static var tazBundleIdentifierBeta: String { "de.taz.taz.beta" }
  static var tazBundleIdentifierStore: String { "de.taz.taz.2" }
}
