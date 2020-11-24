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
  
  @DefaultInt(key: "articleTextSize")
  private var articleTextSize: Int
  
  @Default(key: "colorMode")
  private var colorMode: String?
  
  private func setupButtons() {
    func setSize(_ s: Int) { textSettings.textSize = s; articleTextSize = s }
    var textSize = articleTextSize
    textSettings.textSize = textSize
    textSettings.smallA.onPress {_ in
      if textSize > 30 { textSize -= 10; setSize(textSize) }
    }
    textSettings.largeA.onPress {_ in
      if textSize < 200 { textSize += 10; setSize(textSize) }
    }
    textSettings.percent.onPress {_ in
      if textSize != 100 { textSize = 100; setSize(textSize) }
    }
    textSettings.day.onPress {_ in
      self.colorMode = "light"
    }
    textSettings.night.onPress {_ in
      self.colorMode = "dark"
    }
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(textSettings)
    setupButtons()
    self.view.backgroundColor = .white
    textSettings.backgroundColor = .white
    textSettings.pinHeight(130)
    pin(textSettings.top, to: self.view.top)
    pin(textSettings.left, to: self.view.left, dist: 8)
    pin(textSettings.right, to: self.view.right, dist: -8)
  }
  
}

class TextSettingsView: UIView {
  
  /// Default font
  private static let defaultFont = UIFont.boldSystemFont(ofSize: 20)
  private static let smallFont = UIFont.boldSystemFont(ofSize: 16)
  private static let largeFont = UIFont.boldSystemFont(ofSize: 38)
  
  
  /// Buttons used to switch between various modes
  public var smallA = Button<TextView>()
  public var largeA = Button<TextView>()
  public var percent = Button<TextView>()
  public var day = Button<TextView>()
  public var night = Button<TextView>()
  //public var auto = Button<TextView>() 
  private var verticalStack = UIStackView()
  private var sizeStack = UIStackView()
  private var modeStack = UIStackView()
  
  public var textSize: Int = 100 {
    didSet { percent.buttonView.text = "\(textSize)%" }
  }
  
  private func setup() {
    let grey = UIColor.rgb(0xf6f6f6)
    smallA.buttonView.text = "aA"
    smallA.buttonView.font = TextSettingsView.smallFont
    smallA.buttonView.backgroundColor = grey
    largeA.buttonView.text = "aA"
    largeA.buttonView.font = TextSettingsView.largeFont
    largeA.buttonView.backgroundColor = grey
    percent.buttonView.text = "\(textSize)%"
    percent.buttonView.backgroundColor = grey
    percent.buttonView.font = TextSettingsView.defaultFont
    day.buttonView.text = "Tag"
    day.buttonView.backgroundColor = grey
    day.buttonView.font = TextSettingsView.defaultFont
    night.buttonView.text = "Nacht"
    night.buttonView.backgroundColor = .black  
    night.color = .white
    night.buttonView.font = TextSettingsView.defaultFont
    backgroundColor = UIColor.rgb(0xaaaaaa)
    sizeStack.axis = .horizontal
    sizeStack.alignment = .fill
    sizeStack.distribution = .fillEqually
    sizeStack.spacing = 2
    for v in [smallA, percent, largeA] {
      sizeStack.addArrangedSubview(v)
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
    addSubview(verticalStack)
    pin(verticalStack, to: self, dist: 4)
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
