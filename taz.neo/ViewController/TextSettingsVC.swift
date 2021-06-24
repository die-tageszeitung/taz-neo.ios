//
//  TextSettingsVC.swift
//
//  Created by Norbert Thies on 06.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/**
 The TextSettingsVC is responsible for setting text attributes
 like fontsize of Articles.
 */
class TextSettingsVC: UIViewController, UIStyleChangeDelegate {
  
  /// View responsible for text settings representation
  private var textSettings = TextSettingsView()
  
  @DefaultInt(key: "articleTextSize")
  private var articleTextSize: Int
  
  @DefaultInt(key: "articleColumnMaxWidth")
  private var articleColumnMaxWidth: Int
  
  func updateButtonValuesOnOpen(){
    textSettings.textSize = articleTextSize
    textSettings.articleColumnMaxWidth = articleColumnMaxWidth
  }
  
  @Default(key: "colorMode")
  private var colorMode: String?
  
  private func setupButtons() {
    func setSize(_ s: Int) {
      textSettings.textSize = s
      articleTextSize = s
      NorthLib.Notification.send(globalStylesChangedNotification)
    }
    func setWidth(_ w: Int) {
      textSettings.articleColumnMaxWidth = w
      articleColumnMaxWidth = w
      NorthLib.Notification.send(globalStylesChangedNotification)
    }
    
    
    textSettings.textSize = articleTextSize
    textSettings.smallA.onPress {_ in
      if self.articleTextSize > 30 { setSize(self.articleTextSize-10) }
    }
    textSettings.largeA.onPress {_ in
      if self.articleTextSize < 200 { setSize(self.articleTextSize+10) }
    }
    textSettings.percent.onPress {_ in
      if self.articleTextSize != 100 { setSize(100) }
    }
    
    textSettings.articleColumnMaxWidth = articleColumnMaxWidth
    textSettings.decreaseWith.onPress {_ in
      if self.articleColumnMaxWidth > 250 { setWidth(self.articleColumnMaxWidth-10) }
    }
    textSettings.increaseWith.onPress {_ in
      if self.articleColumnMaxWidth < Int(UIScreen.longSide) - 20 { setWidth(self.articleColumnMaxWidth+10) }
    }
    textSettings.defaultWidth.onPress {_ in
      if self.articleColumnMaxWidth != 660 { setWidth(660) }
    }
   
    textSettings.day.onPress {_ in
      Defaults.darkMode = false
    }
    textSettings.night.onPress {_ in
      Defaults.darkMode = true
    }
  }
  
  func applyStyles() {
    self.view.backgroundColor = Const.SetColor.ios(.secondarySystemBackground).color
    textSettings.backgroundColor = Const.SetColor.ios(.secondarySystemBackground).color
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(textSettings)
    setupButtons()
    textSettings.pinHeight(195)
    pin(textSettings.top, to: self.view.top)
    pin(textSettings.left, to: self.view.left, dist: 8)
    pin(textSettings.right, to: self.view.right, dist: -8)
    registerForStyleUpdates()
  }
  
}

class TextSettingsView: UIView, UIStyleChangeDelegate {
  
  /// Default font
  private static let defaultFont = Const.Fonts.contentFont(size: 20)
  private static let smallFont = Const.Fonts.contentFont(size: 16)
  private static let largeFont = Const.Fonts.contentFont(size: 38)
  
  /// Buttons used to switch between various modes
  public var smallA = Button<TextView>()
  public var largeA = Button<TextView>()
  public var percent = Button<TextView>()
  
  public var decreaseWith = Button<TextView>()
  public var increaseWith = Button<TextView>()
  public var defaultWidth = Button<TextView>()
  
  public var day = Button<TextView>()
  public var night = Button<TextView>()
  //public var auto = Button<TextView>()
  private var verticalStack = UIStackView()
  private var sizeStack = UIStackView()
  private var widthStack = UIStackView()
  private var modeStack = UIStackView()
  
