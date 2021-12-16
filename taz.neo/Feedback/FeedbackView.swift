//
//  FeedbackView.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 02.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import UIKit

/**
 
 UI:
 
 subjectLabel   :::: sendButton
 senderMailDescriptionLabel (wenn angemeldet!!)
 senderMailTextField
 seperator
 messageTextView
 seperator
 lastInteractionTextView  (ONLY ERROR)
 seperator  (ONLY ERROR)
 environmentTextView (ONLY ERROR)
 seperator  (ONLY ERROR)
 attachments
 
 */

public class FeedbackView : UIView {
  let attachmentButtonHeight : CGFloat = 110
  var type:FeedbackType
  var isLoggedIn:Bool
  public let stack = UIStackView()
  public let subjectLabel = UILabel()
  public let messageTextView = ViewWithTextView()
  public let lastInteractionTextView = ViewWithTextView()
  public let environmentTextView = ViewWithTextView()
  public let senderMail = ViewWithTextField()
  public let sendButton = UIButton()
  public let cancelButton = UIButton()
  public let senderMailDescriptionLabel = UILabel.descriptionLabel
  let attachmentsLabel = UILabel.descriptionLabel
  
  // Closure called upon orientation changes
  public var orientationChangedClosure = OrientationClosure()
  public let screenshotAttachmentButton = XImageView()
  public let logAttachmentButton = XImageView()
  
  init(type: FeedbackType, isLoggedIn: Bool) {
    self.type = type
    self.isLoggedIn = isLoggedIn
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    print("deinit: FeedbackView ;-)")
  }
  
  private func setup() {
    self.onTapping { [weak self] (_) in
      self?.endEditing(false)
    }
    setupText()

    cancelButton.setTitle("Abbrechen", for: .normal)
    cancelButton.setTitleColor(Const.SetColor.ios(.link).color, for: .normal)
    cancelButton.setTitleColor(.lightGray, for: .highlighted)
    let cancelButtonWrapper = UIStackView()
    cancelButtonWrapper.alignment = .leading
    cancelButtonWrapper.axis = .vertical
    cancelButtonWrapper.distribution = .equalSpacing
    cancelButtonWrapper.addArrangedSubview(cancelButton)
    
    
    if type == FeedbackType.feedback {
      sendButton.isEnabled = false
      messageTextView.delegate = self
    } else {
      sendButton.isEnabled = true
    }
    
    senderMail.delegate = self
    senderMail.textfield.keyboardType = .emailAddress
    senderMail.textfield.autocapitalizationType = .none
    senderMail.textfield.textContentType = .emailAddress
    
    //Subject & Send Button
    let hStack1 = UIStackView()
    hStack1.alignment = .fill
    hStack1.axis = .horizontal
    ///Content: subjectLabel
    
    subjectLabel.numberOfLines = 0
    subjectLabel.textColor = Const.SetColor.CTDate.color
    subjectLabel.font = UIFont.boldSystemFont(ofSize: Const.Size.LargeTitleFontSize)
    /// Content: sendButton Style
    sendButton.setBackgroundColor(color: Const.SetColor.ios(.link).color, forState: .normal)
    sendButton.setBackgroundColor(color: .lightGray, forState: .disabled)
    sendButton.layer.cornerRadius = 21
    sendButton.setImage(UIImage(name: "arrow.up"), for: .normal)
    sendButton.imageView?.tintColor = .white
    ///Add
    hStack1.addArrangedSubview(subjectLabel)
    hStack1.addArrangedSubview(sendButton)
    
    //Attatchment Container
    let hStack2 = UIView()
    hStack2.addSubview(screenshotAttachmentButton)
    logAttachmentButton.contentMode = .scaleAspectFit
    screenshotAttachmentButton.contentMode = .scaleAspectFit
    hStack2.addSubview(logAttachmentButton)
    logAttachmentButton.image = UIImage(name: "doc.text")
    logAttachmentButton.tintColor = Const.SetColor.ios(.link).color
    
    stack.axis = .vertical
    stack.spacing = 4.0//Seperators increase spacing!
    stack.addArrangedSubview(cancelButtonWrapper)
    stack.addArrangedSubview(hStack1)
    senderMailDescriptionLabel.onTapping { [weak self] _ in
      self?.senderMail.textfield.becomeFirstResponder()
    }
    stack.addArrangedSubview(senderMailDescriptionLabel)
    stack.addArrangedSubview(senderMail)
    senderMail.tag = 0
    stack.addArrangedSubview(UIView.seperator())
    stack.addArrangedSubview(messageTextView)
    messageTextView.tag = 1
    if type == .error {
      stack.addArrangedSubview(UIView.seperator())
      stack.addArrangedSubview(lastInteractionTextView)
      lastInteractionTextView.tag = 2
      stack.addArrangedSubview(UIView.seperator())
      stack.addArrangedSubview(environmentTextView)
      environmentTextView.tag = 3
      stack.addArrangedSubview(UIView.seperator())
      stack.addArrangedSubview(attachmentsLabel)
      stack.addArrangedSubview(hStack2)
    }
    
    
    let scrollView = UIScrollView()
    
    scrollView.addSubview(stack)
    pin(stack, to: scrollView, dist: 12)
    self.addSubview(scrollView)
    pin(scrollView.top, to: self.top, dist: -20)
    pin(scrollView.left, to: self.leftGuide())
    pin(scrollView.right, to: self.rightGuide())
    pin(scrollView.bottom, to: self.bottomGuide())
    
    ///Set Constraints after added to Stack View otherwise Contraint Errosrs are displayed
    sendButton.pinSize(CGSize(width: 42, height: 42))
    screenshotAttachmentButton.pinHeight(attachmentButtonHeight)
    logAttachmentButton.pinHeight(attachmentButtonHeight)
    logAttachmentButton.addBasicShadow()
    screenshotAttachmentButton.addBasicShadow()
    pin(screenshotAttachmentButton, to: hStack2, exclude: .right)
    pin(logAttachmentButton, to: hStack2, exclude: .left)
  }
  
