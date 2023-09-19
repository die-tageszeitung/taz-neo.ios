//
//  NewIssueCVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.01.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib


class IssueCarouselCVC: UICollectionViewController, IssueCollectionViewActions {
  @Default("showBottomTilesAnimation")
  public var showBottomTilesAnimation: Bool
  
  @Default("bottomTilesAnimationLastShown")
  public var bottomTilesAnimationLastShown: Date
  
  @Default("bottomTilesLastShown")
  public var bottomTilesLastShown: Date
  
  @Default("bottomTilesShown")
  public var bottomTilesShown: Int {
    didSet { if bottomTilesShown > 10 { showBottomTilesAnimation = false }  }
  }
  
  /// scroll from left to right or vice versa
  @Default("scrollFromLeftToRight")
  public var scrollFromLeftToRight: Bool {
    didSet {
      if scrollFromLeftToRight {
        collectionView.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
      }
      else {
        collectionView.transform = .identity
      }
      collectionView.reloadData()
    }
  }
  
  private var topStatusButtonConstraint:NSLayoutConstraint?
  private var statusWrapperBottomConstraint: NSLayoutConstraint?
  private var statusWrapperWidthConstraint:NSLayoutConstraint?
  
  /// Animation for ScrollDown
  var scrollDownAnimationView: ScrollDownAnimationView?
  
  private var pullToLoadMoreHandler: (()->())?
  private static let reuseCellId = "issueCollectionViewCell"
  
  var transitionLastCenterIndex: Int?
  var scrollLastCenterIndex: Int = 0
  var preventApiLoadUntilIndex: Int?
  
  var centerIssueDateKey:String?
  
  var centerIndex: Int? {
    guard let cv = collectionView else { return nil }
    let center = self.view.convert(cv.center, to: cv)
    return cv.indexPathForItem(at: center)?.row
  }
  
  let downloadButton = DownloadStatusButton()
  let dateLabel = CrossfadeLabel()
  
  var pickerCtrl : DatePickerController?
  var overlay : Overlay?
  
  lazy var bottomItemsWrapper: UIView = {
    let v = UIView()
    v.addSubview(downloadButton)
    v.addSubview(dateLabel)
    statusWrapperWidthConstraint = v.pinWidth(0)
    dateLabel.contentFont().textColor = Const.Colors.appIconGrey
    dateLabel.textAlignment = .center
    pin(downloadButton, to: v, exclude: .left).top?.constant = -8.0
    downloadButton.color = Const.Colors.appIconGrey
    pin(dateLabel.left, to: v.left, dist: 25, priority: .defaultLow)
    pin(dateLabel.right, to: v.right, dist: -25, priority: .defaultLow)
    v.pinHeight(28)
    
    dateLabel.onTapping {[weak self] _ in
      self?.showDatePicker()
    }
    downloadButton.onTapping { [weak self] _ in
      if self?.downloadButton.indicator.downloadState == .done { return }
      guard let idx = self?.centerIndex,
            let data = self?.service.cellData(for: idx) else { return }
      if let issue = data.issue {
        self?.downloadButton.indicator.downloadState = .waiting
        self?.service.download(issueAt: data.date.date)
      }
    }
    return v
  }()
  
  
  lazy var statusHeader = FetchNewStatusHeader()
  var visibleCellsCount: Int = 6
  
  func evaluateVisibleCellsCount(){
    visibleCellsCount = max(collectionView.visibleCells.count + 2, 6)
  }

  var service: IssueOverviewService
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.downloadButton.layoutSubviews()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Register cell classes
    self.collectionView!.register(IssueCollectionViewCell.self,
                                  forCellWithReuseIdentifier: Self.reuseCellId)
    self.collectionView.showsHorizontalScrollIndicator = false
    self.collectionView.backgroundColor = .black
    
    if scrollFromLeftToRight {
      collectionView.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
    }
    
