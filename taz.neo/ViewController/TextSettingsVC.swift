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
class TextSettingsVC: UIViewController {
  
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
      textSettings.textAlignJustifyButton.buttonView.isActivated = true
      textSettings.textAlignLeftButton.buttonView.isActivated = false
    } else {
      textSettings.textAlignJustifyButton.buttonView.isActivated = false
      textSettings.textAlignLeftButton.buttonView.isActivated = true
    }
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    textSettings.updateWidthSettingButtons(size.width)
  }
  
  private func updateDayNightButtons(){
    self.textSettings.nightModeButton.buttonView.isActivated = Defaults.darkMode
    self.textSettings.dayModeButton.buttonView.isActivated = !Defaults.darkMode
  }
  
  private func setSize(_ s: Int) {
    textSettings.textSize = s
    articleTextSize = s
    Notification.send(globalStylesChangedNotification)
  }
  private func setPercentageWidth(_ w: Int) {
    //#warning("ToDo 0.9.4: use Helper.swift Defaults.articleTextSize functions @see Settings")
    textSettings.articleColumnPercentageWidth = w
    articleColumnPercentageWidth = w
    Notification.send(globalStylesChangedNotification)
  }
  
  private func setupButtons() {
    textSettings.textSize = articleTextSize
    textSettings.smallAButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleTextSize > 30 { self.setSize(self.articleTextSize-10) }
    }
    textSettings.largeAButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleTextSize < 200 { self.setSize(self.articleTextSize+10) }
    }
    textSettings.fontScaleButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleTextSize != 100 { self.setSize(100) }
    }
    
    textSettings.articleColumnPercentageWidth = articleColumnPercentageWidth
//    textSettings.decreaseWith.onPress { [weak self] _ in
//      guard let self = self else { return }
//      if self.articleColumnPercentageWidth > 50 { self.setPercentageWidth(self.articleColumnPercentageWidth-5) }
//    }
//    textSettings.increaseWith.onPress { [weak self] _ in
//      guard let self = self else { return }
//      if self.articleColumnPercentageWidth < max(100, Int(UIWindow.size.width/61)*10) {
//        //61 to have a side padding
//        self.setPercentageWidth(self.articleColumnPercentageWidth+5) }
//    }
    
    textSettings.textAlignLeftButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.textAlign != "left" {
        self.textAlign = "left"
        Notification.send(globalStylesChangedNotification)
        self.updateTextAlignmentButtons()
      }
    }
    
    textSettings.textAlignJustifyButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.textAlign != "justify" {
        self.textAlign = "justify"
        Notification.send(globalStylesChangedNotification)
        self.updateTextAlignmentButtons()
      }
    }
    
    
    textSettings.settingsButton.onPress { _ in
      Notification.send(Const.NotificationNames.gotoSettings)
    }
    
//    textSettings.defaultWidth.onPress { [weak self] _ in
//      guard let self = self else { return }
//      if self.articleColumnPercentageWidth != 100 { self.setPercentageWidth(100) }
//    }
   
    textSettings.dayModeButton.onPress { [weak self] _ in
      guard let self = self else { return }
      self.textSettings.nightModeButton.buttonView.isActivated = false
      self.textSettings.dayModeButton.buttonView.isActivated = true
      Defaults.darkMode = false
    }
    
    textSettings.nightModeButton.onPress {[weak self] _ in
      guard let self = self else { return }
      Defaults.darkMode = true
      self.updateDayNightButtons()
    }
  }
  
  func applyStyles() {
    self.view.backgroundColor = Const.SetColor.HBackground.color
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(textSettings)
    setupButtons()
    textSettings.pinHeight(260)
    pin(textSettings.top, to: self.view.top)
    pin(textSettings.left, to: self.view.left, dist: 8)
    pin(textSettings.right, to: self.view.right, dist: -8)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    applyStyles()
  }
}

class TextSettingsView: UIView {
    
