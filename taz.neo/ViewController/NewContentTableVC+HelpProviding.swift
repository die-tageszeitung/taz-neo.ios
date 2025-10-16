//
//  Untitled.swift
//  taz.neo
//
//  Created by Ringo Müller on 13.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import NorthLib
import UIKit

extension NewContentTableVC : HelpProviding {
  
  var firstVisibleSection: Int? {
      (0..<tableView.numberOfSections)
          .first(where: { tableView.bounds.intersects(tableView.rectForHeader(inSection: $0)) })
  }
  
  var helpItems: [HelpItem] {
    get {
      
      var firstVisibleSectionHeader:ContentTableHeaderFooterView?
      var firstVisibleCell:NewContentTableVcCell?
      var firstVisibleSectionFromCells:Int?
      
      if let firstVisibleIndexPath:IndexPath
          = self.tableView.indexPathsForVisibleRows?.min() {
        firstVisibleSectionFromCells = firstVisibleIndexPath.section
        firstVisibleCell =
        tableView.cellForRow(at: firstVisibleIndexPath) as? NewContentTableVcCell
      }
      
      
      if let idx = firstVisibleSectionFromCells ?? firstVisibleSection {
        for i in 0...4 {
          guard i < tableView.numberOfSections else { break }
          let sectHeader = self.tableView.headerView(forSection: idx + i) as? ContentTableHeaderFooterView
          if sectHeader?.chevron.isHidden == false {
            firstVisibleSectionHeader = sectHeader
            break
          }
        }
      }
      
      let moment = HelpItem(title:"Zurück zur Übersicht",
                          text: "Tippen Sie auf das Titelbild, um zur Ausgabenübersicht zurückzukehren.",
                            isCircleCutout: true,
                          targetView: self.momentImageView)
      let showAllArticles = HelpItem(title:"Alle Artikel anzeigen",
                          text: "Tippen Sie hier, um alle Artikel der Ausgabe anzuzeigen.",
                                     isCircleCutout: true,
                          targetView: self.collapseIcon)
      let playAllArticles = HelpItem(title:"Alle Artikel anhören",
                          text: "Tippen Sie hier, um sich die gesamte Ausgabe von Anfang bis Ende vorlesen zu lassen.",
                                     isCircleCutout: true,
                          targetView: self.listenButton)
      let firstSectionHeader = HelpItem(title:"Ressort/Thema öffnen",
                          text: "Tippen Sie auf den Ressort- bzw. Themennamen, um alle Artikel dieses Bereiches in der Übersicht zu anzuzeigen.",
                                        targetView: firstVisibleSectionHeader?.label)
      let expandRessort = HelpItem(title:"Thema auf-/zuklappen",
                          text: "Tippen Sie auf den Pfeil, um die Liste aller Artikel eines Ressorts anzuzeigen oder auszublenden.",
                                   isCircleCutout: true,
                          targetView: firstVisibleSectionHeader?.chevron)
      let bookmark = HelpItem(title:"Zur Leseliste hinzufügen",
                          text: "Tippen Sie auf den Stern neben einem Artikel, um ihn zu Ihrer Leseliste hinzuzufügen. Ihre Leseliste finden Sie auf dem Startbildschirm neben \"Home\".",
                              isCircleCutout: true,
                              targetView: firstVisibleCell?.bookmarkButton)
      
      return [moment, showAllArticles, playAllArticles, firstSectionHeader, expandRessort, bookmark]
    }
  }

}
