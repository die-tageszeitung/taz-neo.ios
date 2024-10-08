//
//
// FormComponents.swift
//
// Created by Ringo Müller-Gromes on 31.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//

import UIKit
import NorthLib

fileprivate let DottedLineHeight = CGFloat(2.4)

fileprivate let DefaultPadding = CGFloat(15.0)

// MARK: - TazHeader
class TazHeader: Padded.View{
  override init(frame: CGRect) {
    super.init(frame:frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder:coder)
    setup()
  }
  
  convenience init(paddingBottom: CGFloat = 30){
    self.init(frame:.zero)
    self.paddingBottom = paddingBottom
    setup()
  }
  
  func setup() {
    let title = UILabel()
    let line = DottedLineView()
    line.fillColor = Const.SetColor.taz2(.text).color
    title.text = NSLocalizedString("die tageszeitung",
                                   comment: "taz_title")
    title.font = Const.Fonts.titleFont(size: Const.Size.LargeTitleFontSize)
    title.textAlignment = .right
    title.textColor = Const.SetColor.taz2(.text).color
    
    self.addSubview(title)
    self.addSubview(line)
    
    pin(title, to: self, dist: 0, exclude: .bottom)
    pin(line, to: self, dist: 0, exclude: .top)
    NorthLib.pin(line.top, to: title.bottom)
    line.pinHeight(DottedLineHeight)
    
  }
}

// MARK: - TazHeader
class BlockingProcessView : UIView{
  
  let spinner = UIActivityIndicatorView()
  
  public var enabled : Bool = false {
    didSet{
      if enabled {
        self.isHidden = false
        spinner.startAnimating()
        UIView.animate(seconds: 0.3) { [weak self] in
          self?.alpha = 1.0
        }
      }
      else {
        spinner.stopAnimating()
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
          self?.alpha = 0.0
        }) { [weak self] _ in
          self?.isHidden = true
        }
      }
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame:frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder:coder)
    setup()
  }
  
  func setup() {
    self.isHidden = true
    self.addSubview(spinner)
    self.backgroundColor = Const.SetColor.CTBackground.color.withAlphaComponent(0.5)
    pin(spinner.centerX, to: self.centerX)
    pin(spinner.centerY, to: self.centerY)
  }
}


// MARK: - UILabel Extension taz Label
extension Padded.Label{
  convenience init(title: String? = nil,
                   font: UIFont = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize),
                   textColor: UIColor = Const.SetColor.taz2(.text).color,
                   textAlignment: NSTextAlignment = .left,
                   paddingTop: CGFloat = 8,
                   paddingBottom: CGFloat = 8) {
    self.init()
    self.text = title
    self.font = font
    self.textColor = textColor
    self.paddingTop = paddingTop
    self.paddingBottom = paddingBottom
    self.numberOfLines = 0
    self.textAlignment = textAlignment
  }
}

// MARK: - taz UIButton
extension Padded.Button{
  
  enum tazButtonType { case normal, outline, label}
  
  convenience init( type: tazButtonType = .normal,
                    title: String? = NSLocalizedString("Senden", comment: "Send Button Title"),
                    color: UIColor = Const.SetColor.taz2(.text).dynamicColor,
                    textColor: UIColor = Const.SetColor.HBackground.dynamicColor,
                    height: CGFloat = 45,
                    paddingTop: CGFloat = DefaultPadding,
                    paddingBottom: CGFloat = DefaultPadding,
                    target: Any? = nil,
                    action: Selector? = nil) {
    self.init()
    
    if let title = title {
      self.setTitle(title, for: .normal)
    }
    self.backgroundColor = color
    self.setBackgroundColor(color: UIColor.lightGray.withAlphaComponent(0.2), forState: .highlighted)
    self.setTitleColor(textColor, for: .normal)
    self.titleLabel?.font = Const.Fonts.titleFont(size: Const.Size.DefaultButtonFontSize)
    self.layer.cornerRadius = height/2
    self.paddingTop = paddingTop
    self.paddingBottom = paddingBottom
    if let target = target, let action = action {
      self.addTarget(target, action: action, for: .touchUpInside)
    }
    
    self.pinHeight(height)
    
    switch type {
      case .outline:
        self.backgroundColor = .clear
        self.setBackgroundColor(color: UIColor.lightGray.withAlphaComponent(0.2), forState: .highlighted)
        self.addBorder(Const.SetColor.taz2(.text).color, 1.5)
        self.setTitleColor(Const.SetColor.taz2(.text).color, for: .normal)
        self.layer.cornerRadius = height/2
      case .label:
        self.backgroundColor = .clear
        self.setBackgroundColor(color: UIColor.lightGray.withAlphaComponent(0.2), forState: .highlighted)
        self.setTitleColor(Const.SetColor.taz2(.text).color, for: .normal)
      case .normal: fallthrough
      default:
        self.backgroundColor = color
    }
  }
}

// MARK: -  Checkbox
class Checkbox : UIButton {
  
