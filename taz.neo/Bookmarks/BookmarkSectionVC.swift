//
//  BookmarkSectionVC.swift
//  taz.neo
//
//  Created by Norbert Thies on 18.06.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/**
 * A simple subclass of SectionVC with som additional flavours for bookmark handling.
 */
open class BookmarkSectionVC: SectionVC {
  
  // We don't have a toolbar
  override func setupToolbar() {}
  
  // Scroll to article position in bookmark section
  override public var article: Article? {
    didSet {
      if let art = article,
         let wv = currentWebView {
        let id = File.progname(art.html.name)
        let js = """
          document.getElementById("\(id)").scrollIntoView({block: "center"});
        """
        wv.jsexec(js)
      }
    }
  }
  
}
