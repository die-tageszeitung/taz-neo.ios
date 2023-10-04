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
import UIKit

class Usage: NSObject, DoesLog{
  let canTrack: Bool = App.isAlpha
  
  let matomoTracker = MatomoTracker(siteId: "116", baseURL: URL(string: "https://gazpacho.taz.de/matomo.php")!)
  
  fileprivate static let sharedInstance = Usage()
  
  override init() {
    super.init()
  }
}

fileprivate extension Usage {
  func trackEvent(){
    if canTrack == false { return }
  }
  
  func trackScreen(_ path: [String], url: URL? = nil){
    if canTrack == false { return }
    print("trackScreen: " + path.joined(separator: "/"))
    matomoTracker.track(view: path, url: url)
  }
}


public protocol UsageTracker {
  var path:[String] { get }
  var trackingUrl:URL? { get }
}
extension UsageTracker {
  public func trackEvent(){ Usage.sharedInstance.trackEvent() }
  public func trackScreen(){ 
    if path.count == 0 {
      Log.debug("Current Class did not implement path correctly")
      return
    }
    Usage.sharedInstance.trackScreen(path, url: trackingUrl)}
  public var trackingUrl:URL? { nil }
}
//Swizzling is bad
/// By default a view controller is pushed onto the navigation stack

public class UsageVC: UIViewController, UsageTracker {
  public var path:[String]{ get { return []}}
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    trackScreen()
  }
}

public class UsageTVC: UITableViewController, UsageTracker {
  public var path:[String]{ get { return []}}
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    trackScreen()
  }
}
