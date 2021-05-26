//
//  IssueVcWithBottomTiles.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 06.01.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// This Class  extends IssueVC for a bottom Area with a UICollectionVC
/// written to have a minimal Impact on IssueVC on Integration
public class IssueVcWithBottomTiles : UICollectionViewController {
  
  /// should show PDF Info Toast on startup (from config defaults)
  @DefaultBool(key: "showPdfInfoToast")
  public var showPdfInfoToast: Bool
  
  /// Are we in facsimile mode
  @DefaultBool(key: "isFacsimile")
  public var isFacsimile: Bool
  
  // MARK: - Properties
  ///moved issues here to prevent some performance and other issues
  ///obsolate after refactoring & full integration
  public var issues: [Issue] = []

  public var toolBar = ContentToolbar()
  var toolbarHomeButton: Button<ImageView>?
  
  private let reuseIdentifier = "issueVcCollectionViewBottomCell"
  private let reuseHeaderIdentifier = "issueVcCollectionViewHeader"
  private let reuseFooterIdentifier = "issueVcCollectionViewFooter"
  private let itemSpacing:CGFloat = UIWindow.shortSide > 320 ? 30.0 : 20.0
  private let lineSpacing:CGFloat = 20.0
  
  /// size if the buttons with up/down arrow
  let scrollButtonSize = CGSize(width: 80, height: 30)
  let scrollUpButtonAreaHeight:CGFloat=30
  
  /// used to hold IssueVC's content (carousel)
  ///obsolate after refactoring & full integration
  let headerView: UIView = {
    let v = UIView()
    v.backgroundColor = .black
    return v
  }()
  
  ///Array of Section Header Views
  lazy var headerViews : [UIView] = {
    let section2Header = UIView()
    return [headerView,section2Header]
  }()
  
  /// size of the issue items in bottom section;
  lazy var cellSize : CGSize = CGSize(width: 20, height: 20)
  
  /// top top Scroll Target Position, to scroll to if scroll top
  var topPos : CGFloat { get { return -UIWindow.topInset }}
  
  /// activity indicator for Bottom Ares, if load more requested
  let footerActivityIndicator = UIActivityIndicatorView(style: .white)
  
  /// offset for snapping between top area (IssueCarousel) and Bottom Area (tile view)
  var scrollSnapHeight : CGFloat { get { return UIScreen.main.bounds.size.height }}
  
  /// prevent multiple times initialization
  /// for unknown reason viewDidLoad called multiple times within the inheritance: IssueVC->IssueVcWithBottomTiles
  /// obsolate after refactoring & full integration
  var initialized=false
  
  /// Indicate if current state is top on IssueCaroussel or Bottom on Tiele View
  var isUp:Bool = true {
    didSet {
      (self as? IssueVC)?.updateToolbarHomeIcon()
    }
  }
  

  
  /// Indicate scrollAnimation started by Arrow Button touch, to prevent disruption of animation
  var isButtonActionScrolling:Bool = false {
    didSet {
      if isButtonActionScrolling == true {
        onThreadAfter{ [weak self] in
          guard let self = self else { return }
          self.isButtonActionScrolling = false
        }
      }
    }
  }
  
  // MARK: - Lifecycle
  
