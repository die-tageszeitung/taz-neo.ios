//
//  NewPdfOverviewCollectionVC+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 30.10.26.
//  Copyright © 2026 Ringo Müller-Gromes. All rights reserved.
//
import UIKit

extension NewPdfOverviewCollectionVC: HelpProviding{
  var helpItems: [HelpItem] {
    get {
      
      var pageCell: PdfPageCell?
      var articleCell: PdfArticleCell?
      var sectionHeaderView: PdfSectionHeaderView?

      for cell in collectionView.visibleCells {
        if pageCell == nil {
          pageCell = cell as? PdfPageCell
        }
        if let target = cell as? PdfArticleCell {
          articleCell = target
        }
      }

      sectionHeaderView = collectionView
        .visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        .compactMap { $0 as? PdfSectionHeaderView }
        .last
      
      let moment = HelpItem(title:"Zurück zur Übersicht",
                            accessibilityTitle: "Hilfe für das Seitenmenü: Inhalt, dieser ist geöffnet erstes Element: Schalter Zurück zur Übersicht",
                            text: "Tippen Sie auf das Titelbild, um zur Ausgabenübersicht zurückzukehren.",
                            targetView: self.menuHeaderView.coverImageView)
      let modeSwitch = HelpItem(title:"Ansichtswechsel",
                                     text: "Hier können Sie zwischen Listenansicht und Seitenansicht umschalten.",
                                isCircleCutout: true,
                                circleCutoutInsetAdjustment: -20.0,
                                     targetView: self.menuHeaderView.modeSwitchButton)
      let playAllArticles = HelpItem(title:"Alle Artikel anhören",
                                     text: "Tippen Sie hier, um sich die gesamte Ausgabe von Anfang bis Ende vorlesen zu lassen.",
                                     isCircleCutout: true,
                                     circleCutoutInsetAdjustment: -20.0,
                                     targetView: self.menuHeaderView.listenButton)
      let page = HelpItem(title: "Seite anzeigen",
                          text: "Tippen Sie auf \(isPdfPageMode ? "eine" : "die") Seitenminiatur, um diese Seite anzuzeigen.",
                          isCircleCutout: !isPdfPageMode,
                          circleCutoutInsetAdjustment: 6.0,
                          targetView: isPdfPageMode ? nil : pageCell)
      
      let article = HelpItem(title: "Artikel öffnen",
                             text: "Tippen Sie auf den Artikel, um ihn anzuzeigen.",
                             isCircleCutout: true,
                             circleCutoutInsetAdjustment: 4.0,
                             targetView: articleCell)
      
      let ressort = HelpItem(title: "Ressort öffnen",
                             text: "Tippen Sie auf den Ressortnamen, um zur ersten Seite dieses Ressorts in der Zeitungsansicht zu gelangen.",
                             isCircleCutout: true,
                             circleCutoutInsetAdjustment: 4.0,
                             targetView: sectionHeaderView)
      let bookmark = HelpItem(title:"Zur Leseliste hinzufügen",
                              text: "Tippen Sie auf den Stern neben einem Artikel, um ihn zu Ihrer Leseliste hinzuzufügen. Ihre Leseliste finden Sie auf dem Startbildschirm neben \"Home\".",
                              isCircleCutout: true,
                              targetView: articleCell?.bookmarkButton)
      return isPdfPageMode
      ? [moment, modeSwitch, playAllArticles, page]
      : [moment, modeSwitch, playAllArticles, page, article, ressort, bookmark]
    }
  }
  func onDisplay(idx: Int, isClosing: Bool) {
    print("Help Item \(idx+1) \(isClosing ? "closing" : "displaying")")
    
  }
}
