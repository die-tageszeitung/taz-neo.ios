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

// Label and Button
class SearchBarFixedHeader: UIView {
  
  static let height: CGFloat = 30.0
  
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
    pin(extendedSearchButton.top, to: self.topGuide(), dist: 0)
    pin(extendedSearchButton.right, to: self.right, dist: -Const.Size.SmallPadding)
    
    self.addSubview(textLabel)
    pin(textLabel.centerY, to:extendedSearchButton.centerY)
    textLabel.pinSize(CGSize(width: 200, height: 30), priority: .defaultLow)//prevent size animation error
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
    pin(seperator.bottom, to: self.bottom, dist: 5)
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
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


class TableHeaderFilterWrapperView: UIView {
  let wrapper = UIView()

  public private(set) var filterWrapperHeightConstraint: NSLayoutConstraint?
  
  private func setup() {
    self.addSubview(wrapper)
    filterWrapperHeightConstraint = wrapper.pinHeight(0)
    pin(wrapper.right, to: self.right)
    pin(wrapper.left, to: self.left)
    pin(wrapper.top, to: self.top, dist: SearchBarFixedHeader.height)
    pin(wrapper.bottom, to: self.bottom)
    self.backgroundColor = .yellow
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
