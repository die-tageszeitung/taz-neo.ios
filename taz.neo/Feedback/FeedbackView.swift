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
  public let messageTextView = TazTextView()
  public let lastInteractionTextView = TazTextView()
  public let environmentTextView = TazTextView()
  
  public let senderMail = TazTextField(textContentType: .emailAddress,
                                       keyboardType: .emailAddress,
                                       autocapitalizationType: .none)
  public let sendButton = UIButton()
  public let cancelButton = UIButton()
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
    self.backgroundColor = Const.SetColor.taz2(.backgroundForms).color
    setupText()
    self.onTapping { [weak self] (_) in self?.endEditing(false)}
    senderMail.delegate = self
    messageTextView.delegate = self

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
//      messageTextView.delegate = self
    } else {
      sendButton.isEnabled = true
    }
    
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
    stack.spacing = Const.Size.DefaultPadding
    stack.addArrangedSubview(cancelButtonWrapper)
    stack.addArrangedSubview(hStack1)
    stack.addArrangedSubview(senderMail)
    senderMail.tag = 10
    stack.addArrangedSubview(messageTextView)
    messageTextView.tag = 11
    if type == .error {
      stack.addArrangedSubview(lastInteractionTextView)
      lastInteractionTextView.tag = 12
      stack.addArrangedSubview(environmentTextView)
      environmentTextView.tag = 13
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
    logAttachmentButton.shadow()
    screenshotAttachmentButton.shadow()
    pin(screenshotAttachmentButton, to: hStack2, exclude: .right)
    pin(logAttachmentButton, to: hStack2, exclude: .left)
    checkSendButton()
  }
  
  func setupText(){
    messageTextView.topMessage = "Ihre Nachricht"
    lastInteractionTextView.topMessage = "Letzte Interaktion"
    environmentTextView.topMessage = "Zustand (WLAN, Netz, Speicher...)"
    
    lastInteractionTextView.placeholder = "Was waren die letzten Aktionen, die Sie mit der App durchgeführt haben, bevor das Problem aufgetreten ist?"
    
    environmentTextView.placeholder = "Beschreiben Sie mögliche Außeneinflüsse bitte hier. War das WLAN an?, Benutzen Sie eine Firewall, Proxy? Gab es Netzwerkprobleme, genügend Speicher, aussreichend Akku..."
    attachmentsLabel.text = "Anhänge"
    
    switch type {
      case .feedback:
        subjectLabel.text = "Feedback"
        messageTextView.placeholder = "Ihr Feedback.\n \n "
      case .error:
        subjectLabel.text = "Fehler melden"
        messageTextView.placeholder = "Beschreiben Sie ihr Problem bitte hier."
      case .fatalError:
        subjectLabel.text = "Abbsturz melden"
        messageTextView.placeholder = "Beschreiben Sie ihr Problem bitte hier."
    }
    
    if isLoggedIn {
      senderMail.placeholder
        = "Für Rückfragen und Antwort nutzen wir die E-Mail-Adresse ihres taz-Kontos oder nachfolgende E-Mail-Adresse.";
      senderMail.topMessage
        = "Alternative E-Mail (optional)"
    }
    else {
      //User is not logged in
      senderMail.placeholder
        = "Ihre E-Mail-Adresse für Rückfragen und Antworten"
      senderMail.topMessage
        = "Ihre E-Mail für Rückmeldungen"
    }
  }
}

extension FeedbackView {
  var isSenderMailValid : Bool {
    get {
      if type == FeedbackType.feedback,
          (senderMail.text ?? "").isEmpty { return true }//feedback can have empty mail
      if isLoggedIn || (senderMail.text ?? "").isValidEmail() { return true }
      return false
    }
  }
  
  var isMessageFieldValid : Bool {
    get {
      if type != FeedbackType.feedback { return true }///error can have empty message
      return messageTextView.text?.isEmpty == false
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
  public func textViewDidEndEditing(_ textView: UITextView){
    checkSendButton()
    (textView.superview as? TazTextView)?.errorMessage
    = textView.text.isEmpty == true
    ? "Bitte ausfüllen"
    : nil
  }
}

extension FeedbackView : UITextFieldDelegate{
  
  public func textFieldDidBeginEditing(_ textField: UITextField) {
    guard let ti = textField as? KeyboardToolbarForText else { return }
    textField.inputAccessoryView = ti.inputToolbar
  }
  
  public func textFieldDidEndEditing(_ textField: UITextField){
    if textField != senderMail { return}
    checkSendButton()
    if isLoggedIn == false {
      senderMail.bottomMessage = "Bitte ausfüllen"
    }
    else if type != FeedbackType.feedback
              && !(textField.text ?? "").isValidEmail() {
      senderMail.bottomMessage = "Muss E-Mail oder leer sein"
    }
    else {
      senderMail.bottomMessage = nil
    }
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
