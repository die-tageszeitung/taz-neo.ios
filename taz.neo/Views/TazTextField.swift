//
//  TazTextField.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 07.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib

// MARK: - TazTextField
/// A custom `UITextField` implementation with enhanced UI and layout features:
/// - Displays a placeholder as a `topLabel` when the input field is not empty.
/// - Shows an error state by adding a red border when `isError` is set to `true`.
/// - Includes a `bottomLabel` positioned below the background layer, creating the illusion of stacked views.
///   This effect is achieved with a custom layout, maintaining a single `UITextField` instance for simplicity.
/// - Supports Auto Layout with a self-sizing height, dynamically adjusting based on its components,
///   particularly the height of the multi-line `bottomLabel`, which depends on the length of the `bottomMessage`.
/// - Conforms to `KeyboardToolbarForText` for additional keyboard customization.
public class TazTextField : Padded.TextField, KeyboardToolbarForText{
  
  private var _accessibilityLabel: String?
  
  public override var accessibilityLabel: String? {
    get { return (_accessibilityLabel ?? topLabel.text ?? placeholder ?? "").prepend("Eingabe ")   }
    set {_accessibilityLabel = newValue }
  }
  
  public var index: Int?
  let topLabel = UILabel()
  var isError = false {
    didSet {
      if oldValue == isError { return }
      self.bottomLabel.alpha = isError ? 1.0 :1.0
      backgroundLayer.borderColor
      = isError
      ? Const.SetColor.taz2(.notifications_error).color.cgColor
      : CGColor.init(gray: 0, alpha: 0)
      backgroundLayer.borderWidth = isError ? 2.0 : 0.0
      UIView.animate(withDuration: 0.4) {
        self.superview?.setNeedsLayout()
        self.superview?.layoutIfNeeded()
      }
    }
  }
  let backgroundLayer = CALayer()
  let bottomLabel = UILabel()
  ///placeholderLabel is also the magic component for self resize
  ///This  == Textfield has a common Height of (self.TextField + Paddings) + topLabel + bottomLabel = 20
  ///(self.TextField + Paddings) == placeholderLabel.height + dist to topLabel and bottomLabel
  ///Using AutoLayout with V: | topMessage - a - placeholderLabel - b - bottomLabel |
  ///bottomLabel is grow and shrinkable and sets this (TextFild) height
  fileprivate let placeholderLabel = UILabel()
  
  private var handleEnter: (()->())?
  var onResignFirstResponder: (()->())?
  
  func onEnter(closure: @escaping ()->()){
    handleEnter = closure
  }
  
  public override var placeholder:String?{
    get { return placeholderLabel.text }
    set {
      placeholderLabel.text = newValue
      if topMessage == nil {
        topLabel.text = newValue
      }
    }
  }
  
  // MARK: > pwInput
  required init(prefilledText: String? = nil,
                placeholder: String? = nil,
                topMessage: String? = nil,
                color: UIColor = Const.SetColor.CIColor.color,
                textColor: UIColor = Const.SetColor.taz2(.text).color,
                paddingTop: CGFloat = Const.Size.TextFieldPadding,
                paddingBottom: CGFloat = Const.Size.TextFieldPadding,
                textContentType: UITextContentType? = .givenName,
                isSecureTextEntry: Bool = false,
                enablesReturnKeyAutomatically: Bool = false,
                keyboardType: UIKeyboardType = .default,
                autocapitalizationType: UITextAutocapitalizationType = .none,
                target: Any? = nil,
                action: Selector? = nil) {
    super.init(frame:.zero)
    setup(prefilledText: prefilledText,
          placeholder: placeholder,
          topMessage: topMessage,
          color: color,
          textColor: textColor,
          paddingTop: paddingTop,
          paddingBottom: paddingBottom,
          textContentType: textContentType,
          isSecureTextEntry: isSecureTextEntry,
          enablesReturnKeyAutomatically: enablesReturnKeyAutomatically,
          keyboardType: keyboardType,
          autocapitalizationType: autocapitalizationType,
          target: target,
          action: action)
  }
  
  public override func textRect(forBounds bounds: CGRect) -> CGRect {
    let r = bounds.insetBy(dx: Const.Size.DefaultPadding,
                          dy: Const.Size.DefaultPadding)
    return CGRect(x: r.origin.x, y: placeholderLabel.frame.origin.y,
                  width: r.size.width, height: r.size.height)
  }

  public override func editingRect(forBounds bounds: CGRect) -> CGRect {
      return textRect(forBounds: bounds)
  }
  
  public override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
    var rect = super.rightViewRect(forBounds: bounds)
    rect.origin.y -= isError ? 10 : 0;
    rect.origin.x -= 10;
    return rect
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
    
  public override func layoutSubviews() {
    backgroundLayer.frame = CGRect(x: 0,
                                   y: 0,
                                   width: self.frame.size.width,
                                   height: bottomLabel.frame.origin.y - 3)
    super.layoutSubviews()
 }
  
