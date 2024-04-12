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
  
  @Default("articleLineLengthAdjustment")
  private var articleLineLengthAdjustment: Int
  
  @Default("textAlign")
  private var textAlign: String
  
  @Default("multiColumnMode")
  var multiColumnMode: Bool
  
  @Default("columnCountLandscape")
  var columnCountLandscape: Int
  //columnCountPortrait = 2 fix, not displayed
  
  func updateButtonValuesOnOpen(){
    textSettings.textSize = articleTextSize
    updateTextAlignmentButtons()
    updateDayNightButtons()
    updateColumnModeButtons()
    updateLineLengthButtons()
  }
  
  @Default("colorMode")
  private var colorMode: String
  
  private func updateTextAlignmentButtons(){
    textSettings.textAlignJustifyButton.buttonView.isActivated
    = self.textAlign == "justify"
    textSettings.textAlignLeftButton.buttonView.isActivated
    = self.textAlign != "justify"
  }
  
  private func updateDayNightButtons(){
    self.textSettings.nightModeButton.buttonView.isActivated = Defaults.darkMode
    self.textSettings.dayModeButton.buttonView.isActivated = !Defaults.darkMode
  }
  
  private func updateColumnModeButtons(){
    self.textSettings.defaultScrollingButton.buttonView.isActivated = !multiColumnMode
    self.textSettings.horizontalScrollingButton.buttonView.isActivated = multiColumnMode
    self.textSettings.updateViews(for: self.traitCollection.horizontalSizeClass)
  }
  
  private func updateLineLengthButtons(){
    textSettings.lineLengthSmallerButton.buttonView.isActivated
    = articleLineLengthAdjustment == -1
    textSettings.lineLengthDefaultButton.buttonView.isActivated 
    = articleLineLengthAdjustment == 0
    textSettings.lineLengthLargerButton.buttonView.isActivated
    = articleLineLengthAdjustment == 1
  }
  
  private func setSize(_ s: Int) {
    textSettings.textSize = s
    articleTextSize = s
    textSettings.updateColumnButtons()
    Notification.send(globalStylesChangedNotification)
  }
  
  private func setupButtons() {
    textSettings.textSize = articleTextSize
    textSettings.smallAButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleTextSize > 50 { self.setSize(self.articleTextSize-10) }
    }
    textSettings.largeAButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleTextSize < 200 { self.setSize(self.articleTextSize+10) }
    }
    textSettings.fontScaleButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.articleTextSize != 100 { self.setSize(100) }
    }
    
    textSettings.lineLengthSmallerButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if articleLineLengthAdjustment != -1 {
        articleLineLengthAdjustment = -1
        Notification.send(globalStylesChangedNotification)
      }
      self.updateLineLengthButtons()
    }
    
    textSettings.lineLengthDefaultButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if articleLineLengthAdjustment != 0 {
        articleLineLengthAdjustment = 0
        Notification.send(globalStylesChangedNotification)
      }
      self.updateLineLengthButtons()
    }
    
    textSettings.lineLengthLargerButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if articleLineLengthAdjustment != 1 {
        articleLineLengthAdjustment = 1
        Notification.send(globalStylesChangedNotification)
      }
      self.updateLineLengthButtons()
    }
    
    textSettings.columnCount2Button.onPress { [weak self] _ in
      self?.columnCountLandscape = 2
      self?.textSettings.updateColumnButtons()
    }    
    textSettings.columnCount3Button.onPress { [weak self] _ in
      self?.columnCountLandscape = 3
      self?.textSettings.updateColumnButtons()
    }    
    textSettings.columnCount4Button.onPress { [weak self] _ in
      self?.columnCountLandscape = 4
      self?.textSettings.updateColumnButtons()
    }
    
    textSettings.textAlignLeftButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.textAlign != "left" {
        self.textAlign = "left"
        Notification.send(globalStylesChangedNotification)
      }
      self.updateTextAlignmentButtons()
    }
    
    textSettings.textAlignJustifyButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.textAlign != "justify" {
        self.textAlign = "justify"
        Notification.send(globalStylesChangedNotification)
      }
      self.updateTextAlignmentButtons()
    }
    
    textSettings.defaultScrollingButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.multiColumnMode != false {
        self.multiColumnMode = false
        Notification.send(globalStylesChangedNotification)
      }
      self.updateColumnModeButtons()
    }
    
    textSettings.horizontalScrollingButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.multiColumnMode != true {
        self.multiColumnMode = true
        Notification.send(globalStylesChangedNotification)
      }
      self.updateColumnModeButtons()
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
      Defaults.darkMode = false
      self.updateDayNightButtons()
    }
    
    textSettings.nightModeButton.onPress {[weak self] _ in
      guard let self = self else { return }
      Defaults.darkMode = true
      self.updateDayNightButtons()
    }
  }
  
  func applyStyles() {
    self.view.backgroundColor = Const.SetColor.taz(.primaryBackground).color
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(textSettings)
    setupButtons()
    pin(textSettings.top, to: self.view.top)
    pin(textSettings.bottom, to: self.view.bottom, priority: .defaultLow)
    pin(textSettings.left, to: self.view.left, dist: 8)
    pin(textSettings.right, to: self.view.right, dist: -8)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    applyStyles()
    
  }
}

