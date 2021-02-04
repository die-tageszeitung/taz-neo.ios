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
/// Refer Commit af99bd5 for Integration
/// #ToDo: refactor IssueVC later:
/// #1 to get rid of stocking scroll animations if new issues added
/// by implementing: insertItems
/// https://developer.apple.com/documentation/uikit/uicollectionview/1618097-insertitems
/// #2 for cleaner code
/// delegating download, reuse images can be organized much better ...if integrated
/// #3 after iPad & landscape issues are fixed
/// may use just 1 scroll down/to arrow within an animation
/// ... requires landscape layout fixed
public class IssueVcWithBottomTiles : UICollectionViewController{
  
  // MARK: - Properties
  ///moved issues here to prevent some performance and other issues
  ///obsolate after refactoring & full integration
  public var issues: [Issue] = [] {
    didSet{
      print("Issues set!!")
      if oldValue.count != issues.count {
        footerActivityIndicator.stopAnimating()
        //may issues (moments) changed
        //generelly no good to reload them all
        self.collectionView.reloadData()
      }
    }
  }
  
  private let reuseIdentifier = "issueVcCollectionViewBottomCell"
  private let reuseHeaderIdentifier = "issueVcCollectionViewHeader"
  private let reuseFooterIdentifier = "issueVcCollectionViewFooter"
  private let itemSpacing:CGFloat = 30.0
  
  /// header (top section) bottom offset for: app switcher, tabbar, scroll down button
  let bottomOffset:CGFloat=120
  /// size if the buttons with up/down arrow
  let scrollButtonSize = CGSize(width: 80, height: 30)
  let scrollUpButtonAreaHeight:CGFloat=30
  
  /// used to hold IssueVC's content (carousel)
  ///obsolate after refactoring & full integration
  let headerView = UIView()
  
  /// Adds the Scroll Down Arrow/Button
  /// used to reduce the impact/code changes in issue carousel and issueVC for merge
  /// toDo: only use 1 Button for Scroll Up/Down with an change Animation
  ///  requires: Issue Carousel/IssueVC to work in Landscape Mode with various device screen sizes
  ///obsolate after refactoring & full integration
  lazy var headerViews : [UIView] = {
    /* Arrows are hidden by Tabbar!, temporary remove them from UI
    let scrollDownButton = UIButton()
    headerView.addSubview(scrollDownButton)
    pin(scrollDownButton.centerX, to: headerView.centerX)
    pin(scrollDownButton.top, to: headerView.bottom, dist: -bottomOffset)
    scrollDownButton.pinSize(scrollButtonSize)
    scrollDownButton.setImage(UIImage(name: "chevron.down"), for: .normal)
    scrollDownButton.imageView?.tintColor = .white
    scrollDownButton.touch(self, action: #selector(handleScrollDownButtonTouch))
    */
    let section2Header = UIView()
    /*
    let scrollUpButton = UIButton()
    scrollUpButton.pinSize(scrollButtonSize)
    scrollUpButton.setImage(UIImage(name: "chevron.up"), for: .normal)
    scrollUpButton.imageView?.tintColor = .white
    scrollUpButton.touch(self, action: #selector(handleScrollUpButtonTouch))
    section2Header.addSubview(scrollUpButton)
    scrollUpButton.center()
     */
    return [headerView,section2Header]
  }()
  
  /// size of the issue items in bottom section;
  lazy var bottomCellSize : CGSize = {
    /// expect moment image in 2:3 aspect ratio; add 30 ps for label below
    let cellWidth : CGFloat = (UIScreen.main.bounds.size.width - 3*itemSpacing)/2
    return CGSize(width: cellWidth, height: cellWidth*3/2 + 30)//expect 3:2 Format
  }()
  
  
  /// top top Scroll Target Position, to scroll to if scroll top
  let topPos : CGFloat = -UIWindow.topInset
  
  /// activity indicator for Bottom Ares, if load more requested
  let footerActivityIndicator = UIActivityIndicatorView(style: .white)
  
  /// offset for snapping between top area (IssueCarousel) and Bottom Area (tile view)
  var scrollSnapHeight = UIScreen.main.bounds.size.height
  
  /// prevent multiple times initialization
  /// for unknown reason viewDidLoad called multiple times within the inheritance: IssueVC->IssueVcWithBottomTiles
  /// obsolate after refactoring & full integration
  var initialized=false
  
  /// Indicate if current state is top on IssueCaroussel or Bottom on Tiele View
  var isUp:Bool = true
  
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
    layout.minimumLineSpacing = self.itemSpacing
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
    collectionView?.register(PdfOverviewCvcCell.self, forCellWithReuseIdentifier: reuseIdentifier)
    collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: reuseHeaderIdentifier)
    collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: reuseFooterIdentifier)
    Notification.receiveOnce("issueOverview") { (_) in
      if IssueVC.showAnimations { self.showScrollDownAnimations2() }
    }
  }
  
  ///no good.... blank imageview in Step!