  func setup(prefilledText: String? = nil,
             placeholder: String? = nil,
             topMessage: String? = nil,
             color: UIColor = Const.SetColor.CIColor.color,
             textColor: UIColor = Const.SetColor.taz2(.text).color,
             paddingTop: CGFloat = Const.Size.TextFieldPadding,
             paddingBottom: CGFloat = Const.Size.TextFieldPadding,
             textContentType: UITextContentType? = .givenName,
             isSecureTextEntry: Bool = false,
             enablesReturnKeyAutomatically: Bool = false,
             keyboardType: UIKeyboardType = .default,
             autocapitalizationType: UITextAutocapitalizationType = .none,
             target: Any? = nil,
             action: Selector? = nil){
    self.text = prefilledText
    self.placeholder = placeholder
    self.paddingTop = paddingTop
    self.paddingBottom = paddingBottom
    self.contentVerticalAlignment = .top
    
    self.placeholderLabel.textColor = Const.SetColor.taz2(.text_disabled).color
    placeholderLabel.numberOfLines = 0
    self.textColor = textColor
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
      eye.tintColor = Const.SetColor.taz2(.text).color
      eye.onTapping(closure: { _ in
        self.isSecureTextEntry = !self.isSecureTextEntry
        eye.image = self.isSecureTextEntry ? imgEyeSlash : imgEye
      })
      self.rightView = eye
      self.rightViewMode = .always
    }
    backgroundLayer.backgroundColor = Const.SetColor.HBackground.color.cgColor
    self.layer.insertSublayer(backgroundLayer, at: 0)
    self.delegate = self
    bottomLabel.alpha = 0.0
    bottomLabel.numberOfLines = 0
    
    self.addSubview(topLabel)
    self.addSubview(placeholderLabel)
    self.addSubview(bottomLabel)
    
    topLabel.pinHeight(20)
    placeholderLabel.pinHeight(20)
    bottomLabel.pinHeight(20.0, priority: .defaultLow)
    
    pin(topLabel.top, to: self.top, dist: 5)
    pin(placeholderLabel.top, to: topLabel.bottom, dist: 5)
    pin(bottomLabel.top, to: placeholderLabel.bottom, dist: 12)//test with 8 and fix bg
    pin(bottomLabel.bottom, to: self.bottom, dist: 0)
    
    topLabel.alpha = 0.0
    topLabel.numberOfLines = 1

    pin(topLabel.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(topLabel.right, to: self.right, dist: -Const.Size.DefaultPadding)

    topLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    self.topLabel.textColor = Const.SetColor.taz2(.text_icon_grey).color
    
    pin(placeholderLabel.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(placeholderLabel.right, to: self.right, dist: -Const.Size.DefaultPadding)
        
    pin(bottomLabel.left, to: self.left)
    pin(bottomLabel.right, to: self.right)

    bottomLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    bottomLabel.textColor =
    Const.SetColor.taz2(.notifications_errorText).color
    
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
          self?.placeholderLabel.alpha = 1.0
        }
      }
      else {
        UIView.animate(seconds: 0.3) { [weak self] in
          self?.topLabel.alpha = 1.0
          self?.placeholderLabel.alpha = 0.0
        }
      }
    }
  }
  
  open var topMessage: String? {
    didSet {
      topLabel.text = topMessage ?? placeholder
    }
  }
  
  
  // MARK: > bottomMessage
  open var bottomMessage: String?{
    didSet{
      bottomLabel.text = bottomMessage
      isError = self.bottomMessage?.isEmpty == false
      self.bottomLabel.alpha = isError ? 1.0 :1.0
      backgroundLayer.borderColor = isError ? Const.SetColor.taz2(.notifications_error).color.cgColor : CGColor.init(gray: 0, alpha: 0)
      backgroundLayer.borderWidth = isError ? 2.0 : 0.0
      self.accessibilityLabel = bottomMessage
    }
  }
  
  // MARK: > inputToolbar
  lazy public var inputToolbar: UIToolbar = createToolbar()
}

// MARK: - TazTextField : UITextFieldDelegate
extension TazTextField: UITextFieldDelegate{
  
  @objc public func textFieldEditingDidChange(_ textField: UITextField) {
    if let _text = self.text
        , _text.isEmpty,
        self.topLabel.alpha == 1.0 {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = 0.0
        self?.placeholderLabel.alpha = 1.0
      }
    }
    else if self.topLabel.alpha == 0.0 || self.placeholderLabel.alpha == 1.0 {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = 1.0
        self?.placeholderLabel.alpha = 0.0
      }
    }
  }
  
  @objc  public func textFieldEditingDidEnd(_ textField: UITextField) {
    if let _text = self.text, _text.isEmpty {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.placeholderLabel.alpha = 1.0
        if self?.topMessage == self?.placeholder {
          self?.topLabel.alpha = 0.0
        }
      }
    }
  }
  
  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    nextOrEndEdit()
    handleEnter?()
    return true
  }
  
  @objc public func textFieldEditingDidBegin(_ textField: UITextField) {
    textField.inputAccessoryView = inputToolbar
  }
}
