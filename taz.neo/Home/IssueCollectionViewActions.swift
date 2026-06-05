//
//  IssueCollectionViewActions.swift
//  taz.neo
//
//  Created by Ringo Müller on 06.03.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

protocol IssueCollectionViewActions: UIContextMenuInteractionDelegate where Self: UICollectionViewController {
  var service: IssueOverviewService { get set }
}

extension IssueCollectionViewActions {
  
  func deleteIssue(issue: StoredIssue,
                   at indexPath: IndexPath) {
    if issue.isDownloading {
      ///WARNING May not catch all states, due isDownloading is set if Downloader.downloading files;
      ///not in first Step: get Structure Data @REFACTORING
      Log.log("Delete Issue: \(issue.date.short) while downloading")
      Toast.show("Bitte warten Sie bis der Download abgeschossen ist!", .alert)
      return
    }
    
    Log.log("Delete Issue: \(issue.date.short) manually")
    Usage.track(Usage.event.issue.delete,
                name: issue.date.ISO8601)
    Notification.send("issueDelete", content: issue.date)
    issue.lastPage = nil
    issue.lastArticle = nil
    issue.lastContent = nil
    issue.lastArticleScrollPos = nil
    issue.lastSection = nil
    issue.delete()
    self.collectionView.reloadItems(at: [indexPath])
    self.updateCarouselDownloadButton()

    onMainAfter(1.0) {[weak self] in
      /// Bugfix: ensure re-load of deleted issue will be executed.
      /// The item may be removed immediately in
      /// collectionView(_:didEndDisplaying:),
      /// which calls removeFromLoadFromRemote(key:).
      /// This can’t be prevented, so we re-add the item to the load queue
      /// to ensure reload.
      _ = self?.service.cellData(for: indexPath.row)
    }
  }
  
  func resetIssue(issue: StoredIssue,
                   at indexPath: IndexPath) {
    issue.lastPage = nil
    issue.lastArticle = nil
    issue.lastSection = nil
    issue.lastArticleScrollPos = nil
    ///reload is not needed currently
    //self.collectionView.reloadItems(at: [indexPath])
    //self.updateCarouselDownloadButton()
  }
  
  func updateCarouselDownloadButton(){
    guard let home = self as? HomeVC else { return }
    home.downloadButton.indicator.downloadState
    = self.service.cellData(for: home.carousselFixCenterIndex ?? 0)?.downloadState
  }
  
