//
//
// FormView.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

// MARK: - FormularView
public class FormView: UIView {
  
  let DefaultFontSize = CGFloat(16)
  
  // MARK: Container for Content in ScrollView
  let container = UIView()
  let scrollView = UIScrollView()
  
  let blockingView = BlockingProcessView()
  
  public var blocked : Bool = false {
    didSet{
      blockingView.isHidden = !blocked
    }
  }
  
  ///Set views before added to superview otherwise createSubviews() is used
  var views : [UIView]?
  ///if not overwritten and no [views] provided, a taz header is used
  func createSubviews() -> [UIView] { return [TazHeader()] }
  
  // MARK: createSubviews need to be overwritten in inherited
  public override func willMove(toSuperview newSuperview: UIView?) {
    if newSuperview != nil {///do nothing if removed
      setKeyboardObserving()
      let _views = views ?? createSubviews()
      addAndPin(_views)
    }
    super.willMove(toSuperview: newSuperview)
  }
  
  // MARK: addAndPin
  func addAndPin(_ views: [UIView]){
    self.subviews.forEach({ $0.removeFromSuperview() })
    self.backgroundColor = Const.SetColor.CTBackground.color
    if views.isEmpty { return }
    
    let margin : CGFloat = 12.0
    var previous : UIView?
    
    var tfTags : Int = 100
    
    for v in views {
      
      if v is UITextField {
        v.tag = tfTags
        tfTags += 1
      }
      
      //add
      container.addSubview(v)
      //pin
      if previous == nil {
        pin(v, to: container, dist: margin, exclude: .bottom)
      }
      else {
        NorthLib.pin(v.left, to: container.left, dist: margin)
        NorthLib.pin(v.right, to: container.right, dist: -margin)
        NorthLib.pin(v.top, to: previous!.bottom, dist: padding(previous!, v))
      }
      previous = v
    }
    NorthLib.pin(previous!.bottom, to: container.bottom, dist: -margin)
    
    scrollView.addSubview(container)
    NorthLib.pin(container, to: scrollView)
    self.addSubview(scrollView)
    NorthLib.pin(scrollView, to: self)
    
    self.addSubview(blockingView)
    NorthLib.pin(blockingView, to: self)
  }
}

extension FormView {
  func openFaqAction() -> UIAlertAction {
    return UIAlertAction(title: Localized("open_faq_in_browser"), style: .default) { _ in
      guard let url = URL(string: "https://blogs.taz.de/app-faq/") else { return }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
      
  @objc public func showRegisterTips(_ textField: UITextField) {
     Alert.message(title: Localized("register_tips_button"),
                  message: Localized("register_tips_text"), additionalActions:[openFaqAction()])
  }
  
  var registerTipsButton:UIButton{
    get{
      return Padded.Button(type: .label,
                           title: Localized("register_tips_button"),
                           target: self,
                           action: #selector(showRegisterTips))
    }
  }
}

// MARK: Keyboard Action, set ScrollView Insets if Keyboard appears
extension FormView {
  fileprivate func setKeyboardObserving(){
    let notificationCenter = NotificationCenter.default
    
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardWillShow),
                                   name:UIResponder.keyboardWillShowNotification,
                                   object: nil)
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardWillHide),
                                   name:UIResponder.keyboardWillHideNotification,
                                   object: nil)
  }
  
  @objc func keyboardWillShow(_ notification: Notification) {
    if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
      let keyboardRectangle = keyboardFrame.cgRectValue
      let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardRectangle.height, right: 0)
      scrollView.contentInset = contentInsets
    }
  }
  
  @objc func keyboardWillHide(notification:NSNotification){
    let contentInset:UIEdgeInsets = UIEdgeInsets.zero
    scrollView.contentInset = contentInset
  }
}
