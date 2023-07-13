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
  func openIssue(_ issue:StoredIssue, at article: Article?)
}
extension OpenIssueDelegate {
  /// open a Issue
  func openIssue(_ issue:StoredIssue){ openIssue(issue, at: nil)}
}

/// Protocol to handle Open and Display an Issue
protocol PushIssueDelegate {
  /// delagate back the push of a child VC to prevent multiple pushes
  func push(_ viewController:UIViewController, issueInfo: IssueDisplayService)
}

class HomeTVC: UITableViewController {
  
  /// should show PDF Info Toast on startup (from config defaults)
  @Default("showPdfInfoToast")
  public var showPdfInfoToast: Bool
  
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
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
  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent}
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
  
  var pickerCtrl : DatePickerController?
  var overlay : Overlay?
  
  var carouselController: IssueCarouselCVC
  var tilesController: IssueTilesCVC
  var wasUp = true
  
  var carouselControllerCell: UITableViewCell
  var tilesControllerCell: UITableViewCell
  
  lazy var togglePdfButton: Button<ImageView> = {
    return createTogglePdfButton()
  }()

  lazy var loginButton: UIView = {
    return createLoginButton()
  }()
  
  
  var btnLeftConstraint: NSLayoutConstraint?
  
  // MARK: - Custom Components
  
  // MARK: - Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.view.backgroundColor = .black
    self.tableView.showsVerticalScrollIndicator = false
    self.tableView.showsHorizontalScrollIndicator = false
    ///on tapping the down arrows on ipad6mini, the seperator appears no matter what i setup here:
    self.tableView.separatorColor = .clear
    self.tableView.separatorStyle = .none
    self.tableView.allowsSelection = false///seams that it was at first seperator and then selection!
    
    setupCarouselControllerCell()
    setupTilesControllerCell()
    setupTogglePdfButton()
    setupDateButton()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setNeedsStatusBarAppearanceUpdate()
    updateCarouselSize(size: self.view.frame.size)
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    togglePdfButton.isHidden = true
    super.viewWillDisappear(animated)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    togglePdfButton.showAnimated()
    showPdfInfoIfNeeded()
    updateVisibleCellsCount()
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
  
  func updateVisibleCellsCount() {
    carouselController.evaluateVisibleCellsCount()
    tilesController.evaluateVisibleCellsCount()
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return 2
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
      guard self?.view.superview != nil else { return }
      self?.carouselController.statusHeader.currentStatus = .loadPreview
      if ((self?.navigationController?.parent as? UITabBarController)?
        .selectedViewController as? UINavigationController)?
        .viewControllers.last != self {
        _ = service.reloadPublicationDates(refresh: nil, verticalCv: true)
        self?.tilesController.collectionView.reloadData()
        self?.carouselController.collectionView.reloadData()
        return
      }

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
      if up { self.tilesController.collectionView.reloadData() }
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
  }
}

// MARK: - Tab Home handling
extension HomeTVC {
  func onHome(){
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
  func openIssue(_ issue: StoredIssue, at article: Article?) {
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
    issueInfo.showIssue(pushDelegate: self, at: article)
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
    onMainAfter {[weak self] in
      self?.updateVisibleCellsCount()
    }
  }
  
  fileprivate func setupTilesControllerCell() {
    tilesControllerCell.contentView.addSubview(tilesController.view)
    pin(tilesController.view, to: tilesControllerCell)
  }
  
  fileprivate func setupCarouselControllerCell() {
    carouselControllerCell.contentView.addSubview(carouselController.view)
    pin(carouselController.view, toSafe: carouselControllerCell).bottom.constant = -UIWindow.topInset
    carouselControllerCell.backgroundColor = .clear
    
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    Notification.receive(Const.NotificationNames.logoutUserDataDeleted) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    updateLoginButton()
  }
  
  fileprivate func updateLoginButton(){
    if self.feederContext.isAuthenticated {
      loginButton.removeFromSuperview()
      return
    }
    carouselControllerCell.contentView.addSubview(loginButton)
    pin(loginButton.right, to: carouselControllerCell.contentView.rightGuide())
    pin(loginButton.top, to: carouselControllerCell.contentView.topGuide(), dist: 20)
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
    login.textColor = Const.Colors.appIconGrey
    login.text = "Anmelden"
    
    let arrow
    = UIImageView(image: UIImage(name: "arrow.right")?
      .withTintColor(Const.Colors.appIconGrey,
                     renderingMode: .alwaysOriginal))
    arrow.tintColor = Const.Colors.appIconGrey
    
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
  func showPdfInfoIfNeeded(_ delay:Double = 3.0) {
    if showPdfInfoToast == false {
      self.carouselController.showScrollDownAnimationIfNeeded()
      return
    }
    
    onThreadAfter(delay) { [weak self] in
        guard let url = Bundle.main.url(forResource: "lottiePopup",
                                     withExtension: "html",
                                        subdirectory: "BundledResources") else {
          self?.log("Bundled lottie HTML not found!")
          return
        }
      
        let file = File(url)
        guard file.exists  else {
          self?.log("Bundled lottie HTML File not found!")
          return
        }
      
      InfoToast.showWith(lottieUrl: url,
                          title: "Entdecken Sie jetzt die Zeitungsansicht",
                          text: "Hier können Sie zwischen der mobilen und der Ansicht der Zeitungsseiten wechseln",
                          buttonText: "OK",
                          hasCloseX: true,
                          autoDisappearAfter: nil) {   [weak self] in
        self?.log("PdfInfoToast showen and closed")
        self?.showPdfInfoToast = false
        self?.carouselController.showScrollDownAnimationIfNeeded()
      }
    }
  }
}

extension HomeTVC: ReloadAfterAuthChanged {
  public func reloadOpened(){
    ///welches ist die aktuell geöffnete ausgabe?
    ///scrolle zu dieser ausgabe im karussel bzw times brauche ich nicht, die bleiben
    ///download wolke muss sich aber aktualisieren! besonders in tiles TEST!
    guard let selectedIssue = self.issueInfo?.issue as? StoredIssue else { return }
    if selectedIssue.isDownloading == false {
      navigationController?.popToRootViewController(animated: false)
      self.openIssue(selectedIssue)
      return
    }
    Notification.receiveOnce("issue", from: selectedIssue) { [weak self] notif in
      self?.navigationController?.popToRootViewController(animated: false)
      self?.openIssue(selectedIssue)
    }
  }
}
