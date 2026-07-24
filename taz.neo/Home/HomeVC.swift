//
//  HomeVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 23.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

/// Protocol to handle Open and Display an Issue
protocol OpenIssueDelegate {
  /// open a Issue
  func openIssue(_ issue:StoredIssue, openLast: Bool)
}

class HomeVC: UICollectionViewController, OpenIssueDelegate {
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  @Default("isInitialStartup")
  public var isInitialStartup: Bool
  
  /// Are we in facsimile mode
  @Default("isHomeTiles")
  public var isHomeTiles: Bool {
    didSet {
      guard oldValue != isHomeTiles else { return }
      applyScrollDirection(reload: scrollFromLeftToRight)
      if isHomeTiles == false {
        updateHeader(hidden: false)
      }
    }
  }
  
  @Default("scrollFromLeftToRight")
  public var scrollFromLeftToRight: Bool {
    didSet {
      guard oldValue != scrollFromLeftToRight else { return }
      applyScrollDirection(reload: true)
    }
  }
  
  func applyScrollDirection(reload: Bool){
    if isHomeTiles == false && scrollFromLeftToRight {
      collectionView.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
    }
    else {
      collectionView.transform = .identity
    }
    if reload { collectionView.reloadData() }
  }
  
  var carouselCenterIssueIndex:Int?
  var restoreCarouselCenterIssueIndex:Int?
  var centerIssueDateKey:String?
  var isRotating = false
  
  
  private var pullToLoadMoreHandler: (()->())?
  static let reuseCellId = "issueCollectionViewCell"
  
  var loadingIssueInfos:[IssueDisplayService] = []
  var issueInfo:IssueDisplayService?///NEEDED?
  var feederContext:FeederContext
  var service: IssueOverviewService
  
  lazy var statusHeader = FetchNewStatusHeader()
  private var topStatusButtonConstraint:NSLayoutConstraint?
  private var statusWrapperBottomConstraint: NSLayoutConstraint?
  private var statusWrapperWidthConstraint:NSLayoutConstraint?
  
  private var viewModeButtonTopConstraint:NSLayoutConstraint?
  
  /// Temporary variable to prevent the same issue from being opened multiple times due to repeated touches.
  var openingIssue: Issue?
  
  let downloadButton = DownloadStatusButton()
  let downloadButtonTapArea = UIView()
  let dateLabel = CrossfadeLabel()
  
  lazy var calenderImageView: UIImageView = {
    let iv = UIImageView(image: UIImage(named: "calendar")?.withRenderingMode(.alwaysOriginal))
    iv.contentMode = .scaleAspectFit
    iv.pinSize(CGSize(width: 24, height: 24))
    iv.centerY()
    return iv
  }()
  
  let gridItemSpacing:CGFloat = UIWindow.shortSide > 320 ? 30.0 : 20.0
  
  var cellSize : CGSize = .zero
  
  lazy var carouselLayout: IssueCarouselFlowLayout = {
    let layout = IssueCarouselFlowLayout()
    layout.scrollDirection = .horizontal
    layout.sectionInset = .zero
    layout.minimumInteritemSpacing = 1000000.0
    return layout
  }()
  
  
  lazy var gridLayout: UICollectionViewFlowLayout = {
    let lineSpacing:CGFloat = 20.0
    
    let layout = UICollectionViewFlowLayout()
    layout.sectionInset = UIEdgeInsets(top: gridItemSpacing,
                                       left: gridItemSpacing,
                                       bottom: gridItemSpacing,
                                       right: gridItemSpacing)
    layout.minimumLineSpacing = lineSpacing
    layout.minimumInteritemSpacing = gridItemSpacing
    layout.sectionInset = UIEdgeInsets(top: 120, left: layout.sectionInset.left, bottom: layout.sectionInset.bottom, right: layout.sectionInset.right)
    return layout
  }()
  
