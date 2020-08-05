//
//
// FormView.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

fileprivate let DefaultFontSize = CGFloat(16)

// MARK: - FormularView
/// A RegisterView displays an RegisterForm
public class FormView: UIView {
  
  let blockingView = BlockingProcessView()
  
  var views : [UIView] = []{
    didSet{
      addAndPin(views)
      self.backgroundColor = TazColor.CTBackground.color
    }
  }
  
  // MARK: Container for Content in ScrollView
  let container = UIView()
  let scrollView = UIScrollView()
  
  // MARK: agbAcceptLabel with Checkbox
  lazy var agbAcceptTV : CheckboxWithText = {
    let view = CheckboxWithText()
    view.textView.isEditable = false
    view.textView.attributedText = Localized("fragment_login_request_test_subscription_terms_and_conditions").htmlAttributed
    view.textView.linkTextAttributes = [.foregroundColor : TazColor.CIColor.color, .underlineColor: UIColor.clear]
    view.textView.font = AppFonts.contentFont(size: DefaultFontSize)
    view.textView.textColor = TazColor.HText.color
    return view
  }()
  
  private func runPerformanceTest(){
    /* ************************
     Performance Test in Simulator
     Dauer auf 4.2GHZ 4Cores*2Threads < 10s
     **** Resultat: Kein Memory Impact! ****
     setzen der backgroundColor Max 200MB After 32MB
     setzen paddingTop& Max 180MB After 33MB
     ****************************/
    for _ in 0...500000 {
      //      print("Loop:", i)
      let v = UIView()
      //      v.backgroundColor = .red
      v.paddingTop = 1
      v.paddingBottom = 1
    }
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
  
  
  // MARK: addAndPin
  func addAndPin(_ views: [UIView]){
    self.subviews.forEach({ $0.removeFromSuperview() })
    
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
    
    let notificationCenter = NotificationCenter.default
    
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardWillShow),
                                   name:UIResponder.keyboardWillShowNotification,
                                   object: nil)
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardWillHide),
                                   name:UIResponder.keyboardWillHideNotification,
                                   object: nil)
    scrollView.addSubview(container)
    NorthLib.pin(container, to: scrollView)
    self.addSubview(scrollView)
    NorthLib.pin(scrollView, to: self)
    
    self.addSubview(blockingView)
    NorthLib.pin(blockingView, to: self)
  }
}
