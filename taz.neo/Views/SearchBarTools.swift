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
  
  let textLabel = UILabel()
  let filterWrapper = UIView()
  let seperator = UIView()
  
  public private(set) var filterWrapperHeightConstraint: NSLayoutConstraint?
  
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
  
  func set(text: String?, font: UIFont = Const.Fonts.contentFont, color: UIColor = Const.SetColor.ios(.label).color){
    textLabel.text = text
    textLabel.font = font
    textLabel.textColor = color
  }
  
  private func setup() {
    self.addSubview(extendedSearchButton)
    pin(extendedSearchButton.top, to: self.top, dist: 0)
    pin(extendedSearchButton.right, to: self.right, dist: -Const.Size.SmallPadding)
    
    self.addSubview(textLabel)
    pin(textLabel.centerY, to:extendedSearchButton.centerY)
    pin(textLabel.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(textLabel.right, to: extendedSearchButton.left, dist: -Const.Size.SmallPadding, priority: .fittingSizeLevel)
    textLabel.contentFont()
    textLabel.textColor = .red

    seperator.pinHeight(0.5)
    seperator.backgroundColor = Const.SetColor.ios(.label).color
    self.addSubview(seperator)
    pin(seperator.right, to: self.right, dist: -Const.Size.DefaultPadding)
    pin(seperator.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(seperator.top, to: extendedSearchButton.bottom)
    
    self.addSubview(filterWrapper)
    filterWrapperHeightConstraint = filterWrapper.pinHeight(0)
    
    let padding = Device.isIpad ? Const.Size.DefaultPadding : 0
    
    pin(filterWrapper.right, to: self.right, dist: -padding)
    pin(filterWrapper.left, to: self.left, dist: padding)
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
