//
//
// FormComponents.swift
//
// Created by Ringo Müller-Gromes on 31.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//

import UIKit
import NorthLib

fileprivate let MiniPageNumberFontSize = CGFloat(12)
fileprivate let DefaultFontSize = CGFloat(16)
fileprivate let LargeTitleFontSize = CGFloat(34)
fileprivate let DottedLineHeight = CGFloat(2.4)

fileprivate let DefaultPadding = CGFloat(15.0)
fileprivate let TextFieldPadding = CGFloat(10.0)

// MARK: - TazHeader
class TazHeader: Padded.PUIView{
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
    line.fillColor = TazColor.CTDate.color
    title.text = NSLocalizedString("die tageszeitung",
                                   comment: "taz_title")
    title.font = Const.Fonts.contentFont(size: LargeTitleFontSize)
    title.textAlignment = .right
    
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
    self.backgroundColor = TazColor.CTBackground.color.withAlphaComponent(0.5)
    pin(spinner.centerX, to: self.centerX)
    pin(spinner.centerY, to: self.centerY)
  }
}


// MARK: - UILabel Extension taz Label
extension Padded.PUILabel{
  convenience init(title: String? = nil,
                   font: UIFont = Const.Fonts.contentFont(size: DefaultFontSize),
                   paddingTop: CGFloat = 8,
                   paddingBottom: CGFloat = 8) {
    self.init()
    self.text = title
    self.font = font
    self.paddingTop = paddingTop
    self.paddingBottom = paddingBottom
    self.numberOfLines = 0
    self.textAlignment = .center
  }
}

// MARK: - taz UIButton
extension Padded.PUIButton{
  
  enum tazButtonType { case normal, outline, label }
  
  convenience init( type: tazButtonType = .normal,
                    title: String? = NSLocalizedString("Senden", comment: "Send Button Title"),
                    color: UIColor = TazColor.CIColor.color,
                    textColor: UIColor = .white,
                    height: CGFloat = 40,
                    paddingTop: CGFloat = DefaultPadding,
                    paddingBottom: CGFloat = DefaultPadding,
                    target: Any? = nil,
                    action: Selector? = nil) {
    self.init()
    if let title = title {
      self.setTitle(title, for: .normal)
    }
    self.backgroundColor = color
    self.setBackgroundColor(color: color.withAlphaComponent(0.8), forState: .selected)
    
    self.setTitleColor(textColor, for: .normal)
    self.layer.cornerRadius = 3.0
    self.pinHeight(height)
    self.paddingTop = paddingTop
    self.paddingBottom = paddingBottom
    if let target = target, let action = action {
      self.addTarget(target, action: action, for: .touchUpInside)
    }
    
    switch type {
      case .outline:
        self.backgroundColor = .clear
        self.setBackgroundColor(color: UIColor.lightGray.withAlphaComponent(0.2), forState: .selected)
        self.addBorder(TazColor.CIColor.color, 1.0)
        self.setTitleColor(TazColor.CIColor.color, for: .normal)
      case .label:
        self.backgroundColor = .clear
        self.setBackgroundColor(color: UIColor.lightGray.withAlphaComponent(0.2), forState: .selected)
        self.setTitleColor(TazColor.CIColor.color, for: .normal)
      case .normal: fallthrough
      default:
        self.backgroundColor = color
    }
  }
}

// MARK: -  Checkbox
class Checkbox : UIButton {
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
    self.tintColor = TazColor.CTArticle.color
    self.layer.borderColor = TazColor.CTArticle.color.cgColor
    self.layer.borderWidth = 1.0
    self.layer.cornerRadius = 3.0
    self.addTarget(self, action: #selector(toggle), for: .touchUpInside)
  }
  
  @IBAction func toggle(_ sender: UIButton) {
    self.isSelected = !self.isSelected
  }
}

