//
//  IssueVC.swift
//
//  Created by Norbert Thies on 17.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public class IssueVC: IssueVcWithBottomTiles, IssueInfo {
  
  /// The Feeder providing data (from delegate)
  public var gqlFeeder: GqlFeeder { return feederContext.gqlFeeder }  
  /// The Feed to display
  public var feed: Feed { return feederContext.defaultFeed }
  /// Selected Issue to display
  public var issue: Issue { issues[index] }

  /// The FeederContext providing the Feeder and default Feed
  public var feederContext: FeederContext
  
  /// The IssueCarousel showing the available Issues
  public var issueCarousel = IssueCarousel()
  /// The currently available Issues to show
  ///public var issues: [Issue] = [] ///moved to parent
  /// The center Issue (index into self.issues)
  public var index: Int { issueCarousel.index! }
  /// The Section view controller
  public var sectionVC: SectionVC?
  /// Is Issue Download in progress?
  public var isDownloading: Bool = false
  /// Issue Moments to download
  public var issueMoments: [Issue]? 
  
  /// Scroll direction (from config defaults)
  @DefaultBool(key: "carouselScrollFromLeft")
  public var carouselScrollFromLeft: Bool

  /// Perform carousel animations?
  static var showAnimations = true
  
  /// Light status bar because of black background
  override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
  
  /// Date of next Issue to center on
  private var selectedIssueDate: Date? = nil
  
  /// Reset list of Issues to the first (most current) one
  public func resetIssueList() {
    issueCarousel.index = 0
  }
  
  /// Reset list of Issues and carousel
  private func reset() {
    issues = [] 
    issueCarousel.reset()
  }
  
  /// Add Issue to carousel
  private func addIssue(issue: Issue) {
    if let img = feeder.momentImage(issue: issue, isPdf: isFacsimile) {
      var idx = 0
      for iss in issues {
        if iss.date == issue.date { return }
        if iss.date < issue.date { break }
        idx += 1
      }
      debug("inserting issue \(issue.date.isoDate()) at \(idx)")
      issues.insert(issue, at: idx)
      issueCarousel.insertIssue(img, at: idx)
      if let idx = issueCarousel.index { setLabel(idx: idx) }
      if let date = selectedIssueDate {
        if issue.date <= date { selectedIssueDate = nil }
//        else { issueCarousel.index = idx }
      }
    }
  }
  
  /// Move Carousel to certain Issue date (or next smaller)
  func moveTo(date: Date) {
    var idx = 0
    for iss in issues {
      if iss.date == date { return }
      if iss.date < issue.date { break }
      idx += 1
    }    
  }
  
  /// Inspect download Error and show it to user
  func handleDownloadError(error: Error?) {
    // TODO: Handle Download Error
  }
  
  /// Requests sufficient overview Issues from DB/server at
  /// a given date
  private func provideOverview(at date: Date) {
    var from = date
    from.addDays(10)
    selectedIssueDate = date
    reset()
    feederContext.getOvwIssues(feed: feed, count: 21, fromDate: from)
  }

  /// Requests sufficient overview Issues from DB/server
  private func provideOverview() {
    let n = issues.count
    if n > 0 {
      if (n - index) < 6 { 
        var last = issues.last!.date
        last.addDays(-1)
        feederContext.getOvwIssues(feed: feed, count: 10, fromDate: last)
      }
      if index < 6 {
        var date = issues.first!.date
        let first = UsTime(date)
        let now = UsTime.now()
        let secPerDay: Int64 = 3600*24
        let ndays = (now.sec - first.sec) / secPerDay
        if ndays > 10 { 
          date.addDays(10)
          feederContext.getOvwIssues(feed: feed, count: 10, fromDate: date)
        }
        else if ndays > 1 {
          date.addDays(-Int(ndays+1))
          feederContext.getOvwIssues(feed: feed, count: Int(ndays + 1), 
                                     fromDate: date)
        }
      }
    }
    else { feederContext.getOvwIssues(feed: feed, count: 20) }
  }
  
  /// Empty overview array and request new overview
  private func resetOverview() {
    self.issues = []
    provideOverview()
  }
  
  /// Look for newer issues on the server
  private func checkForNewIssues() {
    if issues.count > 0 {
      let now = UsTime.now()
      let latestLoaded = UsTime(issues[0].date)
      let nHours = (now.sec - latestLoaded.sec) / 3600
      if nHours > 6 {
        let ndays = (now.sec - latestLoaded.sec) / (3600*24) + 1
        feederContext.getOvwIssues(feed: feed, count: Int(ndays))
      }
    }
    else { feederContext.getOvwIssues(feed: feed, count: 20) }
  }  
  
  /// Download one section
  private func downloadSection(section: Section, closure: @escaping (Error?)->()) {
    dloader.downloadSection(issue: self.issue, section: section) { [weak self] err in
      if err != nil { self?.debug("Section \(section.html.name) DL Errors: last = \(err!)") }
      else { self?.debug("Section \(section.html.name) DL complete") }
      closure(err)
    }   
  }
  
  /// Setup SectionVC and push it onto the VC stack
  private func pushSectionVC(feederContext: FeederContext, atSection: Int? = nil,
                             atArticle: Int? = nil) {
    sectionVC = SectionVC(feederContext: feederContext, atSection: atSection,
                          atArticle: atArticle)
    if let svc = sectionVC {
      svc.delegate = self
      self.navigationController?.pushViewController(svc, animated: false)
    }
  }
  
  /// Show Issue at a given index, download if necessary
  func showIssue(index givenIndex: Int? = nil, atSection: Int? = nil, 
                         atArticle: Int? = nil) {
    let index = givenIndex ?? self.index
    func openIssue() {
      if isFacsimile {
        #warning("@Ringo: push PDF page controller here")
      }
      else {
        self.pushSectionVC(feederContext: feederContext, atSection: atSection, 
                           atArticle: atArticle)
      }
    }
    guard index >= 0 && index < issues.count else { return }
    let issue = issues[index]
    debug("*** Action: Entering \(issue.feed.name)-" +
      "\(issue.date.isoDate(tz: feeder.timeZone))")
    if let sissue = issue as? StoredIssue, !isDownloading {
      guard feederContext.needsUpdate(issue: sissue) else { openIssue(); return }
      isDownloading = true
      issueCarousel.index = index
      issueCarousel.setActivity(idx: index, isActivity: true)
      Notification.receiveOnce("issueStructure", from: sissue) { [weak self] notif in
        guard let self = self else { return }
        guard notif.error == nil else { 
          self.handleDownloadError(error: notif.error!)
          return 
        }
        self.downloadSection(section: sissue.sections![0]) { [weak self] err in
          guard let self = self else { return }
          self.isDownloading = false
          guard err == nil else { self.handleDownloadError(error: err); return }
          openIssue()
          Notification.receiveOnce("issue", from: sissue) { [weak self] notif in
            guard let self = self else { return }
            if let err = notif.error { 
              self.handleDownloadError(error: err)
              self.error("Issue \(sissue.date.isoDate()) DL Errors: last = \(err)")
            }
            else {
              self.debug("Issue \(sissue.date.isoDate()) DL complete")
              self.setLabel(idx: index)
            }
            self.issueCarousel.setActivity(idx: index, isActivity: false)
          }
        }
      }
      self.feederContext.getCompleteIssue(issue: sissue, isPages: isFacsimile)        
    }
  }
  
  // last index displayed
  fileprivate var lastIndex: Int?
 
  private func setLabel(idx: Int, isRotate: Bool = false) {
    guard idx >= 0 && idx < self.issues.count else { return }
    let issue = self.issues[idx]
    var sdate = issue.date.gLowerDate(tz: self.feeder.timeZone)
    if !issue.isComplete { sdate += " \u{2601}" }
    if isRotate {
      if let last = self.lastIndex, last != idx {
        self.issueCarousel.setText(sdate, isUp: idx > last)
      }
      else { self.issueCarousel.pureText = sdate }
      self.lastIndex = idx
    }
    else { self.issueCarousel.pureText = sdate }
  } 
  
  private func exportMoment(issue: Issue) {
    if let fn = feeder.momentImageName(issue: issue, isCredited: true) {
      let file = File(fn)
      let ext = file.extname
      let dialogue = ExportDialogue<Any>()
      let name = "\(issue.feed.name)-\(issue.date.isoDate(tz: self.feeder.timeZone)).\(ext)"
      dialogue.present(item: file.url, subject: name)
    }
  }
  
  private func deleteIssue() {
    if let issue = issue as? StoredIssue {
      issue.reduceToOverview()
      setLabel(idx: index)
    }
  }
  
  /// Check whether it's necessary to reload the current Issue
  public func checkReload() {
    if let visible = navigationController?.visibleViewController,
       let sissue = issue as? StoredIssue {
      if (visible != self) && feederContext.needsUpdate(issue: sissue) {
        let snap = NavigationController.top()?.presentingViewController?.view.snapshotView(afterScreenUpdates: false)
        WaitingAppOverlay.show(alpha: 1.0,
                               backbround: snap,
                               showSpinner: true,
                               titleMessage: "Aktualisiere Daten",
                               bottomMessage: "Bitte haben Sie einen Moment Geduld!",
                               dismissNotification: Const.NotificationNames.articleLoaded)
        navigationController!.popToRootViewController(animated: true)
        showIssue(index: index, atSection: sissue.lastSection, 
                  atArticle: sissue.lastArticle)
      }
      else {
        print(">>>> IssueVC.checkReload .. do not show Overlay because: visible != self \(visible != self) OR: feederContext.needsUpdate(issue: sissue): \(feederContext.needsUpdate(issue: sissue)) because is still Downloading? sissue.isDownloading: \(sissue.isDownloading)")
      }
    }
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.headerView.addSubview(issueCarousel)
    pin(issueCarousel.top, to: self.headerView.top)
    pin(issueCarousel.left, to: self.headerView.left)
    pin(issueCarousel.right, to: self.headerView.right)
    pin(issueCarousel.bottom, to: self.headerView.bottom, dist: -(bottomOffset+UIWindow.bottomInset))
    issueCarousel.carousel.scrollFromLeftToRight = carouselScrollFromLeft
    issueCarousel.onTap { [weak self] idx in
      self?.showIssue(index: idx, atSection: self?.issue.lastSection, 
                      atArticle: self?.issue.lastArticle)
    }
    issueCarousel.onLabelTap { idx in
      self.showDatePicker()
    }
    issueCarousel.addMenuItem(title: "Bild Teilen", icon: "square.and.arrow.up") { title in
      self.exportMoment(issue: self.issue)
    }
    issueCarousel.addMenuItem(title: "Ausgabe löschen", icon: "trash") {_ in
      self.deleteIssue()
    }
    var scrollChange = false
    issueCarousel.addMenuItem(title: "Scrollrichtung umkehren", icon: "repeat") { title in
      self.issueCarousel.carousel.scrollFromLeftToRight =
        !self.issueCarousel.carousel.scrollFromLeftToRight
      scrollChange = true
      self.carouselScrollFromLeft = self.issueCarousel.carousel.scrollFromLeftToRight
      scrollChange = false
    }
    Defaults.receive() { dnot in
      if !scrollChange && dnot.key == "carouselScrollFromLeft" {
        self.issueCarousel.carousel.scrollFromLeftToRight = self.carouselScrollFromLeft
      }
    }
    
    issueCarousel.iosHigher13?.addMenuItem(title: "Abbrechen", icon: "xmark.circle") {_ in}
    issueCarousel.carousel.onDisplay { [weak self] (idx, om) in
      guard let self = self else { return }
      self.setLabel(idx: idx, isRotate: true)
      if IssueVC.showAnimations {
        IssueVC.showAnimations = false
        //self.issueCarousel.showAnimations()
      }
      self.provideOverview()
    }
    Notification.receive("authenticationSucceeded") { notif in
      self.checkReload()
    }
    Notification.receive(UIApplication.willResignActiveNotification) { _ in
      self.goingBackground()
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { _ in
      self.goingForeground()
    }
    //checkForNewIssues()
  }
  
  var pickerCtrl : MonthPickerController?
  var overlay : Overlay?
  func showDatePicker(){
    let fromDate = feed.firstIssue
    let toDate = feed.lastIssue
    
    if pickerCtrl == nil {
      pickerCtrl = MonthPickerController(minimumDate: fromDate,
                                         maximumDate: toDate,
                                         selectedDate: toDate)
    }
    guard let pickerCtrl = pickerCtrl else { return }
    
    if overlay == nil {
      overlay = Overlay(overlay:pickerCtrl , into: self)
      overlay?.enablePinchAndPan = false
      overlay?.maxAlpha = 0.0
    }
        
    pickerCtrl.doneHandler = {
      self.overlay?.close(animated: true)
//      self.provideOverview(at: pickerCtrl.selectedDate)
      let dstr = pickerCtrl.selectedDate.gMonthYear(tz: self.feeder.timeZone)
      Alert.message(title: "Baustelle",
        message: "Hier werden später die Ausgaben ab \"\(dstr)\" angezeigt.")
    }
    overlay?.openAnimated(fromView: issueCarousel.label, toView: pickerCtrl.content)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    checkForNewIssues()
  }
  
  @objc private func goingBackground() {}
  
  @objc private func goingForeground() {
    checkForNewIssues()
  }
  
  /// Initialize with FeederContext
  public init(feederContext: FeederContext) {
    self.feederContext = feederContext
    super.init()
    Notification.receive("issueOverview") { [weak self] notif in 
      if let err = notif.error { self?.handleDownloadError(error: err) }
      else { self?.addIssue(issue: notif.content as! Issue) }
    }
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
    
} // IssueVC
