//
//  ViewWithTextView.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 02.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib

// MARK: - ViewWithTextView : UITextView


/// A UITextView with Top Label (for Description), Bottom Label (for Errormessages), Placeholder Label (Placeholder)
public class ViewWithTextView : UIStackView, KeyboardToolbarForText{
  public var inputToolbar: UIToolbar { textView.inputToolbar }
  
  public override var tag: Int {
    get { return textView.tag}
    set { textView.tag = newValue }
  }
  
  var textViewheightConstraint:NSLayoutConstraint?
  
  let topLabel = UILabel()
  let bottomLabel = UILabel()
  let textView = PlaceholderUITextView()
  
  weak open var delegate: UITextViewDelegate? {
    didSet {
      textView.tvDelegate = delegate
    }
  }
  
  // MARK: > bottomMessage
  var bottomMessage: String?{
    didSet{
      bottomLabel.text = bottomMessage
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.bottomLabel.alpha = self?.bottomMessage?.isEmpty == false ? 1.0 : 0.0
      }
    }
  }
  
  var text: String?{
    get { self.textView.text }
    set { self.textView.text = newValue }
  }
  
  var isFilled:Bool{ get {return !self.textView.text.isEmpty}}

  
  var placeholder: String? {
    get { return textView.placeholder }
    set { textView.placeholder = newValue }
  }
  
  var topMessage: String?{
    didSet{
      topLabel.text = topMessage
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = self?.topMessage?.isEmpty == false ? 1.0 : 0.0
      }
    }
  }
  
  required init(text: String? = nil,
                font: UIFont = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)) {
    super.init(frame: .zero)
    
    self.axis = .vertical
    
    textView.font = font
    textView.textColor = Const.SetColor.CTDate.color
    textView.placeholderLabel.font = font
    textView.placeholderLabel.textColor = Const.SetColor.ForegroundLight.color

    topLabel.numberOfLines = 1
    topLabel.alpha = 0.0
    topLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    self.topLabel.textColor = Const.SetColor.ForegroundLight.color
    
    topLabel.onTapping { [weak self] _ in
      self?.textView.becomeFirstResponder()
    }
    
    bottomLabel.alpha = 0.0
    bottomLabel.numberOfLines = 1
    bottomLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    bottomLabel.textColor = Const.SetColor.CIColor.color
    
    self.addArrangedSubview(topLabel)
    self.addArrangedSubview(textView)
    self.addArrangedSubview(bottomLabel)
    textView.textContainerInset = Const.Insets.DefaultAll
    textView.textContainer.lineFragmentPadding = 0
    textView.isScrollEnabled = false
    textView.text = text
    textView.backgroundColor = .clear
    self.backgroundColor = Const.SetColor.HBackground.color
  }
  
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class PlaceholderUITextView: UITextView, KeyboardToolbarForText {
  lazy public var inputToolbar: UIToolbar = createToolbar()
  
  var container: UIView? { return self.superview?.superview}
  
  public var placeholderInsets:UIEdgeInsets = Const.Insets.DefaultAll
  public var placeholder:String?{  didSet{ setup()}  }
  weak open var tvDelegate: UITextViewDelegate?
  
  public let placeholderLabel = UILabel()
  
  
  func setup(){
    if self.placeholderLabel.superview != nil { return }
    if self.placeholder == nil { return }
    super.delegate = self
    self.insertSubview(placeholderLabel, at: 0)
    pin(placeholderLabel.top, to: self.top, dist: placeholderInsets.top)
    pin(placeholderLabel.left, to: self.left, dist: placeholderInsets.left)
    placeholderLabel.numberOfLines = 0
    placeholderLabel.text = placeholder
  }
  
  var heightConstraint: NSLayoutConstraint?
  var labelWidthConstraint: NSLayoutConstraint?

  override func layoutSubviews() {
    super.layoutSubviews()
    if self.frame.size.width == 0 { return }
    heightConstraint?.isActive = false
    labelWidthConstraint?.isActive = false
    ///min height is 55
    let nh = max(55,placeholderLabel.sizeThatFits(CGSize(width: self.frame.size.width, height: 2000)).height)
    self.heightConstraint = self.pinHeight(nh + 15, priority: .defaultHigh)
    self.labelWidthConstraint = placeholderLabel.pinWidth(self.frame.size.width)
  }
}

extension PlaceholderUITextView: UITextViewDelegate {
  func textViewDidEndEditing(_ textView: UITextView) {
    if textView.text.isEmpty {
      placeholderLabel.isHidden = false
    }
    tvDelegate?.textViewDidEndEditing?(textView)
  }
  
  func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
    textView.inputAccessoryView = inputToolbar
    return true
  }
  
  public func textViewDidBeginEditing(_ textView: UITextView)
  {
    placeholderLabel.isHidden = true
//    topLabel.text = placeholder
    tvDelegate?.textViewDidBeginEditing?(textView)
    textView.inputAccessoryView = inputToolbar
  }
  
  func textViewDidChange(_ textView: UITextView) {
    tvDelegate?.textViewDidChange?(textView)
  }
}
