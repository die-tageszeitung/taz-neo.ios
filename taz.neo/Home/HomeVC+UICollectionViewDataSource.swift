//
//  HomeVC+UICollectionViewDataSource.swift
//  taz.neo
//
//  Created by Ringo Müller on 23.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit

// MARK: UICollectionViewDataSource

extension HomeVC  {
  
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
    
//    if scrollFromLeftToRight {
//      cell.contentView.transform = CGAffineTransform(rotationAngle: -CGFloat.pi)
//    }
//    else {
//      cell.contentView.transform = CGAffineTransform(rotationAngle: 0)
//    }
    
    if cell.momentView.interactions.isEmpty {
//      let menuInteraction = UIContextMenuInteraction(delegate: self)
//      cell.momentView.addInteraction(menuInteraction)
      cell.backgroundColor = Const.SetColor.HomeBackground.color
    }
    return cell
  }

//  var loadingMoment: MomentView? {
//    didSet {
//      loadingMoment?.isActivity = true
//      oldValue?.isActivity = false
//    }
//  }
  
  // MARK: > Cell Click/Select
  public override func collectionView(_ collectionView: UICollectionView,
                                      didSelectItemAt indexPath: IndexPath) {
    guard let data = self.service.cellData(for: indexPath.row),
          let issue = data.issue else {
      error("Issue not available try later")
      return
    }
//    loadingMoment = (collectionView.cellForItem(at: indexPath) as? IssueCollectionViewCell)?.momentView

//    if data.downloadState == .notStarted {
//      downloadButton.indicator.downloadState = .waiting
//    }
//    (parent as? OpenIssueDelegate)?.openIssue(issue)
  }
  
}
