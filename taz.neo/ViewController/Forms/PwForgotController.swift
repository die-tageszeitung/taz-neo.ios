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
  
  var idInput: UITextField
    = FormularView.textField(placeholder: NSLocalizedString("login_username_hint",
                                                            comment: "E-Mail Input"))
  // MARK: viewDidLoad
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =  [
      FormularView.header(),
      FormularView.label(title: NSLocalizedString("login_forgot_password_header",
                                                  comment: "passwort vergessen header")),
      idInput,
      FormularView.button(title: NSLocalizedString("login_forgot_password_send",
                                                   comment: "login"),
                          target: self, action: #selector(handleSend)),
      FormularView.labelLikeButton(title: NSLocalizedString("cancel_button",
                                                            comment: "abbrechen"),
                                   target: self, action: #selector(handleCancel)),
    ]
    super.viewDidLoad()
  }
  
  // MARK: handleCancel
  @IBAction func handleCancel(_ sender: UIButton) {
    self.dismiss(animated: true, completion:nil)
  }
  
  // MARK: handleSend
  @IBAction func handleSend(_ sender: UIButton) {
    guard let id = idInput.text else { return }
    if id.isEmpty { return }
    if id.isNumber {
      self.mutateSubscriptionReset(id)
    }
    else{
      self.mutatePasswordReset(id)
    }
  }
  
  // MARK: mutateSubscriptionReset
  func mutateSubscriptionReset(_ id: String){
    SharedFeeder.shared.feeder?.subscriptionReset(aboId: id, closure: { (result) in
      switch result {
      case .success(let info):
        switch info.status {
        case .ok:
          let successCtrl = SubscriptionResetSuccessController()
          successCtrl.modalPresentationStyle = .overCurrentContext
          successCtrl.modalTransitionStyle = .flipHorizontal
          self.present(successCtrl, animated: true, completion:{
            self.view.isHidden = true
          })
        case .invalidSubscriptionId:
          Toast.show(Localized("error_invalid_email_or_abo_id"))
        default:
          Toast.show(Localized("error"))
        }
        //ToDo #901        
      case .failure:
        Toast.show(Localized("error"))
        self.log("An error occured: \(String(describing: result.error()))")
      }
    })
  }
  
  // MARK: mutatePasswordReset
  func mutatePasswordReset(_ id: String){
    SharedFeeder.shared.feeder?.passwordReset(email: id, closure: { (result) in
      switch result {
      case .success(let info):
        switch info {
        case .ok:
          let successCtrl = PasswordResetRequestedSuccessController()
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
        Toast.show("ein Fehler...")
        //        print("An error occured: \(String(describing: result.error()))")
      }
    })
  }
}

// MARK: - SubscriptionResetSuccessController
class SubscriptionResetSuccessController: FormsController, MFMailComposeViewControllerDelegate {
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =  [
      FormularView.header(),
      FormularView.label(title: NSLocalizedString("login_forgot_password_email_sent_header",
                                                  comment: "mail to reset send")
      ),
      FormularView.label(title: NSLocalizedString("subscription_reset_found_link",
                                                  comment: "login found link")
      ),
      FormularView.button(title: NSLocalizedString("login_forgot_password_email_sent_back",
                                                   comment: "zurück"),
                          target: self, action: #selector(handleBack)),
      FormularView.label(title: NSLocalizedString("login_subscription_taken_body",
                                                  comment: "contact service")
      ),
      FormularView.labelLikeButton(title: NSLocalizedString("digiabo_email",
                                                            comment: "digitalabo@taz.de"),
                                   target: self, action: #selector(handleMail)),
      FormularView.outlineButton(title: NSLocalizedString("cancel_button",
                                                          comment: "abbrechen"),
                                 target: self, action: #selector(handleBack))
    ]
    super.viewDidLoad()
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
    composeVC.setToRecipients([NSLocalizedString("digiabo_email",
                                                 comment: "digitalabo@taz.de")])
    composeVC.setSubject(NSLocalizedString("digiabo_access_request_subject",
                                           comment: "Mail Subject"))
    composeVC.setMessageBody(NSLocalizedString("digiabo_access_request_message",
                                               comment: "Mail Content"),
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
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =  [
      FormularView.header(),
      FormularView.label(title: NSLocalizedString("login_forgot_password_email_sent_header",
                                                  comment: "mail to reset send"),
                         paddingTop: 30,
                         paddingBottom: 30
      ),
      FormularView.button(title: NSLocalizedString("login_forgot_password_email_sent_back",
                                                   comment: "zurück"),
                          target: self, action: #selector(handleBack)),
      
    ]
    super.viewDidLoad()
  }
  
  // MARK: handleBack Action
  @IBAction func handleBack(_ sender: UIButton) {
    let parent = self.presentingViewController as? PwForgottController
    self.dismiss(animated: true, completion: nil)
    parent?.dismiss(animated: false, completion: nil)
  }
}
