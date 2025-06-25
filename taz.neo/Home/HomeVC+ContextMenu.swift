//
//  HomeVC+ContextMenu.swift
//  taz.neo
//
//  Created by Ringo Müller on 25.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

extension HomeVC : IssueCollectionViewActions  {
  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    return _contextMenuInteraction(interaction, configurationForMenuAtLocation: location)
  }
  
}
