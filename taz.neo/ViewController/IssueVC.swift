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
  public var selectedIssue: Issue { issues[index] }
  /// Opened Issue for viewing
  public var openedIssue: Issue?
  /// Issue reference to pass as IssueInfo
  public var issue: Issue { openedIssue ?? selectedIssue }

  /// The FeederContext providing the Feeder and default Feed
  public var feederContext: FeederContext
  
  /// The IssueCarousel showing the available Issues
  public var issueCarousel = IssueCarousel()
  
  /// Process Indicator for empty Carousel
  var carouselActivityIndicator:UIActivityIndicatorView? = UIActivityIndicatorView(style: .large)
  
  /// the spacing between issueCarousel and the Toolbar
  var issueCarouselLabelWrapperHeight: CGFloat = 120
  /// The currently available Issues to show
  ///public var issues: [Issue] = [] ///moved to parent
  /// The center Issue (index into self.issues)
  #warning("Access \"issueCarousel.index!\" may fail, not use force unwrap")
  public var index: Int {
    get { issueCarousel.index! }
    set { issueCarousel.index = newValue; updateToolbarHomeIcon() }
  }
  
  var verticalPaddings: CGFloat { get {
    let insets = self.navigationController?.view.safeAreaInsets ?? UIWindow.safeInsets
    return 42 + insets.top + insets.bottom
  }}
  
  public var safeIndex: Int? { get { return issueCarousel.index }}
  
  /// The Section view controller
  public var sectionVC: SectionVC?
  /// Is Issue Download in progress?
  public var isDownloading: Bool = false
  /// Issue Moments to download
  public var issueMoments: [Issue]? 
  
  /// Scroll direction (from config defaults)
  @Default("carouselScrollFromLeft")
  public var carouselScrollFromLeft: Bool

  /// Perform carousel animations?
  static var showAnimations = true
  
  /// Light status bar because of black background
  override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
  
  /// Date of next Issue to center on
  private var selectedIssueDate: Date? = nil
  
  /// Are we in archive mode?
  private var isArchiveMode: Bool = false
  
  /// Reset list of Issues to the first (most current) one
  public func resetIssueList() {
    issueCarousel.index = 0
  }
  
  /// Reset list of Issues and carousel
  private func reset() {
    issues = [] 
    issueCarousel.reset()
    self.collectionView.reloadData()
  }
    
  func updateToolbarHomeIcon(){
    self.tabBarItem.image
    = self.safeIndex == 0 && isUp
    ? UIImage(named: "home-fill")
    : UIImage(named: "home")
  }
  
  /// Reset carousel images
  private func resetCarouselImages(isPdf: Bool) {
    issueCarousel.preventReload = true
    var i = 0
    for issue in issues {
      if let img = feeder.momentImage(issue: issue, isPdf: isPdf) {
        issueCarousel[i] = img
        i += 1
      }
    }
    issueCarousel.preventReload = false
  }
  
  /// Add Issue to carousel
  private func addIssue(issue: Issue) {
    ///Update an Issue if Placeholder was there!
    if let idx = issues.firstIndex(where: { $0.date == issue.date}) {
      issues[idx] = issue
      if let img = feeder.momentImage(issue: issue, isPdf: isFacsimile), self.issueCarousel[idx].description.contains("demo-moment-frame"){
        self.issueCarousel.updateIssue(img, at: idx, preventZoomInAnimation: true)
      }
      else {
        ///Refresh Items may not implemented on Data/Model Side
        self.collectionView.reloadItems(at: [IndexPath(item: idx, section: 1)])
      }
      return
    }
    
    if let img = feeder.momentImage(issue: issue, isPdf: isFacsimile) {
      var idx = 0
      for iss in issues {
        if iss.date == issue.date { return }
        if iss.date < issue.date { break }
        idx += 1
      }
      if let spinner = carouselActivityIndicator {
        carouselActivityIndicator = nil
        spinner.stopAnimating()
        spinner.removeFromSuperview()
      }
      debug("inserting issue \(issue.date.isoDate()) at \(idx)")
      ///Fix Crash Bug occoured on iOS 12.4 Simulator  ...not happen on 0.9.0 Release on iPhone 6 iOS 12.5.3
      ///happen after login after restart!
      collectionView.performBatchUpdates { [weak self] in
        self?.issues.insert(issue, at: idx)
        self?.issueCarousel.insertIssue(img, at: idx)
        self?.collectionView.insertItems(at: [IndexPath(item: idx, section: 1)])
      }

      if let idx = issueCarousel.index { setLabel(idx: idx) }
      if let date = selectedIssueDate {
        if issue.date <= date { selectedIssueDate = nil }
        else { index = idx }
      }
    }
  }
  
  /// Move Carousel to certain Issue date (or next smaller)
  func moveTo(date: Date) {
    var idx = 0
    for iss in issues {
      if iss.date == date { return }
      if iss.date < selectedIssue.date { break }
      idx += 1
    }
    index = idx
  }
  
  /// Inspect download Error and show it to user
  func handleDownloadError(error: Error?) {
    self.debug("Err: \(error?.description ?? "-")")
    func showDownloadErrorAlert() {
      let message = """
                    Beim Laden der Ausgabe ist ein Fehler aufgetreten.
                    Bitte versuchen Sie es zu einem späteren Zeitpunkt
                    noch einmal.
                    Sie können bereits heruntergeladene Ausgaben auch
                    ohne Internet-Zugriff lesen.
                    """
      OfflineAlert.message(title: "Warnung", message: message)
    }
    
    if let err = error as? DownloadError, let err2 = err.enclosedError as? FeederError {
      feederContext.handleFeederError(err2){}
    }
    else if let err = error as? DownloadError {
      if err.handled == false {  showDownloadErrorAlert() }
      self.debug(err.enclosedError?.description ?? err.description)
    }
    else if let err = error {
      self.debug(err.description)
      showDownloadErrorAlert()
    }
    else {
      self.debug("unspecified download error")
      showDownloadErrorAlert()
    }
    self.isDownloading = false
  }
  
  /// Requests sufficient overview Issues from DB/server at
  /// a given date
  private func provideOverview(at date: Date) {
    var from = date
    from.addDays(10)
    selectedIssueDate = date
    isArchiveMode = true
    reset()
    feederContext.getOvwIssues(feed: feed, count: 21, fromDate: from, isAutomatically: false)
  }
  
  /// Requests sufficient overview Issues from DB/server
  private func provideOverview() {
    let n = issues.count
    if n > 0 {
      if (n - index) < 6 { 
        var last = issues.last!.date
        last.addDays(-1)
        feederContext.getOvwIssues(feed: feed, count: 10, fromDate: last, isAutomatically: false)
      }
      if index < 6 {
        var date = issues.first!.date
        date.addDays(10)
        feederContext.getOvwIssues(feed: feed, count: 10, fromDate: date, isAutomatically: false)
      }
    }
    else { feederContext.getOvwIssues(feed: feed, count: 20, isAutomatically: false) }
  }
  
  /// Empty overview array and request new overview
  private func resetOverview() {
    self.issues = []
    provideOverview()
  }
  
  /// Download one section
  private func downloadSection(section: Section, closure: @escaping (Error?)->()) {
    dloader.downloadSection(issue: self.selectedIssue, section: section) { [weak self] err in
      if err != nil { self?.debug("Section \(section.html.name) DL Errors: last = \(err!)") }
      else { self?.debug("Section \(section.html.name) DL complete") }
      closure(err)
    }   
  }
  
  /// Setup SectionVC and push it onto the VC stack
  private func pushSectionVC(feederContext: FeederContext, atSection: Int? = nil,
                             atArticle: Int? = nil) {
    sectionVC?.relaese()
    sectionVC = SectionVC(feederContext: feederContext, atSection: atSection,
                          atArticle: atArticle)
    if atArticle == nil {
      sectionVC?.whenLoaded {
        Notification.send(Const.NotificationNames.articleLoaded)
      }
    }
    if let svc = sectionVC {
      svc.delegate = self
      self.navigationController?.pushViewController(svc, animated: true)
    }
  }
  
  /// Show Issue at a given index, download if necessary
  func showIssue(index givenIndex: Int? = nil, atSection: Int? = nil, 
                         atArticle: Int? = nil) {
    guard let index = givenIndex ?? self.safeIndex else { return }
    func openIssue() {
      ArticlePlayer.singleton.baseUrl = issue.baseUrl
      self.openedIssue = issues[index]
      //call it later if Offline Alert Presented
      if OfflineAlert.enqueueCallbackIfPresented(closure: { openIssue() }) { return }
      //prevent multiple pushes!
      if self.navigationController?.topViewController != self { return }
      let authenticatePDF = { [weak self] in
        guard let self = self else { return }
        let loginAction = UIAlertAction(title: Localized("login_button"),
                                        style: .default) { _ in
          self.feederContext.authenticate()
        }
        let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel)
        var expiredText = Localized("subscription_id_expired_withoutDate")
        if let d = Defaults.expiredAccountDate {
          expiredText = Localized(keyWithFormat: "subscription_id_expired", d.gDate())
        }
        
        expiredText
        = expiredText.htmlAttributed?.string.replacingOccurrences(of: "\n\n", with: "\n")
        ?? "Ihr taz-Digiabo ist seit abgelaufen!"
        
        let msg = self.feederContext.isAuthenticated
        ? expiredText
        : "Um das ePaper zu lesen, müssen Sie sich anmelden."
        
        
        Alert.message(title: "Fehler", message: msg, actions: [loginAction, cancelAction])
      }
      
      if isFacsimile {
        ///the positive use case
        let pushPdf = { [weak self] in
          guard let self = self else { return }
          let vc = TazPdfPagesViewController(issueInfo: self)
          self.navigationController?.pushViewController(vc, animated: true)
          if issue.status == .reduced {  authenticatePDF()
          }
          
        }
        ///in case of errors
        let handleError = {
          Toast.show(Localized("error"))
          Notification.send(Const.NotificationNames.articleLoaded)
        }
        
        if feeder.momentPdfFile(issue: issue) != nil {
          pushPdf()
        }
        else if let page1pdf = issue.pages?.first?.pdf {
          self.dloader.downloadIssueData(issue: issue, files: [page1pdf]) { err in
            if err != nil { handleError() }
            else { pushPdf() }
          }
        } else {
          handleError()
        }
      }
      else {
        self.pushSectionVC(feederContext: feederContext, atSection: atSection, 
                           atArticle: atArticle)
      }
    }
    guard index >= 0 && index < issues.count else { return }
    let issue = issues[index]
    feederContext.openedIssue = issue //remember opened issue to not delete if
    debug("*** Action: Entering \(issue.feed.name)-" +
      "\(issue.date.isoDate(tz: feeder.timeZone))")
    /* Dieser Code verhindert, wenn sich der feeder aufgehangen hat, dass eine andere bereits heruntergeladene Ausgabe geöffnet wird
     ...weil isDownloading == true => das wars!
     ein open issue in dem Fall wäre praktisch,
     ...würde dann den >>>Notification.receiveOnce("issueStructure"<<<" raus nehmen
     */
    if let sissue = issue as? StoredIssue {
      guard feederContext.needsUpdate(issue: sissue, toShowPdf: isFacsimile) else { openIssue(); return }
      if isDownloading {
        statusHeader.currentStatus = .loadIssue
        return
      }
      isDownloading = true
      issueCarousel.index = index
      issueCarousel.setActivity(idx: index, isActivity: true)
      Notification.receiveOnce("issueStructure", from: sissue) { [weak self] notif in
        guard let self = self else { return }
        guard notif.error == nil else { 
          self.handleDownloadError(error: notif.error!)
          if issue.status.watchable && self.isFacsimile { openIssue() }
          self.issueCarousel.setActivity(idx: index, isActivity: false)
          return 
        }
        self.downloadSection(section: sissue.sections![0]) { [weak self] err in
          guard let self = self else { return }
          self.statusHeader.currentStatus = .none
          self.isDownloading = false
          guard err == nil else {
            self.handleDownloadError(error: err)
            if issue.status.watchable && self.isFacsimile { openIssue() }
            return
          }
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
      self.feederContext.getCompleteIssue(issue: sissue, isPages: isFacsimile, isAutomatically: false)        
    }
  }
  
  // last index displayed
  fileprivate var lastIndex: Int?
 
  func setLabel(idx: Int, isRotate: Bool = false) {
    guard idx >= 0 && idx < self.issues.count else { return }
    let issue = self.issues[idx]
    var sdate = issue.date.gLowerDate(tz: self.feeder.timeZone)
    if hasDownloadableContent(issue: issue) {
      sdate += " \u{2601}"
    }
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
      let name = "\(issue.feed.name)-\(issue.date.isoDate(tz: self.feeder.timeZone)).\(ext ?? "")"
      dialogue.present(item: file.url, subject: name)
    }
  }
  
  private func delete(issue: StoredIssue) {
    issue.reduceToOverview()
    issueCarousel.carousel.reloadData()
    setLabel(idx: index)
  }
  
  func deleteIssue(issue: Issue? = nil) {
    let issue = issue ?? self.issue
    if issue.isDownloading {
      Alert.message(message: "Bitte warten Sie bis der Download abgeschlossen ist!")
      return
    }
    if let issue = issue as? StoredIssue {
      let bookmarked = StoredArticle.bookmarkedArticlesInIssue(issue: issue)
      if bookmarked.count > 0 {
        let actions = UIAlertController.init( title: "Ausgabe löschen", 
          message: "Diese Ausgabe enthält Lesezeichen. Soll sie wirklich " +
                   "gelöscht werden?",
          preferredStyle:  .actionSheet )
        actions.addAction( UIAlertAction.init( title: "Ja", style: .destructive,
          handler: { [weak self] handler in
          for art in bookmarked { art.hasBookmark = false }
          self?.delete(issue: issue)
        }))
        actions.addAction(UIAlertAction.init(title: "Nein", style: .default))
        actions.presentAt(issueCarousel.carousel.view())
      }
      else { delete(issue: issue) }
    }
  }
  
  var interruptMainTimer: Timer?
  
  lazy var togglePdfButton: Button<ImageView> = {
    let imageButton = Button<ImageView>()
    imageButton.pinSize(CGSize(width: 50, height: 50))
    imageButton.buttonView.hinset = 0.18
    imageButton.buttonView.color = Const.Colors.iconButtonInactive
    imageButton.buttonView.activeColor = Const.Colors.iconButtonActive
    imageButton.accessibilityLabel = "Ansicht umschalten"
    imageButton.isAccessibilityElement = true
    imageButton.onPress(closure: onPDF(sender:))
    imageButton.layer.cornerRadius = 25
    imageButton.backgroundColor = Const.Colors.fabBackground
    imageButton.buttonView.name = self.isFacsimile ? "mobile-device" : "newspaper"
    return imageButton
  }()
  
  lazy var loginButton: UIView = {
    let login = UILabel()
    login.accessibilityLabel = "Anmelden"
    login.isAccessibilityElement = true
    login.contentFont()
    login.textColor = Const.Colors.iconButtonInactive
    login.text = "Anmelden"
    
    let arrow = UIImageView(image: UIImage(name: "arrow.right"))
    arrow.tintColor = Const.Colors.iconButtonInactive
    
    let wrapper = UIView()
    wrapper.addSubview(login)
    wrapper.addSubview(arrow)
    pin(login, to: wrapper, dist:Const.Size.DefaultPadding, exclude: .right)
    pin(arrow, to: wrapper, dist:Const.Size.DefaultPadding, exclude: .left)
    pin(login.right, to: arrow.left, dist: -5.0)

    wrapper.onTapping { [weak self] _ in
       self?.feederContext.authenticate()
    }
    return wrapper
  }()
  
  lazy var topGradient = VerticalGradientView()
  
  /// align FAB to tabbars first icon
  func alignPdfToggleFab(){
    let defaultOffset = 52.0
    // if no tabbar set default offset
    guard let tabBar = (navigationController?.parent as? MainTabVC)?.tabBar else {
      btnLeftConstraint?.constant = defaultOffset
      return
    }
    
    var offset:CGFloat? = 0.0
    // Try to get first Buttons Icon Position
    // In case of changes by apple this may fail
    var leftButton:UIView?
    for case let btn as UIControl in tabBar.subviews {
      if leftButton == nil { leftButton = btn }
      if btn.frame.origin.x < leftButton?.frame.origin.x ?? 0 { leftButton = btn }
    }
    for case let iv as UIImageView in leftButton?.subviews ?? [] {
      offset = iv.center.x + (leftButton?.frame.origin.x ?? 0) + tabBar.frame.origin.x
      break
    }
    // Verify Icon Position or calculate it
    // paddings, spacer items, different item sizes,
    // Icon and Text next not below (like on ipad)
    // are likely to result in errors
    if offset == nil
        || offset ?? 0 < 20
        || offset ?? 0 > UIWindow.size.width/2
    {
      //calculate offset
      let itmmscount = tabBar.items?.count ?? 4
      offset = 0.5*tabBar.frame.size.width/CGFloat(itmmscount) + tabBar.frame.origin.x
    }
    btnLeftConstraint?.constant = offset ?? defaultOffset
    //print("tabBar.frame: \(tabBar.frame) ... offset: \(offset ?? defaultOffset) \(offset==nil ? " FALLBACK! " : "")")
  }
  
  var btnLeftConstraint: NSLayoutConstraint?

  func updateLoginButton(){
    if self.feederContext.isAuthenticated {
      loginButton.removeFromSuperview()
      return
    }
    self.headerView.addSubview(loginButton)
    pin(loginButton.right, to: self.headerView.rightGuide())
    pin(loginButton.top, to: self.headerView.topGuide(), dist: 20)
    topGradient.bringToFront()
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.headerView.addSubview(issueCarousel)
    if let ncView = self.navigationController?.view {
      ncView.addSubview(togglePdfButton)
      btnLeftConstraint = pin(togglePdfButton.centerX, to: ncView.left, dist: 50)
      pin(togglePdfButton.bottom, to: ncView.bottomGuide(), dist: -65)
    }
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    Notification.receive(Const.NotificationNames.logoutUserDataDeleted) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    self.view.addSubview(topGradient)
    topGradient.pinHeight(UIWindow.maxAxisInset)
    pin(topGradient.left, to: self.view.left)
    pin(topGradient.right, to: self.view.right)
    pin(topGradient.top, to: self.view.top)
    
    updateLoginButton()
    pin(issueCarousel.top, to: self.headerView.top)
    pin(issueCarousel.left, to: self.headerView.left)
    pin(issueCarousel.right, to: self.headerView.right)
    pin(issueCarousel.bottom,
        to: self.headerView.bottomGuide(isMargin: true),
        dist: -verticalPaddings)
    issueCarousel.carousel.scrollFromLeftToRight = carouselScrollFromLeft
    issueCarousel.onTap { [weak self] idx in
      guard let self = self, idx < self.issues.count else { return }
      let issue = self.issues[idx]
      self.showIssue(index: idx, atSection: issue.lastSection, 
                     atArticle: issue.lastArticle)
    }
    issueCarousel.onLabelTap { idx in
      self.showDatePicker()
    }
    issueCarousel.addMenuItem(title: "Bild Teilen", icon: "square.and.arrow.up") { 
      [weak self] arg in
      guard let self = self, let idx = arg as? Int else { return }
      self.exportMoment(issue: self.issues[idx])
    }
    issueCarousel.addMenuItem(title: "Ausgabe löschen", icon: "trash") { 
      [weak self] arg in
      guard let self = self, let idx = arg as? Int else { return }
      self.deleteIssue(issue: self.issues[idx])
    }
    var scrollChange = false
    issueCarousel.addMenuItem(title: "Scrollrichtung umkehren", icon: "repeat") { 
      [weak self] arg in
      guard let self = self else { return }
      self.issueCarousel.carousel.scrollFromLeftToRight =
        !self.issueCarousel.carousel.scrollFromLeftToRight
      scrollChange = true
      self.carouselScrollFromLeft = self.issueCarousel.carousel.scrollFromLeftToRight
      scrollChange = false
    }
    if App.isAlpha {
      issueCarousel.addMenuItem(title: "Simulate PN.aboPoll (⍺)", icon: "arrow.up") {_ in
        let pnPl = ["data":["refresh":"aboPoll"], "aps":["content-available":1,"sound":nil ]]
        NotifiedDelegate.singleton.notifier.handleTestRemoteNotification(pnPl)
      }
    }
     
    Defaults.singleton.receive() { [weak self] dnot in
      guard let self = self else { return }
      switch dnot.key {
        case "carouselScrollFromLeft":
          if !scrollChange && dnot.key == "carouselScrollFromLeft" {
            self.issueCarousel.carousel.scrollFromLeftToRight = self.carouselScrollFromLeft
          }
        case "isFacsimile":
          if let isPdf = dnot.val?.bool { self.resetCarouselImages(isPdf: isPdf) }
        default: break
      }
    }
    
    issueCarousel.addMenuItem(title: "Abbrechen", icon: "xmark.circle") {_ in}
    issueCarousel.carousel.onDisplay { [weak self] (idx, om) in
      guard let self = self else { return }
      self.updateToolbarHomeIcon()
      self.setLabel(idx: idx, isRotate: true)
      if IssueVC.showAnimations {
        IssueVC.showAnimations = false
        //self.issueCarousel.showAnimations()
      }
      self.debug("on display: \(idx) / \(self.issues.count)")
      if self.issues.count - idx <= 1 {
        if self.feederContext.isConnected == false {
          Notification.send("checkForNewIssues",
                            content: StatusHeader.status.offline,
                            error: nil,
                            sender: self.feederContext)
        } else {
          Notification.send("checkForNewIssues",
                            content: StatusHeader.status.fetchMoreIssues,
                            error: nil,
                            sender: self.feederContext)
        }
      }
      self.provideOverview()
    }
    
    Notification.receive("reloadIssues") {   [weak self] _ in
      self?.scrollUp(animated: false)
//      self?.isArchiveMode = true
      self?.issueCarousel.reset()//required!
//      self?.provideOverview()
      self?.resetOverview()
      onMainAfter(1.0) {  [weak self] in
        self?.isArchiveMode = false
        self?.index = 0
      }
    }
    
    Notification.receive(UIApplication.willResignActiveNotification) { _ in
      self.goingBackground()
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { _ in
      self.goingForeground()
    }
    
    if let spinner = carouselActivityIndicator {
      self.view.addSubview(spinner)
      spinner.center()
      spinner.startAnimating()
    }
    feederContext.getStoredOvwIssues(feed: feed)
    feederContext.getOvwIssues(feed: feed, count: 4, isAutomatically: false)
  }//Eof viewDidLoad()
  
  var pickerCtrl : DatePickerController?
  var overlay : Overlay?
  
  func showDatePicker(){
    let fromDate = feed.firstIssue
    let toDate = feed.lastIssue
    
    if pickerCtrl == nil {
      pickerCtrl = DatePickerController(minimumDate: fromDate,
                                         maximumDate: toDate,
                                         selectedDate: toDate)
      pickerCtrl?.pickerFont = Const.Fonts.contentFont
    }
    guard let pickerCtrl = pickerCtrl else { return }
    
    if overlay == nil {
      overlay = Overlay(overlay:pickerCtrl , into: self)
      overlay?.enablePinchAndPan = false
      overlay?.maxAlpha = 0.9
    }
        
//    pickerCtrl.doneHandler = {
//      self.overlay?.close(animated: true)
//      self.provideOverview(at: pickerCtrl.selectedDate)
//    }
    
    pickerCtrl.doneHandler = {
      let dstr = pickerCtrl.selectedDate.gDate(tz: self.feeder.timeZone)
      Alert.message(title: "Baustelle",
                    message: "Hier werden später die Ausgaben um den \"\(dstr)\" angezeigt.") { [weak self] in
        self?.overlay?.close(animated: true)
      }
    }
    overlay?.onClose(closure: {  [weak self] in
      self?.overlay = nil
      self?.pickerCtrl = nil
    })
    
    //Update labelButton Offset
    pickerCtrl.bottomOffset = issueCarousel.labelTopConstraintConstant + 50
    
    overlay?.openAnimated(fromView: issueCarousel.label, toView: pickerCtrl.content)
  }
  
  /// Check for new issues only if not in archive mode
  public func checkForNewIssues() {
    if !isArchiveMode { feederContext.checkForNewIssues(feed: feed, isAutomatically: false) }
  }
  
  func invalidateCarouselLayout() {
    self.issueCarousel.carousel.collectionViewLayout.invalidateLayout()
    self.issueCarousel.carousel.updateLayout()
    if let idx = safeIndex {
      self.issueCarousel.carousel.scrollToItem(at: IndexPath(item: idx,
                                                             section: 0),
                                               at: .centeredHorizontally,
                                               animated: false)
    }
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    togglePdfButton.isHidden = true
    super.viewWillDisappear(animated)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.openedIssue = nil
    updateCarouselSize(.zero)//initially show label (set pos not behind toolbar)
    invalidateCarouselLayout()//fix sitze if rotated on pushed vc
    checkForNewIssues()
    alignPdfToggleFab()
    togglePdfButton.showAnimated()
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    onMainAfter { [weak self] in
      self?.invalidateCarouselLayout()
      self?.alignPdfToggleFab()
    }
  }
  
  @objc private func goingBackground() {}
  
  @objc private func goingForeground() {
    checkForNewIssues()
  }
  
  /// Initialize with FeederContext
  public init(feederContext: FeederContext) {
    self.feederContext = feederContext
    super.init()
    updateCarouselSize(.zero)
    if let cfl = issueCarousel.carousel.collectionViewLayout as? CarouselFlowLayout {
      cfl.onLayoutChanged{   [weak self]  newSize in
        self?.updateCarouselSize(newSize)
      }
    }
    Notification.receive("issueOverview") { [weak self] notif in
      if let err = notif.error {
        self?.debug("receive issueOverview Error: \(err)")
        self?.statusHeader.currentStatus = .downloadError
        if let errIssue = notif.sender as? Issue {
          self?.addIssue(issue: errIssue)
        }
      }
      else {
        self?.statusHeader.currentStatus = .none
        self?.addIssue(issue: notif.content as! Issue)
      }
    }
  }
  
  private func updateCarouselSize(_ newSize:CGSize){
    let size
      = newSize != .zero
      ? newSize
      : CGSize(width: UIWindow.size.width,
               height: UIWindow.size.height
               - verticalPaddings)
    let availableH = size.height - 20 - self.issueCarouselLabelWrapperHeight
    let useableH = min(730, availableH) //Limit Height (usually on High Res & big iPad's)
    let availableW = size.width
    let defaultPageRatio:CGFloat = 0.670219
    let maxZoom:CGFloat = 1.3
    let maxPageWidth = defaultPageRatio * useableH / maxZoom
    let relPageWidth = maxPageWidth/availableW
    let relativePageWidth = min(0.6, relPageWidth*0.99)//limit to prevent touch
    self.issueCarousel.carousel.relativePageWidth = relativePageWidth
    self.issueCarousel.carousel.relativeSpacing = min(0.12, 0.2*relPageWidth/0.85)
    let maxHeight = size.width * relativePageWidth * 1.3 / defaultPageRatio
    let padding = (size.height - maxHeight)/2
    self.issueCarousel.labelTopConstraintConstant = 0 - padding
    self.statusBottomConstraint?.constant = padding - 36
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
} // IssueVC

extension IssueVC: ReloadAfterAuthChanged {
  public func reloadOpened(){
    ///remember status to prevent race conditions
    let stillDownloading = selectedIssue.isDownloading
    
    func popAndShowReloaded(){
      navigationController?.popToRootViewController(animated: false)
      showIssue(index: index,
                atSection: selectedIssue.lastSection,
                atArticle: selectedIssue.lastArticle)
    }
    
    if stillDownloading {
      Notification.receiveOnce("issue", from: selectedIssue) { notif in
        popAndShowReloaded()
      }
    }
    else {
      popAndShowReloaded()
    }
  }
}