class TextSettingsView: UIView {
  
  @Default("columnCountLandscape")
  var columnCountLandscape: Int
  
  @Default("multiColumnMode")
  var multiColumnMode: Bool
  
  func isMultiColumnAvailable(for horizontalSiteClass: UIUserInterfaceSizeClass) -> Bool {
    guard horizontalSiteClass == .regular else { return false }
    return multiColumnMode
  }
    
  /// Buttons used to switch between various modes
  public lazy var smallAButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "font-adjust-smaller"
    btn.buttonView.text = "kleinere Schrift"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var largeAButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "font-adjust-bigger"
    btn.buttonView.text = "größere Schrift"
    btn.buttonView.label.contentFont(size: 9.4)
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
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var nightModeButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "dark-mode"
    btn.buttonView.text = "Dunkler Hintergrund"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var defaultScrollingButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "scroll-view"
    btn.buttonView.text = "Einspaltigkeit"
    btn.buttonView.vPadding = 5.0
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var horizontalScrollingButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "column-view"
    btn.buttonView.text = "Mehrspaltigkeit"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var settingsButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.name = "settings"
    btn.buttonView.text = "Einstellungen"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var textAlignLeftButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "text.alignleft"
    btn.buttonView.text = "Linksbündig (Standard)"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var textAlignJustifyButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "text.justify"
    btn.buttonView.text = "Blocksatz"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var lineLengthSmallerButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "minus.square"
    btn.buttonView.text = "schmaler"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var lineLengthDefaultButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "1.square"
    btn.buttonView.text = "normal"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var lineLengthLargerButton : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "plus.rectangle"
    btn.buttonView.text = "breiter"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var columnCount2Button : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "2.lane"
    btn.buttonView.text = "2 Spalten"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var columnCount3Button : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "3.lane"
    btn.buttonView.text = "3 Spalten"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
  public lazy var columnCount4Button : Button<ImageLabelView> = {
    let btn = Button<ImageLabelView>()
    btn.buttonView.symbol = "4.lane"
    btn.buttonView.text = "4 Spalten"
    btn.buttonView.label.contentFont(size: 9.4)
    return btn
  }()
    
  public var textSizeLabel = UILabel("Textgröße")
  public var dayNightLabel = UILabel("Tag- und Nachtmodus")
  public var scrollingModeLabel = UILabel("Artikeldarstellung")
  public var settingsLabel = UILabel("Weitere Einstellungen")
  public var textAlignLabel = UILabel("Textausrichtung")
  public var columnLabel = UILabel("Zeilenlänge")
  
  private var sizeStack = UIStackView()
  private var lineLengthStack = UIStackView()
  private var columnCountStack = UIStackView()
  private var colorModeStack = UIStackView()
  private var scrollingModeStack = UIStackView()
  //settings Button need no stack
  private var alignStack = UIStackView()
  private var verticalStack = UIStackView()//right side stack views
  private var labelStack = UIStackView()//leftSideVerticalStack, only if enoughtWidth
  
