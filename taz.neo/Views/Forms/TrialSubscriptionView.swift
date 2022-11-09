//
//
// TrialSubscriptionView.swift
//
// Created by Ringo Müller-Gromes on 14.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib
import WebKit

extension TrialSubscriptionView : UITextFieldDelegate {
  public func textFieldDidBeginEditing(_ textField: UITextField) {
    if exchangeResponder == false {
      exchangeResponder = true
      firstnameInput.becomeFirstResponder()
      textField.becomeFirstResponder()
      exchangeResponder = false
    }
  }
  
  public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    if let textFieldString = textField.text, let swtRange = Range(range, in: textFieldString) {
          let newString = textFieldString.replacingCharacters(in: swtRange, with: string)
          print("FullString: \(newString)")
      
      
      wv.evaluateJavaScript("checkPassword('\(newString)', '\(mailInput.text ?? "")');", completionHandler: { [weak self] (qs, error) in
        guard let dict = qs as? [String: Any] else { return }
        if let msg = dict["message"] as? String {
          self?.passInput.bottomMessage = msg
        }
        if let col = dict["color"] as? String {
          //ToDo hex color conversion
          switch col {
            case "#f00":
              self?.passInput.bottomLabel.textColor = UIColor.rgb(0xff0000)
            case "#fb0":
              self?.passInput.bottomLabel.textColor = UIColor.rgb(0xffbb0)
            case "#0f0":
              self?.passInput.bottomLabel.textColor = UIColor.rgb(0x00ff00)
            default:
              self?.passInput.bottomLabel.textColor = UIColor.rgb(0xcccccc)
          }
        }
      })
      
    }

      return true
  }
}

public class TrialSubscriptionView : FormView{
  
  public override func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)
    if let url = Bundle.main.url(forResource: "pwcheckimport", withExtension: "html", subdirectory: "BundledResources") {
      wv.load(url: url)
    }
  }
  
  let wv = WebView()


  
  
  var exchangeResponder = false
  
  var mailInput = TazTextField(placeholder: Localized("login_email_hint"),
                               textContentType: .emailAddress,
                               enablesReturnKeyAutomatically: true,
                               keyboardType: .emailAddress,
                               autocapitalizationType: .none)
  
  var passInput = TazTextField(placeholder: Localized("login_password_hint"),
                               textContentType: .password,
                               isSecureTextEntry: true,
                               enablesReturnKeyAutomatically: true)
  
  var pass2Input = TazTextField(placeholder: Localized("login_password_hint"),
                                textContentType: .password,
                                isSecureTextEntry: true,
                                enablesReturnKeyAutomatically: true)
  
  
  var firstnameInput = TazTextField(placeholder: Localized("login_first_name_hint"),
                                    textContentType: .givenName,
                                    enablesReturnKeyAutomatically: true,
                                    keyboardType: .default,
                                    autocapitalizationType: .words)
  
  var lastnameInput = TazTextField(placeholder: Localized("login_surname_hint"),
                                   textContentType: .familyName,
                                   enablesReturnKeyAutomatically: true,
                                   keyboardType: .default,
                                   autocapitalizationType: .words)
  
  var registerButton = Padded.Button(title: Localized("register_button"))
  
  var cancelButton =  Padded.Button(type:.outline, title: Localized("cancel_button"))
  
  // MARK: agbAcceptLabel with Checkbox
  lazy var agbAcceptTV : CheckboxWithText = {
    let view = CheckboxWithText()
    view.textView.isEditable = false
    view.textView.attributedText = Localized("fragment_login_request_test_subscription_terms_and_conditions").htmlAttributed
    view.textView.linkTextAttributes = [.foregroundColor : Const.SetColor.CIColor.color, .underlineColor: UIColor.clear]
    view.textView.font = Const.Fonts.contentFont(size: DefaultFontSize)
    view.textView.textColor = Const.SetColor.HText.color
    return view
  }()
    
  override func createSubviews() -> [UIView] {
    passInput.textContentType = .newPassword
    passInput.delegate = self
    pass2Input.delegate = self
    
    return   [
      Padded.Label(title: Localized("trial_subscription_title")),
      mailInput,
      passInput,
      pass2Input,
      firstnameInput,
      lastnameInput,
      Padded.Label(title:
        Localized("fragment_login_request_test_subscription_existing_account")),
      agbAcceptTV,
      registerButton,
      cancelButton,
      registerTipsButton
    ]
  }
  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    
    mailInput.bottomMessage = ""
    passInput.bottomMessage = ""
    pass2Input.bottomMessage = ""
    firstnameInput.bottomMessage = ""
    lastnameInput.bottomMessage = ""
    agbAcceptTV.error = false
    
    if mailInput.isUsed, (mailInput.text ?? "").isEmpty {
      errors = true
      mailInput.bottomMessage = Localized("login_email_error_empty")
    } else if mailInput.isUsed, (mailInput.text ?? "").isValidEmail() == false {
      errors = true
      mailInput.bottomMessage = Localized("login_email_error_no_email")
    }
    
    if passInput.isUsed, (passInput.text ?? "").isEmpty {
      errors = true
      passInput.bottomMessage = Localized("login_password_error_empty")
    }
    else if passInput.isUsed, (passInput.text ?? "").length < 12 {
      errors = true
      passInput.bottomMessage = Localized("password_too_short")
    }
    else if let mailLeading = mailInput.text?.components(separatedBy: "@").first,
            mailLeading.length > 3,
            passInput.text?.contains(mailLeading) != false {
      errors = true
      passInput.bottomMessage = Localized("password_contains_mail")
    }
    
    if pass2Input.isUsed, pass2Input.isVisible, (pass2Input.text ?? "").isEmpty {
      errors = true
      pass2Input.bottomMessage = Localized("login_password_error_empty")
    }
    else if pass2Input.isUsed, pass2Input.text != passInput.text {
      errors = true
      pass2Input.bottomMessage = Localized("login_password_confirmation_error_match")
    }
    
    if firstnameInput.isUsed, (firstnameInput.text ?? "").isEmpty {
      errors = true
      firstnameInput.bottomMessage = Localized("login_first_name_error_empty")
    }
    
    if lastnameInput.isUsed, (lastnameInput.text ?? "").isEmpty {
      errors = true
      lastnameInput.bottomMessage = Localized("login_surname_error_empty")
    }
    
    if agbAcceptTV.isUsed, agbAcceptTV.checked == false {
      agbAcceptTV.error = true
      return Localized("register_validation_issue_agb")
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    return nil
  }
}

fileprivate extension UIView{
  var isUsed : Bool{
    get{
      return self.superview != nil && self.isHidden == false
    }
  }
}
