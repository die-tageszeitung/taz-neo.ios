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

public class Usage: NSObject, DoesLog{
  
  @Default("usageTrackingCurrentVersion")
  fileprivate var usageTrackingCurrentVersion: String
  
  @Default("usageTrackingAllowed")
  fileprivate var usageTrackingAllowed: Bool
  
  fileprivate let matomoTracker = MatomoTracker(siteId: "116",
                                    baseURL: URL(string: "https://gazpacho.taz.de/matomo.php")!)
  
  static let shared = Usage()
  
  fileprivate var enterBackground: Date?
  fileprivate var currentScreenTitle:String?
  fileprivate var currentScreenUrl:URL?
  
  
  ///use to remove onDisplay handler
  fileprivate var lastPageCollectionVConDosplayClosureKey:String?
  ///remember last PageCollectionVC, to handle onDisplay change due swipe
  fileprivate var lastPageCollectionVC:PageCollectionVC? {
    didSet {
      if let key = lastPageCollectionVConDosplayClosureKey {
        oldValue?.removeOnDisplay(forKey: key)
        lastPageCollectionVConDosplayClosureKey = nil
      }
      lastPageCollectionVConDosplayClosureKey
      = lastPageCollectionVC?.onDisplay(closure: { [weak self] _, _ in
        guard let usageVc = self?.lastPageCollectionVC as? ScreenTracking else { return }
        usageVc.trackScreen()
      })
    }
  }
  
  override init() {
    super.init()
    trackInstallationIfNeeded()
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
      self?.trackEvent(art.hasBookmark ? event.bookmarks.AddArticle : event.bookmarks.RemoveArticle)
    }
    
    $usageTrackingAllowed.onChange{[weak self] _ in
      self?.matomoTracker.isOptedOut = self?.usageTrackingAllowed != true
    }
  }
}

// MARK: - fileprivate Global Events
fileprivate extension Usage {
  func startNewSession(){
    debug("track::NEW SESSIONSTART")
    matomoTracker.startNewSession()
    trackAuthStatus()
    trackSubscriptionStatusIfNeeded(isChange: false)
  }
  
  func goingForeground() {
    ///Start a new Session after App was in BAckground for 2 hours == 60*120
    if let bg = enterBackground, Date().timeIntervalSince(bg) > 60*120 {
      startNewSession()
    }
    trackCurrentScreen()
  }
  
  func goingBackground() {
    trackEvent(event.system.ApplicationMinimize)
    enterBackground = Date()
    matomoTracker.dispatch()
  }
  func appWillTerminate() {
    matomoTracker.dispatch()
  }
}

