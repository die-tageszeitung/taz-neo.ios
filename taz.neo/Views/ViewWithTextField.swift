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
public class TazTextField : Padded.TextField, UITextFieldDelegate, KeyboardToolbarForText{
  public var index: Int?
  static let recomendedHeight:CGFloat = 61.0
  var initialHeight: CGFloat = TazTextField.recomendedHeight
  let topLabel = UILabel()
  var isError = false {
    didSet {
      if oldValue == isError { return }
      self.bottomLabel.alpha = isError ? 1.0 :1.0
      self.heightConstraint?.constant
      = self.initialHeight + (isError ? 20.0 : 0)
      backgroundLayer.borderColor
      = isError
      ? Const.SetColor.taz2(.notifications_error).color.cgColor
      : CGColor.init(gray: 0, alpha: 0)
      backgroundLayer.borderWidth = isError ? 2.0 : 0.0
    }
  }
  let backgroundLayer = CALayer()
  let bottomLabel = UILabel()
  var heightConstraint: NSLayoutConstraint?
//  var bottomLabelHeightConstraint: NSLayoutConstraint?
  
  private var handleEnter: (()->())?
  var onResignFirstResponder: (()->())?
  
  func onEnter(closure: @escaping ()->()){
    handleEnter = closure
  }
  
  var placeholderText: String? {
    get { return placeholder }
    set {
      self.placeholder = newValue
      guard let newValue = newValue else {
        self.attributedPlaceholder = nil
        return
      }
      self.attributedPlaceholder = NSAttributedString(string: newValue,
                                                      attributes: [NSAttributedString.Key.foregroundColor: Const.SetColor.taz2(.text_disabled).color])
    }
  }
  
  // MARK: > pwInput
  required init(prefilledText: String? = nil,
                placeholder: String? = nil,
                color: UIColor = Const.SetColor.CIColor.color,
                textColor: UIColor = Const.SetColor.CTDate.color,
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
    setup(prefilledText: prefilledText,
          placeholder: placeholder,
          color: color,
          textColor: textColor,
          height: height,
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
    if isError { return r}
    return CGRect(x: r.origin.x, y: r.origin.y,
                  width: r.size.width, height: r.size.height + 20)
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
                                   height: self.frame.size.height - (isError ? 20 : 0))
    super.layoutSubviews()
  }
  
  func setup(prefilledText: String? = nil,
             placeholder: String? = nil,
             color: UIColor = Const.SetColor.CIColor.color,
             textColor: UIColor = Const.SetColor.CTDate.color,
             height: CGFloat = TazTextField.recomendedHeight,
             paddingTop: CGFloat = TextFieldPadding,
             paddingBottom: CGFloat = TextFieldPadding,
             textContentType: UITextContentType? = .givenName,
             isSecureTextEntry: Bool = false,
             enablesReturnKeyAutomatically: Bool = false,
             keyboardType: UIKeyboardType = .default,
             autocapitalizationType: UITextAutocapitalizationType = .words,
             target: Any? = nil,
             action: Selector? = nil){
    heightConstraint = pinHeight(initialHeight)
    self.paddingTop = paddingTop
    self.paddingBottom = paddingBottom
    
    placeholderText = placeholder
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
      eye.tintColor = Const.SetColor.ForegroundHeavy.color
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
    bottomLabel.numberOfLines = 1
    self.addSubview(bottomLabel)
    pin(bottomLabel.left, to: self.left)
//    bottomLabelHeightConstraint =
    bottomLabel.pinHeight(20.0)
    pin(bottomLabel.right, to: self.right)
    pin(bottomLabel.bottom, to: self.bottom, dist: 0)
    bottomLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    bottomLabel.textColor =
    Const.SetColor.taz2(.notifications_errorText).color
    
    self.addTarget(self, action: #selector(textFieldEditingDidChange),
                   for: UIControl.Event.editingChanged)
    self.addTarget(self, action: #selector(textFieldEditingDidBegin),
                   for: UIControl.Event.editingDidBegin)
//    self.addTarget(self, action: #selector(textFieldEditingDidEnd),
//                   for: UIControl.Event.editingDidEnd)
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
  
  open var topMessage: String? {
    didSet {
      topLabel.text = topMessage == nil ? placeholder : topMessage
    }
  }
  
  // MARK: > placeholder
  override open var placeholder: String?{
    didSet{
      super.placeholder = placeholder
      if topMessage == nil {
        topLabel.text = placeholder
      }
      if topLabel.superview == nil && placeholder?.isEmpty == false{
        topLabel.alpha = 0.0
        topLabel.numberOfLines = 1
        self.addSubview(topLabel)
        pin(topLabel.left, to: self.left, dist: Const.Size.DefaultPadding)
        pin(topLabel.right, to: self.right, dist: -Const.Size.DefaultPadding)
        pin(topLabel.top, to: self.top, dist: 8)
        topLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
        self.topLabel.textColor = Const.SetColor.ForegroundLight.color
      }
    }
  }
  
  // MARK: > bottomMessage
  open var bottomMessage: String?{
    didSet{
      bottomLabel.text = bottomMessage
      isError = self.bottomMessage?.isEmpty == false
      self.bottomLabel.alpha = isError ? 1.0 :1.0
      self.heightConstraint?.constant
      = self.initialHeight + (isError ? 20.0 : 0)
      
      backgroundLayer.borderColor = isError ? Const.SetColor.taz2(.notifications_error).color.cgColor : CGColor.init(gray: 0, alpha: 0)
      backgroundLayer.borderWidth = isError ? 2.0 : 0.0
      
    }
  }
  
  // MARK: > inputToolbar
  lazy public var inputToolbar: UIToolbar = createToolbar()
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
  
  @objc public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    nextOrEndEdit()
    handleEnter?()
    return true
  }
  
  @objc public func textFieldEditingDidBegin(_ textField: UITextField) {
    textField.inputAccessoryView = inputToolbar
  }
}