  init() {
    let layout = UICollectionViewFlowLayout()
    layout.sectionInset = UIEdgeInsets(top: self.itemSpacing,
                                       left: self.itemSpacing,
                                       bottom: self.itemSpacing,
                                       right: self.itemSpacing)
    layout.minimumLineSpacing = self.lineSpacing
    layout.minimumInteritemSpacing = self.itemSpacing
    ///layout.itemSize not wor, need to implement: UICollectionViewDelegateFlowLayout -> sizeForItemAt
    ///otherwise top area (issue carousel) woun't be displayed
    super.init(collectionViewLayout: layout)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    if initialized { return }
    initialized = true
    collectionView?.showsVerticalScrollIndicator = false
    collectionView?.showsHorizontalScrollIndicator = false
    // Register cell classes
    collectionView?.register(IssueVCBottomTielesCVCCell.self, forCellWithReuseIdentifier: reuseIdentifier)
    collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: reuseHeaderIdentifier)
    collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: reuseFooterIdentifier)
    setupToolbar()
    showPdfInfoIfNeeded()
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateCollectionViewLayout(self.view.frame.size)
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateCollectionViewLayout(size)
  }
  
  func updateCollectionViewLayout(_ forParentSize: CGSize){
    //Calculate Cell Sizes...display 2...6 columns depending on device and Orientation
    //On Phone onle Portrait is enables, so it displays on every phone only 2 columns
    let minCellWidth: CGFloat = forParentSize.width > 800 ? 200 : 160
    let itemsPerRow : CGFloat = CGFloat(Int(forParentSize.width / minCellWidth))
    let cellWidth = (forParentSize.width - (itemsPerRow+1.0)*itemSpacing)/itemsPerRow
    cellSize = CGSize(width: cellWidth, height: cellWidth*3/2 + 30)//expect 3:2 Format
    collectionView.collectionViewLayout.invalidateLayout()
  }

  func setupToolbar() {
    //the button tap closures
    let onHome:((ButtonControl)->()) = { [weak self] _ in
      guard let self = self as? IssueVC else { return }
      self.issueCarousel.carousel.scrollto(0, animated: true)
      if self.isUp == false {
        self.scrollUp()
        self.isUp = true //ensure property is set correctly
        /// sometimes on heavy load its been scrolled up but property did not set correctly due this happen
        /// in delegate...wich was interrupted
      }
    }
    
    let onPDF:((ButtonControl)->()) = {   [weak self] control in
      guard let self = self else { return }
      self.isFacsimile = !self.isFacsimile
      
      if let imageButton = control as? Button<ImageView> {
        imageButton.buttonView.name = self.isFacsimile ? "mobileDevice" : "newspaper"
        imageButton.buttonView.accessibilityLabel = self.isFacsimile ? "App Ansicht" : "Zeitungsansicht"
      }
      self.collectionView.reloadData()
      print("PDF Pressed")
    }
    
    //the buttons and alignments
    toolbarHomeButton = toolBar.addImageButton(name: "home",
                               onPress: onHome,
                               direction: .right,
                               accessibilityLabel: "Übersicht")
    
    _ = toolBar.addImageButton(name: self.isFacsimile ? "mobileDevice" : "newspaper",
                               onPress: onPDF,
                               direction: .left,
                               accessibilityLabel: self.isFacsimile ? "App Ansicht" : "Zeitungsansicht")
        
    //the toolbar setup itself
    toolBar.applyDefaultTazSyle()
    toolBar.pinTo(self.view)
  }
}

// MARK: - UICollectionViewDataSource
extension IssueVcWithBottomTiles {
  public override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 2
  }
  
  public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    if section == 1 {
      return issues.count
    }
    return 0
  }
  
  // MARK: > Cell
  public override func collectionView(_ collectionView: UICollectionView,
                                      cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
    let _cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                   for: indexPath)
    
    guard let cell = _cell as? IssueVCBottomTielesCVCCell else { return _cell }
    
    if let issueVC = self as? IssueVC,
       let issue = issues.valueAt(indexPath.row) {
      
      cell.issue = issue
      
      if let img = issueVC.feeder.momentImage(issue: issue, isPdf: isFacsimile) {
        cell.momentView.image = img
      }
      else {
        cell.momentView.image = nil
      }
      
      if issue.isDownloading == false && issue.isComplete == false {
        cell.button.startHandler = { [weak self] in
          guard let self = self, let sissue = issue as? StoredIssue else { return }
          cell.button.startHandler = nil
          cell.button.downloadState = .waiting
          cell.momentView.isActivity = true
          issueVC.feederContext.getCompleteIssue(issue: sissue,
                                                 isPages: self.isFacsimile)
        }
      }
    }
    return cell
  }
  
  // MARK: > Cell Display
  public override func collectionView(_ collectionView: UICollectionView,
                                      willDisplay cell: UICollectionViewCell,
                                      forItemAt indexPath: IndexPath) {
    if indexPath.section == 1,
       indexPath.row > issues.count - 2 {
      showMoreIssues()
      footerActivityIndicator.startAnimating()
    }
  }
  
  
  func showMoreIssues(){
    guard let issueVC = self as? IssueVC else { return }
    var last = issueVC.issues.last!.date
    last.addDays(-1)
    issueVC.feederContext.getOvwIssues(feed: issueVC.feed, count: 10, fromDate: last)
  }
  
  // MARK: > Cell Click/Select
  public override func collectionView(_ collectionView: UICollectionView,
                                      didSelectItemAt indexPath: IndexPath) {
    guard let issueVC = self as? IssueVC else { return }
    /// Note: if using "animated: true" => Bug: opened Issue stays white!
    issueVC.issueCarousel.carousel.scrollto(indexPath.row)
    issueVC.showIssue(index: indexPath.row)
    #warning("TODO REFACTOR IssueVCBottomTielesCVCCell")
    ///Work with Issue drop on cell, and notifications for download start/stop
    if let cell = collectionView.cellForItem(at: indexPath)
        as? IssueVCBottomTielesCVCCell {
      cell.momentView.isActivity = true
      cell.momentView.setNeedsLayout()
      if issueVC.issue.isDownloading {
        cell.button.downloadState = .process
      }
      else if issueVC.issue.isComplete {
        cell.button.downloadState = .done
      }
      else {
        cell.button.downloadState = .process
      }
    }
  }
  
  // MARK: > Sizes
  public func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             referenceSizeForHeaderInSection section: Int) -> CGSize {
    if section == 0 {
      return UIScreen.main.bounds.size
    }
    else if section == 1 {
      return CGSize(width: UIScreen.main.bounds.size.width,
                    height: scrollUpButtonAreaHeight)
    }
    return CGSize.zero
  }
  
  public func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             referenceSizeForFooterInSection section: Int) -> CGSize {
    if section == 1 {
      // for Load More Activvity Indicator View Placeholder
      return CGSize(width: UIScreen.main.bounds.size.width,
                    height: scrollUpButtonAreaHeight)
    }
    return CGSize.zero
  }
  
  // MARK: > Header/Footer
  public override func collectionView(_ collectionView: UICollectionView,
                                      viewForSupplementaryElementOfKind kind: String,
                                      at indexPath: IndexPath) ->
  UICollectionReusableView {
    if kind == UICollectionView.elementKindSectionHeader {
      return headerFor(at: indexPath)
    }
    return footerFor(at: indexPath)
  }
}

