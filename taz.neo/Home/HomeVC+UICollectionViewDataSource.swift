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
//    updateAccessibilityOrder()
  }
  
  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    guard let cell = cell as? IssueTilesCvcCell,
          let data = service.cellData(for: indexPath.row) else { return }
    cell.data = data
    cell.isAccessibilityElement = true
//    updateAccessibilityOrder()
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
      cell.statusIndicatorTapArea.onTapping { [weak self] _ in
        if cell.button.indicator.downloadState?.canOpen == true,
          let issue = cell.data?.issue {
          self?.openIssue(issue,
                          openLast: true)
          Usage.track(Usage.event.dialog.OpenLastRead, name: "OpenFromHome")
          return
        }
        if let date = cell.data?.date.date,
          self?.service.download(issueAt: date, withAudio: false) != nil {
          self?.log("tap issue => download issueAt: \(date.short)")
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
    if carousselFixCenterIndex == indexPath.row {
      selectIsste(at: indexPath.row)
      return
    }
    scrollTo(indexPath.row, animated: true)
    onMainAfter {[weak self] in
      self?.selectIsste(at: indexPath.row)
    }
  }
  
  private func selectIsste(at index: Int) {
    guard let data = self.service.cellData(for: index),
          let issue = data.issue else {
      error("Issue not available try later")
      return
    }
    if isHomeTiles && data.downloadState == .notStarted {
      Notification.send("issueProgress", content: "waiting", sender: issue)
    }
    else if data.downloadState == .notStarted {
      downloadButton.indicator.downloadState = .waiting
    }
    openIssue(issue)
  }
  
}

///Version Compareable
extension Issue {
  var versionLocal2: Int { versionLocal ?? 0 }
  var versionRemote2: Int { versionRemote ?? 0 }
}


extension HomeVC {
  
  func openIssue(_ issue: StoredIssue, openLast: Bool = false) {
    _openIssue(issue, openLast: openLast, forceOpen: false)
  }
  
  ///open given issue
  ///if issue outdated try to update before open
  private func _openIssue(_ issue: StoredIssue, openLast: Bool = false, forceOpen: Bool) {
    let skipDownload = forceOpen && issue.versionLocal2 < issue.versionRemote2 && issue.isComplete
    log("issue: \(issue.date.short) server: \(issue.versionRemote2) localVersion: \(issue.versionLocal2)")
    if !forceOpen && issue.isComplete && issue.versionLocal2 < issue.versionRemote2 {
      ///try silent update
      ///in case of download errors show popup to request network connection to update or read outdated version
      Notification.receive("issue"){[weak self] notif in
        guard let issue = notif.object as? StoredIssue,
              let observer = notif.userInfo?["observer"] as? Notification.Observer else { return }
        let error: Error? = notif.userInfo?["error"] as? Error
        if error == nil {
          Notification.remove(observer: observer)
          self?.openIssue(issue, openLast: openLast)///force open not required due issue should be updated
          return
        }
        
        Alert.confirm(title: "Aktualisierung verfügbar",
                      message: "Für diese Ausgabe ist eine neuere Version verfügbar.\nSobald Sie online sind, können Sie die aktuelle Version laden.\nMöchten Sie jetzt weiterlesen oder erst aktualisieren?",
                      okText: "Weiterlesen",
                      cancelText: "Aktualisieren") {[weak self] (readNow) in
          if readNow {
            self?._openIssue(issue, openLast: openLast, forceOpen: true)
            Notification.remove(observer: observer)
            return
          }
          self?.feederContext.getCompleteIssue(issue: issue,
                                               isPages: self?.isFacsimile ?? false,
                                              isAutomatically: false,
                                              withAudio: issue.isAudioComplete)
          ///(No isUpdateDownload here to force offline Alert
        }
      }///endOf: Notification.receive("issue")
      self.feederContext.getCompleteIssue(issue: issue,
                                          isPages: isFacsimile,
                                          isAutomatically: false,
                                          withAudio: issue.isAudioComplete,
                                          errorNotificationMessage: "issue")///Notification.receive("issue") above
      return
    }
    
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
    
    let lastReadData = issue.lastReadData
    
    issueInfo.showIssue(pushDelegate: self,
                        atArticle: openLast ? lastReadData.lastArticleIndex : nil,
                        atArticleScrollPos: openLast ? lastReadData.articleScrollPos : nil,
                        atSection: openLast ? lastReadData.lastSectionIndex : nil,
                        atPage: openLast ? lastReadData.lastPage ?? issue.lastPage : nil, skipDownload: skipDownload)
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
