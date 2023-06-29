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
  func _contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    let loc = interaction.location(in: collectionView)
    guard let indexPath = self.collectionView.indexPathForItem(at: loc) else {
      return nil
    }

    guard let issue = service.issue(at: indexPath.row) else {
      return nil
    }
    
    let actions = MenuActions()
    
    if issue.isComplete {
      actions.addMenuItem(title: "Ausgabe löschen",
                          icon: "trash") {[weak self] _ in
        issue.reduceToOverview()
        self?.collectionView.reloadItems(at: [indexPath])
        guard let ccvc = self as? IssueCarouselCVC,
              ccvc.centerIndex == indexPath.row else { return }
        ccvc.downloadButton.indicator.downloadState = .notStarted
      }
    } else {
      actions.addMenuItem(title: "Ausgabe laden",
                          icon: "download") {[weak self] _ in
        self?.service.download(issueAtIndex: indexPath.row)
        //MAY REFRESH!!!
      }
    }
    
    actions.addMenuItem(title: "Bild Teilen",
                        icon: "share") {[weak self] _ in
      self?.service.exportMoment(issue: issue)
    }
    
    actions.addMenuItem(title: "Scrollrichtung umkehren",
                        icon: "repeat") {[weak self] _ in
      guard let ccvc = self as? IssueCarouselCVC else { return }
      ccvc.scrollFromLeftToRight = !ccvc.scrollFromLeftToRight
    }
    
    actions.actions.append(contentsOf: issue.contextMenu(group: 1).actions)
        
    return UIContextMenuConfiguration(identifier: nil,
                                      previewProvider: nil){ _ -> UIMenu? in
      return actions.contextMenu
    }
  }
}
