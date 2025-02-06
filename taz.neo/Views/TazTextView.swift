//
//  TazTextView.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 02.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib

// MARK: - TazTextView
public class TazTextView : UIView, UITextFieldDelegate, KeyboardToolbarForText {
  
  weak open var delegate: (any UITextViewDelegate)?
  
  static let minimalHeight:CGFloat = 61.0
  var minimalHeight:CGFloat = 61.0
  
  var textColor: UIColor? {
    set { textView.textColor = newValue }
    get { textView.textColor}
  }

  var text:String? {
    set { textView.text = newValue }
    get { textView.text}
  }
  
  var topMessage: String?{
    didSet{
      topLabel.text = topMessage
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = self?.topMessage?.isEmpty == false ? 1.0 : 0.0
      }
    }
  }

  var font: UIFont? {
    set { errorLabel.font = newValue; textView.font = newValue }
    get { textView.font}
  }
  
  var placeholder:String?{  didSet{
    placeholderLabel.text = placeholder
  }  }
  
  var topLabelText:String?{  didSet{
    topLabel.text = topLabelText
  }  }
  
  lazy public var inputToolbar: UIToolbar = createToolbar()
  
  private let backgroundView = UIView()
  private let topLabel = UILabel()
  private let errorLabel = UILabel()
  fileprivate let placeholderLabel = UILabel()
  
  public var placeholderInsets:UIEdgeInsets = Const.Insets.DefaultAll
  public var errorMessage:String? {
    didSet {
      let changedState = errorLabel.text?.isEmpty != errorMessage?.isEmpty
      if changedState == false {
        errorLabel.text = errorMessage
        return
      }
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.errorLabel.text = self?.errorMessage
        if self?.errorMessage?.isEmpty == false {
          self?.backgroundView.layer.borderColor
          = Const.SetColor.taz2(.notifications_error).color.cgColor
          self?.backgroundView.layer.borderWidth = 2.0
          self?.errorLabel.alpha = 1.0
        }
        else {
          self?.backgroundView.layer.borderColor = UIColor.clear.cgColor
          self?.backgroundView.layer.borderWidth = 0.0
          self?.errorLabel.alpha = 0.0
        }
        self?.superview?.superview?.layoutIfNeeded()
      }
    }
  }

  private var textView = GrowableTextView()
  public override func becomeFirstResponder() -> Bool {
    return textView.becomeFirstResponder()
  }
  public override func resignFirstResponder() -> Bool {
    return textView.resignFirstResponder()
  }
  
  var heightConstraint: NSLayoutConstraint?

  func setup(){
    backgroundView.backgroundColor = Const.SetColor.HBackground.color
    
    textView.backgroundColor = .clear
    textView.textContainerInset = UIEdgeInsets(top: 0,
                                                 left: Const.Size.DefaultPadding,
                                                 bottom: 0,
                                                 right: Const.Size.DefaultPadding)
    textView.textContainer.lineFragmentPadding = 0
    
    textView.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
    
    topLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    self.topLabel.textColor = Const.SetColor.taz2(.text_icon_grey).color
    self.placeholderLabel.textColor = Const.SetColor.taz2(.text_disabled).color
    placeholderLabel.numberOfLines = 0
    
    errorLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    errorLabel.textColor = Const.SetColor.taz2(.notifications_errorText).color
    
    self.addSubview(backgroundView)
    self.addSubview(placeholderLabel)
    self.addSubview(topLabel)
    self.addSubview(textView)
    self.addSubview(errorLabel)
    
    pin(textView.right, to: self.right)
    pin(textView.left, to: self.left)
    pin(topLabel.right, to: self.right, dist: -Const.Size.DefaultPadding)
    pin(topLabel.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(errorLabel.right, to: self.right, dist: -Const.Size.DefaultPadding)
    pin(errorLabel.left, to: self.left)
    
    pin(topLabel.top, to: self.top, dist: 8)
    pin(textView.top, to: topLabel.bottom, dist: 8)
    pin(placeholderLabel, to: textView, margins: UIEdgeInsets(top: 0,
                                                              left: Const.Size.DefaultPadding,
                                                              bottom: 0,
                                                              right: Const.Size.DefaultPadding), exclude: .bottom)
    pin(errorLabel.top, to: textView.bottom, dist: 4)
    pin(errorLabel.bottom, to: self.bottom)
    
    pin(backgroundView, to: self, exclude: .bottom)
    pin(backgroundView.bottom, to: textView.bottom)
    
    topLabelText = "\(topLabelText ?? "")"//init setter not called!
    placeholder = "\(placeholder ?? "")"
    if text?.isEmpty == true {
      topLabel.alpha = 0.0
    }
    else {
      placeholderLabel.alpha = 0.0
    }
    
    topLabel.onTapping { [weak self] _ in
      if self?.textView.isFirstResponder == true {
        self?.textView.resignFirstResponder()
      }
      else {
        self?.textView.becomeFirstResponder()
      }
    }
  }
  
  // MARK: > pwInput
  required init(text: String? = nil,
                topLabelText: String? = nil,
                placeholder: String? = nil,
                font: UIFont? = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize),
                textColor: UIColor = Const.SetColor.taz2(.text).color,
                minimalHeight: CGFloat = TazTextView.minimalHeight,
                enablesReturnKeyAutomatically: Bool = false,
                keyboardType: UIKeyboardType = .default,
                autocapitalizationType: UITextAutocapitalizationType = .sentences) {
    super.init(frame: .zero)
    self.text = text
    self.placeholder = placeholder
    self.topLabelText = topLabelText
    self.font = font
    self.textColor = textColor
    self.minimalHeight = minimalHeight
    self.textView.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
    self.textView.keyboardType = keyboardType
    self.textView.autocapitalizationType = autocapitalizationType
    self.textView.delegate = self
    setup()
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  class GrowableTextView: UITextView {
    var heightConstraint: NSLayoutConstraint?
    var minimalHeight: CGFloat = 55.0
    var lastCalculatedPlaceholderHeightAlWidth = 0.0
    
    public override func layoutSubviews() {
      super.layoutSubviews()
      let selfW = self.frame.size.width
      if abs(selfW - lastCalculatedPlaceholderHeightAlWidth) > 10, let placeholderLabel = (self.superview as? TazTextView)?.placeholderLabel {
        minimalHeight = max(55.0, 25 + placeholderLabel.sizeThatFits(CGSize(width: selfW, height: 2000)).height )
        lastCalculatedPlaceholderHeightAlWidth = selfW
      }
      let newHeight
      = max(minimalHeight,12 + self.sizeThatFits(CGSize(width: selfW, height: 2000)).height)
      if self.heightConstraint == nil {
        self.heightConstraint = self.pinHeight(newHeight, priority: .defaultHigh)
      }
      else {
        self.heightConstraint?.constant = newHeight
      }
    }
  }
}

extension TazTextView: UITextViewDelegate {
  
  public func textViewDidEndEditing(_ textView: UITextView) {
    delegate?.textViewDidEndEditing?(textView)
    if let _text = textView.text, _text.isEmpty {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.placeholderLabel.alpha = 1.0
        if self?.topMessage == self?.placeholder {
          self?.topLabel.alpha = 0.0
        }
      }
    }
  }
  
  public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if text == "\t" {
      self.nextOrEndEdit()
      return false
    }
    return  delegate?.textView?(textView, shouldChangeTextIn: range, replacementText: text) ?? true
  }
  
  public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
    textView.inputAccessoryView = inputToolbar
    return true
  }
  
  public func textViewDidBeginEditing(_ textView: UITextView)
  {
    delegate?.textViewDidBeginEditing?(textView)
    if self.placeholderLabel.alpha != 0.0 {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = 1.0
        self?.placeholderLabel.alpha = 0.0
      }
    }
    textView.inputAccessoryView = inputToolbar
  }
}
