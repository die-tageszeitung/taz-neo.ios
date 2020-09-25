//
//  IssueVC.swift
//
//  Created by Norbert Thies on 17.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib


/// The protocol used to communicate with calling VCs
public protocol IssueVCdelegate {
  var gqlFeeder: GqlFeeder { get }
  var feed: Feed { get }
  var dloader: Downloader { get }
  var ovwIssues: [Issue]? { get }
  var pushToken: String? { get }
}

public class IssueVC: UIViewController, IssueInfo {
  
  /// The Feeder providing data (from delegate)
  public var gqlFeeder: GqlFeeder { return delegate.gqlFeeder }  
  public var feeder: Feeder { return delegate.gqlFeeder }  
  /// The Feed to display
  public var feed: Feed { return delegate.feed }
  /// Selected Issue to display
  public var issue: Issue { issues[index] }
  /// Downloader from delegate
  public var dloader: Downloader { return delegate.dloader }  
  /// The delegate providing the Feeder and default Feed
  public var delegate: IssueVCdelegate!
  
  /// The IssueCarousel showing the available Issues
  public var issueCarousel = IssueCarousel()
  /// The currently available Issues to show
  public var issues: [Issue] = []
  /// The center Issue (index into self.issues)
  public var index: Int { issueCarousel.index! }
  /// The Section view controller
  public var sectionVC: SectionVC?
  /// Is Issue Download in progress?
  public var isDownloading: Bool = false
  /// Issue Moments to download
  public var issueMoments: [Issue]? 
  
  // The last Alert shown
  private var lastAlert: UIAlertController?
  
  // Is initial appearance
  private var isInitial = true
  
  /// Perform carousel animations?
  static var showAnimations = true
  
  /// Light status bar because of black background
  override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  private var serverDownloadId: String?
  private var serverDownloadStart: UsTime?
  
  /// Reset list of Issues to the first (most current) one
  public func resetIssueList() {
    issueCarousel.index = 0
  }
  
  /// Add moment image to carousel
  func addMoment(issue: Issue) {
    if let img = feeder.momentImage(issue: issue) {
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
    }
  }
  
  /// Inspect download Error and show it to user
  func handleDownloadError(error: Error?) {
    
  }
  
  /// Download Moment images from server if necessary
  func getMoments(_ newIssues: [Issue]) {
    guard issueMoments == nil else { return }
    issueMoments = newIssues    
    for issue in newIssues {
      dloader.downloadMoment(issue: issue) { [weak self] err in
        guard let self = self else { return }
        if err == nil { self.addMoment(issue: issue) }
        else { self.handleDownloadError(error: err) }
        if let idx = self.issueMoments?.firstIndex(where: 
          { $0.date == issue.date } ) {
          self.issueMoments?.remove(at: idx)
        }
        if self.issueMoments?.count == 0 { 
          self.issueMoments = nil 
          self.debug("\(newIssues.count) Moments downloaded")
        }
        
      }
    }
  }
  
  /// Issues received from server
  func issuesReceived(issues iss: [Issue]) {
    guard issueMoments == nil else { return }
    debug()
    // TODO: Check for stored Issues
    // TODO: store new issues in DB
    var newIssues = iss
    if issues.count > 0 {
      if issues.last!.date == newIssues.first!.date {
        newIssues.removeFirst()
      }
    }
    else { 
      issues = [] 
      issueCarousel.reset()
    }
    getMoments(newIssues)
  }
  
  func issuesReceived(result: Result<[Issue], Error>) {
    if let newIssues = result.value() { issuesReceived(issues: newIssues) }
    else {
      // TODO: handle Issue request error
    }
  }
  
  /// Request more Issues from server
  func getCurrentIssues() {
    if issues.count == 0 {
      gqlFeeder.issues(feed: feed, count: 20) { [weak self] res in
        self?.issuesReceived(result: res)
      }
    }
    else {
      if let lastDate = issues.last?.date {
        gqlFeeder.issues(feed: feed, date: lastDate, count: 20) 
        { [weak self] res in
          self?.issuesReceived(result: res)
        }
      }
    }
  }
  