    self.view.addSubview(bottomItemsWrapper)
    bottomItemsWrapper.centerX()
    statusWrapperBottomConstraint = pin(bottomItemsWrapper.top, to: self.view.bottom, dist: 0)
    setupPullToRefresh()
    updateBottomWrapper(for: 0)
    setupReceiveDownloadIssueNotification()
  }
    
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    if transitionLastCenterIndex == nil { transitionLastCenterIndex = centerIndex}
    super.viewWillTransition(to: size, with: coordinator)
    onMain{[weak self] in
      guard let idx = self?.transitionLastCenterIndex else { return }
      self?.transitionLastCenterIndex = nil
      self?.collectionView.scrollToItem(at: IndexPath(row: idx, section: 0),
                      at: .centeredHorizontally,
                      animated: true)
    }
  }
    

  override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    if let handler = pullToLoadMoreHandler,
       scrollView.contentOffset.x < -1.3*self.collectionView.contentInset.left {
      handler()
    }
  }
  
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard let i = centerIndex, scrollLastCenterIndex != i else { return }
    scrollLastCenterIndex = i
    updateBottomWrapper(for: i)
  }
     
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    bottomItemsWrapper.isUserInteractionEnabled = true
    guard let centerIndex else { return }
    updateBottomWrapper(for: centerIndex)
    scrollTo(centerIndex)
  }
  
  func scrollTo(_ index: Int, animated:Bool = true){
    updateBottomWrapper(for: index)
    self.collectionView.scrollToItem(at: IndexPath(row: index, section: 0),
                                     at: .centeredHorizontally,
                                     animated: true)
  }
  
  func updateBottomWrapper(for cidx: Int, force: Bool = false){
    guard let data = service.cellData(for: cidx) else { return }
    
    let txt = data.date.validityDateText(timeZone: GqlFeeder.tz, short: true)
    let newKey = data.date.date.issueKey
    if force || newKey != centerIssueDateKey {
      downloadButton.indicator.downloadState = data.downloadState
      centerIssueDateKey = newKey
      dateLabel.setText(txt)
    }
  }
  
  public func updateDate(){
    guard let i = self.centerIndex else { return }
    updateBottomWrapper(for: i)
  }
    
  // MARK: UICollectionViewDataSource
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return service.publicationDates.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    guard let cell = cell as? IssueCollectionViewCell,
          let data = cell.data else { return }
    cell.data = nil
    service.removeFromLoadFromRemote(key: data.key)
  }
  
  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    guard let cell = cell as? IssueCollectionViewCell,
          let data = service.cellData(for: indexPath.row) else { return }
    cell.data = data
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: Self.reuseCellId,
      for: indexPath)
    guard let cell = cell as? IssueCollectionViewCell else {
      return cell
    }
    
    if scrollFromLeftToRight {
      cell.contentView.transform = CGAffineTransform(rotationAngle: -CGFloat.pi)
    }
    else {
      cell.contentView.transform = CGAffineTransform(rotationAngle: 0)
    }
    
    if cell.momentView.interactions.isEmpty {
      let menuInteraction = UIContextMenuInteraction(delegate: self)
      cell.momentView.addInteraction(menuInteraction)
      cell.backgroundColor = .black
    }
    return cell
  }

  var loadingMoment: MomentView? {
    didSet {
      loadingMoment?.isActivity = true
      oldValue?.isActivity = false
    }
  }
  
  // MARK: > Cell Click/Select
  public override func collectionView(_ collectionView: UICollectionView,
                                      didSelectItemAt indexPath: IndexPath) {
    guard let data = self.service.cellData(for: indexPath.row),
          let issue = data.issue else {
      error("Issue not available try later")
      return
    }
    loadingMoment = (collectionView.cellForItem(at: indexPath) as? IssueCollectionViewCell)?.momentView

    if data.downloadState == .notStarted {
      downloadButton.indicator.downloadState = .waiting
    }
    (parent as? OpenIssueDelegate)?.openIssue(issue)
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    loadingMoment = nil
  }
  
  public init(service: IssueOverviewService) {
    self.service = service
    let layout = IssueCarouselFlowLayout()
    layout.scrollDirection = .horizontal
    layout.sectionInset = .zero
    layout.minimumInteritemSpacing = 1000000.0
    
    super.init(collectionViewLayout: layout)
    
    Notification.receive(Const.NotificationNames.issueUpdate) { [weak self] notification in
        guard let nData = notification.content as? IssueCellData,
              nData.date.date.issueKey == self?.centerIssueDateKey else { return }
      self?.downloadButton.indicator.downloadState = nData.downloadState
      }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}


extension IssueCarouselCVC {
  func reloadVisibleCells() {
    let vips = self.collectionView.indexPathsForVisibleItems
    for ip in vips {
      _ = self.collectionView.cellForItem(at: ip)
    }
    UIView.performWithoutAnimation {
      self.collectionView.reloadItems(at: vips)
    }
  }
}

extension IssueCarouselCVC {
  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    return _contextMenuInteraction(interaction, configurationForMenuAtLocation: location)
  }
}

