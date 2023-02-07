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
  
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  private let lineSpacing:CGFloat = 20.0
  private let itemSpacing:CGFloat = UIWindow.shortSide > 320 ? 30.0 : 20.0
  private static let reuseCellId = "issueTilesCVCCell"
  
  var service: IssueOverviewService

  
  /// size of the issue items
  lazy var cellSize: CGSize = CGSize(width: 20, height: 20)

  
  override func viewDidLoad() {
    super.viewDidLoad()
    collectionView?.backgroundColor = .black
    collectionView?.register(IssueVCBottomTielesCVCCell.self,
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
  
  public override func collectionView(_ collectionView: UICollectionView,
                                      cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    
    let _cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.reuseCellId,
                                                   for: indexPath)
    
    guard let cell = _cell as? IssueVCBottomTielesCVCCell else { return _cell }
    
    guard let issue = service.getIssue(at: indexPath.row) else {
      cell.button.indicator.downloadState = .waiting
      cell.button.label.text = service.date(at: indexPath.row)?.short ?? "-"
      return cell
    }
    
    cell.issue = issue
    
    cell.momentView.image = service.momentImage(issue: issue,
                                                isPdf: isFacsimile)
    
    if service.hasDownloadableContent(issue: issue) {
      cell.button.onTapping {[weak self] _ in
        guard let self else { return }
        cell.button.indicator.downloadState = .waiting
        cell.button.indicator.percent = 0.0
        cell.momentView.isActivity = true
        self.service.getCompleteIssue(issue: issue)
      }
      cell.button.indicator.downloadState = .notStarted
    }
    //
    //    if cell.interactions.isEmpty {
    //      let menuInteraction = UIContextMenuInteraction(delegate: self)
    //      cell.addInteraction(menuInteraction)
    //      cell.backgroundColor = .black
    //    }
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
    guard let date = self.service.date(at: indexPath.row) else {
      error("Impossible Error: Date for IndexPath not found")
      return
    }
    guard let navigationController = self.navigationController else {
      error("Refacoring Error: Date navigation controller not found")
      return
    }
    
    self.service.showIssue(at: date, pushToNc: navigationController)
    #warning("ToDo select in carousell!")
    //    issueVC.issueCarousel.carousel.scrollto(indexPath.row)
    ///Work with Issue drop on cell, and notifications for download start/stop
    guard let cell = collectionView.cellForItem(at: indexPath)
                     as? IssueVCBottomTielesCVCCell else {
      log("Error: Cell could not be found & configured")
      return
    }
    
    let issue = self.service.issue(at: date)
    
    if issue?.isDownloading ?? false {
      cell.button.indicator.downloadState = .process
      cell.momentView.isActivity = true
    }
    else if issue?.isComplete ?? false {
      cell.button.indicator.downloadState = .done
      cell.momentView.isActivity = false
    }
    else {
      cell.button.indicator.downloadState = .process
      cell.momentView.isActivity = true
    }
    cell.momentView.setNeedsLayout()
  }
  
  // MARK: UICollectionViewDelegate
  
  /*
   // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
   override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
   return false
   }
   
   */
  

 
  
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