  /// Look for newer issues on the server
  func checkForNewIssues() {
    guard issues.count > 0 else { return }
    let now = UsTime.now()
    let latestLoaded = UsTime(issues[0].date)
    let nHours = (now.sec - latestLoaded.sec) / 3600
    if nHours > 6 {
      let ndays = (now.sec - latestLoaded.sec) / (3600*24) + 1
      gqlFeeder.issues(feed: feed, count: Int(ndays)) { [weak self] res in
        if let newIssues = res.value() { self?.getMoments(newIssues) }
      }      
    }
  }
  
  /// Download one section
  func downloadSection(section: Section, closure: @escaping (Error?)->()) {
    dloader.downloadSection(issue: self.issue, section: section) { [weak self] err in
      if err != nil { self?.debug("Section DL Errors: last = \(err!)") }
      else { 
        self?.debug("Section DL complete") 
        self?.lastAlert?.dismiss(animated: false)
        self?.lastAlert = nil
      }
      closure(err)
    }   
  }
  
  /// Setup SectionVC and push it onto the VC stack
  func pushSectionVC() {
    sectionVC = SectionVC()
    if let svc = sectionVC {
      svc.delegate = self
      self.navigationController?.pushViewController(svc, animated: false)
      if IssueVC.showAnimations {
        delay(seconds: 1.5) {
          svc.slider.open() { _ in
            delay(seconds: 1.5) {
              svc.slider.close() { _ in
                svc.slider.blinkButton()
              }
            }
          }
        }
      }
    }
  }
  
  /// Tell server we are starting to download
  func markStartDownload(feed: Feed, issue: Issue) {
    let isPush = delegate.pushToken != nil
    debug("Sending start of download to server")
    self.gqlFeeder.startDownload(feed: feed, issue: issue, isPush: isPush) { [weak self] res in
      guard let self = self else { return }
      if let dlId = res.value() {
        self.serverDownloadId = dlId
        self.serverDownloadStart = UsTime.now()
      }
    }
  }
  
  /// Tell server we stopped downloading
  func markStopDownload() {
    if let dlId = self.serverDownloadId {
      let nsec = UsTime.now().timeInterval - self.serverDownloadStart!.timeInterval
      debug("Sending stop of download to server")
      self.gqlFeeder.stopDownload(dlId: dlId, seconds: nsec) {_ in}
      self.serverDownloadId = nil
      self.serverDownloadStart = nil
    }
  }
  
  /// Download Issue at index
  func downloadIssue(index: Int) {
    guard index >= 0 && index < issues.count else { return }
    let issue = issues[index]
    debug("*** Action: Entering \(issue.feed.name)-" +
          "\(issue.date.isoDate(tz: feeder.timeZone))")
    if issue.isComplete { self.pushSectionVC(); return }
    if index < issues.count && !isDownloading {
      isDownloading = true
      issueCarousel.index = index
      issueCarousel.setActivity(idx: index, isActivity: true)
      markStartDownload(feed: feed, issue: issue)
      downloadSection(section: issue.sections![0]) { [weak self] err in
        guard let self = self else { return }
        self.isDownloading = false
        if err != nil { 
          self.handleDownloadError(error: err)
          return
        }
        self.pushSectionVC()
        if !issue.isComplete { 
          delay(seconds: 2) { 
            self.dloader.downloadIssue(issue: issue) { [weak self] err in
              guard let self = self else { return }
              if err != nil { 
                self.error("Issue \(issue.date.isoDate()) DL Errors: last = \(err!)")
                self.handleDownloadError(error: err); 
                return 
              }
              else { 
                self.debug("Issue \(issue.date.isoDate()) DL complete")
                self.issueCarousel.setActivity(idx: index, isActivity: false)
                self.setLabel(idx: index)
                self.markStopDownload()
              }
            }
          }
        }
        else {
          self.issueCarousel.setActivity(idx: index, isActivity: false)
          self.setLabel(idx: index)
        }
      }
    }
  }
  
  // last index displayed
  fileprivate var lastIndex: Int?
 