// MARK: - TazTextField
class TazTextField : Padded.PUITextField, UITextFieldDelegate{
  static let recomendedHeight:CGFloat = 56.0
  private let border = BorderView()
  let topLabel = UILabel()
  let bottomLabel = UILabel()
  private var borderHeightConstraint: NSLayoutConstraint?
  
  
  // MARK: > pwInput
  required init(prefilledText: String? = nil,
                placeholder: String? = nil,
                color: UIColor = TazColor.CIColor.color,
                textColor: UIColor = TazColor.CIColor.color,
                height: CGFloat = TazTextField.recomendedHeight,
                paddingTop: CGFloat = TextFieldPadding,
                paddingBottom: CGFloat = TextFieldPadding,
                textContentType: UITextContentType? = .givenName,
                isSecureTextEntry: Bool = false,
                enablesReturnKeyAutomatically: Bool = false,
                keyboardType: UIKeyboardType = .default,
                autocapitalizationType: UITextAutocapitalizationType = .words,
                target: Any? = nil,
                action: Selector? = nil) {
    super.init(frame:.zero)
    pinHeight(height)
    self.paddingTop = paddingTop
    self.paddingBottom = paddingBottom
    self.placeholder = placeholder
    //tf.borderStyle = .line //Border Bottom Alternative
    //    tf.addBorder(.gray, 1.0, only:UIRectEdge.bottom)
    self.keyboardType = keyboardType
    self.textContentType = textContentType
    self.autocapitalizationType = autocapitalizationType
    self.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
    self.isSecureTextEntry = isSecureTextEntry
    if isSecureTextEntry {
      let imgEye = UIImage(name: "eye.fill")
      let imgEyeSlash = UIImage(name: "eye.slash.fill")
      let eye = UIImageView(image: imgEyeSlash)
      eye.contentMode = .scaleAspectFit
      eye.tintColor = TazColor.CTArticle.color
      eye.onTapping(closure: { _ in
        self.isSecureTextEntry = !self.isSecureTextEntry
        eye.image = self.isSecureTextEntry ? imgEyeSlash : imgEye
      })
      self.rightView = eye
      self.rightViewMode = .always
    }
    setup()
  }
  
  
  // MARK: > init
  public override init(frame: CGRect){
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  func setup(){
    self.addSubview(border)
    self.delegate = self
    self.border.backgroundColor = TazColor.CTArticle.color
    self.borderHeightConstraint = border.pinHeight(1)
    pin(border.left, to: self.left)
    pin(border.right, to: self.right)
    pin(border.bottom, to: self.bottom, dist: -15)
    self.addTarget(self, action: #selector(textFieldEditingDidChange),
                   for: UIControl.Event.editingChanged)
    self.addTarget(self, action: #selector(textFieldEditingDidBegin),
                   for: UIControl.Event.editingDidBegin)
    self.addTarget(self, action: #selector(textFieldEditingDidEnd),
                   for: UIControl.Event.editingDidEnd)
  }
  
  override open var text: String?{
    didSet{
      if let _text = text, _text.isEmpty {
        UIView.animate(seconds: 0.3) { [weak self] in
          self?.topLabel.alpha = 0.0
        }
      }
      else {
        UIView.animate(seconds: 0.3) { [weak self] in
          self?.topLabel.alpha = 1.0
        }
      }
    }
  }
  
  // MARK: > placeholder
  override open var placeholder: String?{
    didSet{
      super.placeholder = placeholder
      topLabel.text = placeholder
      if topLabel.superview == nil && placeholder?.isEmpty == false{
        topLabel.alpha = 0.0
        topLabel.numberOfLines = 1
        self.addSubview(topLabel)
        pin(topLabel.left, to: self.left)
        pin(topLabel.right, to: self.right)
        pin(topLabel.top, to: self.top, dist: -2)
        topLabel.font = Const.Fonts.contentFont(size: MiniPageNumberFontSize)
        self.topLabel.textColor = TazColor.CTArticle.color
        
      }
    }
  }
  
  // MARK: > bottomMessage
  open var bottomMessage: String?{
    didSet{
      bottomLabel.text = bottomMessage
      if bottomLabel.superview == nil && bottomMessage?.isEmpty == false{
        bottomLabel.alpha = 0.0
        bottomLabel.numberOfLines = 1
        self.addSubview(bottomLabel)
        pin(bottomLabel.left, to: self.left)
        pin(bottomLabel.right, to: self.right)
        pin(bottomLabel.bottom, to: self.bottom)
        bottomLabel.font = Const.Fonts.contentFont(size: MiniPageNumberFontSize)
        bottomLabel.textColor = TazColor.CIColor.color
      }
      
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.bottomLabel.alpha = self?.bottomMessage?.isEmpty == false ? 1.0 : 0.0
      }
    }
  }
  
  // MARK: > inputToolbar
  lazy var inputToolbar: UIToolbar = createToolbar()
}

// MARK: - TazTextField : Toolbar
extension TazTextField{
  
