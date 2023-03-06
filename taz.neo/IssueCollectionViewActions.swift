//
//  IssueCollectionViewActions.swift
//  taz.neo
//
//  Created by Ringo Müller on 06.03.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit

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
    
    let mainAction = issue.isComplete
    ? UIAction(title: "Ausgabe löschen",
               image: UIImage(named: "trash")){_ in issue.reduceToOverview()}
    : UIAction(title: "Ausgabe laden",
               image: UIImage(named: "download")){[weak self] _ in
      self?.service.download(issueAtIndex: indexPath.row)}
    
    let shareAction = UIAction(title: "Bild Teilen",
                               image: UIImage(named: "share")) {[weak self] _ in
      self?.service.exportMoment(issue: issue)
    }
        
    return UIContextMenuConfiguration(identifier: nil,
                                      previewProvider: nil){ _ -> UIMenu? in
      return  UIMenu(title: "", children: [mainAction, shareAction])
    }
  }
}
