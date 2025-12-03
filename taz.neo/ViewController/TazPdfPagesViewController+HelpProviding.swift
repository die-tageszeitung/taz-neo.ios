//
//  TazPdfPagesViewController+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller on 19.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit

extension TazPdfPagesViewController: HelpProviding{
    
  var helpItems: [HelpItem] {
    get {
      let menu = HelpItem(title:"Inhaltsverzeichnis öffnen",
                          accessibilityTitle: "Hilfe für die Ausggabenansicht in der Zeitungsansicht, erstes Element: Schalter 'Inhalt' zum öffnen des Inhaltsverzeichnisses der Ausgabe",
                          text: "Tippen Sie hier, um das vollständige Inhaltsverzeichnis der Ausgabe zu sehen.",
                          targetView: slider?.button)
      
      let swiping = HelpItem(title:"Durch die Ausgabe blättern",
                                       text: "Wischen Sie nach links oder rechts, um zur vorherigen oder nächsten Seite zu wechseln.")
      if let img = UIImage(named: "phone-hands-swipe"){
        let iv = UIImageView(image: img)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.pinSize(CGSize(width: 170, height: 170))
        swiping.topImageView = iv
      }
      
      var articleTapText = "Tippen Sie auf der Seite auf einen Artikel, um ihn im Lesemodus anzuzeigen.\nDort können Sie die Schriftgröße ändern, sich den Artikel vorlesen lassen und den Nachtmodus aktivieren."
      if articleFromPdf == false {
        articleTapText.append("\nAchtung! Sie haben diese Funktion deaktiviert. Blättern Sie in der Hilfe weiter, um zu erfahren wie Sie diese Funktion wieder aktivieren können.")
      }
      let articleTap = HelpItem(title:"Artikel lesen",
                                       text: articleTapText)
 
      let pageZoomText
      = doubleTapToZoomPdf
      ? "Vergrößern Sie die Seite, indem Sie zwei Finger auflegen und auseinanderziehen oder tippen Sie einfach doppelt an die Stelle, die Sie vergrößern möchten."
      : "Vergrößern Sie die Seite, indem Sie zwei Finger auflegen und auseinanderziehen."
      
      let pageZoom = HelpItem(title:"Seite vergrößern",
                                       text: pageZoomText)
      if let img = UIImage(named: "phone-hands-pinch"){
        let iv = UIImageView(image: img)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.pinSize(CGSize(width: 170, height: 170))
        pageZoom.topImageView = iv
      }
      
      let facsimileSettings = HelpItem(title:"Einstellungen der Zeitungsansicht",
                                       text: "Tippen Sie länger auf die Zeitungsseite, um schnell die Artikelansicht ein- oder auszuschalten und weitere Einstellungen vorzunehmen.")
      if let img = UIImage(named: "phone-hands-pinch"){
        let iv = UIImageView(image: img)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.pinSize(CGSize(width: 170, height: 170))
        pageZoom.topImageView = iv
      }
      
      let toolbarBack = HelpItem(title:"Zurück",
                         text: "Hier geht es zurück zum Startbildschirm.", isCircleCutout: true, targetView: backButton)
      
      let toolbarShare = HelpItem(title:"Seite teilen",
                            text: "Tippen Sie auf das Teilen-Symbol, um die Seite als PDF an andere weiterzuleiten oder auszudrucken.", isCircleCutout: true, targetView: shareButton)
      
      let toolbarHome = HelpItem(title:"(auch) Zurück",
                         text: "Hier geht es auch zurück zum Startbildschirm.", isCircleCutout: true, targetView: homeButton)
      
      return [menu, articleTap, swiping, pageZoom, facsimileSettings, toolbarBack, toolbarShare, toolbarHome]
    }
  }
  func onDisplay(idx: Int, isClosing: Bool) {
    print("Help Item \(idx+1) \(isClosing ? "closing" : "displaying")")
    
  }
}
