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

public enum EventAction: String, CodableEnum {
  case downloaded,
       ApplicationMinimize = "Application Minimize",
       Login
}
  
public enum EventCategory: String, CodableEnum {
  case Application,
       System,
       AppMode,
       AuthenticationStatus = "Authentication Status",
       User,
       SubscriptionStatus = "Subscription Status"
} // ArticleType


class Usage: NSObject, DoesLog{
  
  @Default("usageTrackingAllowed")
  fileprivate var usageTrackingAllowed: Bool
  
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

    Notification.receive(UIApplication.willResignActiveNotification) { [weak self] _ in
      self?.trackEvent(.System, .ApplicationMinimize)
    }
    
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.doTrackCurrentScreen()
    }
    
    $usageTrackingAllowed.onChange{[weak self] _ in
      self?.matomoTracker.isOptedOut = self?.usageTrackingAllowed != true
    }
  }
}

fileprivate extension Usage {
  func trackEvent(_ category: EventCategory, _ action: EventAction){
    if usageTrackingAllowed == false { return }
    self.matomoTracker.track(eventWithCategory: category.toString(), 
                             action: action.toString(),
                             name: nil,
                             number: nil,
                             url: currentScreenUrl)
  }
  
  func trackScreen(_ path: [String]?, url: URL? = nil){
    currentScreen = path
    currentScreenUrl = url
    doTrackCurrentScreen()
  }
  
  private func doTrackCurrentScreen(){
    if usageTrackingAllowed == false { return }
    var url = ""
    if let s = currentScreenUrl?.absoluteString{
      url = " url: \(s)"
    }
    print("trackScreen: " + (currentScreen ?? []).joined(separator: "/") + url)
    matomoTracker.track(view: currentScreen ?? [], url: currentScreenUrl)
  }
}


extension Usage: UINavigationControllerDelegate {

  func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
    guard let usageVc = viewController as? UsageTracker else {
      debug("NOT trackScreen:: current visible vc: \(viewController) is not prepared for tracking!")
      return
    }
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
