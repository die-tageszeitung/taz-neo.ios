//
//  Usage.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.09.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import MatomoTracker

class Usage: NSObject, DoesLog{
  
  let matomoTracker = MatomoTracker(siteId: "116", baseURL: URL(string: "https://gazpacho.taz.de")!)
  
  fileprivate static let sharedInstance = Rating()
  
  override init() {
    super.init()
//    matomoTracker.
  }
}

extension Usage {
  func trackEvent(){}
  func trackScreen(){}
}

public protocol TrackScreenViewController {
  var path:String { get }
}