  var currentLayout: UICollectionViewFlowLayout {
    get { isHomeTiles ? gridLayout : carouselLayout }
  }
  
  
  lazy var bottomItemsWrapper: UIView = {
    let v = UIView()
    v.addSubview(downloadButton)
    v.addSubview(dateLabel)
    v.addSubview(calenderImageView)
    statusWrapperWidthConstraint = v.pinWidth(0)
    dateLabel.contentFont()
    dateLabel.textAlignment = .center
    pin(downloadButton, to: v, exclude: .left).top?.constant = -8.0
    downloadButton.color = Const.SetColor.HomeText.dynamicColor
    dateLabel.textColor = Const.SetColor.HomeText.dynamicColor
    dateLabel.centerX()
    calenderImageView.centerY(dist: -4)
    pin(calenderImageView.right, to: dateLabel.left, dist: -16.0)
    v.pinHeight(28)
    dateLabel.onTapping {[weak self] _ in
      self?.showDatePicker()
    }
    dateLabel.accessibilityLabel = "Ausgabe via Kalender auswählen"
    calenderImageView.onTapping {[weak self] _ in
      self?.showDatePicker()
    }
    
    downloadButtonTapArea.onTapping { [weak self] _ in
      guard let idx = self?.carousselFixCenterIndex,
            let data = self?.service.cellData(for: idx) else { return }
      
      if self?.downloadButton.indicator.downloadState?.canOpen == true,
         let issue = data.issue {
        self?.openIssue(issue, openLast: true)
        Usage.track(Usage.event.dialog.OpenLastRead, name: "OpenFromHome")
        return
      }
      self?.downloadButton.indicator.downloadState = .waiting
      self?.log("tap download button => download issueAt: \(data.date.date.short) idx: \(idx)")
      self?.service.download(issueAt: data.date.date, withAudio: false)
    }
    return v
  }()
  
  var dataPolicyToast: NewInfoToast?
  
  // Mark: from UIComponents
  let topPadding = 5.0//UIWindow.activeKeyWindow?.screen.bounds.height ?? 601 > 600 ? 80.0 : 5.0
  
  lazy var loginButton: UIButton = createLoginButton()
  lazy var viewModeButton: UIButton = createViewModeButton()
  lazy var datePickerOverlay = createDatePickerWrapperView()
  var datePickerOverlayTitleLabel: UIView?
  
  let datePicker = UIDatePicker()
  