  func setupText(){
    messageTextView.topMessage = "Ihre Nachhricht"
    lastInteractionTextView.topMessage = "Letzte Interaktion"
    environmentTextView.topMessage = "Zustand"
    
    lastInteractionTextView.placeholder = "Was waren die letzten Aktionen, die Sie mit der App durchgeführt haben, bevor das Problem aufgetreten ist?"
    
    environmentTextView.placeholder = "Beschreiben Sie mögliche Außeneinflüsse bitte hier. War das WLAN an?, Benutzen Sie eine Firewall, Proxy? Gab es Netzwerkprobleme, genügend Speicher, aussreichend Akku..."
    attachmentsLabel.text = "Anhänge"
    
    switch type {
      case .feedback:
        subjectLabel.text = "Feedback"
        messageTextView.placeholder = "Ihr Feedback."
      case .error:
        subjectLabel.text = "Fehler melden"
        messageTextView.placeholder = "Beschreiben Sie ihr Problem bitte hier."
      case .fatalError:
        subjectLabel.text = "Abbsturz melden"
        messageTextView.placeholder = "Beschreiben Sie ihr Problem bitte hier."
    }
    
    if isLoggedIn {
      senderMailDescriptionLabel.text
        = "Für Rückfragen und Antwort nutzen wir Ihre taz-ID E-Mail-Adresse oder nachfolgende E-Mail-Adresse.";
      senderMail.placeholder
        = "Alternative E-Mail (optional)"
    }
    else {
      //User is not logged in
      senderMailDescriptionLabel.text
        = "Rückfragen und Antworten sollen an nachfolgende E-Mail-Adresse zugestellt werden."
      senderMail.placeholder
        = "Ihre E-Mail für Rückmeldungen (optional)"
    }
  }
}



extension FeedbackView {
  var isSenderMailValid : Bool {
    get {
      if (senderMail.text ?? "").isEmpty { return true }
      if (senderMail.text ?? "").isValidEmail() { return true }
      return false
    }
  }
  
  var isMessageFieldValid : Bool {
    get {
      if type != FeedbackType.feedback { return true }
      return messageTextView.isFilled
    }
  }
  
  public var canSend : Bool {
    get { return isSenderMailValid && isMessageFieldValid }
  }
  
  func checkSendButton(){
    sendButton.isEnabled = canSend
  }
}

extension FeedbackView : UITextViewDelegate{
  
//  public func textViewDidChange(_ textView: UITextView){
//
//  }
  
  public func textViewDidEndEditing(_ textView: UITextView){
    if textView != messageTextView.textView { return }
    checkSendButton()
    messageTextView.bottomMessage = isMessageFieldValid
    ? nil
    : "Darf nicht leer sein"
  }
}

extension FeedbackView : UITextFieldDelegate{
  public func textFieldDidEndEditing(_ textField: UITextField){
    if textField != senderMail.textfield { return}//only handle this here!
    checkSendButton()
    senderMail.bottomMessage = isSenderMailValid
    ? nil
    : "Muss E-Mail oder leer sein"
  }
  
  public func textViewDidChange(_ textView: UITextView) {
    checkSendButton()
  }
}

extension UILabel{
  static var descriptionLabel : UILabel {
    get {
      let label = UILabel()
      label.numberOfLines = 0
      label.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
      label.textColor = Const.SetColor.ForegroundLight.color
      return label
    }
  }
}

extension UIView{
  func addBasicShadow(){
    self.layer.shadowOpacity = 0.25
    self.layer.shadowOffset = CGSize(width: 2, height: 2)
    self.layer.shadowRadius = 4
    self.layer.shadowColor = Const.SetColor.CTDate.color.cgColor
  }
}