  func contextMenuInteraction(for indexPath: IndexPath, issue: StoredIssue) -> UIContextMenuConfiguration? {
    let actions = MenuActions()
        
    if issue.hasLastReadForCurrentMode {
      actions.addMenuItem(title: "Weiterlesen",
                          icon: "bookmark") {[weak self] _ in
        (self as? OpenIssueDelegate)?.openIssue(issue, openLast: true)
        Usage.track(Usage.event.dialog.OpenLastRead, name: "OpenFromHome")
      }
      actions.addMenuItem(title: "Lesestatus zurücksetzen",//Als neu/ungelesen markieren
                          icon: "bookmark-stroke-s") {[weak self] _ in
        issue.lastPage = nil
        issue.lastArticle = nil
        issue.lastSection = nil
        issue.lastContent = nil
        self?.collectionView.reloadItems(at: [indexPath])
        self?.updateCarouselDownloadButton()
      }
    }
   
    
    if issue.isComplete && issue.isAudioComplete == false && issue.hasAudio
    {
      actions.addMenuItem(title: "Audioinhalte laden",
                          icon: "download",
                          enabled: issue.isDownloading == false) {[weak self] _ in
        Notification.send("issueProgress", content: "waiting", sender: issue)
        self?.service.download(issueAt: issue.date, withAudio: true)
        guard let home = self as? HomeVC,
              home.carousselFixCenterIndex == indexPath.row else { return }
        home.downloadButton.indicator.downloadState = .waiting
      }
    } else if issue.isComplete == false {
      actions.addMenuItem(title: "Ausgabe laden",
                          icon: "download",
                          enabled: issue.isDownloading == false) {[weak self] _ in
        Notification.send("issueProgress", content: "waiting", sender: issue)
        self?.service.download(issueAt: issue.date, withAudio: false)
        guard let home = self as? HomeVC,
              home.carousselFixCenterIndex == indexPath.row else { return }
        home.downloadButton.indicator.downloadState = .waiting
      }
      ///issue.audioFiles.count > 0 not possible until download
      actions.addMenuItem(title: "Ausgabe mit Audio laden",
                          icon: "download",
                          enabled: issue.isDownloading == false) {[weak self] _ in
        Notification.send("issueProgress", content: "waiting", sender: issue)
        self?.service.download(issueAt: issue.date, withAudio: true)
        guard let home = self as? HomeVC,
              home.carousselFixCenterIndex == indexPath.row else { return }
        home.downloadButton.indicator.downloadState = .waiting
      }
    }
    
    actions.addMenuItem(title: "Bild Teilen",
                        icon: "share") {[weak self] _ in
      self?.service.exportMoment(issue: issue, sourceView: self?.view)
    }
    
    if let home = self as? HomeVC,
        home.isHomeTiles == false {
      actions.addMenuItem(title: "Scrollrichtung umkehren",
                          icon: "repeat") {_ in
        home.scrollFromLeftToRight.toggle()
      }
    }
    
    actions.addMenuItem(title: "Ausgabe löschen",
                        icon: "trash",
                        enabled: issue.isDownloading == false) {[weak self] _ in
      self?.deleteIssue(issue: issue, at: indexPath)
    }
    
    actions.actions.append(contentsOf: issue.contextMenu(group: 1).actions)
    Usage.track(Usage.event.dialog.IssueActions)
    return UIContextMenuConfiguration(identifier: nil,
                                      previewProvider: nil){ _ -> UIMenu? in
      return actions.contextMenu
    }
  }
  
  func _contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    configurationForMenuAtLocation location: CGPoint
  ) -> UIContextMenuConfiguration? {
    
    // Convert the touch location into the CollectionView coordinate system.
    let locationInCollectionView = interaction.location(in: collectionView)
    
    // Primary hit test.
    //
    // UICollectionView.indexPathForItem(at:) occasionally fails on iPad 9
    // when the carousel layout is initially displayed and the centered item
    // is scaled using a custom UICollectionViewFlowLayout.
    //
    // Therefore determine the tapped cell by checking the visible cell frames
    // directly in CollectionView coordinates.
    for cell in collectionView.visibleCells {
      let frame = cell.convert(cell.bounds, to: collectionView)
      if frame.contains(locationInCollectionView) {
        // Read the issue directly from the cell.
        // Using service.cellData(for:) could theoretically return a different
        // model if the datasource changes between hit testing and menu creation.
        if let issueCell = cell as? IssueCollectionViewCell,
           let issue = issueCell.data?.issue,
           let indexPath = collectionView.indexPath(for: issueCell) {
          return contextMenuInteraction(for: indexPath, issue: issue)
        }
        break
      }
    }
    
    // Fallback to UICollectionView hit testing.
    // This is the preferred UIKit API and works correctly in most cases.
    if let indexPath = collectionView.indexPathForItem(at: locationInCollectionView),
       let issue = service.cellData(for: indexPath.row)?.issue {
      return contextMenuInteraction(for: indexPath, issue: issue)
    }
    
    // Final fallback.
    // During layout transitions, animations or scrolling, the interaction may
    // already be attached to a cell even though hit testing above failed.
    if let tappedCell = interaction.view?.superview?.superview as? IssueCollectionViewCell,
       let issue = tappedCell.data?.issue,
       let indexPath = collectionView.indexPath(for: tappedCell) {
      return contextMenuInteraction(for: indexPath, issue: issue)
    }
    return nil
  }
}
