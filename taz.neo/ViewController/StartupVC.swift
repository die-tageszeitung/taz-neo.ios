//
//  StartupVC.swift
//
//  Created by Norbert Thies on 27.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A simple view controller only showing a startup screen
/// ...just a Spinner in Git History there is more
class StartupVC : UIViewController {
  public var text: String = "Starte..." {
    didSet {
      label.text = text
    }
  }
  
  let label = UILabel()
  let ai = UIActivityIndicatorView()
  
  override func viewDidLoad() {
    label.numberOfLines = -1
    label.text = text
    label.contentFont().center()
    label.textColor = .white
    

    self.view.addSubview(label)
    self.view.addSubview(ai)
    
    pin(label.left, to: self.view.leftGuide(isMargin: true), dist: 10)
    pin(label.right, to: self.view.rightGuide(isMargin: true), dist: 10)
    label.centerY()
    
    ai.centerX()
    pin(label.top, to: ai.bottom, dist: 10)
    
    ai.startAnimating()
  }
  
  open override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    ai.stopAnimating()
  }
} // StartupVC
