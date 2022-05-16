//
//  PlaceholderView.swift
//  taz.neo
//
//  Created by Ringo Müller on 12.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib

class PlaceholderView: UIView{
  
  lazy var label: UILabel = {
    let lbl = UILabel()
    lbl.textAlignment = .center
    lbl.numberOfLines = 0
    lbl.boldContentFont(size: Const.Size.SubtitleFontSize)
    lbl.textColor =  Const.SetColor.taz(.textFieldClear).color
    return lbl
  }()
  
  lazy var icon: UIImageView = {
    let ico = UIImageView()
    ico.tintColor = Const.SetColor.taz(.textFieldClear).color
    ico.pinSize(CGSize(width: 56, height: 56))
    return ico
  }()
  
  func setup(){
    self.addSubview(icon)
    self.addSubview(label)
    pin(label.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(label.right, to: self.right, dist: -Const.Size.DefaultPadding)
    label.centerY(dist: -20)
    icon.centerX()
    pin(icon.bottom, to: label.top, dist: -18)
  }
  
  init(_ text: String, image: UIImage?){
    super.init(frame: .zero)
    self.icon.image = image
    self.label.text = text
    setup()
  }
  
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    label.textColor =  Const.SetColor.taz(.textFieldClear).color
    icon.tintColor = Const.SetColor.taz(.textFieldClear).color
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
