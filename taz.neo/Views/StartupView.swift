//
//  StartupView.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

let TazRot = UIColor.rgb(0xd50d2e)

class StartupView: UIView {
  var startupLogo: UIImage?
  var imageView: UIImageView?
  
  override init(frame: CGRect) {
    startupLogo = UIImage(named: "StartupLogo")
    imageView = UIImageView(image: startupLogo)
    super.init(frame: frame)
    backgroundColor = TazRot
    if let iv = imageView {
      addSubview(iv)
      pin(iv.centerX, to: self.centerX)
      pin(iv.centerY, to: self.centerY)
    }
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
}
