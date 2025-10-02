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
  var items: [HelpItem] {
    get {
      let menu = HelpItem(title:"Inhaltsverzeichnis öffnen",
                               text: "Tippen Sie auf das taz-Logo, um das vollständige Inhaltsverzeichnis der Ausgabe zu sehen.",
                               isCircleCutout: false,
                          targetView: slider?.button)
      
//      Titel: Durch Ressorts blättern
//      Text: Wischen Sie nach links oder rechts, um zu weiteren Artikeln im Ressort zu gelangen.
      
      
      let swiping = HelpItem(title:"Durch Artikel blättern",
                                       text: "Wischen Sie nach links oder rechts, um zum vorigen oder nächsten Artikel zu wechseln.")
      if let img = UIImage(name: "arrowshape.left.arrowshape.right"){
        let wrapper = UIView()
        let view = UIImageView(image: img)
        view.tintColor = .white
        view.contentMode = .center
        view.pinWidth(80)
        wrapper.addSubview(view)
        pin(view.top, to: wrapper.top, dist: 18)
        pin(view.bottom, to: wrapper.bottom)
        view.centerX(dist: 20)
        swiping.contentView = wrapper
      }
      
      
      let itm = HelpItem(title:"Willkommen in der taz neo App!",
                         text: "Hier finden Sie die neuesten Nachrichten und Artikel.",
                         isCircleCutout: true,
                         targetView: self.backButton)
      return [menu, swiping, itm]
    }
  }
  func onDisplay(idx: Int, isClosing: Bool) {
    print("Help Item \(idx+1) \(isClosing ? "closing" : "displaying")")
    
  }
}

