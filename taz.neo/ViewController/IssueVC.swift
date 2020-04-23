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
  func markStartDownload(feed: Feed, issue: Issue)
  func markStopDownload()
}

public class IssueVC: UIViewController, SectionVCdelegate {
  
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
  
  // The last Alert shown
  private var lastAlert: UIAlertController?
  
  /// Perform carousel animations?
  static var showAnimations = true
  
  /// Light status bar because of black background
  override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  
  /// Add moment image to carousel
  func addMoment(issue: Issue) {
    if let img = feeder.momentImage(issue: issue) {
      var idx = 0
      for iss in issues {
        if iss.date == issue.date { return }
        if iss.date < issue.date { break }
        idx += 1
      }
      issues.insert(issue, at: idx)
      issueCarousel.insertIssue(img, at: idx)
    }
  }
  
  /// Inspect download Error and show it to user
  func handleDownloadError(error: Error?) {
    
  }
  
  /// Download Moment images from server if necessary
  func getMoments(_ newIssues: [Issue]) {
    for issue in newIssues {
      dloader.downloadMoment(issue: issue) { [weak self] err in
        if err == nil { self?.addMoment(issue: issue) }
        else { self?.handleDownloadError(error: err) }
      }
    }
  }
  
  /// Issues received from server
  func issuesReceived(issues iss: [Issue]) {
    // TODO: Check for stored Issues
    // TODO: store new issues in DB
    var newIssues = iss
//    print("received: \(iss.count) issues")
//    for i in iss { print("  \(UsTime(i.date).toString())") }
    if (issues.count > 0) && (issues.last!.date == newIssues.first!.date) {
      newIssues.removeFirst()
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
        gqlFeeder.issues(feed: feed, date: lastDate, count: 20) { [weak self] res in
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
    if dloader.needDownloadResources() {
      lastAlert = Alert.message(message: 
        "Es müssen noch Ressourcen geladen werden, dies kann einen kleinen Moment dauern")
    }
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
  
  /// Download Issue at index
  func downloadIssue(index: Int) {
    if index < issues.count {
      let issue = issues[index]
      issueCarousel.index = index
      issueCarousel.setActivity(idx: index, isActivity: true)
      delegate.markStartDownload(feed: feed, issue: issue)
      downloadSection(section: issue.sections![0]) { [weak self] err in
        guard let self = self else { return }
        if err != nil { self.handleDownloadError(error: err); return }
        self.pushSectionVC()
        delay(seconds: 2) { 
          self.dloader.downloadIssue(issue: issue) { [weak self] err in
            guard let self = self else { return }
            if err != nil { 
              self.error("Issue DL Errors: last = \(err!)")
              self.handleDownloadError(error: err); 
              return 
            }
            else { 
              self.debug("Issue DL complete")
              self.issueCarousel.setActivity(idx: index, isActivity: false)
              self.delegate.markStopDownload()
            }
          }
        }
      }
    }
  }
  
  // last index displayed
  fileprivate var lastIndex: Int?
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    view.addSubview(issueCarousel)
    pin(issueCarousel.top, to: view.top)
    pin(issueCarousel.left, to: view.left)
    pin(issueCarousel.right, to: view.right)
    pin(issueCarousel.bottom, to: view.bottom, dist: -(80+UIWindow.bottomInset))
    issueCarousel.carousel.scrollFromLeftToRight = false    
    issueCarousel.onTap { [weak self] idx in
      self?.downloadIssue(index: idx)
    }
    issueCarousel.onLabelTap { idx in
      Alert.message(title: "Baustelle", message: "Durch diesen Knopf wird später die Archivauswahl angezeigt")
    }
    issueCarousel.addMenuItem(title: "Bild Teilen", icon: "square.and.arrow.up") { title in
      Alert.message(title: "Baustelle", message: "Hier kommt später der 'Teilen'-Dialog")
    }
    issueCarousel.addMenuItem(title: "Ausgabe löschen", icon: "trash") { title in
      Alert.message(title: "Baustelle", message: "Hiermit wird die markierte Ausgabe gelöscht")
    }
    issueCarousel.addMenuItem(title: "Ausgabe nicht automatisch löschen", icon: "trash.slash") { title in
      Alert.message(title: "Baustelle", message: "Hiermit wird die markierte Ausgabe vom automatischen Löschen ausgenommen")
    }
    issueCarousel.addMenuItem(title: "Scrollrichtung umkehren", icon: "repeat") { title in
      self.issueCarousel.carousel.scrollFromLeftToRight = !self.issueCarousel.carousel.scrollFromLeftToRight
    }
    issueCarousel.carousel.onDisplay { [weak self] (idx, om) in
      guard let self = self else { return }
      let sdate = self.issues[idx].date.gLowerDateString(tz: self.feeder.timeZone)
      if let last = self.lastIndex {
        self.issueCarousel.setText(sdate, isUp: idx > last)
      }
      else { self.issueCarousel.text = sdate }
      self.lastIndex = idx
      if IssueVC.showAnimations {
        IssueVC.showAnimations = false
        self.issueCarousel.showAnimations()
      }
      if idx == (self.issueCarousel.carousel.count - 10) { self.getCurrentIssues() }
    }
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(goingBackground), 
      name: UIApplication.willResignActiveNotification, object: nil)
    nc.addObserver(self, selector: #selector(goingForeground), 
                   name: UIApplication.willEnterForegroundNotification, object: nil)

  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    checkForNewIssues()
  }
  
  @objc private func goingBackground() {}
  
  @objc private func goingForeground() {
    checkForNewIssues()
  }
  
} // IssueVC
