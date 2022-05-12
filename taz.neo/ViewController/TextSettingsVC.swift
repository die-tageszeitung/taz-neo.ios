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
  
  @Default("articleTextSize")
  private var articleTextSize: Int
  
  @Default("articleColumnPercentageWidth")
  private var articleColumnPercentageWidth: Int
  
  @Default("textAlign")
  private var textAlign: String
  
  func updateButtonValuesOnOpen(){
    textSettings.textSize = articleTextSize
    textSettings.articleColumnPercentageWidth = articleColumnPercentageWidth
    updateTextAlignmentButtons()
    updateDayNightButtons()
  }
  
  @Default("colorMode")
  private var colorMode: String
  
  private func updateTextAlignmentButtons(){
    if self.textAlign == "justify" {
      textSettings.textAlignJustify.buttonView.isActivated = true
      textSettings.textAlignLeft.buttonView.isActivated = false
    } else {
      textSettings.textAlignJustify.buttonView.isActivated = false
      textSettings.textAlignLeft.buttonView.isActivated = true
    }
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    textSettings.updateWidthSettingButtons(size.width)
  }
  
  private func updateDayNightButtons(){
    self.textSettings.night.buttonView.isActivated = Defaults.darkMode
    self.textSettings.day.buttonView.isActivated = !Defaults.darkMode
  }
  
  private func setupButtons() {
    func setSize(_ s: Int) {
      textSettings.textSize = s
      articleTextSize = s
      Notification.send(globalStylesChangedNotification)
    }
    func setPercentageWidth(_ w: Int) {
      //#warning("ToDo 0.9.4: use Helper.swift Defaults.articleTextSize functions @see Settings")
      textSettings.articleColumnPercentageWidth = w
      articleColumnPercentageWidth = w
      Notification.send(globalStylesChangedNotification)
    }
        
    textSettings.textSize = articleTextSize
    textSettings.smallA.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleTextSize > 30 { setSize(self.articleTextSize-10) }
    }
    textSettings.largeA.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleTextSize < 200 { setSize(self.articleTextSize+10) }
    }
    textSettings.percent.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleTextSize != 100 { setSize(100) }
    }
    
    textSettings.articleColumnPercentageWidth = articleColumnPercentageWidth
    textSettings.decreaseWith.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleColumnPercentageWidth > 50 { setPercentageWidth(self.articleColumnPercentageWidth-5) }
    }
    textSettings.increaseWith.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleColumnPercentageWidth < max(100, Int(UIWindow.size.width/61)*10) {
        //61 to have a side padding
        setPercentageWidth(self.articleColumnPercentageWidth+5) }
    }
    
    textSettings.textAlignLeft.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.textAlign != "left" {
        self.textAlign = "left"
        Notification.send(globalStylesChangedNotification)
        self.updateTextAlignmentButtons()
      }
    }
    
    textSettings.textAlignJustify.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.textAlign != "justify" {
        self.textAlign = "justify"
        Notification.send(globalStylesChangedNotification)
        self.updateTextAlignmentButtons()
      }
    }
    
    textSettings.defaultWidth.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleColumnPercentageWidth != 100 { setPercentageWidth(100) }
    }
   
    textSettings.day.onPress { [weak self] _ in
      guard let self = self else { return }
      self.textSettings.night.buttonView.isActivated = false
      self.textSettings.day.buttonView.isActivated = true
      Defaults.darkMode = false
    }
    
    textSettings.night.onPress {[weak self] _ in
      guard let self = self else { return }
      Defaults.darkMode = true
      self.updateDayNightButtons()
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
    textSettings.pinHeight(260)
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
  
  public var decreaseWith = Button<ImageView>()
  public var increaseWith = Button<ImageView>()
  public var defaultWidth = Button<TextView>()

  public var textAlignLeft = Button<ImageView>()
  public var textAlignJustify = Button<ImageView>()
  
  public var day = Button<TextView>()
  public var night = Button<TextView>()
  //public var auto = Button<TextView>()
  private var verticalStack = UIStackView()
  private var sizeStack = UIStackView()
  private var widthStack = UIStackView()
  private var alignStack = UIStackView()
  private var modeStack = UIStackView()
  
  public var textSize: Int = 100 {
    didSet { percent.buttonView.text = "\(textSize)%" }
  }
  
  public var articleColumnPercentageWidth: Int = 100 {
    didSet {
      defaultWidth.buttonView.text = "\(articleColumnPercentageWidth)%"
      updateWidthSettingButtons()
    }
  }
  
  func updateWidthSettingButtons(_ withWindowWidth:CGFloat = UIWindow.size.width){
    if articleColumnPercentageWidth >= Int(withWindowWidth/61)*10 {//61 to have a side padding
      defaultWidth.buttonView.color = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
      increaseWith.buttonView.color = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
    }
    else if self.articleColumnPercentageWidth <= 50 {
      increaseWith.buttonView.color = Const.SetColor.ios(.link).color
      defaultWidth.buttonView.color = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
      decreaseWith.buttonView.color = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
    }
    else {
      defaultWidth.buttonView.color = Const.SetColor.ios(.link).color
      increaseWith.buttonView.color = Const.SetColor.ios(.link).color
      decreaseWith.buttonView.color = Const.SetColor.ios(.link).color
    }
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
    percent.buttonView.label.baselineAdjustment = .alignCenters
    percent.buttonView.font = TextSettingsView.defaultFont
    
    defaultWidth.buttonView.label.baselineAdjustment = .alignCenters
    defaultWidth.buttonView.font = TextSettingsView.defaultFont
    
    decreaseWith.inset = 0.435
    increaseWith.inset = 0.435
    decreaseWith.buttonView.name = "arrow_right_arrow_left_square"
    increaseWith.buttonView.name = "arrow_right_arrow_left_square_fill"
    
    textAlignLeft.inset = 0.435
    textAlignJustify.inset = 0.435
    textAlignLeft.buttonView.image = UIImage(name: "text.alignleft")
    textAlignJustify.buttonView.image = UIImage(name: "text.justify")
          
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
    
    alignStack.axis = .horizontal
    alignStack.alignment = .fill
    alignStack.distribution = .fillEqually
    alignStack.spacing = 2
    for v in [textAlignLeft, textAlignJustify] {
      alignStack.addArrangedSubview(v)
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
    verticalStack.addArrangedSubview(widthStack)
    verticalStack.addArrangedSubview(alignStack)
    verticalStack.setCustomSpacing(12.0, after: modeStack)
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
          day.buttonView,
          textAlignLeft.buttonView,
          textAlignJustify.buttonView
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
