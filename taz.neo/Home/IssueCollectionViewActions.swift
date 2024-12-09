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
    
    Log.debug("Delete Issue: \(issue.date.short)")
    Usage.track(Usage.event.issue.delete,
                name: issue.date.ISO8601)
    Notification.send("issueDelete", content: issue.date)
    issue.delete()
    self.collectionView.reloadItems(at: [indexPath])
    self.updateCarouselDownloadButton()
  }
  
  func updateCarouselDownloadButton(){
    guard let ccvc = self as? IssueCarouselCVC else { return }
    ccvc.downloadButton.indicator.downloadState
    = self.service.cellData(for: ccvc.centerIndex ?? 0)?.downloadState
  }
  
  func _contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    let loc = interaction.location(in: collectionView)
    guard let indexPath = self.collectionView.indexPathForItem(at: loc) else {
      return nil
    }

    guard let issue = self.service.cellData(for: indexPath.row)?.issue else {
      return nil
    }
    
    let actions = MenuActions()
    
    actions.addMenuItem(title: "Ausgabe löschen",
                        icon: "trash",
                        enabled: issue.isDownloading == false) {[weak self] _ in
      self?.deleteIssue(issue: issue, at: indexPath)
    }
    
    if issue.isComplete && issue.isAudioComplete == false && issue.hasAudio
    {
        actions.addMenuItem(title: "Audioinhalte laden",
                            icon: "download",
                            enabled: issue.isDownloading == false) {[weak self] _ in
          self?.service.download(issueAt: issue.date, withAudio: true)
          guard let ccvc = self as? IssueCarouselCVC,
                ccvc.centerIndex == indexPath.row else { return }
          ccvc.downloadButton.indicator.downloadState = .waiting
        }
    } else if issue.isComplete == false {
      actions.addMenuItem(title: "Ausgabe laden",
                          icon: "download",
                          enabled: issue.isDownloading == false) {[weak self] _ in
        self?.service.download(issueAt: issue.date, withAudio: false)
        guard let ccvc = self as? IssueCarouselCVC,
              ccvc.centerIndex == indexPath.row else { return }
        ccvc.downloadButton.indicator.downloadState = .waiting
      }
      ///issue.audioFiles.count > 0 not possible until download
      actions.addMenuItem(title: "Ausgabe mit Audio laden",
                          icon: "download",
                          enabled: issue.isDownloading == false) {[weak self] _ in
        self?.service.download(issueAt: issue.date, withAudio: true)
        guard let ccvc = self as? IssueCarouselCVC,
              ccvc.centerIndex == indexPath.row else { return }
        ccvc.downloadButton.indicator.downloadState = .waiting
      }
    }
    
    actions.addMenuItem(title: "Bild Teilen",
                        icon: "share") {[weak self] _ in
      self?.service.exportMoment(issue: issue, sourceView: self?.view)
    }
    
    if self.isKind(of: IssueCarouselCVC.self) {
      actions.addMenuItem(title: "Scrollrichtung umkehren",
                          icon: "repeat") {[weak self] _ in
        guard let ccvc = self as? IssueCarouselCVC else { return }
        ccvc.scrollFromLeftToRight = !ccvc.scrollFromLeftToRight
      }
    }
    
    actions.actions.append(contentsOf: issue.contextMenu(group: 1).actions)
    Usage.track(Usage.event.dialog.IssueActions)
    return UIContextMenuConfiguration(identifier: nil,
                                      previewProvider: nil){ _ -> UIMenu? in
      return actions.contextMenu
    }
  }
}
