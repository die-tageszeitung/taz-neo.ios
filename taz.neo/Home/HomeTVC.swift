//
//  HomeTVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 01.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// Protocol to handle Open and Display an Issue
protocol OpenIssueDelegate {
  /// open a Issue
  func openIssue(_ issue:StoredIssue, atArticle: Int?, atPage: Int?, isReloadOpened: Bool)
}
extension OpenIssueDelegate {
  /// open a Issue
  func openIssue(_ issue:StoredIssue, isReloadOpened: Bool = false){
    openIssue(issue, atArticle: nil, atPage: nil, isReloadOpened: isReloadOpened)
  }
}

/// Protocol to handle Open and Display an Issue
protocol PushIssueDelegate {
  /// delagate back the push of a child VC to prevent multiple pushes
  func push(_ viewController:UIViewController, issueInfo: IssueDisplayService)
}

extension HomeTVC: CoachmarkVC {
  var viewName: String { Coachmarks.IssueCarousel.typeName }
  
  public func targetView(for item: CoachmarkItem) -> UIView? {
    guard let item = item as? Coachmarks.IssueCarousel else { return nil }
    
    switch item {
      case .pdfButton:
        return togglePdfButton
      case .loading:
        if carouselController.downloadButton.indicator.downloadState == .notStarted {
          return carouselController.downloadButton
        }
        fallthrough
      default:
        return nil
    }
  }
  
  public func target(for item: CoachmarkItem) -> (UIImage, [UIView], [CGPoint])? {
    guard let item = item as? Coachmarks.IssueCarousel,
          item == .tiles else { return nil }
    return (UIImage(named: "cm-scroll")?.withRenderingMode(.alwaysOriginal), [], [])
    as? (UIImage, [UIView], [CGPoint]) ?? nil
  }
}


class HomeTVC: UITableViewController {

  /// should show PDF Info Toast on startup (from config defaults)
  @Default("showPdfInfoToast")
  public var showPdfInfoToast: Bool
  
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  @Default("voiceoverControls")
  var voiceoverControls: Bool
  
  private var dataPolicyToast: NewInfoToast?
  
  #warning("Refactor ContentVC should hold it's IssueInfo Reference")
  ///Needed because ContentVC did not has a strong reference to its IssueInfo Object
  ///if not using this both vars
  ///Array: Push after Download not work
  ///Var: IssueInfo no content to display
  var loadingIssueInfos:[IssueDisplayService] = []
  var issueInfo:IssueDisplayService?
  var feederContext:FeederContext
  var issueOverviewService: IssueOverviewService
  
  /// offset for snapping between top area (IssueCarousel) and Bottom Area (tile view)
  var scrollSnapHeight : CGFloat { get { return UIScreen.main.bounds.size.height }}
  override var preferredStatusBarStyle:
  UIStatusBarStyle { App.isLMD ? .darkContent : .lightContent }
  //  var service: DataService
  
  /**
   Selection unten => Top Ausgabe ist selectiert
   
   Memory
   old IssueVC
    Started as App91MB scroll -36d 179MBscroll -90d 333mb
   new
   Started as App21MB scroll -36d 95MBscroll -90d 91mb
   
   
   same Index
   ==> besser: ich bin 1.1.2005 oben scrolle runter und bin dort auch P*A*R*T*Y
   ==> kann SOMIT besser die richtige Ausgabe finden und muss nicht ewig scrollen
   ==> DO IT!!
   BETTER 2 STEP NAVIGATION
   unten 5.5.2015 HOME => Scroll Tiles newest => HOME GOTO TOP
   
   footerActivityIndicator for bottom cells no more needed saves ~70LInes
   SNAPP SCROLLING (IF WORKS) SAVES ~40LINES
   
   @next Refactoring: https://developer.apple.com/documentation/uikit/views_and_controls/collection_views/implementing_modern_collection_views
    * pro: less Memory all in one
    * con: no experiance now, no time, 2023's implementation seam to work an is maintainable
   */
  // MARK: - UI Components / Vars
  var carouselController: IssueCarouselCVC
  var tilesController: IssueTilesCVC
  var wasUp = true { didSet { if oldValue != wasUp { trackScreen() }}}
  
