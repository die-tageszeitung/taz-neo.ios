//
//  HomeVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 23.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

class HomeVC: UICollectionViewController {
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  /// Are we in facsimile mode
  @Default("isHomeTiles")
  public var isHomeTiles: Bool
  
  var centerIssueDateKey:String?
  
  var scrollLastCenterIndex: Int = 0
  
  private var pullToLoadMoreHandler: (()->())?
  static let reuseCellId = "issueCollectionViewCell"
  
  var loadingIssueInfos:[IssueDisplayService] = []
  var issueInfo:IssueDisplayService?
  var feederContext:FeederContext
  var service: IssueOverviewService
  
  lazy var statusHeader = FetchNewStatusHeader()
  public var issueSelectionChangeDelegate: IssueSelectionChangeDelegate?
  private var topStatusButtonConstraint:NSLayoutConstraint?
  private var statusWrapperBottomConstraint: NSLayoutConstraint?
  private var statusWrapperWidthConstraint:NSLayoutConstraint?
  
  /// Temporary variable to prevent the same issue from being opened multiple times due to repeated touches.
  var openingIssue: Issue?
  
  let downloadButton = DownloadStatusButton()
  let dateLabel = CrossfadeLabel()
  
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
    statusWrapperWidthConstraint = v.pinWidth(0)
    dateLabel.contentFont()
    dateLabel.textAlignment = .center
    pin(downloadButton, to: v, exclude: .left).top?.constant = -8.0
    downloadButton.color = Const.SetColor.HomeText.dynamicColor
    dateLabel.textColor = Const.SetColor.HomeText.dynamicColor
    dateLabel.centerX()
    v.pinHeight(28)
    
