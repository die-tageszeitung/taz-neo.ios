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
               image: UIImage(named: "trash")){[weak self] _ in
      issue.reduceToOverview()
      self?.collectionView.reloadItems(at: [indexPath])
      guard let ccvc = self as? IssueCarouselCVC,
            ccvc.centerIndex == indexPath.row else { return }
      ccvc.downloadButton.indicator.downloadState = .notStarted
    }
    : UIAction(title: "Ausgabe laden",
               image: UIImage(named: "download")){[weak self] _ in
      self?.service.download(issueAtIndex: indexPath.row)}
    
    let shareAction = UIAction(title: "Bild Teilen",
                               image: UIImage(named: "share")) {[weak self] _ in
      self?.service.exportMoment(issue: issue)
    }
    
    let invertRotation = UIAction(title: "Scrollrichtung umkehren",
                               image: UIImage(named: "repeat")) {[weak self] _ in
      guard let ccvc = self as? IssueCarouselCVC else { return }
      ccvc.scrollFromLeftToRight = !ccvc.scrollFromLeftToRight
    }
    
    var actions: [UIAction] =  [mainAction, shareAction]
    
    if self is IssueCarouselCVC {
      actions.append(invertRotation)
    }
    
    let defaultMenu = UIMenu(title: "",
                             options: .displayInline,
                             children: actions)
    let playMenu = ArticlePlayer.singleton.contextMenu(for: issue)
        
    return UIContextMenuConfiguration(identifier: nil,
                                      previewProvider: nil){ _ -> UIMenu? in
      return UIMenu(title: "", children: [defaultMenu, playMenu])
      //    without header there is no scrolling on iPhone 12 mini
      //      return UIMenu(title: "taz vom \(issue.date.short)", children: [defaultMenu, playMenu])
    }
  }
}