  var isAccessibilityMode: Bool = false {
    didSet {
      if oldValue == isAccessibilityMode { return }
      accessibilityControlls.isHidden = !isAccessibilityMode
      scroll(up: true, animated: false)
      tableView.isScrollEnabled = !isAccessibilityMode
      tableView.reloadData()
    }
  }
  
  var carouselControllerCell: UITableViewCell
  var tilesControllerCell: UITableViewCell
  
  lazy var togglePdfButton: Button<ImageView> = {
    return createTogglePdfButton()
  }()

  lazy var loginButton: UIView = {
    return createLoginButton()
  }()
  
  var accessibilityPlayHelper: UILabel = UILabel()
  var accessibilityOlderHelper = UIImageView()
  var accessibilityNewerHelper = UIImageView()
  
  lazy var accessibilityControlls: UIView = {
    accessibilityPlayHelper.onTapping {[weak self] _ in
      guard let idx = self?.carouselController.centerIndex,
            let issue = self?.issueOverviewService.cellData(for: idx)?.issue else { return }
      ArticlePlayer.singleton.play(issue: issue,
                                   startFromArticle: nil,
                                   enqueueType: .replaceCurrent)
    }
    accessibilityPlayHelper.numberOfLines = 2
    accessibilityPlayHelper.accessibilityTraits = .button
    accessibilityPlayHelper.boldContentFont().color(.white).centerText()
    //--
    accessibilityOlderHelper.onTapping {[weak self] _ in
      guard let idx = self?.carouselController.centerIndex else { return }
      self?.carouselController.scrollTo(idx+1, animated: false)
    }
    accessibilityOlderHelper.accessibilityLabel = "Ausgabe zurück"
    accessibilityOlderHelper.accessibilityTraits = .button
    accessibilityOlderHelper.isAccessibilityElement = true
    accessibilityOlderHelper.image = UIImage(named: "forward")
    accessibilityOlderHelper.image?.accessibilityTraits = .none
    accessibilityOlderHelper.tintColor = .white
    //--
    accessibilityNewerHelper.onTapping {[weak self] _ in
      guard let idx = self?.carouselController.centerIndex else { return }
      if idx == 0 { return }
      self?.carouselController.scrollTo(idx-1, animated: false)
    }
    accessibilityNewerHelper.accessibilityLabel = "Ausgabe vor"
    accessibilityNewerHelper.accessibilityTraits = .button
    accessibilityNewerHelper.isAccessibilityElement = true
    accessibilityNewerHelper.image = UIImage(named: "backward")
    accessibilityNewerHelper.image?.accessibilityTraits = .none
    accessibilityNewerHelper.tintColor = .white
    
    accessibilityPlayHelper.accessibilityLabel = "aktuelle Ausgabe abspielen, bitte benutzen Sie die Mediensteuerung auf dem Speerbildschirm um zwischen den Artikeln zu wechseln"
    accessibilityPlayHelper.text = "aktuelle Ausgabe abspielen"
    accessibilityPlayHelper.accessibilityTraits = .button
    accessibilityPlayHelper.isAccessibilityElement = true
    
    //--
    let accessibilityInfoLabel = UILabel(frame: CGRect(x: 5, y: 50, width: 10, height: 4))
    accessibilityInfoLabel.text = "Voiceover Hilfsschaltflächen aktiviert\nVoiceover deaktivieren\num diese zu deaktivieren"
    //--
    accessibilityInfoLabel.contentFont().color(.white).centerText()
    accessibilityInfoLabel.numberOfLines = 3
    accessibilityInfoLabel.isAccessibilityElement = false
    //--
    let wrapper = UIView()
    wrapper.addSubview(accessibilityPlayHelper)
    wrapper.addSubview(accessibilityOlderHelper)
    wrapper.addSubview(accessibilityNewerHelper)
    wrapper.addSubview(accessibilityInfoLabel)
    wrapper.backgroundColor = UIColor.black.withAlphaComponent(0.8)
    //--
    pin(accessibilityOlderHelper.right, to: wrapper.right)
    pin(accessibilityNewerHelper.left, to: wrapper.left)
    accessibilityPlayHelper.centerX()
    pin(accessibilityPlayHelper.bottom, to: wrapper.bottom)
    pin(accessibilityOlderHelper.bottom, to: wrapper.bottom)
    pin(accessibilityNewerHelper.bottom, to: wrapper.bottom)
    pin(accessibilityInfoLabel, to: wrapper, exclude: .bottom)
    pin(accessibilityPlayHelper.top, to: accessibilityInfoLabel.bottom, dist: 10)
    //--
    wrapper.isHidden = true
    return wrapper
  }()
 
