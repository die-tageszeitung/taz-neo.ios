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
      
      return [menu, swiping]
    }
  }
  func onDisplay(idx: Int, isClosing: Bool) {
    print("Help Item \(idx+1) \(isClosing ? "closing" : "displaying")")
    
  }
}