  lazy var blurView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.black.withAlphaComponent(0.84)
    return view
  }()
  
  func onHome(){
    collectionView.scrollToItem(at: IndexPath(row: 0, section: 0),
                                at: isHomeTiles ? .centeredVertically : .centeredHorizontally,
                                animated: true)
  }
  
  func showDatePicker() {
    guard datePickerOverlay.superview == nil else { return }
    datePickerOverlay.isHidden = true
    datePickerOverlay.accessibilityViewIsModal = true
    Usage.track(Usage.event.dialog.IssueDatePicker)
    datePicker.date = service.date(at: carousselFixCenterIndex ?? 0)?.date ?? Date()
    self.view.addSubview(datePickerOverlay)
    pin(datePickerOverlay, to: self.view)
    datePickerOverlay.showAnimated(){[weak self] in
      self?.updateAccessibilityOrder()
      guard let target = self?.datePickerOverlayTitleLabel ?? self?.datePickerOverlay else { return }
      UIAccessibility.post(notification: .layoutChanged, argument: target)
    }
  }
  
  var carousselScrollingCenterIndex: Int? {
    guard !isHomeTiles else { return nil }
    guard let cv = collectionView else { return nil }
    
    let centerX = cv.contentOffset.x + cv.bounds.width / 2
    
    return cv.visibleCells
      .compactMap { cell -> (Int, CGFloat)? in
        guard let ip = cv.indexPath(for: cell) else { return nil }
        return (ip.row, abs(cell.center.x - centerX))
      }
      .min(by: { $0.1 < $1.1 })?
      .0
  }
  
  var carousselFixCenterIndex: Int? {
    guard !isHomeTiles else { return nil }
      guard let cv = collectionView else { return nil }
      let visibleCenterX = cv.contentOffset.x + cv.bounds.width / 2
      let rect = CGRect(origin: cv.contentOffset, size: cv.bounds.size)
      return cv.collectionViewLayout
          .layoutAttributesForElements(in: rect)?
          .filter { $0.representedElementCategory == .cell }
          .min {
              abs($0.center.x - visibleCenterX)
              <
              abs($1.center.x - visibleCenterX)
          }?
          .indexPath.row
  }
  
  /// Determines whether scrolling to the given index should be animated or immediate.
  ///
  /// - Parameter index: The target item index to scroll to.
  /// - Returns: `true` if the index is within or near the currently visible range (including a buffer),
  ///            indicating that animated scrolling is appropriate. Returns `false` if the index is far away,
  ///            in which case an immediate jump is preferred.
  func shouldScrollAnimatedTo(_ index: Int) -> Bool {
    let visibleIndexPaths = collectionView.indexPathsForVisibleItems
    guard !visibleIndexPaths.isEmpty else { return false }
    
    let visibleRows = visibleIndexPaths.map(\.row)
    let dist = isHomeTiles ? visibleRows.count : 10
    guard let min = visibleRows.min(),
          let max = visibleRows.max(),
          index >= 0 else {
      return false
    }
    
    let range = (min - dist)...(max + dist)
    return range.contains(index)
  }
  
  private var lastKnownSize:CGSize = .zero
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let newSize = view.bounds.size
    guard lastKnownSize != newSize else { return }
    lastKnownSize = newSize
    updateCollectionViewLayout(newSize)
    guard !isHomeTiles else { return }
    guard let idx = carouselCenterIssueIndex else { return }
    ///do not make big jumps
    if let cidx = carousselScrollingCenterIndex,
       abs(cidx - idx) > 2 { return
    }
    onMainAfter {[weak self] in self?.scrollTo(idx, animated: true)  }
  }
  
  var nextHorizontalSizeClass:UIUserInterfaceSizeClass?
  var initialized = false
  
  override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    nextHorizontalSizeClass = newCollection.horizontalSizeClass
    super.willTransition(to: newCollection, with: coordinator)
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
      super.traitCollectionDidChange(previousTraitCollection)
      if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
        updateCollectionViewLayout(view.bounds.size)
      }
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateCollectionViewLayout(size, horizontalSizeClass: nextHorizontalSizeClass)
    nextHorizontalSizeClass = nil
    restoreCarouselCenterIssueIndex = isHomeTiles ? nil : carouselCenterIssueIndex
    isRotating = true
    coordinator.animate(alongsideTransition: { [weak self] _ in
      self?.restoreCenteredIndexIfNeeded(animated: false, reset: false)
    }) { [weak self] _ in
      self?.isRotating = false
      self?.restoreCenteredIndexIfNeeded(animated: true, reset: true)
    }
  }
  
  private func headerTopDist(hidden: Bool) -> CGFloat{
    let isBigScreen = UIWindow.activeKeyWindow?.screen.bounds.height ?? 0 > 990
    if isBigScreen {
      return hidden ? -10.0 : 20.0
    }
    else {
      return hidden ? -35.0 : 0.0
    }
  }
  
  private func updateHeader(hidden: Bool) {
    let dist = headerTopDist(hidden: hidden)
    guard viewModeButtonTopConstraint?.constant != dist else { return }
    viewModeButtonTopConstraint?.constant = dist
    
    UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
      self.viewModeButton.imageView?.alpha = hidden ? 0 : 1
      self.loginButton.imageView?.alpha = hidden ? 0 : 1
      self.view.layoutIfNeeded()
    }
  }
  
  func postAccessibilityScreenAnnouncement(){
    guard self.navigationController?.viewControllers.count == 1 else { return }
    let homeDescription = """
    Sie befinden sich in der Ausgabenübersicht.
    Hier finden Sie alle Ausgaben nach Datum sortiert.
    Der Bildschirm ist wie folgt aufgebaut:
    Oben befinden sich die Darstellungsoptionen und die Hilfe-Schaltfläche.
    Darunter können Sie über den Kalender ein Ausgabedatum auswählen.
    Anschließend folgt die Liste aller taz-Ausgaben bis zurück ins Jahr 2011.
    
    Im unteren Bereich befindet sich die Tableiste mit den Bereichen Home, Leseliste, Suche und Einstellungen.
    
    Ein Doppeltippen auf Home fokussiert die aktuelle Ausgabe.
    
    Mit 4 Fingern unten tippen um die Tabbar auszuwählen.
    """
    UIAccessibility.post(notification: .announcement, argument: homeDescription)
  }
  
  // creates the order for accessabillity elements. at first the viewModeButton then visible cells sorted by index path
  func updateAccessibilityOrder() {
    ///if date picker is open this is the accessibilityElement
    if datePickerOverlay.superview != nil {
      self.view.accessibilityElements = [datePickerOverlay]
      return
    }
    var elements: [Any] = []

    elements.append(viewModeButton as Any)
    if self.feederContext.isAuthenticated == false{
      elements.append(loginButton)
    }
    
    elements.appendIfPresent(HelpBusiness.accessibileHelpButton)
    
    if isHomeTiles == false {
      elements.append(dateLabel)
    }

    let visibleCells = collectionView.visibleCells
    let visibleIndexPaths = visibleCells.compactMap { collectionView.indexPath(for: $0) }
    let sortedIndexPaths = visibleIndexPaths.sorted() // IndexPath Vergleich: section then item
    
    for ip in sortedIndexPaths {
      if let cell = collectionView.cellForItem(at: ip) {
        elements.append(cell)
      }
    }
    self.view.accessibilityElements = elements
  }
    
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    openingIssue = nil
  }
  
  func reanchorCarousel(animated: Bool = false, doLayout: Bool = false) {
    guard isHomeTiles == false else { return }
    if doLayout { collectionView.layoutIfNeeded() }
    let index = carouselCenterIssueIndex ?? 0
    collectionView.scrollToItem(
      at: IndexPath(item: index, section: 0),
      at: .centeredHorizontally,
      animated: animated
    )
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    guard isHomeTiles == false else { return }
    updateCarouselSize(view.frame.size)
    reanchorCarousel(animated: false, doLayout: false)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    updateAccessibilityOrder()
    showRequestTrackingIfNeeded()
    onMainAfter(2.0) {[weak self] in self?.postAccessibilityScreenAnnouncement() }
    guard initialized == false else { return }
    initialized = true
    guard !isHomeTiles else { return }
    scrollTo(0, animated: true)
  }
  
  override func viewDidLoad() {
    collectionView.contentInsetAdjustmentBehavior = .never
    collectionView.setCollectionViewLayout(currentLayout, animated: false)
    super.viewDidLoad()
    self.collectionView.register(IssueTilesCvcCell.self,
                                 forCellWithReuseIdentifier: Self.reuseCellId)
    self.collectionView.showsHorizontalScrollIndicator = false
    self.collectionView.backgroundColor = Const.SetColor.HomeBackground.color
    self.collectionView.isAccessibilityElement = false

    self.view.insertSubview(blurView, aboveSubview: collectionView)
    self.view.addSubview(blurView)
    self.view.addSubview(statusHeader)
    self.view.addSubview(viewModeButton)
    self.view.addSubview(loginButton)
    self.view.addSubview(bottomItemsWrapper)
    self.view.addSubview(downloadButtonTapArea)

    downloadButtonTapArea.pinSize(CGSize(width: 60.0, height: 60.0))
    downloadButtonTapArea.layer.cornerRadius = 30.0
    
    self.overrideUserInterfaceStyle = .dark
    pin(blurView, to: view, exclude: .bottom)
    pin(blurView.bottom, to: viewModeButton.bottom, dist: Const.Dist2.s10)
    pin(statusHeader.bottom, to: viewModeButton.bottom, dist: 4.0)
    
    pin(loginButton.right, to: self.view.rightGuide(), dist: -9.0)
    pin(loginButton.bottom, to: viewModeButton.bottom)
    
    viewModeButton.pinWidth(75.0)
    loginButton.pinWidth(75.0)
    
    pin(statusHeader.left, to: viewModeButton.right)
    pin(statusHeader.right, to: loginButton.left, priority: .defaultLow)
    
    pin(viewModeButton.left, to: self.view.leftGuide(), dist: 11.0)
    viewModeButtonTopConstraint = pin(viewModeButton.top,
                                      to: self.view.topGuide(),
                                      dist: headerTopDist(hidden: false))

    updateLoginButton()
    updateButtonMenu()
    
    $isFacsimile.onChange{[weak self] _ in
      self?.log("isFacsimile: \(String(describing: self?.isFacsimile))")
      guard let self = self else { return }
      let indexPaths = collectionView.indexPathsForVisibleItems
      collectionView.reloadItems(at: indexPaths)
      trackScreen()
      updateButtonMenu()
      updateAccessibilityOrder()
      if isHomeTiles { return }
      guard let centerIndex = self.carousselFixCenterIndex else { return }
      ///update wrapper for carousel
      updateBottomWrapper(for: centerIndex, force: true)
    }
    
    $isHomeTiles.onChange{[weak self] _ in
      self?.log("isHomeTiles: \(String(describing: self?.isHomeTiles))")
      self?.updateCollectionViewLayout()
      onMainAfter(0.05) {[weak self] in self?.applyLayout() }
      onMain(after: 0.7) {[weak self] in
        guard self?.isHomeTiles == false else { return }
        ///fix centered issue after change from tiles to carousel 
        guard let idx = self?.carousselScrollingCenterIndex else { return }
        self?.scrollTo(idx, animated: true)
      }
      self?.trackScreen()
      self?.updateButtonMenu()
      self?.bottomItemsWrapper.isHidden = (self?.isHomeTiles ?? true)
      self?.downloadButtonTapArea.isHidden = (self?.isHomeTiles ?? true)
      self?.updateAccessibilityOrder()
    }

    bottomItemsWrapper.isHidden = isHomeTiles
    downloadButtonTapArea.isHidden = isHomeTiles
    bottomItemsWrapper.centerX()
    pin(downloadButtonTapArea.centerX, to: downloadButton.centerX)
    pin(downloadButtonTapArea.centerY, to: downloadButton.centerY)
    statusWrapperBottomConstraint = pin(bottomItemsWrapper.top, to: self.view.bottom, dist: 0)
    
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    Notification.receive(Const.NotificationNames.logoutUserDataDeleted) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    Notification.receive(Const.NotificationNames.refreshOverview) { [weak self] _ in
      self?.collectionView.reloadData()
    }
    ///Handle new issues
    Notification.receive(Const.NotificationNames.publicationDatesChanged) {[weak self] _ in
      self?.log("received publicationDatesChanged")
      if self?.view.superview == nil {
        _ = self?.service.reloadPublicationDates(refresh: nil, verticalCv: true)
        ///Old Data, Offline, In Issue, Online => Update => Back to Home: this fixes home in wired state
        self?.collectionView.reloadData()
        onMainAfter {[weak self] in self?.updateDate() }
        return
      }
      self?.statusHeader.currentStatus = .loadPreview
      guard let service = self?.service,
            let self = self else { return }
       ///if no changes not reload
      guard service.reloadPublicationDates(refresh: collectionView,
                                           verticalCv: false) else { return }
      if self.isHomeTiles == false {
        self.updateDate()
      }
      self.collectionView.reloadData()
    }
    
    ///Handle reachability changes: show offline status
    Notification.receive(Const.NotificationNames.feederUnreachable) {[weak self] _ in
      self?.statusHeader.currentStatus = .offline
    }
    ///Handle reachability changes: show offline status
    Notification.receive(Const.NotificationNames.feederReachable) {[weak self] _ in
      self?.statusHeader.currentStatus = .online
    }
    
    Notification.receive(Const.NotificationNames.newAutolIssueLoaded) {[weak self] _ in
      self?.log("received newAutolIssueLoaded on Main-Thread: \(Thread.isMainThread) send reload to ctrl's")
      self?.service.updateIssues()
      _ = self?.service.reloadPublicationDates(refresh: nil, verticalCv: false)
      self?.collectionView.reloadData()
      self?.onHome()
      let newHeaderStatus: FetchNewStatusHeader.status
      = self?.feederContext.isConnected == true ? .online : .offline
      Notification.send(Const.NotificationNames.checkForNewIssues,
                        content: newHeaderStatus,
                        error: nil,
                        sender: self?.service)
      if self?.isHomeTiles == true { return }
      onMainAfter {[weak self] in
        self?.updateBottomWrapper(for: 0, force: true)
      }
    }
    
    Notification.receive(Const.NotificationNames.issueUpdate) { [weak self] notification in
      guard self?.isHomeTiles == false,
            let nData = notification.content as? IssueCellData,
            nData.date.date.issueKey == self?.centerIssueDateKey else { return }
      self?.downloadButton.indicator.downloadState = nData.downloadState
    }
    
    updateLoginButton()
    
    setupPullToRefresh()
    updateBottomWrapper(for: 0)
    setupReceiveDownloadIssueNotification()
    applyScrollDirection(reload: false)
  }
  
  public func updateDate(){
    guard isHomeTiles == false else { return }
    guard let i = self.carousselFixCenterIndex else { return }
    updateBottomWrapper(for: i)
  }
  
  func updateButtonMenu(){ configureMenu(for: viewModeButton) }
  
  fileprivate func setupPullToRefresh() {
    Notification.receive(Const.NotificationNames.checkForNewIssues,
                         from: self.service) { [weak self] notification in
      if let status = notification.content as? FetchNewStatusHeader.status {
        print("receive status: \(status)")
        self?.statusHeader.currentStatus = status
      }
    }
    self.pullToLoadMoreHandler = {   [weak self] in
      self?.statusHeader.currentStatus = .fetchNewIssues
      URLCache.shared.removeAllCachedResponses()
      self?.service.checkForNewIssues()
    }
  }
  
  override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    guard let handler = pullToLoadMoreHandler else { return }
    if isHomeTiles {
      if -scrollView.contentOffset.y > 0.2 * scrollView.bounds.height {
        handler()
      }
    } else {
      if scrollView.contentOffset.x < -1.3 * scrollView.contentInset.left {
        handler()
      }
    }
  }
  
  private var lastContentOffset: CGFloat = 0
  
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if isRotating { return }
    if isHomeTiles {
      let offsetY = scrollView.contentOffset.y
      guard offsetY > 0 else { return }
      if offsetY > lastContentOffset {//scrolldown
        updateHeader(hidden: true)
      } else if offsetY < lastContentOffset {//scrollup
        updateHeader(hidden: false)
      }
      lastContentOffset = offsetY
      return
    }
    guard let i = carousselScrollingCenterIndex else { return }
    updateBottomWrapper(for: i)
  }
  
  private func restoreCenteredIndexIfNeeded(animated: Bool, reset: Bool) {
    guard !isHomeTiles, let cidx = restoreCarouselCenterIssueIndex else { return }
    scrollTo(cidx, animated: animated)
    guard reset else { return }
    restoreCarouselCenterIssueIndex = nil
  }
     
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    guard isHomeTiles == false else { return }
    bottomItemsWrapper.isUserInteractionEnabled = true
    guard let centerIndex = carousselFixCenterIndex else { return }
    updateBottomWrapper(for: centerIndex)
    scrollTo(centerIndex)
    updateAccessibilityOrder()
  }
  
  func scrollTo(_ index: Int, animated:Bool = true){
    updateBottomWrapper(for: index)
    self.collectionView.scrollToItem(at: IndexPath(row: index, section: 0),
                                     at: isHomeTiles ? .centeredVertically : .centeredHorizontally,
                                     animated: shouldScrollAnimatedTo(index))
  }
  
  func updateBottomWrapper(for cidx: Int, force: Bool = false){
    guard let data = service.cellData(for: cidx) else { return }
    let txt = data.labelText()
    let newKey = data.date.date.issueKey
    if force || newKey != centerIssueDateKey {
      downloadButton.indicator.downloadState = data.downloadState
      centerIssueDateKey = newKey
      carouselCenterIssueIndex = cidx
      dateLabel.setText(txt)
    }
  }
  
  fileprivate func updateLoginButton(){
    loginButton.isHidden = self.feederContext.isAuthenticated
  }
  
  func applyLayout(){
    UIView.animate(withDuration: 0.3) {[weak self] in
      guard let self = self else { return }
      self.collectionView.setCollectionViewLayout(self.currentLayout, animated: true)
    }
  }
  
  func configureMenu(for button: UIButton) {
    // Gruppe 1: Ansicht
    let appViewAction = UIAction(
      title: "Mobile Ansicht",
      image: UIImage(named: "mobile-device"),
      discoverabilityTitle: isFacsimile ? nil : "Ausgewählt",
      state: isFacsimile ? .off : .on
    ) {[weak self] _ in
      if self?.isFacsimile == false { return }
      self?.isFacsimile.toggle()  }
    
    let newspaperAction = UIAction(
      title: "Zeitungsansicht",
      image: UIImage(named: "newspaper"),
      discoverabilityTitle: isFacsimile ? "Ausgewählt":nil,
      state: isFacsimile ? .on : .off
    ) {[weak self] _ in
      if self?.isFacsimile == true { return }
      self?.isFacsimile.toggle()  }
    
    appViewAction.accessibilityHint = isFacsimile
        ? "Zur mobilen Ansicht wechseln. Empfohlen für VoiceOver."
        : "Mobile Ansicht aktiviert. Für VoiceOver empfohlen."

    newspaperAction.accessibilityHint = isFacsimile
        ? "Zeitungsansicht aktiviert. Für VoiceOver empfehlen wir jedoch die mobile Ansicht."
        : "Zur Zeitungsansicht wechseln."
    
    //Ansicht, Anzeige, Lesemodus
    let viewGroup = UIMenu(title: "Ansicht", options: .displayInline, children: [appViewAction, newspaperAction])
    
    // Gruppe 2: Darstellung
    let tileAction = UIAction(
      title: "Kacheln",
      image: UIImage(named: "tiles"),
      state: isHomeTiles ? .on : .off
    ) {[weak self] _ in
      if self?.isHomeTiles == true { return }
      self?.isHomeTiles.toggle()  }
    
    let carouselAction = UIAction(
      title: "Karussell",
      image: UIImage(named: "carousel"),
      state: isHomeTiles ? .off : .on
    ) {[weak self] _ in
      if self?.isHomeTiles == false { return }
      self?.isHomeTiles.toggle()
    }
    
    tileAction.accessibilityHint = isHomeTiles
        ? "Kachelansicht aktiviert. Für VoiceOver empfehlen wir die Karussellansicht."
        : "Zur Kachelansicht wechseln."
    carouselAction.accessibilityHint = isHomeTiles
        ? "Zur für VoiceOver optimierten Karussellansicht wechseln."
        : "Karussellansicht aktiviert. Für VoiceOver optimiert."
    
    // Anordnung, Darstellungsform
    let layoutGroup = UIMenu(title: "Anordnung", options: .displayInline, children: [carouselAction, tileAction])
    
    // Gruppe 3: Archiv
    let archiveAction = UIAction(
      title: "Gehe zu Ausgabe",
      image: UIImage(named: "calendar")) {[weak self] _ in
        guard let self = self else { return }
        showDatePicker()
      }
    let archiveGroup = UIMenu(title: "Ausgabenarchiv", options: .displayInline, children: [archiveAction])
    
    // Komplettes Menü zuweisen
    if #available(iOS 14.0, *) {
      button.menu = UIMenu(title: "", children: [viewGroup, layoutGroup, archiveGroup])
      button.showsMenuAsPrimaryAction = true
    }
  }
  
  func openArchive(){}
  
  public init(service: IssueOverviewService, feederContext: FeederContext) {
    self.service = service
    self.feederContext = feederContext
    super.init(collectionViewLayout:  UICollectionViewLayout())
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension HomeVC {
  func updateCollectionViewLayout(_ newSize: CGSize? = nil, horizontalSizeClass:UIUserInterfaceSizeClass? = nil){
    isHomeTiles
    ? updateGridSize(newSize ?? view.frame.size)
    : updateCarouselSize(newSize ?? view.frame.size, horizontalSizeClass: horizontalSizeClass)
  }

  private func updateGridSize(_ newSize:CGSize){
    //Calculate Cell Sizes...display 2...6 columns depending on device and Orientation
    //On Phone onle Portrait is enables, so it displays on every phone only 2 columns
    let minCellWidth: CGFloat = newSize.width > 800 ? 200 : 160
    let itemsPerRow : CGFloat = CGFloat(Int(newSize.width / minCellWidth))
    debug("updateGridSize: \(newSize), itemsPerRow: \(itemsPerRow)")
    let cellWidth = (newSize.width - (itemsPerRow+1.0)*gridItemSpacing)/itemsPerRow
    gridLayout.itemSize = CGSize(width: cellWidth, height: cellWidth*3/2 + 30)//expect 3:2 Format
    
    self.collectionView.contentInset
    = UIEdgeInsets.zero
  }
  
  private func updateCarouselSize(_ size:CGSize, horizontalSizeClass:UIUserInterfaceSizeClass? = nil){
    let horizontalSizeClass = horizontalSizeClass ?? self.traitCollection.horizontalSizeClass
    let defaultPageRatio:CGFloat = 0.670219
    debug("updateCarouselSize: \(size)")
    var sideInset = 0.0
    var cw: CGFloat//cellWidth
    //https://developer.apple.com/design/human-interface-guidelines/foundations/layout/
    if horizontalSizeClass == .compact && size.width < size.height * 0.6 {
      cw = size.width*0.6
      let h = cw/defaultPageRatio
      carouselLayout.itemSize = CGSize(width: cw, height: h)
      carouselLayout.minimumLineSpacing //= 60.0
      = size.width*0.155//0.3/2 out of view bei 0.4/2
      sideInset = (size.width - cw)/2
    } else {
      //Moments are 660*985
      let h = min(size.height*0.5, 985*UIScreen.main.scale)
      cw = h*defaultPageRatio
      carouselLayout.itemSize = CGSize(width: cw, height: h)
      carouselLayout.minimumLineSpacing //= 60.0
      = cw*0.3//0.3/2 out of view bei 0.4/2
      sideInset = (size.width - cw)/2
    }
    ///Warning: using maxinset! due top inset is wrong after rotation because its called from viewWillTransition
    let  offset = 0.5*( size.height - carouselLayout.maxScale*carouselLayout.itemSize.height) - 42.0
    statusWrapperBottomConstraint?.constant = -offset
    statusWrapperWidthConstraint?.constant = cw*carouselLayout.maxScale
    
    self.collectionView.contentInset
    = UIEdgeInsets(top:46.0,left:sideInset,bottom:0,right:sideInset)
  }
  
}

extension HomeVC {
  func setupReceiveDownloadIssueNotification(){
    Notification.receive("issueProgress", closure: { [weak self] notif in
      guard let issue = notif.object as? Issue else { return }
      
      guard let key = self?.centerIssueDateKey,
            issue.date.issueKey == key else { return }
      if (notif.content as? String) == "deleted" {
        self?.downloadButton.indicator.downloadState = .notStarted
      }
      else if let (loaded,total) = notif.content as? (Int64,Int64) {
        let percent = Float(loaded)/Float(total)
        if percent > 0.05 {
          if percent != 1.0 {
            self?.downloadButton.indicator.downloadState = .process
          }
          else {
            self?.downloadButton.indicator.downloadState
            = issue.downloadState
          }
          self?.downloadButton.indicator.percent = percent
        }
      }
      else if let dlState = notif.content as? DownloadStatusIndicatorState {
        onMainAfter {[weak self] in
          self?.downloadButton.indicator.downloadState = dlState
        }
      }
    })
  }
}

extension HomeVC: ReloadAfterAuthChanged {
  public func reloadOpened(){
    guard let selectedIssue = self.issueInfo?.issue as? StoredIssue else { return }
    navigationController?.popToRootViewController(animated: false)
    if selectedIssue.isDownloading == false {
      self.openIssue(selectedIssue, openLast: true)
      return
    } else {
      Notification.receiveOnce("issue", from: selectedIssue) { [weak self] notif in
        self?.openIssue(selectedIssue, openLast: true)
      }
    }
  }
}
