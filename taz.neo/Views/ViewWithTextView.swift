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
public class ViewWithTextView : UIStackView{
  
  var textViewheightConstraint:NSLayoutConstraint?
  
  var isFilled:Bool{ get {return self.textView.text != placeholder}}
  
  let topLabel = UILabel()
  let bottomLabel = UILabel()
  let textView = UITextView()
  
  weak open var delegate: UITextViewDelegate?
  
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
    get {
      return isFilled ? self.textView.text : nil}
    set {
      self.textView.text = newValue
      verifyPlaceholder()
    }
  }
  
  var placeholder : String? {
    didSet { verifyPlaceholder() }
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
    
    textView.delegate = self
    textView.font = font
    textView.textColor = Const.SetColor.CTDate.color
    
    topLabel.numberOfLines = 1
    topLabel.alpha = 0.0
    topLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    self.topLabel.textColor = Const.SetColor.ForegroundLight.color
    
    bottomLabel.alpha = 0.0
    bottomLabel.numberOfLines = 1
    bottomLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    bottomLabel.textColor = Const.SetColor.CIColor.color
    
    self.addArrangedSubview(topLabel)
    self.addArrangedSubview(textView)
    self.addArrangedSubview(bottomLabel)
    
    textView.textContainerInset = UIEdgeInsets.zero
    textView.textContainer.lineFragmentPadding = 0
    textView.isScrollEnabled = false
    textView.text = text
    textView.backgroundColor = .clear
    
//    self.textViewDidBeginEditing(textView)
  }
  
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  
  // MARK: > inputToolbar
//  lazy var inputToolbar: UIToolbar = createToolbar()
}

// MARK: - TazTextField : Toolbar
extension ViewWithTextView{
  
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
    self.textView.resignFirstResponder()
  }
  
  @objc func textFieldToolbarPrevButtonPressed(sender: UIBarButtonItem) {
    let nextView = self.superview?.viewWithTag(self.tag - 1)
    if let nextField = nextView as? UITextField {
      nextField.becomeFirstResponder()
    }
    else if let nextView = nextView as? UITextView {
      nextView.becomeFirstResponder()
    }
    else if let nextView = nextView as? ViewWithTextView {
      nextView.textView.becomeFirstResponder()
    }
    else {
      self.resignFirstResponder()
    }
  }
  
  @objc func textFieldToolbarNextButtonPressed(sender: UIBarButtonItem) {
    nextOrEndEdit()
  }
  
  func nextOrEndEdit(){
    let nextView = self.superview?.viewWithTag(self.tag + 1)
    if let nextField = nextView as? UITextField {
      nextField.becomeFirstResponder()
    }
    else if let nextView = nextView as? UITextView {
      nextView.becomeFirstResponder()
    }
    else if let nextView = nextView as? ViewWithTextView {
      nextView.textView.becomeFirstResponder()
    }
    else {
      self.textView.resignFirstResponder()
    }
  }
  
  public override func becomeFirstResponder() -> Bool {
    self.textView.becomeFirstResponder()
  }
}

// MARK: - TazTextField : UITextViewDelegate
extension ViewWithTextView : UITextViewDelegate{
  public func textViewDidBeginEditing(_ textView: UITextView)
  {
//    textView.inputAccessoryView = inputToolbar
    if (textView.text == placeholder)
    {
      if let constraint = textViewheightConstraint {
        constraint.constant = textView.frame.size.height      }
      else {
        textViewheightConstraint = textView.pinHeight(textView.frame.size.height, priority: .defaultHigh)
      }
      textView.text = ""
      textView.textColor = Const.SetColor.CTDate.color
    }
  }
  
  public func textViewDidEndEditing(_ textView: UITextView)
  {
    verifyPlaceholder()
    textView.resignFirstResponder()
    delegate?.textViewDidEndEditing?(textView)
  }
  
  func verifyPlaceholder(){
    
//    print("""
//      verify placeholder for tazTextView with
//      \ntopMessage: \(self.topMessage)
//      \nplaceholder: \(self.placeholder)
//      \ntext: \(self.text)
//      \nbottomMessage: \(self.bottomMessage)
//    """)
    
    if (self.textView.text == "")
    {
      self.textView.text = placeholder
      self.textView.textColor = Const.SetColor.ForegroundLight.color
    }
    else {
      textView.textColor = Const.SetColor.CTDate.color
    }
  }
  
//  public func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
//    nextOrEndEdit()
//    return true
//  }
}