  fileprivate func updateViews(for horizontalSiteClass: UIUserInterfaceSizeClass){
    ///0: FontSize 1: Day/Night 2: Single/Multi(iPAd!) 3: More 4: Width/Count
    /// Warning Rotation may not set in Device.isLandscape!!
    ///not displaying extra settings for iPhone
    if Device.isIphone { return }
    //iPad, Mac: multiColumnMode(true/false), TextSize>LineLength, DeviceWidth(compact/regular)
    
    ///If multiColumnMode == false SHOW lineLengthStack | ENABLED if DeviceWidth > Compact
    if isMultiColumnAvailable(for: horizontalSiteClass){///multiColumnMode == true && regular width
      columnLabel.text = "Spaltenanzahl"
      if columnCountStack.superview == nil {
        verticalStack.insertArrangedSubview(columnCountStack,
                                            at: verticalStack.subviews.count)
      }
      if lineLengthStack.superview != nil {
        lineLengthStack.removeFromSuperview()
      }
      updateColumnButtons()
    }
    else if horizontalSiteClass == .regular{
      columnLabel.text = "Zeilenlänge"
      if lineLengthStack.superview == nil {
        verticalStack.insertArrangedSubview(lineLengthStack,
                                            at: verticalStack.subviews.count)
      }
      if columnCountStack.superview != nil {
        columnCountStack.removeFromSuperview()
      }
    }
    else {
      if columnCountStack.superview != nil {
        columnCountStack.removeFromSuperview()
      }
      if lineLengthStack.superview != nil {
        lineLengthStack.removeFromSuperview()
      }
    }
    
    if horizontalSiteClass == .regular {
      if scrollingModeStack.superview == nil {
        verticalStack.insertArrangedSubview(scrollingModeStack,
                                            at: 2)
      }
      if scrollingModeLabel.superview == nil {
        labelStack.insertArrangedSubview(scrollingModeLabel,
                                            at: 2)
      }
      if columnLabel.superview == nil {
        labelStack.insertArrangedSubview(columnLabel,
                                         at: labelStack.subviews.count)
        columnLabel.pinHeight(65.5)
        columnLabel.baselineAdjustment = .alignCenters
      }
    }
    else {
      if scrollingModeStack.superview != nil {
        scrollingModeStack.removeFromSuperview()
      }
      if scrollingModeLabel.superview != nil {
        scrollingModeLabel.removeFromSuperview()
      }
    }
  }
  
  fileprivate func updateColumnButtons(){
    let isLandscape = UIWindow.isLandscapeInterface
    let availableColumnsCount:Int = isLandscape ? Defaults.availableColumnsCount : 2
    let columnsCountSetting = isLandscape ? columnCountLandscape : 2
    let selectedColumnCount
    = columnsCountSetting >= availableColumnsCount
    ? availableColumnsCount
    : columnsCountSetting
        
    columnCount3Button.isEnabled = availableColumnsCount > 2
    columnCount3Button.alpha = availableColumnsCount > 2 ? 1.0 : 0.3
    columnCount4Button.isEnabled = availableColumnsCount > 3
    columnCount4Button.alpha = availableColumnsCount > 3 ? 1.0 : 0.3
    
    columnCount2Button.buttonView.isActivated = selectedColumnCount == 2
    columnCount3Button.buttonView.isActivated = selectedColumnCount == 3
    columnCount4Button.buttonView.isActivated = selectedColumnCount == 4
  }
  
