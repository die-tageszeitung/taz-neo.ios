//
//  TableSectionSeperatorFooterView.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

///just a black/white line
class TableSectionSeperatorFooterView: UITableViewHeaderFooterView, UIStyleChangeDelegate{
  static let ReuseIdentifier = "TableSectionSeperatorFooterViewIdentifier"
  var line: UIView = UIView()
  
  func applyStyles() {
    line.backgroundColor = Const.SetColor.HText.color
  }
  
  func setup() {
    line.backgroundColor = Const.SetColor.ios(.systemBackground).color
    self.contentView.addSubview(line)
    
    pin(line.left, to: self.contentView.left, dist: Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    pin(line.right, to: self.contentView.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    line.centerY()
    line.pinHeight(0.7)
    
    self.contentView.layoutMargins.left = Const.Size.DefaultPadding
    self.contentView.layoutMargins.right = Const.Size.DefaultPadding
    
    registerForStyleUpdates()
  }
  
  override init(reuseIdentifier: String?) {
    super.init(reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}
