//
//  ArticleVC+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller on 02.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import NorthLib
import UIKit

extension ArticleVC: HelpProviding{
    
  var helpItems: [HelpItem] {
    get {
      let menu = HelpItem(title:"Inhaltsverzeichnis öffnen",
                          text: "Tippen Sie hier, um das vollständige Inhaltsverzeichnis der Ausgabe zu sehen.",
                          targetView: slider?.button)
      
      let swiping = HelpItem(title:"Durch Artikel blättern",
                                       text: "Wischen Sie nach links oder rechts, um zum vorherigen oder nächsten Artikel zu wechseln.")
      if let img = UIImage(named: "phone-hands-swipe"){
        let iv = UIImageView(image: img)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.pinSize(CGSize(width: 170, height: 170))
        swiping.topImageView = iv
      }
      
      let galleryZoom = HelpItem(title:"Bild vergrößern",
                                       text: "Tippen Sie auf ein Bild, um es im Vollbildmodus zu öffnen. Dort können Sie mit zwei Fingern hineinzoomen.")
      if let img = UIImage(named: "phone-hands-pinch"){
        let iv = UIImageView(image: img)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.pinSize(CGSize(width: 170, height: 170))
        galleryZoom.topImageView = iv
      }

      
      let gallerySwipe = HelpItem(title:"Bildergalerie",
                         text: "Wenn im Vollbildmodus kleine Punkte unter dem Bild zu sehen sind, gibt es mehrere Bilder. Wischen Sie nach links oder rechts, um durch die Galerie zu blättern.")
      
      if let img = UIImage(named: "phone-hands-swipe"){
        let iv = UIImageView(image: img)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.pinSize(CGSize(width: 170, height: 170))
        gallerySwipe.topImageView = iv
      }
      
      let isSearchIssue = self.issue is VirtualIssue
      let isBookmarkIssue = self.issue.isBookmarkIssue
      let isRegularIssue = !isSearchIssue && !isBookmarkIssue
      
      let backText
      = isRegularIssue
      ? "Hier geht es zurück zur Ressortübersicht und wenn Sie lange gedrückt halten, direkt zum Startbildschirm."
      : isBookmarkIssue
      ? "Hier geht es zurück zur Leseliste."
      : "Hier geht es zurück zu den Suchergebnissen."
      
      let toolbarBack = HelpItem(title:"Zurück",
                         text: backText,
                                 isCircleCutout: true,
                                 targetView: backButton)
      
      var items = [swiping]
      

      ///Not for Bookmark and Search!
      if isRegularIssue { items.insert(menu, at: 0) }
      
      if article is VirtualArticle {//TOM's!
        items.append(toolbarBack)
        return items
      }
      
      let bookmarkItem
      = HelpItem(title: isBookmarkIssue 
                 ? "Lesezeichen löschen"
                 : "Artikel speichern",
                 text: isBookmarkIssue
                 ? "Tippen Sie auf den gefüllten Stern, um den Artikel von Ihrer Leseliste zu entfernen."
                 :"Tippen Sie auf das Stern Symbol, um den Artikel in Ihrer Leseliste zu speichern. Die Leseliste erreichen Sie über den Startbildschirm.",
                 isCircleCutout: true,
                 targetView: bookmarkButton)
      
      
      items.append(contentsOf: [galleryZoom, gallerySwipe, toolbarBack, bookmarkItem])
      
      if article?.isShareable == true {
        items.append(HelpItem(title:"Artikel teilen",
                              text: "Tippen Sie auf das Teilen-Symbol, um den Artikel an andere weiterzuleiten.", isCircleCutout: true, targetView: shareButton))
      }
      
      if article?.canPlayAudio == true {
        items.append(HelpItem(title:"Artikel anhören",
                              text: "Tippen Sie auf das Lautsprecher-Symbol, um sich den Artikel vorlesen zu lassen.", isCircleCutout: true, targetView: playButton))
      }
        
      items.append(HelpItem(title:"Schriftgröße anpassen",
                            text: "Passen Sie hier die Schriftgröße nach Ihren Bedürfnissen an.", isCircleCutout: true, targetView: textSettingsButton))
      
      if isRegularIssue {
        items.append(HelpItem(title:"Ressortübersicht öffnen",
                              text: "Tippen Sie auf den Ressortnamen, um direkt zur Übersicht dieses Ressorts zu gelangen.", targetView: header.titleLabel))

      }
      
      let search = HelpItem(title:"Archivsuche – leicht gemacht!",
                            text: "Halten Sie ein Wort im Artikel gedrückt, um es zu markieren.\nÜber das Kontextmenü können Sie es kopieren oder direkt im taz-Archiv danach suchen.")
      if let img = UIImage(named: "Img-SearchMenu"){
        let view = UIImageView(image: img)
        view.contentMode = .scaleAspectFit
        view.pinHeight(130)
        search.contentView = view
      }
      items.append(search)
      return items
    }
  }
  func onDisplay(idx: Int, isClosing: Bool) {
    print("Help Item \(idx+1) \(isClosing ? "closing" : "displaying")")
    
  }
}
