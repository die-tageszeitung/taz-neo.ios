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

//Usage Event
public enum uEvt {
  case application(Application)
  public enum Application: String, CodableEnum {
    case downloaded
  }
  case system(System)
  public enum System: String, CodableEnum {
    case ApplicationMinimize = "Application Minimize",
         NavigationBack = "Navigation Back"
  }
  case appMode(AppMode)
  public enum AppMode: String, CodableEnum {
    case SwitchToMobileMode = "Switch to Mobile Mode",
         SwitchToPDFMode = "Switch to PDF Mode"
  }
  case authenticationStatus(AuthenticationStatus)
  public enum AuthenticationStatus: String, CodableEnum {
    case Authenticated = "State Authenticated",
         Anonymous = "State Anonymous"
  }
  case user(User)
  public enum User: String, CodableEnum {
    case Login = "Login",
         Logout = "Logout"
  }
  case dialog(Dialog)
  public enum Dialog: String, CodableEnum {
    case LoginHelp = "Login Help",
         SubscriptionHelp = "Subscription Help",
         SubscriptionElapsed = "Subscription Elapsed",
         AllowNotificationsInfo = "Allow Notifications Info",
         IssueActions = "Issue Actions",
         IssueDatePicker = "Issue Date Picker",
         TextSettings = "Text Settings",
         SharingNotPossible = "Sharing Not Possible",
         AutomaticDownloadChoice = "Automatic Download Choice",
         PDFModeLoginHint = "PDF Mode Login Hint",
         PDFModeSwitchHint = "PDF Mode Switch Hint",
         ConnectionError = "Connection Error",
         FatalError = "Fatal Error",
         IssueDownloadError = "Issue Download Error"
  }
  case subscriptionStatus(SubscriptionStatus)
  public enum SubscriptionStatus: String, CodableEnum {
    case Elapsed = "Elapsed",
         SubcriptionRenewed = "Subcription Renewed"
  }
  case subscription(Subscription)
  public enum Subscription: String, CodableEnum {
    case InquirySubmitted = "Inquiry Submitted",
         InquiryFormValidationError = "Inquiry Form Validation Error",
         InquiryServerError = "Inquiry Server Error",
         InquiryNetworkError = "Inquiry Network Error",
         TrialConfirmed = "Trial Confirmed"
  }
  case bookmarks(Bookmarks)
  public enum Bookmarks: String, CodableEnum {
    case AddArticle = "Add Article",
         RemoveArticle = "Remove Article"}
  case share(Share)
  public enum Share: String, CodableEnum {
    case ShareArticle = "Share Article",
         ShareSearchHit = "Share Search Hit",
         IssueMoment = "Issue Moment"}
  case drawer(Drawer)
  public enum Drawer: String, CodableEnum {
    case Open = "Open",
         Tap = "Tap",
         Toggle = "Toggle"
  }
  case audioPlayer(AudioPlayer)
  public enum AudioPlayer: String, CodableEnum {
    case PlayArticle = "Play Article",
         ChangePlaySpeed = "Change Play Speed",
         Maximize = "Maximize",
         Minimize = "Minimize",
         Close = "Close",
         SkipNext = "Skip Next",
         SkipPrevious = "Skip Previous",
         SeekForward = "Seek Forward",
         SeekBackward = "Seek Backward",
         SeekPosition = "Seek Position",
         Resume = "Resume",
         Pause = "Pause",
         EnableAutoPlayNext = "Enable Auto Play Next",
         DisableAutoPlayNext = "Disable Auto Play Next"
  }
  var usageEvent: UsageEvent {
    switch self {
      case .application(let value): return ("Application", value.rawValue)
      case .system(let value): return ("System", value.rawValue)
      case .appMode(let value): return ("AppMode", value.rawValue)
      case .authenticationStatus(let value): return ("Authentication Status", value.rawValue)
      case .user(let value):return ("User", value.rawValue)
      case .dialog(let value): return ("Dialog", value.rawValue)
      case .subscriptionStatus(let value): return ("Subscription Status", value.rawValue)
      case .subscription(let value): return ("Subscription", value.rawValue)
      case .bookmarks(let value): return ("Bookmarks", value.rawValue)
      case .share(let value): return ("Share", value.rawValue)
      case .drawer(let value): return ("Drawer", value.rawValue)
      case .audioPlayer(let value): return ("Audio Player", value.rawValue)
    }
  }
  public typealias UsageEvent = (Category: String, Action: String)
  /** HOW TO EXTRACT Category/Action
   public extension CodableEnum {  var root: Self { return self }}
   public extension EventKeys { var root2: Self { return self }}
   let key = EventKeys.audioPlayer(.Close)
   print(key.usageEvent.Action) //Close
   print(key.usageEvent.Category) //Audio Player
   print(key.root2)//audioPlayer(Close)
   print(Mirror(reflecting: key).subjectType)//EventKeys
   */
}


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
  
  var enterBackground: Date?
  
  func startNewSession(){
    matomoTracker.startNewSession()
    trackAuthStatus()
    trackSubscriptionStatusIfNeeded(isChange: false)
  }
  
  func goingForeground() {
    doTrackCurrentScreen()
    ///Start a new Session after App was in BAckground for 2 hours == 60*120
    if let bg = enterBackground, Date().timeIntervalSince(bg) > 60*120 {
      startNewSession()
    }
  }
  
  func goingBackground() {
    trackEvent(uEvt.system(.ApplicationMinimize))
    enterBackground = Date()
    matomoTracker.dispatch()
  }
  func appWillTerminate() {
    matomoTracker.dispatch()
  }

  func trackAuthStatus() {
    TazAppEnvironment.isAuthenticated
    ? Usage.track(uEvt.authenticationStatus(.Authenticated))
    : Usage.track(uEvt.authenticationStatus(.Anonymous))
  }
  
  func trackSubscriptionStatusIfNeeded(isChange: Bool) {
    if Defaults.expiredAccount {
      Usage.track(uEvt.subscriptionStatus(.Elapsed))
    }
    else if isChange {
      Usage.track(uEvt.subscriptionStatus(.SubcriptionRenewed))
    }
  }
  
  override init() {
    super.init()
    Notification.receive(UIApplication.willResignActiveNotification) { [weak self] _ in
      self?.goingBackground()
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.goingForeground()
    }
    Notification.receive(UIApplication.willTerminateNotification) { [weak self] _ in
      self?.appWillTerminate()
    }
//    Notification.receive(Const.NotificationNames.authenticationSucceeded) { [weak self] notif in
//      self?.trackEvent(uEvt.user(.Login))
//      self?.startNewSession()
//      self?.trackEvent(uEvt.authenticationStatus(.Authenticated))
//    }
    Notification.receive(Const.NotificationNames.expiredAccountDateChanged) {[weak self]  _ in
      self?.trackSubscriptionStatusIfNeeded(isChange: true)
    }
    
    $usageTrackingAllowed.onChange{[weak self] _ in
      self?.matomoTracker.isOptedOut = self?.usageTrackingAllowed != true
    }
  }
}

fileprivate extension Usage {
  func trackEvent(_ uevt: uEvt){
    if usageTrackingAllowed == false { return }
    let event = uevt.usageEvent
    var url = ""
    if let s = currentScreenUrl?.absoluteString{
      url = " on url: \(s)"
    }
    print("trackEvent with Category: \"\(event.Category)\" and Action: \"\(event.Action)\"\(url)")
    self.matomoTracker.track(eventWithCategory: event.Category,
                             action: event.Action,
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

extension Usage: NavigationDelegate {
  func popViewController(){
    trackEvent(uEvt.system(.NavigationBack))
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
  public func trackEvent(_ uevt: uEvt){
    ensureBackground{ Usage.sharedInstance.trackEvent(uevt) }
  }
  public func trackScreen(){
    if path == nil || path?.count ?? 0 == 0 {
      Log.debug("Current Class did not implement path correctly")
      return
    }
    let path = path
    let trackingUrl = trackingUrl
    ensureBackground{ Usage.sharedInstance.trackScreen(path, url: trackingUrl)}
  }
}

extension Usage {
  public static func track(_ uevt: uEvt){
    ensureBackground{ Usage.sharedInstance.trackEvent(uevt) }
  }
}
