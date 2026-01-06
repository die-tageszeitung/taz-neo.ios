//
//  HomeVC+UICollectionViewDataSource.swift
//  taz.neo
//
//  Created by Ringo Müller on 23.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

// MARK: UICollectionViewDataSource

extension HomeVC  {
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return service.publicationDates.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    guard let cell = cell as? IssueTilesCvcCell,
          let data = cell.data else { return }
    cell.data = nil
    service.removeFromLoadFromRemote(key: data.key)
    cell.isAccessibilityElement = false
    updateAccessibilityOrder()
  }
  
  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    guard let cell = cell as? IssueTilesCvcCell,
          let data = service.cellData(for: indexPath.row) else { return }
    cell.data = data
    cell.isAccessibilityElement = true
    updateAccessibilityOrder()
  }
    
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell
    = collectionView.dequeueReusableCell( withReuseIdentifier: Self.reuseCellId,
                                          for: indexPath)
    guard let cell = cell as? IssueTilesCvcCell else { return cell }
    cell.backgroundColor = Const.Colors.Light.HomeBackground
    cell.update()
    ///only add functions once
    if cell.interactions.isEmpty {
      let menuInteraction = UIContextMenuInteraction(delegate: self)
      cell.addInteraction(menuInteraction)
      cell.button.onTapping { [weak self] _ in
        if cell.button.indicator.downloadState?.canOpen == true,
          let issue = cell.data?.issue {
          self?.openIssue(issue,
                          openLast: true)
          Usage.track(Usage.event.dialog.OpenLastRead, name: "OpenFromHome")
          return
        }
        if let date = cell.data?.date.date,
          self?.service.download(issueAt: date, withAudio: false) != nil {
          cell.button.indicator.downloadState = .waiting
        }
      }
    }
    
    if isHomeTiles == false && scrollFromLeftToRight {
      cell.contentView.transform = CGAffineTransform(rotationAngle: -CGFloat.pi)
    }
    else {
      cell.contentView.transform = CGAffineTransform(rotationAngle: 0)
    }
    return cell
  }
  
  // MARK: > Cell Click/Select
  public override func collectionView(_ collectionView: UICollectionView,
                                      didSelectItemAt indexPath: IndexPath) {
    guard let data = self.service.cellData(for: indexPath.row),
          let issue = data.issue else {
      error("Issue not available try later")
      return
    }
    if isHomeTiles {
      Notification.send("issueProgress", content: "waiting", sender: issue)
    }
    else if data.downloadState == .notStarted {
      downloadButton.indicator.downloadState = .waiting
    }
    openIssue(issue)
  }
  
}

extension HomeVC {
  func openIssue(_ issue: StoredIssue, openLast: Bool = false) {
    let openLast = openLast || Defaults.reopenAutomaticSetting
    ///How to prevent multiple open?
    ///already pushed => no problem
    ///3 downloads in Progress => first downloaded? n/ last clicked?
    ///previously first clicked was used so do it again
    ///What happen if download fail? => Nothing another tap may download and open a issue
    ///QUESTIONS
    ///should/can i handle massive multiple downloads?
    ///should i allow?
    ///YES: Which one is selected? What if selected is no reference here?
    ///if  not what happen if i only have
    ///TRY TO BUGFIX MULTIPLE OPEN OF Logged Out not downloaded issue due it causes other errors by saving which issue was tried to open and unset after 10 seconds od push delegate happen
    if openingIssue?.date.issueKey == issue.date.issueKey { return }
    onMainAfter(10) {[weak self] in self?.openingIssue = nil }
    openingIssue = issue
    let issueInfo = IssueDisplayService(feederContext: feederContext,
                                    issue: issue)
    loadingIssueInfos.append(issueInfo)
    issueInfo.showIssue(pushDelegate: self,
                         atArticle: openLast ? issue.lastArticleIndexForCurrentMode : nil,
                         atArticleScrollPos: openLast ? issue.lastArticleScrollPos : nil,
                         atSection: openLast ? issue.lastSection : nil,
                         atPage:openLast ? issue.lastPage : nil)
  }
}


extension HomeVC: PushIssueDelegate {
  func push(_ viewController: UIViewController, issueInfo: IssueDisplayService) {
    loadingIssueInfos.removeAll(where: { $0 == issueInfo })
    if navigationController?.topViewController != self {
      log("skip pushing: \(viewController) since another is already pushed. the other: \(String(describing: navigationController?.topViewController))")
      return
    }
    self.issueInfo = issueInfo
    self.navigationController?.pushViewController(viewController, animated: true)
  }
}
