//
//  ContinueReadingController.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.07.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

class ContinueReadingController: FloatingPanelController {
  init(title: String,
       text: String,
       image: UIImage? = nil,
       targetVc: UIViewController,
       bottomOffset: CGFloat? = nil,
       finishHandler: @escaping (Bool?)->()){
    super.init(nibName: nil, bundle: nil)
    
    contentView.rightPadding = 2*contentView.padding + 33.0 //for close x with a width of 28px
    contentView.imageView.image = image
    contentView.imageView.contentMode = .scaleAspectFit
    contentView.topLabel.text = title
    contentView.bottomLabel.text = text
    
    self.finishHandler = finishHandler
    
    setup(targetVc: targetVc, sidePadding: contentView.padding)
  }
  
  init(lastContent: Content?,
       targetVc: UIViewController,
       bottomOffset: CGFloat? = nil,
       finishHandler: @escaping (Bool?)->()){
    super.init(nibName: nil, bundle: nil)
    contentView.rightPadding = 2*contentView.padding + 33.0 //for close x with a width of 28px
    if let lastArticle = lastContent as? Article {
      contentView.imageView.image = lastArticle.firstImage
    }
    else if let lastSection = lastContent as? Section {
      contentView.imageView.image = lastSection.firstImage
    }
    contentView.bottomLabel.text = lastContent?.title ?? "(kein Titel angegeben)"
    
    self.finishHandler = finishHandler
    
    setup(targetVc: targetVc, sidePadding: contentView.padding)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension ContentToolbar {
  var yOffset: CGFloat {
    let frame = self.convert(self.bounds, to: nil)
    return frame.size.height - frame.origin.y
  }
}

