//
//  IssueTilesCVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 01.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class IssueTilesCVC: UICollectionViewController, IssueCollectionViewActions {
  
  private static let reuseCellId = "IssueTilesCvcCell"
  
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  private let lineSpacing:CGFloat = 20.0
  private let itemSpacing:CGFloat = UIWindow.shortSide > 320 ? 30.0 : 20.0
  
  var service: IssueOverviewService

  var isActive = true {
    didSet {
      self.collectionView.reloadData()
    }
  }
  
  /// size of the issue items
  lazy var cellSize: CGSize = CGSize(width: 20, height: 20)

  override func viewDidLoad() {
    super.viewDidLoad()
    collectionView?.backgroundColor = .black
    collectionView?.register(IssueTilesCvcCell.self,
                             forCellWithReuseIdentifier: Self.reuseCellId)
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    if UIDevice.current.orientation.isLandscape && Device.isIphone {
      UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
    super.viewWillAppear(animated)
    updateCollectionViewLayout(self.view.frame.size)
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateCollectionViewLayout(size)
  }
  
  // MARK: UICollectionViewDataSource
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return isActive ? 1 : 0
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return isActive ? service.publicationDates.count : 0
  }
  
  ///Refactor to enqueue load issue/image and remove from load all in cellForItemAt
  ///because end display is called after willDisplay on PDF/mobile switch
  ///so not loaded PDF Moments have been removed imaditly
  ///
  ///NEXT CHALLANGE, maybe the same
  ///on switch TO MOBILE
  ///cell x xx PDF           => 2.2.2012 MOBILE
  ///cell 2.2.2012 PDF => x.x.MOBILE ==> REMOVED FROM LOAD >  X X X XX X
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell
    = collectionView.dequeueReusableCell( withReuseIdentifier: Self.reuseCellId,
                                          for: indexPath)
    guard let cell = cell as? IssueTilesCvcCell else { return cell }
    var old = "-"
    if let date = cell.data?.date.date {
      old = date.issueKey
      service.removeFromLoadFromRemote(date: date)
    }
    cell.data = service.cellData(for: indexPath.row)///set even if nil to apply new value
    print(">>x> exchange cell \(old) new: \(cell.data?.date.date.issueKey ?? "-") cellHash: \(cell.hash)")
    ///Init once
    if cell.interactions.isEmpty {
      let menuInteraction = UIContextMenuInteraction(delegate: self)
      cell.addInteraction(menuInteraction)
      cell.backgroundColor = .black
      #warning("CHECK IF CORRECT CELL LOADED MOVED CODE TO HERE MAYBE WRONG")
      cell.button.onTapping { [weak self] _ in
        if self?.service.download(issueAtIndex: indexPath.row) != nil {
          cell.button.indicator.downloadState = .waiting
        }
      }
    }
    return cell
  }
  
  override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    print(">>x> end display cell for date: \((cell as? IssueTilesCvcCell)?.data?.date.date.issueKey ?? "-") cellHash: \(cell.hash)")
  }

  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    guard let cell = cell as? IssueTilesCvcCell else { return }
    cell.button.indicator.downloadState = service.issueDownloadState(at: indexPath.row)
  }
  
  // MARK: > Cell Click/Select
  public override func collectionView(_ collectionView: UICollectionView,
                                      didSelectItemAt indexPath: IndexPath) {
    guard let issue = self.service.cellData(for: indexPath.row)?.issue else {
      error("Issue not available try later")
      return
    }
    
    for case let cell as IssueTilesCvcCell in collectionView.visibleCells {
      if cell.data?.issue != issue { continue }
      if cell.button.indicator.downloadState == .notStarted {
        cell.button.indicator.downloadState = .waiting
      }
      break
    }
    (parent as? OpenIssueDelegate)?.openIssue(issue)
  }
  
  // MARK: UICollectionViewDelegate

  // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
  override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  public init(service: IssueOverviewService) {
    self.service = service
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
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension IssueTilesCVC {
  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    return _contextMenuInteraction(interaction, configurationForMenuAtLocation: location)
  }
}

extension IssueTilesCVC {
  func reloadVisibleCells() {
    let vips = self.collectionView.indexPathsForVisibleItems
    //Prevent download all Issues in Caroussel on current date switch to PDF
    if vips.count == 0 { return }
    for ip in vips {
      _ = self.collectionView.cellForItem(at: ip)
    }
    UIView.performWithoutAnimation {
      self.collectionView.reloadItems(at: vips)
    }
  }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension IssueTilesCVC: UICollectionViewDelegateFlowLayout {
  public func collectionView(_ collectionView: UICollectionView,
                             layout collectionViewLayout: UICollectionViewLayout,
                             sizeForItemAt indexPath: IndexPath) -> CGSize {
    return cellSize
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
}