  var btnLeftConstraint: NSLayoutConstraint?
  
  // MARK: - Custom Components
  
  // MARK: - Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.view.backgroundColor = Const.Colors.Light.HomeBackground
    carouselController.collectionView.backgroundColor = Const.Colors.Light.HomeBackground
    self.tableView.showsVerticalScrollIndicator = false
    self.tableView.showsHorizontalScrollIndicator = false
    ///on tapping the down arrows on ipad6mini, the seperator appears no matter what i setup here:
    self.tableView.separatorColor = .clear
    self.tableView.separatorStyle = .none
    self.tableView.allowsSelection = false///seams that it was at first seperator and then selection!
    Notification.receive(UIAccessibility.voiceOverStatusDidChangeNotification){   [weak self] _ in
      self?.updateAccessibillityHelper()
    }
    
    carouselController.issueSelectionChangeDelegate = self
    setupCarouselControllerCell()
    setupTilesControllerCell()
    tilesControllerCell.isAccessibilityElement = false
    setupDateButton()
    #if TAZ
      setupTogglePdfButton()
      togglePdfButton.isAccessibilityElement = false
    #endif
    carouselController.dateLabel.isAccessibilityElement = false
    carouselControllerCell.isAccessibilityElement = false
    carouselController.collectionView.isAccessibilityElement = false
    tilesControllerCell.isAccessibilityElement = false
    tilesControllerCell.contentView.isAccessibilityElement = false
    tilesController.collectionView.isAccessibilityElement = false
    $voiceoverControls.onChange{ [weak self] _ in self?.updateAccessibillityHelper() }
    updateAccessibillityHelper()
   }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setNeedsStatusBarAppearanceUpdate()
    updateCarouselSize(size: self.view.frame.size)
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    #if TAZ
      togglePdfButton.isHidden = true
    #endif
    super.viewWillDisappear(animated)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    #if TAZ
    togglePdfButton.isHidden = false
    #endif
    showRequestTrackingIfNeeded()
    self.carouselController.showScrollDownAnimationIfNeeded()
    scroll(up: wasUp)
    Rating.homeAppeared()
  }
  
 @objc private func updateAccessibillityHelper(){
   let isLoggedIn = loginButton.superview == nil
   isAccessibilityMode
    = isLoggedIn
    && voiceoverControls
    && UIAccessibility.isVoiceOverRunning
  }
  
  var nextHorizontalSizeClass:UIUserInterfaceSizeClass?
  
  override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    nextHorizontalSizeClass = newCollection.horizontalSizeClass
    super.willTransition(to: newCollection, with: coordinator)
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateCarouselSize(size: size, horizontalSizeClass: nextHorizontalSizeClass)
    nextHorizontalSizeClass = nil
    self.verifyUp()
    coordinator.animate(alongsideTransition: nil, completion: {[weak self] _ in
      guard let self = self else { return }
      self.scroll(up: self.wasUp)
    })

  }
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return UIAccessibility.isVoiceOverRunning ? 1 : 2
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return self.view.frame.size.height
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return indexPath.row == 0 ? carouselControllerCell : tilesControllerCell
  }
  
  public init(service: IssueOverviewService, feederContext: FeederContext) {
    carouselController = IssueCarouselCVC(service: service)
    tilesController = IssueTilesCVC(service: service)
    self.feederContext = feederContext
    self.issueOverviewService = service
    
    carouselControllerCell =  UITableViewCell()
    tilesControllerCell = UITableViewCell()
    
    super.init(style: .plain)
    
    self.addChild(carouselController)
    self.addChild(tilesController)
    ///Handle new issues
    Notification.receive(Const.NotificationNames.publicationDatesChanged) {[weak self] _ in
      if self?.view.superview == nil {
        _ = service.reloadPublicationDates(refresh: nil, verticalCv: true)
        ///Old Data, Offline, In Issue, Online => Update => Back to Home: this fixes home in wired state
        self?.carouselController.collectionView.reloadData()
        self?.tilesController.collectionView.reloadData()
        onMainAfter {[weak self] in self?.carouselController.updateDate() }
        return
      }
      self?.carouselController.statusHeader.currentStatus = .loadPreview
      guard let service = self?.issueOverviewService,
            let self = self else { return }
      let up = self.verifyUp()
      ///cv to be reloaded by service
      ///unfortunately we have to tell vc the changed indexPaths and then refresh the datamodel then commit changes
      ///the other cv: tiles or carousel will be reloaded with reloadData()  due not visible
      guard let targetCv = up ? self.carouselController.collectionView
                              : self.tilesController.collectionView else { return }
      ///if no changes not reload
      guard service.reloadPublicationDates(refresh: targetCv,
                                           verticalCv: !up) else { return }
      //refresh the other collection view controller
      if up {
        self.tilesController.collectionView.reloadData()
        self.carouselController.updateDate()
      }
      else { self.carouselController.collectionView.reloadData() }
    }
    ///Handle reachability changes: show offline status
    Notification.receive(Const.NotificationNames.feederUnreachable) {[weak self] _ in
      self?.carouselController.statusHeader.currentStatus = .offline
    }
    ///Handle reachability changes: show offline status
    Notification.receive(Const.NotificationNames.feederReachable) {[weak self] _ in
      self?.carouselController.statusHeader.currentStatus = .none
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

protocol IssueSelectionChangeDelegate {
  /// Register Handler for Current Object
  /// Will call applyStyles() on register @see extension UIStyleChangeDelegate
  func setCurrent(cellData: IssueCellData, idx: Int)
}


extension HomeTVC: IssueSelectionChangeDelegate {
  func  setCurrent(cellData: IssueCellData, idx: Int) {
    if cellData.issue?.audioFiles.count ?? 0 > 0 {
      accessibilityPlayHelper.text = "taz vom\n\(cellData.date.date.short) abspielen"
      accessibilityPlayHelper.accessibilityLabel = "taz vom\n\(cellData.date.date.short) abspielen"
    }
    else {
      accessibilityPlayHelper.text = "taz vom\n\(cellData.date.date.short) laden und abspielen"
      accessibilityPlayHelper.accessibilityLabel = "taz vom\n\(cellData.date.date.short) laden und abspielen"
    }
  }
}

// MARK: - UIScrollViewDelegate (and Helper)
extension HomeTVC {

  @discardableResult
  fileprivate func verifyUp() -> Bool {
    guard let scrollView = self.tableView else { return wasUp }
    wasUp = scrollView.contentOffset.y < self.view.frame.size.height*0.7
    return wasUp
  }
  
  open override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    ///Not call super, it will crash if optional different scrollDelegate not set
    if decelerate { return }
    snapScrollViewIfNeeded(scrollView)
  }
  
  open override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    snapScrollViewIfNeeded(scrollView, targetContentOffset: targetContentOffset.pointee)
  }
  
  open override func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
    snapScrollViewIfNeeded(scrollView)
  }
    
  open override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    snapScrollViewIfNeeded(scrollView)
  }
  
  open override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    wasUp = scrollView.contentOffset.y < 200.0
  }
}

