//
//  SearchBarTools.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.03.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import NorthLib

class SearchBarTools: UIView {
  
  var bottomAreaHeightConstraint:NSLayoutConstraint?
  var widthConstraint:NSLayoutConstraint?
  
  var isOpen:Bool = false {
    didSet {
      if let tv = self.superview as? UITableView {
        self.bottomAreaHeightConstraint?.isActive = !self.isOpen
        self.setNeedsLayout()
        self.layoutIfNeeded()

        let f2 = !self.isOpen
        ? CGRect(x: 0.0, y: 0.0, width: 390.0, height: 153)
        : CGRect(x: 0.0, y: 0.0, width: 390.0, height: 32)
        
        
        // Animate the height change
//        let f = CGRect(x: 0, y: 0, width: tv.frame.size.width, height: self.frame.size.height)
//                print("SearchBarTools \n   frame : \(self.frame) \n   new : \(f) \n   tvhf: \(tv.tableHeaderView?.frame )")
        UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut) {
          tv.beginUpdates()
          tv.tableHeaderView?.frame = f2
          tv.endUpdates()
//          tv.setNeedsLayout()
//          tv.layoutIfNeeded()
        }
        return
      }
      


      
      UIView.animate(seconds: 0.3) { [weak self] in
        guard let self = self else { return }
        self.bottomAreaHeightConstraint?.isActive = !self.isOpen
        self.setNeedsLayout()
        self.layoutIfNeeded()
      }
    }
  }
  
  lazy var errorTextLabel = UILabel()
  
  lazy var extendedSearchButton: Button<ImageView> = {
    let button = Button<ImageView>()
    button.pinSize(CGSize(width: 32, height: 32))
    button.buttonView.hinset = 0.1
    button.buttonView.name = "filter"
    button.buttonView.imageView.tintColor = .black
    button.onTapping { [weak self] _ in
      guard let self = self else { return }
      self.isOpen = !self.isOpen
      print("Open is now: \(self.isOpen)")
    }
    return button
  }()
  
  lazy var bottomArea: UIView = {
    let v = UIView()
//    bottomAreaHeightConstraint = v.pinHeight(80)
    return v
  }()

  private func setup() {
    self.addBorder(.yellow.withAlphaComponent(0.7), 6)
    self.addSubview(extendedSearchButton)
    pin(extendedSearchButton.top, to: self.top, dist: 0)
    pin(extendedSearchButton.right, to: self.right, dist: -Const.Size.SmallPadding)
    
    self.addSubview(errorTextLabel)
    pin(errorTextLabel.centerY, to:extendedSearchButton.centerY)
    pin(errorTextLabel.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(errorTextLabel.right, to: extendedSearchButton.left, dist: -Const.Size.SmallPadding, priority: .fittingSizeLevel)
    errorTextLabel.contentFont()
    errorTextLabel.textColor = .red
    
    let seperator = UIView()
    seperator.pinHeight(0.5)
    seperator.backgroundColor = .black
    self.addSubview(seperator)
    pin(seperator.right, to: self.right, dist: -Const.Size.DefaultPadding)
    pin(seperator.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(seperator.top, to: extendedSearchButton.bottom)
    
    self.addSubview(bottomArea)
    pin(bottomArea.right, to: self.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    pin(bottomArea.left, to: self.left, dist: Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    bottomAreaHeightConstraint = bottomArea.pinHeight(120)
    bottomAreaHeightConstraint?.isActive = false
    
    pin(bottomArea.top, to: seperator.bottom)
    pin(bottomArea.bottom, to: self.bottom)
    
    self.backgroundColor = .purple
    bottomArea.backgroundColor = .yellow
    widthConstraint = self.pinWidth(UIWindow.shortSide)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}
