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
    lbl.boldContentFont()
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

class BookmarksEmptyStateView: PlaceholderView{
  
  lazy var syncLabel: UILabel = {
    let lbl = UILabel()
    lbl.textAlignment = .center
    lbl.numberOfLines = 0
    lbl.contentFont()
    lbl.textColor = Const.SetColor.ios(.secondaryLabel).color
    lbl.addBorderView(Const.SetColor.ios(.secondaryLabel).color, edge: .bottom)
    return lbl
  }()
  
  lazy var spinner = UIActivityIndicatorView()
  
  override func setup(){
    super.setup()
    spinner.isHidden = true
    spinner.style = .medium
    spinner.color = Const.SetColor.ios(.secondaryLabel).color
    self.addSubview(syncLabel)
    self.addSubview(spinner)
    syncLabel.centerX()
    spinner.centerX()
    pin(syncLabel.top, to: label.bottom, dist: 18)
    pin(spinner.centerY, to: syncLabel.centerY)
  }
}
