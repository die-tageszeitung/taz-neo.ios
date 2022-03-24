//
//  SearchBarTools.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.03.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//
import NorthLib

// Label and Button
class SearchBarFixedHeader: UIView {
  
  public private(set) var filterWrapperHeightConstraint: NSLayoutConstraint?
  
  let wrapper = UIView()
  
  let textLabel = UILabel()
  let seperator = UIView()
  //todo rename to filter button
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
    textLabel.alpha = 1.0//ensure visible
    textLabel.font = font
    textLabel.textColor = color
  }
  
  var filterActive:Bool = false {
    didSet {
      extendedSearchButton.buttonView.isActivated
      = filterActive
    }
  }
  
  private func setup() {
    self.addSubview(extendedSearchButton)
    pin(extendedSearchButton.top, to: self.top, dist: 8)
    pin(extendedSearchButton.right, to: self.right, dist: -Const.Size.SmallPadding)
    
    self.addSubview(textLabel)
    pin(textLabel.centerY, to:extendedSearchButton.centerY)
//    textLabel.pinSize(CGSize(width: 200, height: 30), priority: .defaultLow)//prevent size animation error
    pin(textLabel.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(textLabel.right, to: extendedSearchButton.left, dist: -Const.Size.SmallPadding, priority: .fittingSizeLevel)
    textLabel.contentFont()
    textLabel.textColor = .red

    seperator.pinHeight(0.5)
    seperator.backgroundColor = Const.SetColor.ios(.label).color
    self.addSubview(seperator)
    pin(seperator.right, to: self.right, dist: -Const.Size.DefaultPadding)
    pin(seperator.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(seperator.top, to: self.top, dist: 40)
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
    
    self.addSubview(wrapper)
//    filterWrapperHeightConstraint = wrapper.pinHeight(0)
    pin(wrapper.right, to: self.right)
    pin(wrapper.left, to: self.left)
    pin(wrapper.top, to: seperator.bottom, dist: 0)
    pin(wrapper.bottom, to: self.bottom)
    
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
