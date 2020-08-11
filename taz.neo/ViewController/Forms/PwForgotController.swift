//
//
// PwForgottController.swift
//
// Created by Ringo Müller-Gromes on 22.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import MessageUI
import NorthLib

// MARK: - PwForgottController
/// Presents PwForgott Form and Functionallity for request Subscription Data or reset Password for tazID Accounts
/// ChildViews/Controller are pushed modaly
class PwForgottController: FormsController {
  
  override public var uiBlocked : Bool {
    didSet{
      super.uiBlocked = uiBlocked
      submitButton.isEnabled = !uiBlocked
    }
  }
  
  let idInput
    = TazTextField(placeholder: Localized("login_username_hint"))
  
  lazy var submitButton:UIButton = {
    return UIButton(title: Localized("login_forgot_password_send"),
             target: self,
             action: #selector(handleSend))
  }()
  
  override func getContentViews() -> [UIView] {
    return  [
      TazHeader(),
      UILabel(title: Localized("login_forgot_password_header")),
      idInput,
      submitButton,
      defaultCancelButton
    ]
  }
  // MARK: viewDidLoad
  override func viewDidLoad() {
    super.viewDidLoad()
    idInput.autocapitalizationType = .none
    idInput.textContentType = .emailAddress
    idInput.keyboardType = .emailAddress
  }
    
  // MARK: handleSend
  @IBAction func handleSend(_ sender: UIButton) {
    uiBlocked = true
    guard let id = idInput.text, !id.isEmpty  else {
      idInput.bottomMessage = Localized("login_username_error_empty")
      Toast.show(Localized("register_validation_issue"))
      uiBlocked = false
      return
    }
    
    if id.isNumber {
      self.mutateSubscriptionReset(id)
    }
    else if !id.isValidEmail(){
      idInput.bottomMessage = Localized("error_invalid_email_or_abo_id")
      Toast.show(Localized("register_validation_issue"))
      uiBlocked = false
    }
    else{
      self.mutatePasswordReset(id)
    }
  }
  
  // MARK: mutateSubscriptionReset
  func mutateSubscriptionReset(_ id: String){
    auth.feeder.subscriptionReset(aboId: id, closure: { [weak self]  (result) in
      guard let self = self else { return }
      switch result {
        case .success(let info):
          switch info.status {
            case .ok: fallthrough
            case .invalidSubscriptionId: fallthrough
            case .alreadyConnected: fallthrough
            default:
              let successCtrl = SubscriptionResetSuccessController(self.auth)
              successCtrl.modalPresentationStyle = .overCurrentContext
              successCtrl.modalTransitionStyle = .flipHorizontal
              self.present(successCtrl, animated: true, completion:{
                self.view.isHidden = true
              })
        }
        //ToDo #901
        case .failure:
          Toast.show(Localized("error"))
          self.log("An error occured in mutateSubscriptionReset: \(String(describing: result.error()))")
      }
      self.uiBlocked = false
    })
  }
  
  // MARK: mutatePasswordReset
  func mutatePasswordReset(_ id: String){
    auth.feeder.passwordReset(email: id, closure: { [weak self]  (result) in
      guard let self = self else { return }
      switch result {
        case .success(let info):
          switch info {
            case .ok:
              let successCtrl = PasswordResetRequestedSuccessController(self.auth)
              successCtrl.modalPresentationStyle = .overCurrentContext
              successCtrl.modalTransitionStyle = .flipHorizontal
              self.present(successCtrl, animated: true, completion:{
                self.view.isHidden = true
              })
            case .invalidMail:
              Toast.show(Localized("error_invalid_email_or_abo_id"))
            case .mailError:
              fallthrough
            default:
              Toast.show(Localized("error"))
        }
        case .failure:
          Toast.show(Localized("error"))
          self.log("An error occured in mutatePasswordReset: \(String(describing: result.error()))")
      }
      self.uiBlocked = false
    })
  }
}

// MARK: - SubscriptionResetSuccessController
class SubscriptionResetSuccessController: FormsController, MFMailComposeViewControllerDelegate {
  override func getContentViews() -> [UIView] {
    return   [
      TazHeader(),
      UILabel(title: Localized("login_forgot_password_email_sent_header")
      ),
      UILabel(title: Localized("subscription_reset_found_link")
      ),
      UIButton(title: Localized("login_forgot_password_email_sent_back"),
               target: self, action: #selector(handleBack)),
      UILabel(title: Localized("login_subscription_taken_body")
      ),
      UIButton(type: .label, title: Localized("digiabo_email"),
               target: self, action: #selector(handleMail)),
      UIButton(type: .outline ,title: Localized("cancel_button"),
               target: self, action: #selector(handleBack))
    ]
  }
  
  // MARK: handleBack Action
  @IBAction func handleBack(_ sender: UIButton) {
    let parent = self.presentingViewController as? PwForgottController
    self.dismiss(animated: true, completion: nil)
    parent?.dismiss(animated: false, completion: nil)
  }
  
  // MARK: handleMail Action
  @IBAction func handleMail(_ sender: UIButton) {
    if MFMailComposeViewController.canSendMail() == false { return }
    
    let composeVC = MFMailComposeViewController()
    composeVC.mailComposeDelegate = self
    
    // Configure the fields of the interface.
    composeVC.setToRecipients([Localized("digiabo_email")])
    composeVC.setSubject(Localized("digiabo_access_request_subject"))
    composeVC.setMessageBody(Localized("digiabo_access_request_message"),
                             isHTML: false)
    // Present the view controller modally.
    self.present(composeVC, animated: true, completion: nil)
  }
  
  // MARK: Mail Dismiss
  func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true)
  }
}

// MARK: - PasswordResetRequestedSuccessController
class PasswordResetRequestedSuccessController: FormsController {
  override func getContentViews() -> [UIView] {
    return  [
      TazHeader(),
      UILabel(title: Localized("login_forgot_password_email_sent_header"),
              paddingTop: 30,
              paddingBottom: 30
      ),
      UIButton(title: Localized("login_forgot_password_email_sent_back"),
               target: self, action: #selector(handleBack)),
      
    ]
  }
  
  // MARK: handleBack Action
  @IBAction func handleBack(_ sender: UIButton) {
    let parent = self.presentingViewController as? PwForgottController
    self.dismiss(animated: true, completion: nil)
    parent?.dismiss(animated: false, completion: nil)
  }
}