// MARK: - Scroll Extensions
extension HomeTVC {
  ///Implementation of the scroll Snapping simplified, the 20% trigger can be implemented within Refactoring after Integration
  func snapScrollViewIfNeeded(_ scrollView: UIScrollView, targetContentOffset:CGPoint? = nil) {
    
    let targetOffset = targetContentOffset != nil
    ? targetContentOffset!.y
    : scrollView.contentOffset.y
    
    if wasUp {
      if targetOffset < 0.1 * scrollSnapHeight {
        scroll(up: true)
      }
      else {
        scroll(up: false)
      }
    }
    else {
      if targetOffset < 0.8 * scrollSnapHeight {
        scroll(up: true)
      }
      else if targetOffset < 1.1 * scrollSnapHeight {
        scroll(up: false)
      }
    }
  }
  
  func scroll(up:Bool, animated:Bool=true){
    self.tableView.scrollToRow(at:  IndexPath(row: up ? 0 : 1, section: 0),
                               at: .top,
                               animated: animated)
  }

}

// MARK: - PDF App View Switching
extension HomeTVC {
  func onPDF(sender:Any){
    self.isFacsimile = !self.isFacsimile
    Usage.track(self.isFacsimile ? Usage.event.appMode.SwitchToPDFMode : Usage.event.appMode.SwitchToMobileMode)
    deactivateCoachmark(Coachmarks.IssueCarousel.pdfButton)
    
    if let imageButton = sender as? Button<ImageView> {
      imageButton.buttonView.name = self.isFacsimile ? "mobile-device" : "newspaper"
      imageButton.buttonView.accessibilityLabel = self.isFacsimile ? "App Ansicht" : "Zeitungsansicht"
    }
    Toast.show(self.isFacsimile
    ? "<h2>Zeitungsansicht</h2><p>Sie können jetzt die taz im Layout<br>der Zeitungsansicht lesen.</p>"
    : "<h2>App-Ansicht</h2><p>Sie können jetzt die taz in der<br>für mobile Geräte<br>optimierten Ansicht lesen.</p>")
    self.tilesController.reloadVisibleCells()
    self.carouselController.reloadVisibleCells()
    self.carouselController.updateBottomWrapper(for: self.carouselController.centerIndex ?? 0,
                                                force: true)
    trackScreen()
  }
}