  public var textSize: Int = 100 {
    didSet { percent.buttonView.text = "\(textSize)%" }
  }
  
  public var articleColumnMaxWidth: Int = 660 {
    didSet { defaultWidth.buttonView.text = "⬌ \(articleColumnMaxWidth)px" }
  }
  
  private func setup() {
    
    largeA.buttonView.label.textInsets = UIEdgeInsets(top: -12.0, left: 0, bottom: 0, right: 0)
    smallA.buttonView.label.textInsets = UIEdgeInsets(top: 4.0, left: 0, bottom: 0, right: 0)
    
    smallA.buttonView.text = "a"
    smallA.buttonView.font = TextSettingsView.smallFont
    smallA.buttonView.label.baselineAdjustment = .alignCenters
    largeA.buttonView.text = "a"
    largeA.buttonView.label.baselineAdjustment = .alignCenters
    largeA.buttonView.font = TextSettingsView.largeFont
    percent.buttonView.text = "\(textSize)%"
    percent.buttonView.label.baselineAdjustment = .alignCenters
    percent.buttonView.font = TextSettingsView.defaultFont
    
    decreaseWith.buttonView.text = "-"
    decreaseWith.buttonView.font = TextSettingsView.defaultFont
    decreaseWith.buttonView.label.baselineAdjustment = .alignCenters
    increaseWith.buttonView.text = "+"
    increaseWith.buttonView.label.baselineAdjustment = .alignCenters
    increaseWith.buttonView.font = TextSettingsView.defaultFont
    defaultWidth.buttonView.text = "⬌ \(articleColumnMaxWidth)px"
    defaultWidth.buttonView.label.baselineAdjustment = .alignCenters
    defaultWidth.buttonView.font = TextSettingsView.defaultFont

    day.buttonView.text = "Tag"
    day.buttonView.font = TextSettingsView.defaultFont
    night.buttonView.text = "Nacht"
    
    night.buttonView.font = TextSettingsView.defaultFont
    sizeStack.axis = .horizontal
    sizeStack.alignment = .fill
    sizeStack.distribution = .fillEqually
    sizeStack.spacing = 2
    for v in [smallA, percent, largeA] {
      sizeStack.addArrangedSubview(v)
    }
    
    widthStack.axis = .horizontal
    widthStack.alignment = .fill
    widthStack.distribution = .fillEqually
    widthStack.spacing = 2
    for v in [decreaseWith, defaultWidth, increaseWith] {
      widthStack.addArrangedSubview(v)
    }
    
    modeStack.axis = .horizontal
    modeStack.alignment = .fill
    modeStack.distribution = .fillEqually
    modeStack.spacing = 2
    for v in [day, night] {
      modeStack.addArrangedSubview(v)
    }
    verticalStack.axis = .vertical
    verticalStack.alignment = .fill
    verticalStack.distribution = .fillEqually
    verticalStack.spacing = 2
    verticalStack.addArrangedSubview(sizeStack)
    verticalStack.addArrangedSubview(modeStack)
    let separator = UIView()
    separator.pinHeight(0.1)
    verticalStack.addArrangedSubview(separator)
    separator.heightAnchor.constraint(equalTo: stackView.heightAnchor, multiplier: 0.6).isActive = true
    verticalStack.addArrangedSubview(widthStack)
    addSubview(verticalStack)
    pin(verticalStack, to: self, dist: 4)
    registerForStyleUpdates()
  }
  
  func applyStyles() {
    [smallA.buttonView,
         largeA.buttonView,
          percent.buttonView,
          decreaseWith.buttonView,
          defaultWidth.buttonView,
          increaseWith.buttonView,
          night.buttonView,
          day.buttonView
          ].forEach {
            //Active Background Color deactivated for the Moment due missing unclear Color Values
          $0.activeBackgroundColor = Const.SetColor.ios(._tertiarySystemBackgroundDown).color
          $0.backgroundColor = Const.SetColor.ios(.tertiarySystemBackground).color
          $0.activeColor = Const.SetColor.ios(.tintColor).color
        }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
}