  var accessibilityPrefix: String? {
    didSet {
      accessibilityLabel = accessibilityPrefix
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
  
  func setup(){
    self.setBackgroundImage(UIImage(name: "xmark"), for: .selected)
    self.tintColor = Const.SetColor.taz2(.text).color
    self.layer.borderColor = Const.SetColor.taz2(.text).color.cgColor
    self.layer.borderWidth = 1.0
    self.layer.cornerRadius = 3.0
    self.addTarget(self, action: #selector(toggle), for: .touchUpInside)
    self.accessibilityTraits = .button
  }
  
  @IBAction func toggle(_ sender: UIButton) {
    self.isSelected = !self.isSelected
    self.accessibilityLabel = "\(accessibilityPrefix ?? "") \(self.isSelected ? "Akzeptiert" : "Nicht akzeptiert")"
  }
}

// MARK: -  Checkbox
class RadioButton : UIButton {
  
  override var tintColor: UIColor! {
    didSet {
      super.tintColor = tintColor
      self.setBackgroundImage(UIImage.circle(diam: 30, padding: 6, color: tintColor), for: .selected)
    }
  }
  
  override var isSelected: Bool {
    didSet {
      self.layer.borderColor = isSelected
      ? tintColor.cgColor
      : Const.SetColor.taz2(.text).color.cgColor
    }
  }
  
  func setup(){
    self.imageView?.contentMode = .scaleAspectFit
    self.layer.borderWidth = 1.0
    self.tintColor = Const.Colors.radioGreen
    self.addTarget(self, action: #selector(toggle), for: .touchUpInside)
  }
  
  override func draw(_ rect: CGRect) {
    super.draw(rect)
    self.layer.cornerRadius = (rect.width + rect.height)/4 //circle or ellipse depending on rect
  }
  
  @IBAction func toggle(_ sender: UIButton) {
    self.isSelected = !self.isSelected
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

// MARK: - CustomTextView : UITextView
class CustomTextView : Padded.TextView{
  
  private var heightConstraint: NSLayoutConstraint?
  
  static var boldLinks : [NSAttributedString.Key : Any] {
    get {
      return [.foregroundColor : Const.SetColor.CIColor.color,
              .font: Const.Fonts.titleFont(size: Const.Size.DefaultFontSize),
              .underlineColor: UIColor.clear]
    }
  }
  
  required init(htmlText: String,
                paddingTop: CGFloat = Const.Size.TextFieldPadding,
                paddingBottom: CGFloat = Const.Size.TextFieldPadding,
                font: UIFont = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize),
                textColor: UIColor = Const.SetColor.taz2(.text).color,
                textAlignment: NSTextAlignment = .left,
                linkTextAttributes: [NSAttributedString.Key : Any] = [.foregroundColor : Const.SetColor.CIColor.color,
                                                                      .underlineColor: UIColor.clear]) {
    super.init(frame: .zero, textContainer:nil)
    self.paddingTop = paddingTop
    self.paddingBottom = paddingBottom
    self.backgroundColor = .clear
    
    var attributedString = htmlText.mutableAttributedStringFromHtml
    let all = NSRange(location: 0, length: attributedString?.length ?? 0)
    
    /// unfortunately underlines are cut-off with our custom font
    /// fix it by set .lineHeightMultiple = 1.2
    let style = NSMutableParagraphStyle()
    style.lineHeightMultiple = 1.12
    style.alignment = textAlignment
    
    /// prefer setting styles of the attributedString instead of self.font due this overwrites the whole
    /// attributed string whis needs to be set first
    attributedString?.addAttribute(.paragraphStyle, value: style, range: all)
    attributedString?.addAttribute(.font, value: font, range: all)
    attributedString?.addAttribute(.foregroundColor, value: textColor, range: all)
    attributedString?.addAttribute(.backgroundColor, value: UIColor.clear, range: all)
    
    self.linkTextAttributes = linkTextAttributes
    //unfortunately link font is overwritten by self font so we need to toggle this attributes
    //esspecially the combination with different link font did not work
    if let linkFont = linkTextAttributes[.font], let originalText = attributedString {
      let newString = NSMutableAttributedString(attributedString: originalText)
      originalText.enumerateAttributes(in: NSRange(0..<originalText.length), options: .reverse) { (attributes, range, pointer) in
        if let _ = attributes[.link] {
          newString.removeAttribute(.font, range: range)
          newString.addAttribute(.font, value: linkFont, range: range)
        }
      }
      attributedString = newString
    }
    
    self.attributedText = attributedString
    
    heightConstraint = self.pinHeight(10)
    heightConstraint?.priority = .defaultLow///tested: no Problem on iOS 12.4 due view not loaded!
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  convenience init(){
    self.init(htmlText:"")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    heightConstraint?.constant = self.sizeThatFits(self.frame.size).height
  }
}

// MARK: -  Composed Components

// MARK: -  CheckboxWithText
class CheckboxWithText:UIView{
  public var checked : Bool { get {checkbox.isSelected}}
  public let textView:CustomTextView = CustomTextView()
  public let checkbox = Checkbox()
  
  public var error : Bool = false {
    didSet {
      checkbox.layer.borderColor
        = error ? Const.SetColor.CIColor.color.cgColor : Const.SetColor.taz2(.text_icon_grey).color.cgColor
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
  
  func setup(){
    self.addSubview(checkbox)
    self.addSubview(textView)
    pin(checkbox.left, to: self.left)
    pin(textView.left, to: checkbox.right, dist: 8)
    pin(textView.right, to: self.right)
    pin(textView.top, to: self.top)
    pin(textView.bottom, to: self.bottom)
    checkbox.pinSize(CGSize(width: 20, height: 20))
    pin(checkbox.centerY, to: self.centerY)
    
  }
}

extension UIImage {
  class func circle(diam: CGFloat, padding: CGFloat = 0.0, color: UIColor) -> UIImage? {
    if padding*2 > diam { return nil }

    UIGraphicsBeginImageContextWithOptions(CGSize(width: diam, height: diam),
                                           false,
                                           0)
    let ctx = UIGraphicsGetCurrentContext()!
    ctx.saveGState()
    
    ctx.setFillColor(color.cgColor)
    ctx.fillEllipse(in: CGRect(x: padding,
                               y: padding,
                               width: diam - 2*padding,
                               height: diam - 2*padding))
    ctx.restoreGState()
    let img = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return img
  }
}
