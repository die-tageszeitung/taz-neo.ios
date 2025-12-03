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
  var helpItems: [HelpItem] {
    get {
      let menu = HelpItem(title:"Inhaltsverzeichnis öffnen",
                          accessibilityTitle: "Hilfe für die Ausggabenansicht auf Ressortebene, erstes Element: Schalter 'Inhalt' zum öffnen des Inhaltsverzeichnisses der Ausgabe",
                               text: "Tippen Sie hier, um das vollständige Inhaltsverzeichnis der Ausgabe zu sehen.",
                          targetView: slider?.button)
      
      let swiping = HelpItem(title:"Durch Ressorts blättern",
                             text: "Wischen Sie nach links oder rechts, um zum vorherigen oder nächsten Ressort zu wechseln.",
                             accessibilityLabelText: " sie mit den Tasten: nächstes und vorheriges Ressort.")
      
      let toolbarBack = HelpItem(title:"Zurück",
                         text: "Hier geht es zurück zum Startbildschirm.",
                                 accessibilityLabelText: "Hier geht es zurück zum Startbildschirm, Schalter in der Toolbar unten",
                                 isCircleCutout: true, targetView: backButton)
      
      if let img = UIImage(named: "phone-hands-swipe"){
        let iv = UIImageView(image: img)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.pinSize(CGSize(width: 170, height: 170))
        swiping.topImageView = iv
      }
      
      return [menu, swiping, toolbarBack]
    }
  }
}

