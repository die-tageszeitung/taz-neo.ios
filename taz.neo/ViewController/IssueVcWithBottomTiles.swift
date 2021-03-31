//
//  IssueVcWithBottomTiles.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 06.01.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

// MARK: - ShowPDF
extension IssueVcWithBottomTiles {
  func showPdfInfo() {
    var img : UIImage?
    
    if let url = Bundle.main.url(forResource: "PDF-Button_640px",
                                 withExtension: "gif",
                                 subdirectory: "BundledRessources") {
      let file = File(url)
      if file.exists {
        img = UIImage.animatedGif(File(url).data)
      }
    }
     
    InfoToast.showWith(image: img, title: "Entdecken Sie jetzt die Zeitungsansicht", text: "Hier können Sie zwischen der mobilen und der Ansicht der Zeitungsseiten wechseln", buttonText: "OK", hasCloseX: true, autoDisappearAfter: nil) {
      print("Closed")
    }
  }
}




/// This Class  extends IssueVC for a bottom Area with a UICollectionVC
/// written to have a minimal Impact on IssueVC on Integration
public class IssueVcWithBottomTiles : UICollectionViewControllerWithTabbar{
  
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
        #warning("@Norbert/Ringo DO NOT RELOAD EVERYTHING USE INSERT!... look in Merge in nthies's changes")
        self.collectionView.reloadData()
      }
    }
  }
  
  /// Are we in facsimile mode
  @DefaultBool(key: "isFacsimile")
  public var isFacsimile: Bool

  public var toolBar = OverviewContentToolbar()
  
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
    collectionView?.register(IssueVCBottomTielesCVCCell.self, forCellWithReuseIdentifier: reuseIdentifier)
    collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: reuseHeaderIdentifier)
    collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: reuseFooterIdentifier)
    setupToolbar()
    
    
    onThreadAfter(2.0) { [weak self] in
      self?.showPdfInfo()
    }
  }

  func setupToolbar() {
    //the button tap closures
    let onHome:((ButtonControl)->()) = { [weak self] _ in
      guard let self = self as? IssueVC else { return }
      self.issueCarousel.carousel.scrollto(0, animated: true)
    }
    
    
    
    let onPDF:((ButtonControl)->()) = {   [weak self] control in
      guard let self = self else { return }
      self.showPdfInfo()
      self.isFacsimile = !self.isFacsimile
      
      if let imageButton = control as? Button<ImageView> {
        imageButton.buttonView.name = self.isFacsimile ? "newspaper" : "mobileDevice"
      }
      print("PDF Pressed")
    }
    
    //the buttons and alignments
    _ = toolBar.addImageButton(name: "home",
                               onPress: onHome,
                               direction: .right,
                               accessibilityLabel: "Übersicht")
    
    _ = toolBar.addImageButton(name: self.isFacsimile ? "newspaper" : "mobileDevice",
                               onPress: onPDF,
                               direction: .left,
                               accessibilityLabel: self.isFacsimile ? "App Ansicht" : "Zeitungsansicht")
        
    //the toolbar setup itself
    toolBar.applyDefaultTazSyle()
    toolBar.pinTo(self.view)
    whenScrolled(minRatio: 0.01) {  [weak self] ratio in
      if ratio < 0, self?.isUp == false { self?.toolBar.hide()}
      else { self?.toolBar.hide(false)}
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

    guard let cell = _cell as? IssueVCBottomTielesCVCCell else { return _cell }
    
    cell.imageView.image = nil
    
    if let issueVC = self as? IssueVC,
       let issue = issues.valueAt(indexPath.row) {
      cell.text = issue.date.shorter
      cell.button.titleLabel?.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
      /// ToDo: for not Downloaded Items, click, load finished, the cloud did not disappear
      /// should be done in Refactoring with PDF Image for Cells
      if issue.isDownloading {
//        cell.button.downloadState = .process
//        cell.button.percent = 0.5
//        cell.button.startHandler = nil
//        cell.button.stopHandler = nil
      }
      else if issue.isComplete {
        cell.button.downloadState = .done
        cell.button.startHandler = nil
        cell.button.stopHandler = nil
      }
      else {
        cell.button.downloadState = .notStarted
        cell.button.startHandler = {
          cell.button.startHandler = nil
          cell.button.downloadState = .process
          #warning("@Norbert Download Status did not work as expected whole time at 0 ...then 100%")
          cell.observer = Notification.receive("issueProgress", from: issue) { notif in
            print("Recive Notification from \((notif.object as? Issue)?.date) handler for: \(issue.date)")
            if let (loaded,total) = notif.content as? (Int64,Int64) {
              print("...has status: \(Float(loaded)/Float(total)) ==  \(loaded)/\(total)")
              cell.button.percent = Float(loaded)/Float(total)
            }
          }
          #warning("@Norbert Downloading Issue with this, not downloading section 0 at first")
          if let sissue = issue as? StoredIssue {
//            guard issueVC.feederContext.needsUpdate(issue: sissue) else { openIssue(); return }
//            isDownloading = true
//            issueCarousel.index = index
//            issueCarousel.setActivity(idx: index, isActivity: true)
//            issueVC.feederContext.str
            issueVC.feederContext.getCompleteIssue(issue: sissue, isPages: self.isFacsimile)
          }
        }
        cell.button.stopHandler = {}
      }
      
      if let img = issueVC.feeder.momentImage(issue: issue) {
        cell.imageView.image = img
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
  open override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    super.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
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

// MARK: - UICollectionViewDelegateFlowLayout
extension IssueVcWithBottomTiles: UICollectionViewDelegateFlowLayout {
  public func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             sizeForItemAt indexPath: IndexPath) -> CGSize {
    return bottomCellSize
  }
}

// MARK: - Helper for ContentToolbar
extension ContentToolbar {
  func addSpacer(_ direction:Toolbar.Direction) {
    let button = Toolbar.Spacer()
    self.addButton(button, direction: direction)
  }
  
  func addImageButton(name:String,
                      onPress:@escaping ((ButtonControl)->()),
                      direction: Toolbar.Direction,
                      symbol:String? = nil,
                      accessibilityLabel:String? = nil,
                      isBistable: Bool = true,
                      width:CGFloat = 40,
                      height:CGFloat = 40,
                      vInset:CGFloat = 0.0,
                      hInset:CGFloat = 0.0
                      ) -> Button<ImageView> {
    let button = Button<ImageView>()
    button.pinWidth(width, priority: .defaultHigh)
    button.pinHeight(height, priority: .defaultHigh)
    button.vinset = vInset
    button.hinset = hInset
    button.isBistable = isBistable
    button.buttonView.name = name
    button.buttonView.symbol = symbol
    
    if let al = accessibilityLabel {
      button.isAccessibilityElement = true
      button.accessibilityLabel = al
    }
    
    self.addButton(button, direction: direction)
    button.onPress(closure: onPress)
    return button
  }
}

// MARK: - UICollectionViewControllerWithTabbar
/// UICollectionViewController with whenScrolled with min ratio handler
open class UICollectionViewControllerWithTabbar : UICollectionViewController {
  
  // The closure to call when content scrolled more than scrollRatio
  private var whenScrolledClosure: ((CGFloat)->())?
  private var scrollRatio: CGFloat = 0
  
  /// Define closure to call when web content has been scrolled
  public func whenScrolled( minRatio: CGFloat, _ closure: @escaping (CGFloat)->() ) {
    scrollRatio = minRatio
    whenScrolledClosure = closure
  }
  
  // content y offset at start of dragging
  private var startDragging: CGFloat?
    
  open override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    startDragging = scrollView.contentOffset.y
  }
  
  open override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if let sd = startDragging {
      let scrolled = sd-scrollView.contentOffset.y
      let ratio = scrolled / scrollView.bounds.size.height
      if let closure = whenScrolledClosure, abs(ratio) >= scrollRatio {
        closure(ratio)
      }
    }
    startDragging = nil
  }
}

// MARK: - OverviewContentToolbar
/// ContentToolbar with easier constraint animation and changed animation target
public class OverviewContentToolbar : ContentToolbar {
  public override func hide(_ isHide: Bool = true) {
    if isHide {
      UIView.animate(withDuration: 0.5) { [weak self] in
        self?.heightConstraint?.constant = 0
        self?.superview?.layoutIfNeeded()
      }
    }
    else if self.heightConstraint?.constant != self.totalHeight {
      UIView.animate(withDuration: 0.5) { [weak self] in
        self?.heightConstraint?.constant = self!.totalHeight
        self?.superview?.layoutIfNeeded()
      }
    }
  }
}