// MARK: - fileprivate Tracking Helper
fileprivate extension Usage {
  func trackSubscriptionStatusIfNeeded(isChange: Bool) {
    if Defaults.expiredAccount {
      trackEvent(Usage.event.subscriptionStatus.Elapsed)
    }
    else if isChange {
      trackEvent(Usage.event.subscriptionStatus.SubcriptionRenewed)
    }
  }
  
  func trackInstallationIfNeeded() {
    if usageTrackingCurrentVersion != App.bundleVersion {
      usageTrackingCurrentVersion = App.bundleVersion
      let downloadEvent = Self.event.application.downloaded
      self.matomoTracker.track(eventWithCategory: downloadEvent.category,
                               action: downloadEvent.action,
                               name: nil,
                               number: nil,
                               url:  URL(path: usageTrackingCurrentVersion))
    }
  }
  
  func trackAuthStatus() {
    TazAppEnvironment.isAuthenticated
    ? trackEvent(Usage.event.authenticationStatus.Authenticated)
    : trackEvent(Usage.event.authenticationStatus.Anonymous)
  }
  
  func trackEvent(_ event: any TrackingEvent, name: String? = nil){
    trackEvent(category: event.category,
               action: event.action,
               name: name,
               finishSession: event.finishSession)
  }
  
  func trackEvent(category: String,
                          action: String,
                          name: String? = nil,
                          dimensions: [CustomDimension]? = nil,
                          finishSession:Bool = false){
    var info = ""
    if let name = name { info += " name: \(name)"}
    if dimensions?.isEmpty == false { info += " customDimensions: [" }
    for dim in dimensions ?? [] {
      info += "\(dim), "
    }
    if dimensions?.isEmpty == false { info.removeLast(2);  info += "]" }
    debug("track::Event with Category: \"\(category)\", Action: \"\(action)\"\(info)")
    if let dim = dimensions {
      self.matomoTracker.track(eventWithCategory: category,
                               action: action,
                               name: name,
                               dimensions: dim)
    }
    else {
      self.matomoTracker.track(eventWithCategory: category,
                               action: action,
                               name: name,
                               number: nil,
                               url: nil)
    }
    
    if finishSession {
      matomoTracker.dispatch()
      startNewSession()
    }
  }
  
  static func trackEvent(category: String,
                         action: String,
                         name: String? = nil,
                         dimensions: [CustomDimension]? = nil,
                         finishSession:Bool = false){
    if shared.usageTrackingAllowed == false { return }
    ensureBackground { Usage.shared.trackEvent(category: category,
                                               action: action,
                                               name: name,
                                               dimensions: dimensions,
                                               finishSession: finishSession)
    }
  }
}

// MARK: - Tracking Public Accessors
extension Usage {
  static func track(_ event: any TrackingEvent, name: String? = nil){
    if shared.usageTrackingAllowed == false { return }
    ensureBackground {
      Usage.shared.trackEvent(event, name: name)
    }
  }
  
  static func track(screen: DefaultScreen){
    guard let title = screen.title,
          let url = screen.url else {
      shared.debug("track::Screen title or url is not available for \(screen)")
      return
    }
    track(screenTitle: title, url: url)
  }
  
  static func track(screenTitle: String, url: URL){
    shared.currentScreenTitle = screenTitle
    shared.currentScreenUrl = url
    ensureBackground {
      Usage.shared.trackCurrentScreen()
    }
  }
  
  // MARK: Internal Screen Tracking
  private func trackCurrentScreen(){
    if usageTrackingAllowed == false { return }
    guard let currentScreenTitle = currentScreenTitle else  { return }
    debug("track::Screen: \(currentScreenTitle) url: \(currentScreenUrl?.absoluteString ?? "-")")
    matomoTracker.track(view: [currentScreenTitle], url: currentScreenUrl)
  }
}

// MARK: - extension NavigationDelegate: magic tracking on VC Dismiss
extension Usage: NavigationDelegate {
  public func popViewController(){
    Usage.track(Usage.event.system.NavigationBack)
  }
}

// MARK: - extension UINavigationControllerDelegate: magic tracking on VC show
extension Usage: UINavigationControllerDelegate {
  public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
    guard let usageVc = viewController as? ScreenTracking else {
      debug("track::NOT track Screen: current visible vc: \(viewController) is not prepared for tracking!")
      return
    }
    if let pcvc = usageVc as? PageCollectionVC {
      lastPageCollectionVC = pcvc
    }
    usageVc.trackScreen()
  }
}