//  func showScrollDownAnimations3(){
//    typealias Step = AppOverlayStep
//    var steps:[AppOverlayStep] = []
//    steps.append(AppOverlayStep(UIImage(named: "scrollDown")))
//    steps.append(AppOverlayStep(nil,totalDuration:1.0, action: {
//      self.isButtonActionScrolling = true
//      self.collectionView.decelerationRate = UIScrollView.DecelerationRate(rawValue: 0.3)
//      self.collectionView.setContentOffset(CGPoint(x:0, y:UIScreen.main.bounds.size.height*0.6),
//                                           animated: true)
//    }))
//    steps.append(AppOverlayStep(UIImage(named: "scrollUp"), action: {
//      self.scrollUp()
//    }))
//    AppOverlay.show(steps: steps, initialDelay: 1.0)
//  }
  
  func showScrollDownAnimations2(){
    typealias Step = AppOverlayStep
    var steps:[AppOverlayStep] = []
    steps.append(AppOverlayStep(UIImage(named: "scrollDown"), action: {
      self.isButtonActionScrolling = true
      self.collectionView.decelerationRate = UIScrollView.DecelerationRate(rawValue: 0.3)
      self.collectionView.setContentOffset(CGPoint(x:0, y:UIScreen.main.bounds.size.height*0.6),
                                           animated: true)
    }))
    steps.append(AppOverlayStep(UIImage(named: "scrollUp"), action: {
      self.scrollUp()
    }))
    AppOverlay.show(steps: steps, initialDelay: 1.0) {[weak self] in
      self?.collectionView.decelerationRate = .normal
    }
  }
  
  func showScrollDownAnimations1(){
    AppOverlay.show(UIImage(named: "scrollDown"), 2.0,2.0) {
        self.isButtonActionScrolling = true
        self.collectionView.decelerationRate = UIScrollView.DecelerationRate(rawValue: 0.3)
        self.collectionView.setContentOffset(CGPoint(x:0, y:UIScreen.main.bounds.size.height*0.6),
                                             animated: true)
      onMainAfter(1.0) {
        AppOverlay.show(UIImage(named: "scrollUp"), 2.0) {
          self.scrollUp()
        }
      }
    }
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
    
    guard let cell = _cell as? PdfOverviewCvcCell else { return _cell }
    
    cell.label?.text = nil
    cell.imageView?.image = nil
    
    if let issueVC = self as? IssueVC,
       let issue = issues.valueAt(indexPath.row) {
      cell.text = issue.date.shorter
      cell.button?.titleLabel?.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
      /// ToDo for not Downloaded Items, click, load finished, the cloud did not disappear
      /// should be done in Refactoring
      cell.cloudHidden = issue.isComplete
      cell.label?.textAlignment = .center
      if let img = issueVC.feeder.momentImage(issue: issue) {
        //        print("Moment Image Size: \(img.mbSize) for: \(img) with scale: \(img.scale)")
        #warning("2.4 MB is quire big for 8 cells and more on Screen; could cause performance issues")
        cell.imageView?.image = img
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
      //load more
//      (self as? IssueVC)?.issueCarousel.index = issues.count
//      (self as? IssueVC)?.provideOverview()
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
    /// Warning if using "animated: true" => Bug: opened Issue stays white!
    issueVC.issueCarousel.carousel.scrollto(indexPath.row)
    issueVC.showIssue(index: indexPath.row)
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

// MARK: - UIScrollViewDelegate
/// Add some ScrollView Snapping Magic
extension IssueVcWithBottomTiles {
  public override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if decelerate { return }
    snapScrollViewIfNeeded(scrollView)
  }
  
  public override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    snapScrollViewIfNeeded(scrollView, targetContentOffset: targetContentOffset.pointee)
  }
  
  public override func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
    snapScrollViewIfNeeded(scrollView)
  }
  
  public override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    snapScrollViewIfNeeded(scrollView)
  }
  
  public override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    isUp = collectionView.indexPathsForVisibleItems.count == 0
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

//// MARK: - Interaction Extensions
//extension IssueVcWithBottomTiles {
//  ///Actions for
//  @IBAction func handleScrollDownButtonTouch(_ sender: UIButton) {
//    isButtonActionScrolling = true
//    scrollDown()
//  }
//  @IBAction func handleScrollUpButtonTouch(_ sender: UIButton) {
//    isButtonActionScrolling = true
//    scrollUp()
//  }
//}

// MARK: - UICollectionViewDelegateFlowLayout
extension IssueVcWithBottomTiles: UICollectionViewDelegateFlowLayout {
  public func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             sizeForItemAt indexPath: IndexPath) -> CGSize {
    return bottomCellSize
  }
}