extension IssueCarouselCVC {
  func updateCarouselSize(_ size:CGSize, horizontalSizeClass:UIUserInterfaceSizeClass){
    guard let layout = self.collectionView.collectionViewLayout as? CarouselFlowLayout else { return }
    let defaultPageRatio:CGFloat = 0.670219
    
    var sideInset = 0.0
    var cw: CGFloat//cellWidth
    //https://developer.apple.com/design/human-interface-guidelines/foundations/layout/
    if horizontalSizeClass == .compact && size.width < size.height * 0.6 {
      cw = size.width*0.6
      let h = cw/defaultPageRatio
      layout.itemSize = CGSize(width: cw, height: h)
      layout.minimumLineSpacing //= 60.0
      = size.width*0.155//0.3/2 out of view bei 0.4/2
      sideInset = (size.width - cw)/2
    } else {
      //Moments are 660*985
      let h = min(size.height*0.5, 985*UIScreen.main.scale)
      cw = h*defaultPageRatio
      layout.itemSize = CGSize(width: cw, height: h)
      layout.minimumLineSpacing //= 60.0
      = cw*0.3//0.3/2 out of view bei 0.4/2
      sideInset = (size.width - cw)/2
    }
    ///Warning: using maxinset! due top inset is wrong after rotation because its called from viewWillTransition
    let  offset = 0.5*( size.height
             - UIWindow.maxInset
             - layout.maxScale*layout.itemSize.height) - 20
//    print("dist is: -0,5* (\(size.height)   -   \(UIWindow.topInset)   -   \(layout.maxScale*layout.itemSize.height))=\(statusWrapperBottomConstraint?.constant ?? 0)\n  0.5 * ( size.height - UIWindow.safeInsets.top - HomeTVC.defaultHeight - layout.maxScale*layout.itemSize.height)")
    topStatusButtonConstraint?.constant = offset
    statusWrapperBottomConstraint?.constant = -offset
    statusWrapperWidthConstraint?.constant = cw*layout.maxScale
    
    self.collectionView.contentInset
    = UIEdgeInsets(top:0,left:sideInset,bottom:0,right:sideInset)
    
  }
  
}


extension IssueCarouselCVC {
  
  fileprivate func setupPullToRefresh() {
    //add status Header
    self.view.addSubview(statusHeader)
    pin(statusHeader.left, to: self.view.left)
    pin(statusHeader.right, to: self.view.right)
    topStatusButtonConstraint = pin(statusHeader.bottom, to: self.view.top, dist: 0)
       
    Notification.receive(Const.NotificationNames.checkForNewIssues, from: self.service) { [weak self] notification in
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
}


extension IssueCarouselCVC {
  func setupReceiveDownloadIssueNotification(){
    Notification.receive("issueProgress", closure: { [weak self] notif in
      guard let key = self?.centerIssueDateKey,
            (notif.object as? Issue)?.date.issueKey == key else { return }
      if let (loaded,total) = notif.content as? (Int64,Int64) {
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


// MARK: - showScrollDownAnimationIfNeeded
extension IssueCarouselCVC {
  
  
  /// shows an animation to generate the user's interest in the lower area
  ///  **Requirements to show animation:**
  ///
  ///  **showBottomTilesAnimation** ConfigDefault is true
  ///  **bottomTilesLastShown** is at least 24h ago
  ///  **bottomTilesAnimationLastShown** is at least 30s ago
  ///  - no active animation
  ///
  /// - Parameter delay: delay after animation started if applicable
  func showScrollDownAnimationIfNeeded(delay:Double = 2.0) {
    if showBottomTilesAnimation == false { return }
    guard (Date().timeIntervalSince(bottomTilesLastShown) >= 60*60*24) &&
          (Date().timeIntervalSince(bottomTilesAnimationLastShown) >= 30)
    else { return }
    
    if scrollDownAnimationView == nil {
      scrollDownAnimationView = ScrollDownAnimationView()
    }
    
    guard let scrollDownAnimation = scrollDownAnimationView else {
      return
    }
    
    if scrollDownAnimation.superview == nil {
      self.view.addSubview(scrollDownAnimation)
      scrollDownAnimation.centerX()
      pin(scrollDownAnimation.bottom, to: self.view.bottomGuide(), dist: -12)
    }
    
    onMainAfter(delay) {   [weak self] in
      self?.scrollDownAnimationView?.animate()
      self?.bottomTilesAnimationLastShown = Date()
    }
  }
}

extension IssueCarouselCVC {
  func showDatePicker(){    
    if pickerCtrl == nil {
      let selected = service.date(at: centerIndex ?? 0)?.date
      pickerCtrl = DatePickerController(minimumDate: service.firstIssueDate,
                                        maximumDate: service.lastIssueDate,
                                         selectedDate: selected ?? service.firstIssueDate)
      pickerCtrl?.pickerFont = Const.Fonts.contentFont
    }
    guard let pickerCtrl = pickerCtrl else { return }
    
    if overlay == nil {
      overlay = Overlay(overlay:pickerCtrl , into: self)
      overlay?.enablePinchAndPan = false
      overlay?.maxAlpha = 0.9
    }
    
    pickerCtrl.doneHandler = {[weak self] in
      guard let self else { return }
      let date = pickerCtrl.selectedDate
      let idx = self.service.nextIndex(for: date)
      self.scrollTo(idx, animated: true)
      self.overlay?.close(animated: true)
    }
    overlay?.onClose(closure: {  [weak self] in
      self?.overlay = nil
      (self?.parent as? HomeTVC)?.tilesController.isActive = true
      self?.pickerCtrl = nil
    })

    overlay?.openAnimated(fromView: bottomItemsWrapper, toView: pickerCtrl.content)
    (self.parent as? HomeTVC)?.tilesController.isActive = false
  }
}
