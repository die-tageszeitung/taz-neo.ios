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
  public var viewName: String {
    return "Home"
  }
  
  public func targetView(for item: CoachmarkItem) -> UIView? {
    return nil
  }
  
  public func target(for item: CoachmarkItem) -> (UIImage, [UIView], [CGPoint])? {
    return nil
  }
  
  public func openHelp() {
    CoachmarksBusiness.shared.showHelp(sender: self)
  }
  var items: [CoachmarkItem] {
    get {
      let itm = CoachmarkItem(title:"Willkommen in der taz neo App!",
                              text: "Hier finden Sie die neuesten Nachrichten und Artikel.",
                              isCircleCutout: true,
                              targetView: self.backButton)
      return [itm, itm]
    }
    
  }
}