  func setLabel(idx: Int, isRotate: Bool = false) {
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
  
  func exportMoment(issue: Issue) {
    if let fn = feeder.momentImageName(issue: issue, isCredited: true) {
      let file = File(fn)
      let ext = file.extname
      let dialogue = ExportDialogue<Any>()
      let name = "\(issue.feed.name)-\(issue.date.isoDate(tz: self.feeder.timeZone)).\(ext)"
      dialogue.present(item: file.url, subject: name)
    }
  }
  
  func deleteIssue() {
    let name = feeder.date2a(issue.date)
    let idir = feeder.issueDir(feed: feed.name, issue: name)
    let momentFiles = issue.moment.files.map { $0.name }
    let files = idir.contents()
    for f in files {
      if !momentFiles.contains(f) {
        print("rm \(f)")
        File("\(idir.path)/\(f)").remove()
      }
    }
    issue.isComplete = false
    setLabel(idx: index)
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    let dfl = Defaults.singleton
    view.backgroundColor = .black
    view.addSubview(issueCarousel)
    pin(issueCarousel.top, to: view.top)
    pin(issueCarousel.left, to: view.left)
    pin(issueCarousel.right, to: view.right)
    pin(issueCarousel.bottom, to: view.bottom, dist: -(80+UIWindow.bottomInset))
    issueCarousel.carousel.scrollFromLeftToRight = 
      dfl["carouselScrollFromLeft"]!.bool    
    issueCarousel.onTap { [weak self] idx in
      self?.downloadIssue(index: idx)
    }
    issueCarousel.onLabelTap { idx in
      if true /* SET TRUE TO USE DATEPICKER */ {
        self.showDatePicker()
        return;
      }
      Alert.message(title: "Baustelle", message: "Durch diesen Knopf wird später die Archivauswahl angezeigt")
    }
    issueCarousel.addMenuItem(title: "Bild Teilen", icon: "square.and.arrow.up") { title in
      self.exportMoment(issue: self.issue)
    }
    issueCarousel.addMenuItem(title: "Ausgabe löschen", icon: "trash") {_ in
      self.deleteIssue()
    }
    issueCarousel.addMenuItem(title: "Scrollrichtung umkehren", icon: "repeat") { title in
      self.issueCarousel.carousel.scrollFromLeftToRight = !self.issueCarousel.carousel.scrollFromLeftToRight
      dfl["carouselScrollFromLeft"] =
        self.issueCarousel.carousel.scrollFromLeftToRight ? "true" : "false"
    }
    
    issueCarousel.iosHigher13?.addMenuItem(title: "Abbrechen", icon: "xmark.circle") {_ in}
    issueCarousel.carousel.onDisplay { [weak self] (idx, om) in
      guard let self = self else { return }
      self.setLabel(idx: idx, isRotate: true)
      if IssueVC.showAnimations {
        IssueVC.showAnimations = false
        //self.issueCarousel.showAnimations()
      }
      if idx == (self.issueCarousel.carousel.count - 10) { self.getCurrentIssues() }
    }
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(goingBackground),
                   name: UIApplication.willResignActiveNotification, object: nil)
    nc.addObserver(self, selector: #selector(goingForeground),
                   name: UIApplication.willEnterForegroundNotification, object: nil)
    if let issues = delegate.ovwIssues, issues.count > 0 {
      issuesReceived(issues: issues)
    }
  }
  
  var pickerCtrl : MonthPickerController?
  var overlay : Overlay?
  func showDatePicker(){
    let fromDate = DateComponents(calendar: Calendar.current, year: 2010, month: 6, day: 1, hour: 12).date
      ?? Date()
    
    let toDate = Date()
    
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
      print("Selected: \(pickerCtrl.selectedDate)")
    }
//    overlay?.open(animated: true, fromBottom: true)
    overlay?.openAnimated(fromView: issueCarousel.label, toView: pickerCtrl.content)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if self.isInitial { isInitial = false }
    else { checkForNewIssues() }
  }
  
  @objc private func goingBackground() {}
  
  @objc private func goingForeground() {
    checkForNewIssues()
  }
  
} // IssueVC
