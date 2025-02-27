//
//  BookmarkTableHeaderCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// Tableview cell as section header to prevent section header stacking
class BookmarkTableHeaderCell: UITableViewCell, UIStyleChangeDelegate{
  
  static let ReuseIdentifier = "BookmarkTableHeaderViewIdentifier"
  
  var dateLabel: UILabel = UILabel()
  let dottedLine = DottedLineView()
  private let imgView = UIImageView()
  var image: UIImage? {
    didSet {
      imgView.image = image
      textLeftImageConstraint?.isActive = image != nil
    }
  }
  
  var active: Bool = false {
    didSet {
      dateLabel.textColor
      = active
      ? Const.SetColor.CIColor.color
      : Const.SetColor.ios(.label).color
      if active == false && oldValue == true {
        contentView.layoutSubviews()
      }
    }
  }
  
  func applyStyles() {
    contentView.backgroundColor = Const.SetColor.ios(.systemBackground).color
    dottedLine.fillColor = Const.SetColor.HText.color
    dottedLine.strokeColor = Const.SetColor.HText.color
  }
  var textLeftImageConstraint: NSLayoutConstraint?
  func setup(){
    dottedLine.offset = 1.7
    dottedLine.pinHeight(Const.Size.DottedLineHeight*0.7)
    self.contentView.addSubview(dottedLine)
    self.contentView.addSubview(dateLabel)
    self.contentView.addSubview(imgView)
    pin(dottedLine.left, to: self.contentView.left, dist: Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    pin(dottedLine.right, to: self.contentView.right, dist: -Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    pin(dottedLine.bottom, to: self.contentView.bottom)
    imgView.pinSize(CGSize(width: 28, height: 37))
    imgView.contentMode = .scaleAspectFit
    
    pin(dateLabel.left, to: self.contentView.left, dist: Const.Size.DefaultPadding, priority: .defaultLow)
    pin(dateLabel.right, to: self.contentView.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    
    pin(imgView.left, to: self.contentView.left, dist: Const.Size.DefaultPadding)
    pin(imgView.bottom, to: self.contentView.bottom, dist: -Const.Size.DefaultPadding + 5)
    pin(dateLabel.centerY, to: imgView.centerY, dist: App.isLMD ? 2 : 0)
    textLeftImageConstraint = pin(dateLabel.left, to: imgView.right, dist: Const.Dist2.s10)
    textLeftImageConstraint?.isActive = false
    
    self.contentView.layoutMargins.top = 0.0
    self.contentView.layoutMargins.left = Const.Size.DefaultPadding
    self.contentView.layoutMargins.right = Const.Size.DefaultPadding
    
    registerForStyleUpdates()
    if App.isLMD {
      dateLabel.lmdArnhem(italic: true, size: 19)
    } else {
      dateLabel.boldContentFont()
    }
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}