// MARK: Tracking Consts :: Screens and Events
extension Usage {
   public enum DefaultScreen: String, CodableEnum {
    case CoverflowMobile = "Coverflow Mobile",
         CoverflowPDF = "Coverflow PDF",
         ArchiveMobile = "Archive Mobile",
         ArchivePDF = "Archive PDF",
         BookmarksList = "Bookmarks List",
         BookmarksEmpty = "Bookmarks Empty",
         Search = "Search",
         Settings = "Settings",
         ErrorReport = "Error Report",
         FeedbackReport = "Feedback",
         FatalError = "Fatal Error",
         Login = "Login",
         SubscriptionSwitchToDigiabo = "Subscription Switch To Digiabo",
         SubscriptionExtendWithDigiabo = "Subscription Extend With Digiabo",
         SubscriptionTrialInfo = "Subscription Trial Info",
         SubscriptionTrialElapsedInfo = "Subscription Trial Elapsed Info",
         SubscriptionElapsedInfo = "Subscription Elapsed Info",
         SubscriptionAccountLoginCreate = "Subscription Account Login/Create",
         Terms = "Terms",
         DataPolicy = "Data Policy",
         Revocation = "Revocation",
         WelcomeSlides = "Welcome Slides",
         ForgotPassword = "Forgot Password",
         SearchHelp = "SearchHelp"
    var url: URL? {
      switch self {
        case .CoverflowMobile: return URL(string: "/home/coverflow/mobile")
        case .CoverflowPDF: return URL(string: "/home/coverflow/pdf")
        case .ArchiveMobile: return URL(string: "/home/archive/mobile")
        case .ArchivePDF: return URL(string: "/home/archive/pdf")
        case .BookmarksList: return URL(string: "/bookmarks/list")
        case .BookmarksEmpty: return URL(string: "/bookmarks/empty")
        case .Search: return URL(string: "/search")
        case .Settings: return URL(string: "/settings")
        case .ErrorReport: return URL(string: "/error_report")
        case .FeedbackReport: return URL(string: "/feedback")
        case .FatalError: return URL(string: "/error_fatal")
        case .Login: return URL(string: "/login")
        case .SubscriptionSwitchToDigiabo: return URL(string: "/subscription/switch")
        case .SubscriptionExtendWithDigiabo: return URL(string: "/subscription/extend")
        case .SubscriptionTrialInfo: return URL(string: "/subscription/trial_info")
        case .SubscriptionTrialElapsedInfo: return URL(string: "/subscription/trial_elapsed")
        case .SubscriptionElapsedInfo: return URL(string: "/subscription/elapsed")
        case .SubscriptionAccountLoginCreate: return URL(string: "/subscription/account_login")
        case .DataPolicy: return URL(string: "/data_policy")
        case .Terms: return URL(string: "/terms")
        case .Revocation: return URL(string: "/revocation")
        case .WelcomeSlides: return URL(string: "/welcome_slides")
        case .ForgotPassword: return URL(string: "/forgot_password")
        case .SearchHelp: return URL(string: "/search/help")
      }
    }
    var title: String? { return self.rawValue }
  }
  public struct event {
    enum application: String, TrackingEvent {
      var category: String { "Application" }
      case downloaded = "Downloaded"
    }
    enum appMode: String, TrackingEvent {
      var category: String { "AppMode" }
      case SwitchToMobileMode = "Switch to Mobile Mode",
           SwitchToPDFMode = "Switch to PDF Mode"
    }
    enum audio: String, TrackingEvent {
      var category: String { "Audio Player" }
      case PlayArticle = "Play Article",
           ChangePlaySpeed = "Change Play Speed",
           InitialPlaySpeed = "Initial Play Speed",
           Maximize = "Maximize",
           Minimize = "Minimize",
           OpenArticle = "Open Article",
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
    enum authenticationStatus: String, TrackingEvent {
      var category: String { "Authentication Status" }
      case Authenticated = "State Authenticated",
           Anonymous = "State Anonymous"
    }
    enum bookmarks: String, TrackingEvent {
      var category: String { "Bookmarks" }
      case AddArticle = "Add Article",
           RemoveArticle = "Remove Article"
    }
//    enum coachmark: String, TrackingEvent {
//      var category: String { "Coachmark" }
//      case slider = "Slider"
//    }
    enum dialog: String, TrackingEvent {
      var category: String { "Dialog" }
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
    struct drawer {
      enum action_open: String, TrackingEvent {
        var category: String { "Drawer" }
        var action: String { "Open" }
        case Open = "Open"
      }
      enum action_tap: String, TrackingEvent {
        var category: String { "Drawer" }
        var action: String { "Tap" }
        case Page = "Tap Page",
             Section = "Tap Section",
             Article = "Tap Article",
             Imprint = "Tap Imprint",
             Moment = "Tap Moment",
             Bookmark = "Tap Bookmark",
             PlayIssue = "Tap Play Issue"
      }
      enum action_toggle: String, TrackingEvent{
        var action: String { "Toggle" }
        var category: String { "Drawer" }
        case Section = "Toggle Section",
             AllSections = "Toggle all Sections"
      }
    }
    enum share: String, TrackingEvent {
      var name: String { "Share" }
      var category: String { "Share" }
      case Article = "Share Article",
           SearchHit = "Share SearchHit",
           FaksimilelePage = "Faksimilele Page",
           IssueMoment = "Issue Moment"
    }
    enum subscription: String, TrackingEvent {
      var category: String { "Subscription" }
      case InquirySubmitted = "Inquiry Submitted",
           InquiryFormValidationError = "Inquiry Form Validation Error",
           InquiryServerError = "Inquiry Server Error",
           InquiryNetworkError = "Inquiry Network Error",
           TrialConfirmed = "Trial Confirmed"
    }
    enum subscriptionStatus: String, TrackingEvent {
      var category: String { "Subscription Status" }
      case Elapsed = "Elapsed",
           SubcriptionRenewed = "Subcription Renewed"
    }
    enum system: String, TrackingEvent {
      var category: String { "System" }
      case ApplicationMinimize = "Application Minimize",
           NavigationBack = "Navigation Back"
    }
    enum user: String, TrackingEvent {
      var category: String { "User" }
      case Login = "Login",
           Logout = "Logout"
    }
  }
}

// MARK: Enum Helper for Events
protocol TrackingEvent: CodableEnum { var category: String { get } }
extension TrackingEvent {
  var action: String { rawValue }
  var finishSession:Bool { return self is Usage.event.user }
}

// MARK: Tracking Helper for complex Tracking Events
extension Usage {
  struct xtrack {
    struct share {
      static func article(content: Content?){
        let evt = Usage.event.share.Article
        trackEvent(category: evt.category,
                          action: evt.action,
                          name: content?.trackingPath,
                          dimensions: content?.customDimensions)
      }
      static func searchHit(content: Content?){
        let evt = Usage.event.share.SearchHit
        trackEvent(category: evt.category,
                          action: evt.action,
                          name: content?.trackingPath,
                          dimensions: content?.customDimensions)
      }
      static func faksimilelePage(issue: Issue, pagina: String){
        let evt = Usage.event.share.SearchHit
        trackEvent(category: evt.category,
                          action: evt.action,
                          name: issue.trackingNamePathId+"/pdf/\(pagina)")
      }
      static func issueMoment(_ issue: Issue){
        let evt = Usage.event.share.SearchHit
        trackEvent(category: evt.category,
                   action: evt.action,
                   name: issue.trackingNamePathId)
      }
    }
    struct audio {
      static func play(content: Content?){
        let evt = Usage.event.audio.PlayArticle
        trackEvent(category: evt.category,
                          action: evt.action,
                          name: content?.trackingPath,
                          dimensions: content?.customDimensions)
      }
      static func changePlaySpeed(ratio: Double){
        let evt = Usage.event.audio.ChangePlaySpeed
        trackEvent(category: evt.category,
                          action: evt.action,
                          name: "\(ratio)")
      }
      static func setInitialPlaySpeed(ratio: Double){
        let evt = Usage.event.audio.InitialPlaySpeed
        trackEvent(category: evt.category,
                          action: evt.action,
                          name: "\(ratio)")
      }
      static func maximize(){
        let evt = Usage.event.audio.Maximize
        trackEvent(category: evt.category,
                          action: evt.action)
      }
      static func minimize(){
        let evt = Usage.event.audio.Minimize
        trackEvent(category: evt.category,
                          action: evt.action)
      }
      static func openArticle(content: Content?){
        let evt = Usage.event.audio.OpenArticle
        trackEvent(category: evt.category,
                          action: evt.action,
                          name: content?.trackingPath,
                          dimensions: content?.customDimensions)
      }
      static func close(){
        let evt = Usage.event.audio.Close
        trackEvent(category: evt.category,
                          action: evt.action)
      }
      struct skip {
        static func Next(){
          let evt = Usage.event.audio.SkipNext
          trackEvent(category: evt.category,
                            action: evt.action)
        }
        static func Previous(){
          let evt = Usage.event.audio.SkipPrevious
          trackEvent(category: evt.category,
                            action: evt.action)
        }
      }
      static func seek(direction: seekOption.direction, source: seekOption.source){
        trackEvent(category: direction.Action.category,
                          action: direction.Action.rawValue,
                          name: source.rawValue)
      }
      struct seekOption {
        enum direction { 
          case forward, backward
          var Action: Usage.event.audio {
            switch self {
              case .forward: return .SeekForward
              case .backward: return .SeekBackward
            }
          }
        }
        enum source: String, CodableEnum {
          case fifteenSeconds = "15 Seconds",
               nextBreak = "Break",
               skipButtonAppUI = "Skip Button Down: AppUI",
               skipButtonSystem = "Skip Button Down: SystemControl"
        }
      }
      static func seekToposition(){
        let evt = Usage.event.audio.SeekPosition
        trackEvent(category: evt.category,
                          action: evt.action)
      }
      static func resume(){
        let evt = Usage.event.audio.Resume
        trackEvent(category: evt.category,
                          action: evt.action)
      }
      static func pause(){
        let evt = Usage.event.audio.Pause
        trackEvent(category: evt.category,
                          action: evt.action)
      }
      static func autoPlayNext(enable: Bool){
        let evt = enable ? Usage.event.audio.EnableAutoPlayNext
        : Usage.event.audio.DisableAutoPlayNext
        trackEvent(category: evt.category,
                          action: evt.action)
      }
    }
  }
}

// MARK: - Screen Tracking with ViewController magic
protocol DefaultScreenTracking: ScreenTracking where Self: UIViewController {
  var defaultScreen: Usage.DefaultScreen? { get }
}

extension DefaultScreenTracking {
  public var screenUrl:URL? { defaultScreen?.url }
  public var screenTitle:String? { defaultScreen?.title }
}

public protocol ScreenTracking where Self: UIViewController {
  var screenUrl:URL? { get }
  var screenTitle:String? { get }
  var customDimension: [CustomDimension]? { get }
}

public extension ScreenTracking {
  var customDimension: [CustomDimension]? { nil }//Default Implementation
  func trackScreen(){
    guard let screenUrl = screenUrl else {
      debug("track::Current Class did not implement screenUrl correctly")
      return
    }
    guard let screenTitle = screenTitle else {
      debug("track::Current Class did not implement screenTitle correctly")
      return
    }
    Usage.track(screenTitle: screenTitle, url: screenUrl)
  }
}

// MARK: -

// MARK: - Screen Tracking for Individuell Controller
extension HomeTVC: DefaultScreenTracking {
  public var defaultScreen: Usage.DefaultScreen? {
    switch (wasUp, isFacsimile) {
      case (true, true): return .CoverflowPDF
      case (true, false): return .CoverflowMobile
      case (false, true): return .ArchivePDF
      case (false, false): return .ArchiveMobile
    }
  }
}

// MARK: ...SearchController
extension SearchController: DefaultScreenTracking {
  public var defaultScreen: Usage.DefaultScreen? { .Search }
}
// MARK: ...SettingsVC
extension SettingsVC: DefaultScreenTracking {
  public var defaultScreen: Usage.DefaultScreen? { .Settings }
}

//TazPdfPagesViewController

// MARK: ...for FormsController
extension FormsResultController: DefaultScreenTracking {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    trackScreen()
  }
  