  fileprivate func createToolbar() -> UIToolbar{
    /// setting toolbar width fixes the h Autolayout issue, unfortunatly not the v one no matter which height
    let toolbar =  UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
    toolbar.barStyle = .default
    toolbar.isTranslucent = true
    toolbar.sizeToFit()
    
    /// Info: Issue with Autolayout
    /// the solution did not solve our problem:
    /// https://developer.apple.com/forums/thread/121474
    /// because we use autocorection/password toolbar also
    /// also the following options did not worked:
    ///   UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
    ///   toolbar.setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
    ///   toolbar.setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
    ///   toolbar.autoresizesSubviews = false
    ///   toolbar.translatesAutoresizingMaskIntoConstraints = true/false
    ///   ....
    ///   toolbar.sizeToFit()
    ///   toolbar.pinHeight(toolbar.frame.size.height).priority = .required
    ///   ....
    /// Maybe extend: CustomToolbar : UIToolbar and invoke updateConstraints/layoutSubviews
    /// to reduce constraint priority or set frame/size
    
    let doneButton  = UIBarButtonItem(image: UIImage(name: "checkmark")?.withRenderingMode(.alwaysTemplate),
                                      style: .done,
                                      target: self,
                                      action: #selector(textFieldToolbarDoneButtonPressed))
    
    let prevButton  = UIBarButtonItem(title: "❮",
                                      style: .plain,
                                      target: self,
                                      action: #selector(textFieldToolbarPrevButtonPressed))
    
    
    let nextButton  = UIBarButtonItem(title: "❯",
                                      style: .plain,
                                      target: self,
                                      action: #selector(textFieldToolbarNextButtonPressed))
    
    prevButton.tintColor = Const.Colors.ciColor
    nextButton.tintColor = Const.Colors.ciColor
    doneButton.tintColor = Const.Colors.ciColor
    
    let flexibleSpaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    let fixedSpaceButton = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
    fixedSpaceButton.width = 30
    
    toolbar.setItems([prevButton, fixedSpaceButton, nextButton, flexibleSpaceButton, doneButton], animated: false)
    toolbar.isUserInteractionEnabled = true
    
    return toolbar
  }
  
  @objc func textFieldToolbarDoneButtonPressed(sender: UIBarButtonItem) {
    self.resignFirstResponder()
  }
  
  @objc func textFieldToolbarPrevButtonPressed(sender: UIBarButtonItem) {
    if let nextField = self.superview?.viewWithTag(self.tag - 1) as? UITextField {
      nextField.becomeFirstResponder()
    } else {
      self.resignFirstResponder()
    }
  }
  
  @objc func textFieldToolbarNextButtonPressed(sender: UIBarButtonItem) {
    nextOrEndEdit()
  }
  
  func nextOrEndEdit(){
    if let nextField = self.superview?.viewWithTag(self.tag + 1) as? UITextField {
      nextField.becomeFirstResponder()
    } else {
      self.resignFirstResponder()
    }
  }
}

// MARK: - TazTextField : UITextFieldDelegate
extension TazTextField{
  @objc public func textFieldEditingDidChange(_ textField: UITextField) {
    if let _text = textField.text, _text.isEmpty {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = 0.0
      }
    }
    else {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = 1.0
      }
    }
  }
  
  @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    nextOrEndEdit()
    return true
  }
  
  @objc public func textFieldEditingDidBegin(_ textField: UITextField) {
    textField.inputAccessoryView = inputToolbar
    
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.border.backgroundColor = TazColor.CIColor.color
      self?.topLabel.textColor = TazColor.CIColor.color
      self?.borderHeightConstraint?.constant = 2.0
    }
  }
  
  @objc public func textFieldEditingDidEnd(_ textField: UITextField) {
    //textField.text = textField.text?.trim //work not good "123 456" => "123"
    //push (e.g.) pw forgott child let end too late
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.border.backgroundColor = TazColor.CTArticle.color
      self?.topLabel.textColor = TazColor.CTArticle.color
      self?.borderHeightConstraint?.constant = 1.0
    }
  }
}

// MARK: - CustomTextView : UITextView
class CustomTextView : Padded.PUITextView{
  
  private var heightConstraint: NSLayoutConstraint?
  
  static var boldLinks : [NSAttributedString.Key : Any] {
    get {
      return [.foregroundColor : TazColor.CIColor.color,
              .font: Const.Fonts.titleFont(size: DefaultFontSize),
              .underlineColor: UIColor.clear]
    }
  }
  
  required init(htmlText: String,
                paddingTop: CGFloat = TextFieldPadding,
                paddingBottom: CGFloat = TextFieldPadding,
                font: UIFont = Const.Fonts.contentFont(size: DefaultFontSize),
                textColor: UIColor = TazColor.HText.color,
                textAlignment: NSTextAlignment = .left,
                linkTextAttributes: [NSAttributedString.Key : Any] = [.foregroundColor : TazColor.CIColor.color,
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
    heightConstraint?.priority = .defaultLow
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public init(){
    super.init(frame: .zero, textContainer:nil)
    heightConstraint = self.pinHeight(50)
    heightConstraint?.priority = .defaultLow
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
  public let textView = CustomTextView()
  public let checkbox = Checkbox()
  
  public var error : Bool = false {
    didSet {
      checkbox.layer.borderColor
        = error ? TazColor.CIColor.color.cgColor : TazColor.CTArticle.color.cgColor
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