  private func setup() {
    [sizeStack, colorModeStack, scrollingModeStack, alignStack, lineLengthStack, columnCountStack].forEach {
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
    
    settingsButton.pinHeight(65.5)
    settingsButton.layer.cornerRadius = 8.0
    settingsButton.clipsToBounds = true
    
    alignStack.addArrangedSubview(textAlignLeftButton)
    alignStack.addArrangedSubview(textAlignJustifyButton)
    
    lineLengthStack.addArrangedSubview(lineLengthSmallerButton)
    lineLengthStack.addArrangedSubview(lineLengthDefaultButton)
    lineLengthStack.addArrangedSubview(lineLengthLargerButton)
    
    columnCountStack.addArrangedSubview(columnCount2Button)
    columnCountStack.addArrangedSubview(columnCount3Button)
    columnCountStack.addArrangedSubview(columnCount4Button)
    
    //Need to exchange Einspaltigkeit/Mehrspaltigkeit ...Hochformat wird nur 2 angeboten
    verticalStack.axis = .vertical
    verticalStack.alignment = .fill
    verticalStack.spacing = 12.0
    verticalStack.addArrangedSubview(sizeStack)
    verticalStack.addArrangedSubview(colorModeStack)
    verticalStack.addArrangedSubview(settingsButton)
    verticalStack.addArrangedSubview(alignStack)
    ///addArrangedSubview(lineLengthStack) **handled in: updateViews(...**
    verticalStack.setCustomSpacing(20.0, after: settingsButton)
    addSubview(verticalStack)
    
    labelStack.axis = .vertical
    labelStack.alignment = .fill
    labelStack.spacing = 12.0
    [textSizeLabel, dayNightLabel, scrollingModeLabel, settingsLabel, textAlignLabel].forEach {
      $0.pinHeight(65.5)//Settings and others in hStack are 65.5
      $0.baselineAdjustment = .alignCenters
      labelStack.addArrangedSubview($0)
    }
    labelStack.setCustomSpacing(20.0, after: textAlignLabel)

    labelStack.isHidden = true
    addSubview(labelStack)
    
    pin(labelStack,
        to: self,
        margins: UIEdgeInsets(top: 5, left: 3, bottom: 10, right: 3),
        exclude: .right
    ).bottom?.priority = .fittingSizeLevel
    labelStack.pinWidth(220)
    
    let vstConstrains = pin(verticalStack,
        to: self,
        margins: UIEdgeInsets(top: 5, left: 3, bottom: 10, right: 3)
    )
    vstConstrains.bottom?.priority = .fittingSizeLevel
    vStackLeftLayoutConstraint = vstConstrains.left
  }
  
  var vStackLeftLayoutConstraint: NSLayoutConstraint?
  
  func applyStyles() {
    if UIScreen.isIpadRegularHorizontalSize {
      vStackLeftLayoutConstraint?.constant = 220
      labelStack.isHidden = false
    }
    else {
      labelStack.isHidden = true
      vStackLeftLayoutConstraint?.constant = 3
    }
    [smallAButton.buttonView,
     largeAButton.buttonView,
     fontScaleButton.buttonView,
     dayModeButton.buttonView,
     nightModeButton.buttonView,
     defaultScrollingButton.buttonView,
     horizontalScrollingButton.buttonView,
     settingsButton.buttonView,
     textAlignLeftButton.buttonView,
     textAlignJustifyButton.buttonView,
     lineLengthSmallerButton.buttonView,
     lineLengthDefaultButton.buttonView,
     lineLengthLargerButton.buttonView,
     lineLengthDefaultButton.buttonView,
     columnCount2Button.buttonView,
     columnCount3Button.buttonView,
     columnCount4Button.buttonView
     ].forEach {
      //Active Background Color deactivated for the Moment due missing unclear Color Values
      $0.activeBackgroundColor = Const.SetColor.taz(.buttonActiveBackground).color
      $0.backgroundColor = Const.SetColor.taz(.buttonBackground).color
      $0.activeColor = Const.SetColor.taz(.buttonActiveForeground).color
      $0.color = Const.SetColor.taz(.buttonForeground).color
        }
    [textSizeLabel, dayNightLabel, scrollingModeLabel, settingsLabel, textAlignLabel, columnLabel].forEach {
      $0.textColor = Const.SetColor.taz(.primaryForeground).color
    }
    backgroundColor = Const.SetColor.taz(.primaryBackground).color
    sizeStack.backgroundColor = Const.SetColor.taz(.primaryForeground).color
    lineLengthStack.backgroundColor = Const.SetColor.taz(.primaryForeground).color
    scrollingModeStack.backgroundColor = Const.SetColor.taz(.primaryForeground).color
    let horizontalSizeClass: UIUserInterfaceSizeClass
    = UIWindow.keyWindow?.traitCollection.horizontalSizeClass
    ?? self.traitCollection.horizontalSizeClass
    self.updateViews(for: horizontalSizeClass)
  }
  
  //UIImage(named: "settings")
  public var textSize: Int = 100 {
    didSet { fontScaleButton.buttonView.text = "\(textSize)%" }
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