// MARK: - Tab Home handling
extension HomeTVC {
  func onHome(){
    if self.carouselController.pickerCtrl != nil { return }
    if verifyUp() {
      self.carouselController.preventApiLoadUntilIndex = 0
      self.tilesController.collectionView
        .scrollToItem(at: IndexPath(row: 0, section: 0),
                      at: .top,
                      animated: false)
      self.carouselController.collectionView
        .scrollToItem(at: IndexPath(row: 0, section: 0),
                      at: .centeredHorizontally,
                      animated: true)
    }
    else {
      let ips = self.tilesController.collectionView.indexPathsForVisibleItems.map { $0.row }
      let count = ips.count
      ///focus issue from tiles to caroussel
      ///    if not cell 0 visible in tiles
      ///    if not current caroussel center is visible in tiles
      ///    use tiles center cell to focus caroussel
      if !ips.contains(0),
         !ips.contains(carouselController.centerIndex ?? 0),
         count>0,
         let idx = ips.sorted().valueAt(count/2) {
        self.carouselController.scrollTo(idx)
      }
      self.scroll(up: true)
    }
  }
}

extension HomeTVC: OpenIssueDelegate {
  func openIssue(_ issue: StoredIssue, atArticle: Int? = nil, atPage: Int? = nil, isReloadOpened: Bool = false) {
    ///How to prevent multiple open?
    ///already pushed => no problem
    ///3 downloads in Progress => first downloaded? n/ last clicked?
    ///previously first clicked was used so do it again
    ///What happen if download fail? => Nothing another tap may download and open a issue
    ///QUESTIONS
    ///should/can i handle massive multiple downloads?
    ///should i allow?
    ///YES: Which one is selected? What if selected is no reference here?
    ///if  not what happen if i only have
    
    let issueInfo = IssueDisplayService(feederContext: feederContext,
                                    issue: issue)
    loadingIssueInfos.append(issueInfo)
    issueInfo.showIssue(pushDelegate: self, atArticle: atArticle, atPage:atPage, isReloadOpened: isReloadOpened)
  }
}

