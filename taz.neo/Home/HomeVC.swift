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
  
  #warning("ToDo")
  var centerIndex: Int = 0
  
  private var pullToLoadMoreHandler: (()->())?
  static let reuseCellId = "issueCollectionViewCell"
  
  var loadingIssueInfos:[IssueDisplayService] = []
  var issueInfo:IssueDisplayService?
  var feederContext:FeederContext
  var service: IssueOverviewService
  
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
    return layout
  }()
  
  var currentLayout: UICollectionViewFlowLayout {
    get { isHomeTiles ? gridLayout : carouselLayout }
  }
  
  private var dataPolicyToast: NewInfoToast?
  
  /// Temporary variable to prevent the same issue from being opened multiple times due to repeated touches.
  private var openingIssue: Issue?
  
  
  var pickerCtrl : DatePickerController?
  var overlay : Overlay?
  
  func onHome(){
    collectionView.scrollToItem(at: IndexPath(row: 0, section: 0),
                                at: isHomeTiles ? .top : .centeredHorizontally,
                                animated: true)
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
  
  func openIssue(_ issue:StoredIssue, isReloadOpened: Bool = false){
#warning("todo")
//    openIssue(issue, atArticle: nil, atPage: nil, isReloadOpened: isReloadOpened)
  }
  lazy var viewModeButton: UIButton = {
    let menuButton = UIButton(type: .system)

    // Set SF Symbol as image
    let icon = UIImage(systemName: "ellipsis")
    menuButton.setImage(icon, for: .normal)

    // Optional: Tintfarbe (Standard ist systemBlue)
    menuButton.tintColor = Const.Colors.appIconGrey

    // Optional: Zugriffshilfe
    menuButton.accessibilityLabel = "Ansicht umschalten"
    
    menuButton.pinSize(CGSize(width: 40, height: 40))
    menuButton.addBorder(Const.Colors.appIconGrey, 1.5)
    menuButton.layer.cornerRadius = 20
    return menuButton
  }()
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
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
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Register cell classes
    self.collectionView.register(IssueCollectionViewCell.self,
                                  forCellWithReuseIdentifier: Self.reuseCellId)
    self.collectionView.showsHorizontalScrollIndicator = false
    self.collectionView.backgroundColor = Const.SetColor.HomeBackground.color
    self.view.addSubview(viewModeButton)
    updateButtonMenu()
    self.overrideUserInterfaceStyle = .dark
    pin(viewModeButton.left, to: self.view.leftGuide(), dist: 15.0)
    pin(viewModeButton.top, to: self.view.topGuide(), dist: 25.0)
    
    
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
    }
  }
  
  func updateButtonMenu(){ configureMenu(for: viewModeButton) }
  
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

      // Komplettes Menü zuweisen
    if #available(iOS 14.0, *) {
      button.menu = UIMenu(title: "", children: [viewGroup, layoutGroup])
      button.showsMenuAsPrimaryAction = true
    }
  }
  
  func viewModeChanged(){}
  func layoutModeChanged(){}
  
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
   /* topStatusButtonConstraint?.constant = offset*/
    /*statusWrapperBottomConstraint?.constant = -offset*/
    /*statusWrapperWidthConstraint?.constant = cw*layout.maxScale*/
    
    self.collectionView.contentInset
    = UIEdgeInsets(top:0,left:sideInset,bottom:0,right:sideInset)
  }
  
}
