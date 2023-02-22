//
//  IssueTilesCVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 01.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class IssueTilesCVC: UICollectionViewController {
  
  private static let reuseCellId = "IssueTilesCvcCell"
  
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  private let lineSpacing:CGFloat = 20.0
  private let itemSpacing:CGFloat = UIWindow.shortSide > 320 ? 30.0 : 20.0
  
  var service: IssueOverviewService

  
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
    return 1
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return service.issueDates.count
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: Self.reuseCellId,
      for: indexPath)
    guard let cell = cell as? IssueTilesCvcCell,
          let data = service.cellData(for: indexPath.row) else { return cell }
    cell.date = data.date
    cell.issue = data.issue
    cell.image = data.image
    cell.button.indicator.downloadState = service.issueDownloadState(at: indexPath.row)
    cell.button.onTapping { [weak self] _ in
      if cell.button.indicator.downloadState == .done  { return }
      self?.service.download(issueAtIndex: indexPath.row,
                             updateStatusButton: cell.button)
    }
    return cell
  }
    
  
  // MARK: > Cell Display
  public override func collectionView(_ collectionView: UICollectionView,
                                      willDisplay cell: UICollectionViewCell,
                                      forItemAt indexPath: IndexPath) {
    //    if indexPath.section == 1,
    //       indexPath.row > issues.count - 2 {
    //      showMoreIssues()
    //      footerActivityIndicator.startAnimating()
    //    }
  }
  
  // MARK: > Cell Click/Select
  public override func collectionView(_ collectionView: UICollectionView,
                                      didSelectItemAt indexPath: IndexPath) {
    guard let issue = self.service.issue(at: indexPath.row) else {
      error("Issue not available try later")
      return
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
  func reloadVisibleCells() {
    let vips = self.collectionView.indexPathsForVisibleItems
    for ip in vips {
      _ = self.collectionView.cellForItem(at: ip)
    }
    //is faster tested with iPadOS 16.2 iPad Pro 2 Simulators same
    // Data/environment; code change if false,... Lamdscape
    // reconfigure feels ~1/3 faster
    // @see: https://swiftsenpai.com/development/cells-reload-improvements-ios-15/
    if #available(iOS 15.0, *) {
      self.collectionView.reconfigureItems(at: vips)
    } else {
      UIView.performWithoutAnimation {
        self.collectionView.reloadItems(at: vips)
      }
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
