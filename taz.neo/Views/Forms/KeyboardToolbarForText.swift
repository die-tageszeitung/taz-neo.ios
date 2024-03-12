//
//  KeyboardToolbarForText.swift
//  taz.neo
//
//  Created by Ringo Müller on 22.03.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit

public protocol KeyboardToolbarForText where Self: UIResponder{
  var inputToolbar: UIToolbar { get }
  var container: UIView? { get }
}

fileprivate extension UIResponder {
  @objc func textFieldToolbarDoneButtonPressed(sender: UIBarButtonItem) {
    self.resignFirstResponder()
  }
  
  @objc func textFieldToolbarPrevButtonPressed(sender: UIBarButtonItem) {
    guard let self = self as? UIView else { return }
    if let next = (self as? KeyboardToolbarForText)?.container?.viewWithTag(self.tag - 1) {
      next.becomeFirstResponder()
    }
    else {
      self.resignFirstResponder()
    }
  }
  
  @objc func textFieldToolbarNextButtonPressed(sender: UIBarButtonItem) {
    (self as? KeyboardToolbarForText)?.nextOrEndEdit()
  }
}

public extension KeyboardToolbarForText where Self: UIResponder{
  var container: UIView? { return (self as? UIView)?.superview }
  
  func createToolbar() -> UIToolbar{
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
    
    prevButton.tintColor = Const.SetColor.CIColor.color
    nextButton.tintColor = Const.SetColor.CIColor.color
    doneButton.tintColor = Const.SetColor.CIColor.color
    
    let flexibleSpaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    let fixedSpaceButton = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
    fixedSpaceButton.width = 30
    
    toolbar.setItems([prevButton, fixedSpaceButton, nextButton, flexibleSpaceButton, doneButton], animated: false)
    toolbar.isUserInteractionEnabled = true
    
    return toolbar
  }
  
  func nextOrEndEdit(){
    guard let self = self as? UIView else { return }
    if let next = (self as? KeyboardToolbarForText)?.container?.viewWithTag(self.tag + 1) {
      next.becomeFirstResponder()
    }
    else {
      self.resignFirstResponder()
    }
  }
}