  public var defaultScreen: Usage.DefaultScreen? {
    switch self {
    case let sfc as SubscriptionFormController:
        return sfc.ui.formType.defaultScreen
      case is LoginController: return .Login
      case is PwForgottController: return .ForgotPassword
      case is TrialSubscriptionController: return .SubscriptionAccountLoginCreate
      default:return nil
    }
  }
}


// MARK: ...for MetaPages / TazIntroVC
class TazIntroVC: IntroVC, DefaultScreenTracking {
  var defaultScreen: Usage.DefaultScreen? {
    guard let html = self.webView.webView.url?.lastPathComponent else { return nil }
    switch html {
      case Const.Filename.dataPolicy: return .DataPolicy
      case Const.Filename.terms: return .Terms
      case Const.Filename.revocation: return .Revocation
      case Const.Filename.welcomeSlides: return .WelcomeSlides
      case "searchHelp.html": return .SearchHelp
      default: return nil
    }
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    trackScreen()
  }
}

extension SectionVC: ScreenTracking {
  public var screenUrl:URL? {
    guard let trackingPath = section?.trackingPath else { return nil }
    return URL(path: "issue/\(self.feederContext.feedName)/\(self.issue.date.ISO8601)/\(trackingPath)")
  }
  public var screenTitle:String? {
    section?.title
  }
}

extension ArticleVC: ScreenTracking {
  public var screenUrl:URL? {
    guard let article = article,
          let artFileName = article.html?.name,
          let artPath = article.trackingPath,
    let sectionFileName = adelegate?.article2section[artFileName]?.first?.html?.name
    else { return nil }
    return URL(path: "issue/\(self.feederContext.feedName)/\(self.issue.date.ISO8601)/section/\(sectionFileName)/\(artPath)",
               id: article.serverId)
  }
  public var screenTitle:String? {
    article?.title
  }
}

// MARK: -

// MARK: - Helper

// MARK: -

// MARK: ...Content
extension Content{
  var customDimensions: [CustomDimension]? {
    guard let art = self as? Article else { return nil }
    var dim = art.articleType?.customDimension ?? []
    if let ol = art.onlineLink {
      dim.append(CustomDimension(index: 1, value: ol))
    }
    return dim
  }
  
