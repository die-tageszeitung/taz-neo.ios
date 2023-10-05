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
  
  static let sharedInstance = Usage()
  
  fileprivate var currentScreen:[String]?
  fileprivate var currentScreenUrl:URL?
  
  fileprivate var lastPageCollectionVConDosplayClosureKey:String?
  fileprivate var lastPageCollectionVC:PageCollectionVC? {
    didSet {
      if let key = lastPageCollectionVConDosplayClosureKey {
        oldValue?.removeOnDisplay(forKey: key)
        lastPageCollectionVConDosplayClosureKey = nil
      }
      lastPageCollectionVConDosplayClosureKey
      = lastPageCollectionVC?.onDisplay(closure: { [weak self] _, _ in
        guard let usageVc = self?.lastPageCollectionVC as? UsageTracker else { return }
        usageVc.trackScreen()
      })
    }
  }
  
  override init() {
    super.init()
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.doTrackCurrentScreen()
    }
  }
}

fileprivate extension Usage {
  func trackEvent(){
    if canTrack == false { return }
  }
  
  func trackScreen(_ path: [String]?, url: URL? = nil){
    currentScreen = path
    currentScreenUrl = url
    doTrackCurrentScreen()
  }
  
  private func doTrackCurrentScreen(){
    if canTrack == false { return }
    var url = ""
    if let s = currentScreenUrl?.absoluteString{
      url = " url: \(s)"
    }
    print("trackScreen: " + (currentScreen ?? []).joined(separator: "/") + url)
    matomoTracker.track(view: currentScreen ?? [], url: currentScreenUrl)
  }
}


extension Usage: UINavigationControllerDelegate {
  //on bookmark and search didshow will appeared twice
//  public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
//    
//  }
  
  func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
//    print("willShow trackScreen::\(viewController) navctrl: \(navigationController)")
    guard let usageVc = viewController as? UsageTracker else {
      debug("NOT trackScreen:: current visible vc: \(viewController) is not prepared for tracking!")
      return
    }
    #warning("This is probably a Memory LEAK!!")
    if let pcvc = usageVc as? PageCollectionVC {
      lastPageCollectionVC = pcvc
    }
    usageVc.trackScreen()
  }
}

public protocol UsageTracker where Self: UIViewController {
  var path:[String]? { get }
  var trackingUrl:URL? { get }
}

extension UsageTracker {
  public var trackingUrl:URL? { return nil }
  public var trackingScreenOnAppear:Bool  { return true }
  public func trackEvent(){ Usage.sharedInstance.trackEvent() }
  public func trackScreen(){
    if path == nil || path?.count ?? 0 == 0 {
      Log.debug("Current Class did not implement path correctly")
      return
    }
    Usage.sharedInstance.trackScreen(path, url: trackingUrl)
  }
}