// MARK: - UICollectionViewDataSource Helper
extension IssueVcWithBottomTiles {
  ///Section 0 Header: IssueCarousel with Arrow Down; Section 1 Header: Arrow Up
  func headerFor(at indexPath: IndexPath) ->
  UICollectionReusableView {
    let header = collectionView
      .dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader,
                                        withReuseIdentifier: reuseHeaderIdentifier,
                                        for: indexPath)
    for sv in header.subviews {
      sv.removeFromSuperview()
    }
    if let sv = headerViews.valueAt(indexPath.section) {
      header.addSubview(sv)
      pin(sv, to:header)
    }
    return header
  }
  
  /// Only for Section 1 Footer: Load More Activity Indicator
  func footerFor(at indexPath: IndexPath) ->
  UICollectionReusableView {
    let footer = collectionView
      .dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter,
                                        withReuseIdentifier: reuseFooterIdentifier,
                                        for: indexPath)
    for sv in footer.subviews {
      sv.removeFromSuperview()
    }
    
    if indexPath.section == 1 {
      footer.addSubview(footerActivityIndicator)
      footerActivityIndicator.center()
    }
    return footer
  }
}

// MARK: - UIScrollViewDelegate (from UICollectionViewController)
/// Add some ScrollView Snapping Magic
extension IssueVcWithBottomTiles {
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
    ///@RingoToDO WARNING NOT WORK RELIABLE
//    isUp = collectionView.indexPathsForVisibleItems.count == 0
    isUp = scrollView.contentOffset.y < 200.0
//    print("isUp: \(isUp) scrollOffset: \(scrollView.contentOffset)")
  }
}

// MARK: - Scroll Extensions
extension IssueVcWithBottomTiles {
  ///Implementation of the scroll Snapping simplified, the 20% trigger can be implemented within Refactoring after Integration
  func snapScrollViewIfNeeded(_ scrollView: UIScrollView, targetContentOffset:CGPoint? = nil) {
    
    if isButtonActionScrolling == true { return }
    
    let targetOffset = targetContentOffset != nil
      ? targetContentOffset!.y
      : scrollView.contentOffset.y
    
    if isUp {
      if targetOffset < 0.1 * scrollSnapHeight {
        scrollUp()
      }
      else {
        scrollDown(true)
      }
    }
    else {
      if targetOffset < 0.8 * scrollSnapHeight {
        scrollUp()
      }
      else if targetOffset < 1.1 * scrollSnapHeight {
        scrollDown()
      }
    }
  }
  
  func scrollDown(_ reloadData:Bool = false){
    self.collectionView.setContentOffset(CGPoint(x:0, y:scrollSnapHeight),
                                         animated: true)
    if reloadData { self.collectionView.reloadData() }
  }
  
  func scrollUp(){
    self.collectionView.setContentOffset(CGPoint(x:0, y:topPos),
                                         animated: true)
  }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension IssueVcWithBottomTiles: UICollectionViewDelegateFlowLayout {
  public func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             sizeForItemAt indexPath: IndexPath) -> CGSize {
    return cellSize
  }
}



// MARK: - ShowPDF Info Toast
extension IssueVcWithBottomTiles {
  func showPdfInfoIfNeeded(_ delay:Double = 3.0) {
    if showPdfInfoToast == false { return }
    
    onThreadAfter(delay) {
      var img : UIImage?
      if let url = Bundle.main.url(forResource: "PDF-Button_640px_transparent",
                                   withExtension: "gif",
                                   subdirectory: "BundledResources") {
        let file = File(url)
        if file.exists {
          img = UIImage.animatedGif(File(url).data)
        }
      }
      
      InfoToast.showWith(image: img, title: "Entdecken Sie jetzt die Zeitungsansicht",
                         text: "Hier können Sie zwischen der mobilen und der Ansicht der Zeitungsseiten wechseln",
                         buttonText: "OK",
                         hasCloseX: true,
                         autoDisappearAfter: nil) {   [weak self] in
        self?.log("PdfInfoToast showen and closed")
        self?.showPdfInfoToast = false
      }
    }
  }
}