  /// Buttons used to switch between various modes
  public lazy var smallAButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "font-adjust-smaller"
    btn.buttonView.text = "kleinere Schrift"
    btn.buttonView.label.contentFont(size: 9.0)
    return btn
  }()
  public lazy var largeAButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "font-adjust-bigger"
    btn.buttonView.text = "größere Schrift"
    btn.buttonView.label.contentFont(size: 9.0)
    return btn
  }()
  public lazy var fontScaleButton : Button<TextView> = {
    let btn = Button<TextView>()
    btn.buttonView.label.baselineAdjustment = .alignCenters
    btn.buttonView.font = Const.Fonts.contentFont(size: Const.Size.SmallerFontSize)
    return btn
  }()
  public lazy var dayModeButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "light-mode"
    btn.buttonView.text = "Heller Hintergrund"
    btn.buttonView.label.contentFont(size: 9.0)
    return btn
  }()
  public lazy var nightModeButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "dark-mode"
    btn.buttonView.text = "Dunkler Hintergrund"
    btn.buttonView.label.contentFont(size: 9.0)
    return btn
  }()
  public lazy var defaultScrollingButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "scroll-view"
    btn.buttonView.text = "größere Schrift"
    btn.buttonView.vPadding = 5.0
    btn.buttonView.label.contentFont(size: 9.0)
    return btn
  }()
  public lazy var horizontalScrollingButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "column-view"
    btn.buttonView.text = "größere Schrift"
    btn.buttonView.label.contentFont(size: 9.0)
    return btn
  }()
  public lazy var settingsButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "settings"
    btn.buttonView.text = "Einstellungen"
    btn.buttonView.label.contentFont(size: 9.0)
    return btn
  }()
  public lazy var textAlignLeftButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "text.alignleft"
    btn.buttonView.text = "linksbündig (Standard)"
    btn.buttonView.label.contentFont(size: 9.0)
    return btn
  }()
  public lazy var textAlignJustifyButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "text.justify"
    btn.buttonView.text = "Blocksatz"
    btn.buttonView.label.contentFont(size: 9.0)
    return btn
  }()
    
  public var textSizeLabel = UILabel("Textgröße")
  public var dayNightLabel = UILabel("Tag- und Nachtmodus")
  public var scrollingModeLabel = UILabel("Artikeldarstellung")
  public var settingsLabel = UILabel("Weitere Einstellungen")
  
  private var sizeStack = UIStackView()
  private var colorModeStack = UIStackView()
  private var scrollingModeStack = UIStackView()
  //settings Button need no stack
  private var alignStack = UIStackView()
  private var verticalStack = UIStackView()//right side stack views
  private var labelStack = UIStackView()//leftSideVerticalStack, only if enoughtWidth
  
  private func setup() {
    [sizeStack, colorModeStack, scrollingModeStack, alignStack].forEach {
      $0.axis = .horizontal
      $0.alignment = .fill
      $0.distribution = .fillEqually
      $0.spacing = 0.8
      $0.layer.cornerRadius = 8.0
      $0.clipsToBounds = true
    }
    
    for v in [smallAButton, fontScaleButton, largeAButton] {
      sizeStack.addArrangedSubview(v)
    }
    
    for v in [dayModeButton, nightModeButton] {
      colorModeStack.addArrangedSubview(v)
    }
    
    for v in [defaultScrollingButton, horizontalScrollingButton] {
      scrollingModeStack.addArrangedSubview(v)
    }
    
    settingsButton.pinHeight(58)
    settingsButton.layer.cornerRadius = 8.0
    settingsButton.clipsToBounds = true
    
    for v in [textAlignLeftButton, textAlignJustifyButton] {
      alignStack.addArrangedSubview(v)
    }
    
    verticalStack.axis = .vertical
    verticalStack.alignment = .fill
//    verticalStack.distribution = .fillEqually
    verticalStack.spacing = 12.0
    verticalStack.addArrangedSubview(sizeStack)
    verticalStack.addArrangedSubview(colorModeStack)
    verticalStack.addArrangedSubview(scrollingModeStack)
    verticalStack.addArrangedSubview(settingsButton)
    verticalStack.addArrangedSubview(alignStack)
    verticalStack.setCustomSpacing(20.0, after: settingsButton)
    addSubview(verticalStack)
    pin(verticalStack, 
        to: self,
        margins: UIEdgeInsets(top: 5, left: 3, bottom: 10, right: 3)
    ).bottom.priority = .fittingSizeLevel
  }
  
  func applyStyles() {
    [smallAButton.buttonView,
     largeAButton.buttonView,
     fontScaleButton.buttonView,
     dayModeButton.buttonView,
     nightModeButton.buttonView,
     defaultScrollingButton.buttonView,
     horizontalScrollingButton.buttonView,
     settingsButton.buttonView,
     textAlignLeftButton.buttonView,
     textAlignJustifyButton.buttonView
     ].forEach {
      //Active Background Color deactivated for the Moment due missing unclear Color Values
      $0.activeBackgroundColor = Const.SetColor.CTDate.color
      $0.backgroundColor = Const.SetColor.ios(.secondarySystemBackground).color
      $0.activeColor = Const.SetColor.HBackground.color
      $0.color = Const.SetColor.CTDate.color
        }
    backgroundColor = Const.SetColor.HBackground.color
    sizeStack.backgroundColor = Const.SetColor.CTDate.color
    scrollingModeStack.backgroundColor = Const.SetColor.CTDate.color
  }
  
  //UIImage(named: "settings")
  public var textSize: Int = 100 {
    didSet { fontScaleButton.buttonView.text = "\(textSize)%" }
  }
  
  public var articleColumnPercentageWidth: Int = 100 {
    didSet {
//      defaultWidth.buttonView.text = "\(articleColumnPercentageWidth)%"
      updateWidthSettingButtons()
    }
  }
  
  func updateWidthSettingButtons(_ withWindowWidth:CGFloat = UIWindow.size.width){
    if articleColumnPercentageWidth >= Int(withWindowWidth/61)*10 {//61 to have a side padding
//      defaultWidth.buttonView.color = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
//      increaseWith.buttonView.color = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
    }
    else if self.articleColumnPercentageWidth <= 50 {
//      increaseWith.buttonView.color = Const.SetColor.ios(.link).color
//      defaultWidth.buttonView.color = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
//      decreaseWith.buttonView.color = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
    }
    else {
//      defaultWidth.buttonView.color = Const.SetColor.ios(.link).color
//      increaseWith.buttonView.color = Const.SetColor.ios(.link).color
//      decreaseWith.buttonView.color = Const.SetColor.ios(.link).color
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    applyStyles()
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
