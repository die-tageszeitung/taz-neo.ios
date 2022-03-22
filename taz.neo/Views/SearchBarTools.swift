//
//  SearchBarTools.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.03.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

/**
 Probleme Umsetzung UI/UX
 flackern bei von search controller nach tableview verschieben
 konzept des search controllers passt nicht zu ux konzept
 hoche annimieren noch keine Lösung
 => 2-3PT für UI/UX?
 
 */


import NorthLib

class SearchBarTools: UIView {
  
  lazy var errorTextLabel = UILabel()
  lazy var filterWrapper = UIView()
  
  var filterActive:Bool = false {
    didSet {
      extendedSearchButton.buttonView.isActivated
      = filterActive
    }
  }
  
  lazy var extendedSearchButton: Button<ImageView> = {
    let button = Button<ImageView>()
    button.pinSize(CGSize(width: 32, height: 32))
    button.buttonView.hinset = 0.1
    button.buttonView.name = "filter"
    button.buttonView.activeColor = Const.SetColor.ios(.tintColor).color
    button.buttonView.color = Const.SetColor.ios_opaque(.closeX).color
    button.buttonView.isActivated = false
    return button
  }()
  
  private func setup() {
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
    
    self.addSubview(filterWrapper)
    filterWrapper.pinHeight(0, priority: .fittingSizeLevel)
    pin(filterWrapper.right, to: self.right, dist: -Const.Size.DefaultPadding)
    pin(filterWrapper.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(filterWrapper.top, to: seperator.bottom)
    pin(filterWrapper.bottom, to: self.bottom, dist: -2)
    
    self.pinWidth(UIWindow.shortSide)
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