extension HomeTVC: PushIssueDelegate {
  func push(_ viewController: UIViewController, issueInfo: IssueDisplayService) {
    loadingIssueInfos.removeAll(where: { $0 == issueInfo })
    if navigationController?.topViewController != self {
      log("skip pushing: \(viewController) since another is already pushed. the other: \(String(describing: navigationController?.topViewController))")
      return
    }
    self.issueInfo = issueInfo
    self.navigationController?.pushViewController(viewController, animated: true)
  }
}

// MARK: - Subview Setup/Configuration
extension HomeTVC {
  
  fileprivate func updateCarouselSize(size:CGSize, horizontalSizeClass:UIUserInterfaceSizeClass? = nil){
    let horizontalSizeClass
    = horizontalSizeClass ?? self.traitCollection.horizontalSizeClass
    carouselController
      .updateCarouselSize(size,
                          horizontalSizeClass: horizontalSizeClass)
  }
  
  fileprivate func setupTilesControllerCell() {
    tilesControllerCell.contentView.addSubview(tilesController.view)
    pin(tilesController.view, to: tilesControllerCell)
  }
  
  fileprivate func setupCarouselControllerCell() {
    carouselController.view.isAccessibilityElement = !isAccessibilityMode
    carouselControllerCell.contentView.addSubview(carouselController.view)
    pin(carouselController.view, toSafe: carouselControllerCell).bottom?.constant = -UIWindow.topInset
    carouselControllerCell.backgroundColor = .clear
    
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    Notification.receive(Const.NotificationNames.logoutUserDataDeleted) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    updateLoginButton()
    carouselControllerCell.contentView.addSubview(accessibilityControlls)
    pin(accessibilityControlls.left, to: carouselControllerCell.contentView.left, dist: 12.0)
    pin(accessibilityControlls.right, to: carouselControllerCell.contentView.right, dist: -12.0)
    pin(accessibilityControlls.top, to: carouselControllerCell.contentView.topGuide(isMargin: true), dist: 15)
  }
  
  fileprivate func updateLoginButton(){
    if self.feederContext.isAuthenticated {
      loginButton.removeFromSuperview()
      updateAccessibillityHelper()
      return
    }
    let topPadding = UIWindow.keyWindow?.screen.bounds.height ?? 601 > 600 ? 20.0 : 5.0
    carouselControllerCell.contentView.addSubview(loginButton)
    pin(loginButton.right, to: carouselControllerCell.contentView.rightGuide())
    pin(loginButton.top, to: carouselControllerCell.contentView.topGuide(), dist: topPadding)
    updateAccessibillityHelper()
  }
  
  fileprivate func setupTogglePdfButton(){
    guard let ncView = navigationController?.view else { return }
    ncView.addSubview(togglePdfButton)
    btnLeftConstraint = pin(togglePdfButton.centerX, to: ncView.left, dist: 50)
    pin(togglePdfButton.bottom, to: ncView.bottomGuide(), dist: -65)
  }
  
  fileprivate func setupDateButton(){

  }
}

// MARK: - UI Components Creation Helper
extension HomeTVC {
  fileprivate func createTogglePdfButton() -> Button<ImageView> {
    let imageButton = Button<ImageView>()
    imageButton.pinSize(CGSize(width: 50, height: 50))
    imageButton.buttonView.hinset = 0.18
    imageButton.buttonView.color = Const.Colors.appIconGrey
    imageButton.buttonView.activeColor = Const.Colors.appIconGreyActive
    imageButton.accessibilityLabel = "Ansicht umschalten"
    imageButton.isAccessibilityElement = true
    imageButton.onPress(closure: onPDF(sender:))
    imageButton.layer.cornerRadius = 25
    imageButton.backgroundColor = Const.Colors.fabBackground
    imageButton.buttonView.name = self.isFacsimile ? "mobile-device" : "newspaper"
    return imageButton
  }
  