    dateLabel.onTapping {[weak self] _ in
      guard let self = self else { return }
      showDatePicker(sourceView: dateLabel)
      Usage.track(Usage.event.dialog.IssueDatePicker)
    }
    downloadButton.onTapping { [weak self] _ in
      if self?.downloadButton.indicator.downloadState == .done { return }
      guard let idx = self?.centerIndex,
            let data = self?.service.cellData(for: idx) else { return }
      if let issue = data.issue {
        self?.downloadButton.indicator.downloadState = .waiting
        self?.service.download(issueAt: data.date.date, withAudio: false)
        CoachmarksBusiness.shared.deactivateCoachmark(Coachmarks.IssueCarousel.loading)
      }
    }
    return v
  }()
  
  private var dataPolicyToast: NewInfoToast?
  
  // Mark: from UIComponents
  var pickerCtrl : DatePickerController?
  var overlay : Overlay?
  
  lazy var loginButton: UIView = createLoginButton()
  lazy var viewModeButton: UIButton = createViewModeButton()
  
  //  FrostGradientView, SoftFrostView
  lazy var blurView: FrostGradientView = {
    let view = FrostGradientView(effect: UIBlurEffect(style: .systemMaterial))
    view.fadeHeight = 50;
    view.alpha = 0.97
    return view
  }()
  
  func onHome(){
    collectionView.scrollToItem(at: IndexPath(row: 0, section: 0),
                                at: isHomeTiles ? .top : .centeredHorizontally,
                                animated: true)
  }
  
  var centerIndex1: Int? {
    guard let cv = collectionView else { return nil }
    let center = self.view.convert(cv.center, to: cv)
    return cv.indexPathForItem(at: center)?.row
  }
  
  var centerIndex: Int? { return centerIndexPath(returnFirstItemIfVisible: true)?.row }
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
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let s = view.frame.size
    isHomeTiles ? updateCarouselSize(s) : updateGridSize(s)//initially the not displayed one
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
  
  override func viewDidLoad() {
    collectionView.setCollectionViewLayout(currentLayout, animated: false)
    super.viewDidLoad()
    self.collectionView.register(IssueTilesCvcCell.self,
                                 forCellWithReuseIdentifier: Self.reuseCellId)
    self.collectionView.showsHorizontalScrollIndicator = false
    self.collectionView.backgroundColor = Const.SetColor.HomeBackground.color
    
    self.view.addSubview(viewModeButton)
    updateButtonMenu()
    self.overrideUserInterfaceStyle = .dark
    pin(viewModeButton.left, to: self.view.leftGuide(), dist: 15.0)
    pin(viewModeButton.top, to: self.view.topGuide(), dist: 25.0)
    
    updateLoginButton()
    
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
    
    self.view.addSubview(bottomItemsWrapper)
    bottomItemsWrapper.isHidden = isHomeTiles
    bottomItemsWrapper.centerX()
    statusWrapperBottomConstraint = pin(bottomItemsWrapper.top, to: self.view.bottom, dist: 0)
    
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    Notification.receive(Const.NotificationNames.logoutUserDataDeleted) { _ in
      onMainAfter {[weak self] in self?.updateLoginButton() }
    }
    updateLoginButton()
    
    setupPullToRefresh()
    updateBottomWrapper(for: 0)
    setupReceiveDownloadIssueNotification()
    
    self.view.insertSubview(blurView, aboveSubview: collectionView)
    pin(blurView, to: view, exclude: .bottom)
    blurView.pinHeight(150)
  }
  
  func updateButtonMenu(){ configureMenu(for: viewModeButton) }
  
  fileprivate func setupPullToRefresh() {
    //add status Header
    self.view.addSubview(statusHeader)
    pin(statusHeader.left, to: viewModeButton.right)
    pin(statusHeader.right, to: self.view.right)
    topStatusButtonConstraint = pin(statusHeader.bottom, to: self.view.top, dist: 0)
       
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
  
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard let i = centerIndex, scrollLastCenterIndex != i else { return }
    scrollLastCenterIndex = i
    updateBottomWrapper(for: i)
  }
     
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    bottomItemsWrapper.isUserInteractionEnabled = true
    guard let centerIndex = centerIndex1 else { return }
    updateBottomWrapper(for: centerIndex)
    scrollTo(centerIndex)
  }
  
  func scrollTo(_ index: Int, animated:Bool = true){
    updateBottomWrapper(for: index)
    self.collectionView.scrollToItem(at: IndexPath(row: index, section: 0),
                                     at: isHomeTiles ? .centeredVertically : .centeredHorizontally,
                                     animated: shouldScrollAnimatedTo(index))
  }
  
  func updateBottomWrapper(for cidx: Int, force: Bool = false){
    guard let data = service.cellData(for: cidx) else { return }
    issueSelectionChangeDelegate?.setCurrent(cellData: data,
                                             idx: cidx)
    let isMonthly = service.feed.cycle == .monthly
    let txt = isMonthly ? data.date.date.gMonthYear(tz: GqlFeeder.tz) :
                          data.date.validityDateText(short: true)
    let newKey = data.date.date.issueKey
    if force || newKey != centerIssueDateKey {
      downloadButton.indicator.downloadState = data.downloadState
      centerIssueDateKey = newKey
      dateLabel.setText(txt)
    }
  }
  
  fileprivate func updateLoginButton(){
    if self.feederContext.isAuthenticated {
      loginButton.removeFromSuperview()
      //      updateAccessibillityHelper()
      return
    }
    let topPadding = UIWindow.keyWindow?.screen.bounds.height ?? 601 > 600 ? 20.0 : 5.0
    view.addSubview(loginButton)
    pin(loginButton.right, to: view.rightGuide())
    pin(loginButton.top, to: view.topGuide(), dist: topPadding)
    //    updateAccessibillityHelper()
  }
  
  func applyLayout(){
    UIView.animate(withDuration: 0.3) {[weak self] in
      guard let self = self else { return }
      collectionView.setCollectionViewLayout(currentLayout, animated: true)
    }completion: {[weak self] _ in
      guard let self = self, !isHomeTiles, let targetIp = centerIndexPath(returnFirstItemIfVisible: true) else { return }
      collectionView.scrollToItem(at: targetIp,
                                  at: .centeredHorizontally,
                                  animated: true)
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
    
    let layoutGroup = UIMenu(title: "Darstellung", options: .displayInline, children: [tileAction, carouselAction])
    
    // Gruppe 3: Archiv
    let archiveAction = UIAction(
      title: "Gehe zu Ausgabe",
      image: UIImage(systemName: "calendar")) {[weak self] _ in
        guard let self = self else { return }
        showDatePicker(sourceView: collectionView)
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
     topStatusButtonConstraint?.constant = offset
    statusWrapperBottomConstraint?.constant = -offset
    statusWrapperWidthConstraint?.constant = cw*carouselLayout.maxScale
    
    self.collectionView.contentInset
    = UIEdgeInsets(top:0,left:sideInset,bottom:0,right:sideInset)
  }
  
}

extension HomeVC {
  func setupReceiveDownloadIssueNotification(){
    Notification.receive("issueProgress", closure: { [weak self] notif in
      guard let key = self?.centerIssueDateKey,
            (notif.object as? Issue)?.date.issueKey == key else { return }
      if (notif.content as? String) == "deleted" {
        self?.downloadButton.indicator.downloadState = .notStarted
      }
      else if let (loaded,total) = notif.content as? (Int64,Int64) {
        let percent = Float(loaded)/Float(total)
        if percent > 0.05 {
          if percent != 1.0 {
            self?.downloadButton.indicator.downloadState = .process
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


protocol IssueSelectionChangeDelegate {
  /// Register Handler for Current Object
  /// Will call applyStyles() on register @see extension UIStyleChangeDelegate
  func setCurrent(cellData: IssueCellData, idx: Int)
}


extension HomeVC: IssueSelectionChangeDelegate {
  func  setCurrent(cellData: IssueCellData, idx: Int) {
//    if cellData.issue?.audioFiles.count ?? 0 > 0 {
//      accessibilityPlayHelper.text = "taz vom\n\(cellData.date.date.short) abspielen"
//      accessibilityPlayHelper.accessibilityLabel = "taz vom\n\(cellData.date.date.short) abspielen"
//    }
//    else {
//      accessibilityPlayHelper.text = "taz vom\n\(cellData.date.date.short) laden und abspielen"
//      accessibilityPlayHelper.accessibilityLabel = "taz vom\n\(cellData.date.date.short) laden und abspielen"
//    }
  }
}
