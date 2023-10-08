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
public enum uEvt: Equatable {
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
         FaksimilelePage = "Faksimilele Page",
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
  public typealias UsageEvent = (category: String, action: String)
  var usageEvent: UsageEvent {
    switch self {
      case .application(let value): 
        return (Categories.application.rawValue,
                value.rawValue)
      case .system(let value): 
        return (Categories.system.rawValue,
                value.rawValue)
      case .appMode(let value):
        return (Categories.appMode.rawValue,
                value.rawValue)
      case .authenticationStatus(let value):
        return (Categories.authenticationStatus.rawValue,
                value.rawValue)
      case .user(let value):
        return (Categories.user.rawValue,
                value.rawValue)
      case .dialog(let value):
        return (Categories.dialog.rawValue,
                value.rawValue)
      case .subscriptionStatus(let value):
        return (Categories.subscriptionStatus.rawValue,
                value.rawValue)
      case .subscription(let value):
        return (Categories.subscription.rawValue,
                value.rawValue)
      case .bookmarks(let value):
        return (Categories.bookmarks.rawValue,
                value.rawValue)
      case .share(let value):
        return (Categories.share.rawValue,
                value.rawValue)
      case .drawer(let value):
        return (Categories.drawer.rawValue,
                value.rawValue)
      case .audioPlayer(let value):
        return (Categories.audioPlayer.rawValue,
                value.rawValue)
    }
  }
  var category: String { self.usageEvent.category }
  var action: String { self.usageEvent.action }
  public enum Categories: String, CodableEnum {
    case application = "Application"
    case system = "System"
    case appMode = "AppMode"
    case authenticationStatus = "Authentication Status"
    case user = "User"
    case dialog = "Dialog"
    case subscriptionStatus = "Subscription Status"
    case subscription = "Subscription"
    case bookmarks = "Bookmarks"
    case share = "Share"
    case drawer = "Drawer"
    case audioPlayer = "Audio Player"
  }
  public enum ActionName {
    case drawerOpenNames(OpenNames)
    public enum OpenNames: String, CodableEnum {
      case Unknown = "Unknown"
    }
    case drawerTapNames(TapNames)
    public enum TapNames: String, CodableEnum {
      case TapPage = "Tap Page",
           TapSection = "Tap Section",
           TapArticle = "Tap Article",
           TapImprint = "Tap Imprint",
           TapMoment = "Tap Moment",
           TapBookmark = "Tap Bookmark",
           TapPlayIssue = "Tap Play Issue"
    }
    case drawerToggleNames(ToggleNames)
    public enum ToggleNames: String, CodableEnum {
      case ToggleSection = "Toggle Section",
           ToggleAllSections = "Toggle all Sections"
    }
    var rawValue: String {
      switch self {
        case .drawerOpenNames(let value):
          return value.rawValue
        case .drawerToggleNames(let value):
          return value.rawValue
        case .drawerTapNames(let value):
          return value.rawValue
      }
    }
  }
  /** HOW TO EXTRACT Category/Action
   ...unfortunatly: Enum with raw type cannot have cases with arguments
   and: Enum case cannot have a raw value if the enum does not have a raw type
   -- so using; usageEvent
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
  
  @Default("usageTrackingCurrentVersion")
  var usageTrackingCurrentVersion: String
  
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
    print("track::NEW SESSIONSTART")
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
    if usageTrackingCurrentVersion != App.bundleVersion {
      usageTrackingCurrentVersion = App.bundleVersion
      var urlString = "http://ios.\(App.bundleIdentifier)/\(usageTrackingCurrentVersion)"
      trackEvent(uEvt.application(.downloaded), eventUrlString: urlString)
    }
    
    trackAuthStatus()
    trackSubscriptionStatusIfNeeded(isChange: false)
    Notification.receive(UIApplication.willResignActiveNotification) { [weak self] _ in
      self?.goingBackground()
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.goingForeground()
    }
    Notification.receive(UIApplication.willTerminateNotification) { [weak self] _ in
      self?.appWillTerminate()
    }
    Notification.receive(Const.NotificationNames.expiredAccountDateChanged) {[weak self]  _ in
      self?.trackSubscriptionStatusIfNeeded(isChange: true)
    }
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      guard let art = msg.sender as? StoredArticle else { return }
      let evt = art.hasBookmark
      ? uEvt.bookmarks(.AddArticle)
      : uEvt.bookmarks(.RemoveArticle)
      let name = art.html?.name.isEmpty == false ? "article/\(art.html?.name ?? "-")|\(art.serverId ?? -1)" : nil
      self?.trackEvent(evt, eventUrlString: name)
    }
    
    $usageTrackingAllowed.onChange{[weak self] _ in
      self?.matomoTracker.isOptedOut = self?.usageTrackingAllowed != true
    }
  }
}

fileprivate extension Usage {
  func trackEvent(_ uevt: uEvt, actionName: uEvt.ActionName? = nil, eventUrlString: String? = nil){
    if usageTrackingAllowed == false { return }
    let event = uevt.usageEvent
    var eventUrl: URL?
    if event.category == uEvt.Categories.dialog.rawValue {
      eventUrl = currentScreenUrl
    }
    else if let eventUrlString = eventUrlString {
      eventUrl = URL(string: eventUrlString)
    }
    let actionNameInfo = actionName != nil ? " name: \(actionName?.rawValue ?? "")" : ""
    let urlInfo = eventUrl != nil ? " url: \(eventUrl?.absoluteString ?? "")" : ""
    print("track::Event with Category: \"\(event.category)\", Action: \"\(event.action)\"\(actionNameInfo)\(urlInfo)")
    self.matomoTracker.track(eventWithCategory: event.category,
                             action: event.action,
                             name: actionName?.rawValue,
                             number: nil,
                             url: eventUrl ?? currentScreenUrl)
    if uevt.usageEvent.category == uEvt.Categories.user.rawValue {
      startNewSession()
    }
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
    print("track::Screen: " + (currentScreen ?? []).joined(separator: "/") + url)
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
    if let sfvc = self as? SubscriptionFormController,
       sfvc.ui.formType == .expiredDigiPrint || sfvc.ui.formType == .expiredDigiSubscription {
         self.trackEvent(uEvt.dialog(.SubscriptionElapsed))
       }
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
  public static func track(_ uevt: uEvt, actionName: uEvt.ActionName? = nil, eventUrlString: String? = nil){
    ensureBackground{ Usage.sharedInstance.trackEvent(uevt, actionName: actionName, eventUrlString: eventUrlString) }
  }
  public static func trackScreen(path: [String]?){
    ensureBackground{ Usage.sharedInstance.trackScreen(path) }
  }
}

class TazIntroVC: IntroVC, UsageTracker {
  var path:[String]? { return ["webview", self.webView.webView.url?.lastPathComponent ?? "-" ]}
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    trackScreen()
  }
}
