//
//  SectionVC+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller on 09.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

//
//  ArticleVC+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller on 02.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import NorthLib
import UIKit

extension SectionVC: HelpProviding{
  var items: [HelpItem] {
    get {
      let menu = HelpItem(title:"Inhaltsverzeichnis öffnen",
                               text: "Tippen Sie hier, um das vollständige Inhaltsverzeichnis der Ausgabe zu sehen.",
                          targetView: slider?.button)
      
      let swiping = HelpItem(title:"Durch Ressorts blättern",
                                       text: "Wischen Sie nach links oder rechts, um zum vorigen oder nächsten Ressort zu wechseln.")
      if let img = UIImage(named: "phone-hands-swipe"){
        let iv = UIImageView(image: img)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.pinSize(CGSize(width: 170, height: 170))
        swiping.topImageView = iv
      }
      
      let menuMoment = HelpItem(title:"Wieder zur Übersicht",
                               text: "Klicken Sie auf das kleine Titelbild, um zur Übersicht der Ausgaben zurückzukehren. Oder nutzen Sie den \"Zurück\"-Knopf unten links",
                                targetView: contentTable?.momentImageView)
      
      let menuListen = HelpItem(title:"Alle Artikel anhören",
                               text: "Tippen Sie hier, um sich die gesamte Ausgabe von Anfang bis Ende vorlesen zu lassen.",
                                targetView: contentTable?.listenButton)
      
      let showAll = HelpItem(title:"Alle Artikel anzeigen",
                               text: "Tippen Sie auf den Doppelpfeil, um die Liste aller Artikel dieser Ausgabe zu öffnen oder wieder zu schließen.",
                             isCircleCutout: true,
                                targetView: contentTable?.collapseIcon)
      #warning("table is not initialized yet, neet getter on first access")
      let ressortOpen = HelpItem(title:"Themenbereich öffnen",
                               text: "Tippen Sie auf den Namen des Bereichs, um alle Artikel in der Übersicht dazu zu sehen.",
                                targetView: contentTable?.firstSectionHeaderLabel)
      
      let ressortExpand = HelpItem(title:"Themenbereich aufklappen",
                               text: "Tippen Sie auf den kleinen Pfeil, um die Artikel in diesem Bereich anzuzeigen.\n  Sie sehen dann alle zum Ressort gehörigen Artikel",
                                   isCircleCutout: true,
                                targetView: contentTable?.firstSectionHeaderChevron)

      
      return [menu, menuMoment, menuListen, showAll, ressortOpen, ressortExpand, swiping]
    }
  }
  
  func onDisplay(idx: Int, isClosing: Bool) {
    if idx > 0 && slider?.isOpen == false {
      helpDidOpenSlider = true
      slider?.open(animated: false)
    }
    if idx == 0 && helpDidOpenSlider {
      helpDidOpenSlider = false
      slider?.close(animated: false)
    }
      
    
    #warning("on end display fehlt!")///slider was open...do close
    print("Help Item \(idx+1) \(isClosing ? "closing" : "displaying")")
  }
}