  var trackingPath: String? {
    if let sect = self as? Section, let name = sect.html?.name {
      return "section/\(name)"
    }
    else if let art = self as? Article, let name = art.html?.name {
      return "article/\(name)"
    }
    return nil
  }
}

// MARK: ...for Forms Controller
fileprivate extension SubscriptionFormDataType {
  var defaultScreen: Usage.DefaultScreen {
    switch self {
      case .expiredDigiPrint: return .SubscriptionElapsedInfo//not tested currently
      case .expiredDigiSubscription: return .SubscriptionTrialElapsedInfo
      case .print2Digi: return .SubscriptionSwitchToDigiabo
      case .printPlusDigi: return .SubscriptionExtendWithDigiabo
      case .trialSubscription: return .SubscriptionAccountLoginCreate//unused here!
    }
  }
}

// MARK: ...Article.ArticleType
fileprivate extension ArticleType {
  var customDimension: [CustomDimension] {[CustomDimension(index: 0, value: self.rawValue)] }
}

// MARK: ...Issue
fileprivate extension Issue {
  var trackingNamePathId: String { "/issue/\(self.feed.name)/\(self.date.ISO8601)" }
}
// MARK: ...URL
extension URL {
  /// Creates app url with given path params
  /// - Parameters:
  ///   - path: relative path
  ///   - params: additional params
  public init?(path: String, id: Int? = nil){
    let str = id == nil ? path : "\(path)?id=\(id ?? -1)"
    self.init(string:"\(AppDomain.id)/\(str)")
  }
}
// MARK: ...URL/Host
fileprivate struct AppDomain { static let id = "http://app.taz.de" }
