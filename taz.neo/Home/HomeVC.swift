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

extension OpenIssueDelegate {
  /// open a Issue, shortcut with openLast == false as default
  func openIssue(_ issue:StoredIssue, openLast: Bool = false){
    openIssue(issue, openLast: openLast || Defaults.reopenAutomaticSetting)
  }
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
  
  var centerIssueDateKey:String?
  
  var scrollLastCenterIndex: Int = 0
  
  private var pullToLoadMoreHandler: (()->())?
  static let reuseCellId = "issueCollectionViewCell"
  
  var loadingIssueInfos:[IssueDisplayService] = []
  var issueInfo:IssueDisplayService?
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
    
    downloadButton.onTapping { [weak self] _ in
      guard let idx = self?.centerIndex,
            let data = self?.service.cellData(for: idx) else { return }
      
      if self?.downloadButton.indicator.downloadState?.canOpen == true,
         let issue = data.issue {
        self?.openIssue(issue, openLast: true)
        Usage.track(Usage.event.dialog.OpenLastRead, name: "OpenFromHome")
        return
      }
      self?.downloadButton.indicator.downloadState = .waiting
      self?.service.download(issueAt: data.date.date, withAudio: false)
    }
    return v
  }()
  
  private var dataPolicyToast: NewInfoToast?
  
  // Mark: from UIComponents
  let topPadding = 5.0//UIWindow.keyWindow?.screen.bounds.height ?? 601 > 600 ? 80.0 : 5.0
  
  lazy var loginButton: UIButton = createLoginButton()
  lazy var viewModeButton: UIButton = createViewModeButton()
  lazy var datePickerOverlay = createDatePickerWrapperView()
  var datePickerOverlayTitleLabel: UIView?
  
  let datePicker = UIDatePicker()
  
  //  FrostGradientView, SoftFrostView
  lazy var blurView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.black.withAlphaComponent(0.84)
    return view
  }()
  
  lazy var blurView2: FrostGradientView = {
    let view = FrostGradientView(effect: UIBlurEffect(style: .systemMaterial))
    view.fadeHeight = 8.0;
    view.alpha = 0.97
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
    datePicker.date = service.date(at: centerIndex ?? 0)?.date ?? Date()
    self.view.addSubview(datePickerOverlay)
    pin(datePickerOverlay, to: self.view)
    datePickerOverlay.showAnimated(){[weak self] in
      self?.updateAccessibilityOrder()
      guard let target = self?.datePickerOverlayTitleLabel ?? self?.datePickerOverlay else { return }
      UIAccessibility.post(notification: .layoutChanged, argument: target)
    }
  }
  
  var centerIndex: Int? {
    guard let cv = collectionView else { return nil }
    let center = self.view.convert(cv.center, to: cv)
    return cv.indexPathForItem(at: center)?.row
  }
  
  /// Returns the index path of the center-most visible item in the collection view.
  /// If `returnFirstItemIfVisible` is `true` and the first item (item 0) is visible,
  /// it returns IndexPath(item: 0, section: 0) instead.
  ///
  /// - Parameter returnFirstItemIfVisible: Whether to prioritize returning the first item if it's visible.
  /// - Returns: The median visible IndexPath, or the first item if specified and visible.
  func centerIndexPath(returnFirstItemIfVisible: Bool = false) -> IndexPath? {
    let visibleIndexPaths = collectionView.indexPathsForVisibleItems
    guard !visibleIndexPaths.isEmpty else { return nil }
    
    // If enabled: return the first item if it is currently visible
    if returnFirstItemIfVisible,
       visibleIndexPaths.contains(where: { $0.item == 0 }) {
      return IndexPath(item: 0, section: 0)
    }
    
    // Sort index paths by section and then item
    let sorted = visibleIndexPaths.sorted { lhs, rhs in
      if lhs.section != rhs.section {
        return lhs.section < rhs.section
      } else {
        return lhs.item < rhs.item
      }
    }
    
    // Return the middle index path (numerically centered)
    let middleIndex = sorted.count / 2
    return sorted[middleIndex]
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
  
  var collectionViewLayoutInitialized = false
  private var lastKnownSize:CGSize = .zero
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    /// fixes layout when returning to home after resizing/rotating app in a pushed child vc
    if collectionViewLayoutInitialized
        && !isHomeTiles
        && lastKnownSize != view.frame.size {
      updateCarouselSize(view.frame.size)
    }
    
    guard collectionViewLayoutInitialized == false else { return }
    collectionViewLayoutInitialized = true
    let s = view.frame.size
    //initially update the not displayed one
    isHomeTiles ? updateCarouselSize(s) : updateGridSize(s)
    //initially update the currently displayed one
    updateCollectionViewLayout()
  }
  
  var nextHorizontalSizeClass:UIUserInterfaceSizeClass?
  
  override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    nextHorizontalSizeClass = newCollection.horizontalSizeClass
    super.willTransition(to: newCollection, with: coordinator)
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateCollectionViewLayout(size, horizontalSizeClass: nextHorizontalSizeClass)
    nextHorizontalSizeClass = nil
  }
  
  private func headerTopDist(hidden: Bool) -> CGFloat{
    let isBigScreen = UIWindow.keyWindow?.screen.bounds.height ?? 0 > 990
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
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    updateAccessibilityOrder()
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
      updateButtonMenu()
    }
    
    $isHomeTiles.onChange{[weak self] _ in
      self?.log("isHomeTiles: \(String(describing: self?.isHomeTiles))")
      self?.updateCollectionViewLayout()
      self?.applyLayout()
      self?.updateButtonMenu()
      self?.bottomItemsWrapper.isHidden = (self?.isHomeTiles ?? true)
    }
    

    bottomItemsWrapper.isHidden = isHomeTiles
    bottomItemsWrapper.centerX()
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
      self?.statusHeader.currentStatus = .none
    }
    
    Notification.receive(Const.NotificationNames.newAutolIssueLoaded) {[weak self] _ in
      self?.log("received newAutolIssueLoaded on Main-Thread: \(Thread.isMainThread) send reload to ctrl's")
      self?.service.updateIssues()
      _ = self?.service.reloadPublicationDates(refresh: nil, verticalCv: false)
      self?.collectionView.reloadData()
      self?.onHome()
      Notification.send(Const.NotificationNames.checkForNewIssues,
                        content: FetchNewStatusHeader.status.none,
                        error: nil,
                        sender: self?.service)
      if self?.isHomeTiles == true { return }
      onMainAfter {[weak self] in
        self?.updateBottomWrapper(for: 0, force: true)
      }
    }