  fileprivate func createLoginButton() -> UIView {
    let login = UILabel()
    login.accessibilityLabel = "Anmelden"
    login.isAccessibilityElement = true
    login.contentFont()
    login.textColor = Const.SetColor.HomeText.dynamicColor
    login.text = "Anmelden"
    
    let arrow
    = UIImageView(image: UIImage(name: "arrow.right")?
      .withTintColor(Const.Colors.appIconGrey,
                     renderingMode: .alwaysTemplate))
    arrow.tintColor = Const.SetColor.HomeText.dynamicColor
    
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
  }
}
// MARK: - ShowPDF Info Toast
extension HomeTVC {
  func showRequestTrackingIfNeeded() {
    if Defaults.usageTrackingAllowed != nil {
      showCoachmarkIfNeeded()
      return
    }
    _ = StoreBusiness.canRegister///initially check App Store
    guard let image = UIImage(named: "BundledResources/UsagePopover.png")else {
      log("Bundled UsagePopover.png not found!")
      return
    }
    var fromBottom = false
    if dataPolicyToast == nil {
      fromBottom = true
      dataPolicyToast = NewInfoToast.showWith(image: image,
                            title: "Eine noch bessere taz App? Sie haben es in der Hand",
                            text: "Anonyme Nutzungsdaten helfen uns, noch besser zu werden. Wir wissen natürlich: Wer Daten will, muss freundlich sein – deshalb behandeln wir diese mit größtmöglicher Sorgfalt und absolut vertraulich. Ihre Einwilligung zur Nutzung kann zudem jederzeit widerrufen werden.",
                            button1Text: "Ja, ich helfe mit",
                            button2Text: "Nein, keine Daten senden",
                            button1Handler: { Defaults.usageTrackingAllowed = true; Usage.shared.setup() },
                            button2Handler: { Defaults.usageTrackingAllowed = false },
                            dataPolicyHandler: {[weak self] in self?.showDataPolicyModal()})
    }
    dataPolicyToast?.accessibilityViewIsModal = true
    dataPolicyToast?.button1.accessibilityLabel = "Tracking zustimmen"
    dataPolicyToast?.button2.accessibilityLabel = "Tracking verweigern"
    ///unfortunately links are not accessible @see: https://stackoverflow.com/a/49366620
    #warning("accessibility: Change Component")
    dataPolicyToast?.privacyText.accessibilityLabel = "Hinweise zum Datenschutz finden Sie in den Einstellungen"
    dataPolicyToast?.privacyText.isAccessibilityElement = false
    dataPolicyToast?.privacyText.accessibilityTraits = .none
    dataPolicyToast?.show(fromBottom: fromBottom)
  }
  
  func showDataPolicyModal(){
    let localResource = File(feederContext.gqlFeeder.dataPolicy)
    guard localResource.exists else {log("dataPolicy not found");  return }
    
    let introVC = TazIntroVC()
    introVC.topOffset = Const.Dist.margin
    introVC.isModalInPresentation = true
    introVC.webView.webView.load(url: localResource.url)
    self.modalPresentationStyle = .fullScreen
    introVC.modalPresentationStyle = .fullScreen
    introVC.webView.webView.scrollDelegate.atEndOfContent {_ in }
    introVC.webView.onX {_ in
      introVC.dismiss(animated: true, completion: nil)
    }
    self.present(introVC, animated: true) {
      //Overwrite Default in: IntroVC viewDidLoad
      introVC.webView.buttonLabel.text = nil
    }
  }
}

extension HomeTVC: ReloadAfterAuthChanged {
  public func reloadOpened(){
    guard let selectedIssue = self.issueInfo?.issue as? StoredIssue else { return }
    navigationController?.popToRootViewController(animated: false)
    if selectedIssue.isDownloading == false {
      self.openIssue(selectedIssue, isReloadOpened: true)
      return
    } else {
      Notification.receiveOnce("issue", from: selectedIssue) { [weak self] notif in
        self?.openIssue(selectedIssue, isReloadOpened: true)
      }
    }
  }
}