#warning("ToDo 1.6.0")//????
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
    guard let i = self.centerIndex else { return }
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
  
  var centerIndex2: Int? { return centerIndexPath(returnFirstItemIfVisible: true)?.row }
  
  private var lastContentOffset: CGFloat = 0
  
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
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
    guard let i = centerIndex, scrollLastCenterIndex != i else { return }
    scrollLastCenterIndex = i
    updateBottomWrapper(for: i)
  }
     
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    guard isHomeTiles == false else { return }
    bottomItemsWrapper.isUserInteractionEnabled = true
    guard let centerIndex = centerIndex else { return }
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
      title: "App-Ansicht",
      image: UIImage(systemName: "iphone.gen3"),
      state: isFacsimile ? .off : .on
    ) {[weak self] _ in self?.isFacsimile.toggle()  }
    
    let newspaperAction = UIAction(
      title: "Zeitungsansicht",
      image: UIImage(systemName: "newspaper"),
      state: isFacsimile ? .on : .off
    ) {[weak self] _ in self?.isFacsimile.toggle()  }
    
    let viewGroup = UIMenu(title: "Ansicht", options: .displayInline, children: [appViewAction, newspaperAction])
    
    // Gruppe 2: Darstellung
    let tileAction = UIAction(
      title: "Kachelansicht",
      image: UIImage(systemName: "square.grid.2x2"),
      state: isHomeTiles ? .on : .off
    ) {[weak self] _ in self?.isHomeTiles.toggle()  }
    
    let carouselAction = UIAction(
      title: "Karussell",
      image: UIImage(systemName: "rectangle.split.3x1"),
      state: isHomeTiles ? .off : .on
    ) {[weak self] _ in self?.isHomeTiles.toggle()  }
    
    let layoutGroup = UIMenu(title: "Layout", options: .displayInline, children: [tileAction, carouselAction])
    
    // Gruppe 3: Archiv
    let archiveAction = UIAction(
      title: "Gehe zu Ausgabe",
      image: UIImage(systemName: "calendar")) {[weak self] _ in
        guard let self = self else { return }
        showDatePicker()
      }
    let archiveGroup = UIMenu(title: "Ausgaben Archiv", options: .displayInline, children: [archiveAction])
    
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
  //  public func collectionView(_ collectionView: UICollectionView,
  //                             layout collectionViewLayout: UICollectionViewLayout,
  //                             sizeForItemAt indexPath: IndexPath) -> CGSize {
  //    return cellSize
  //  }
  
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
    log("updateGridSize: \(newSize), itemsPerRow: \(itemsPerRow)")
    let cellWidth = (newSize.width - (itemsPerRow+1.0)*gridItemSpacing)/itemsPerRow
    gridLayout.itemSize = CGSize(width: cellWidth, height: cellWidth*3/2 + 30)//expect 3:2 Format
    
    self.collectionView.contentInset
    = UIEdgeInsets.zero
  }
  
  private func updateCarouselSize(_ size:CGSize, horizontalSizeClass:UIUserInterfaceSizeClass? = nil){
    lastKnownSize = size
    let horizontalSizeClass = horizontalSizeClass ?? self.traitCollection.horizontalSizeClass
    let defaultPageRatio:CGFloat = 0.670219
    log("updateCarouselSize: \(size)")
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
    let  offset = 0.5*( size.height
                        - UIWindow.maxInset
                        - carouselLayout.maxScale*carouselLayout.itemSize.height) - 20
    //    print("dist is: -0,5* (\(size.height)   -   \(UIWindow.topInset)   -   \(layout.maxScale*layout.itemSize.height))=\(statusWrapperBottomConstraint?.constant ?? 0)\n  0.5 * ( size.height - UIWindow.safeInsets.top - HomeTVC.defaultHeight - layout.maxScale*layout.itemSize.height)")
//     topStatusButtonConstraint?.constant = offset
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
            = issue.hasLastReadForCurrentMode == true
            ? .read
            : .downloaded
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
