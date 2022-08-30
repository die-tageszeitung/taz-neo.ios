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
class PwForgottController: FormsController {
  
  private var contentView = PwForgottView()
  override var ui : PwForgottView { get { return contentView }}
  var childDismissType:dismissType?
  /**
   #todo move that to the place where its needed
   idInput.autocapitalizationType = .none
   idInput.textContentType = .emailAddress
   idInput.keyboardType = .emailAddress
   */
  
  // MARK: init
  convenience init(id:String?, auth: AuthMediator) {
    self.init(auth)
    ui.idInput.text = id
    ui.idInput.autocapitalizationType = .none
    ui.submitButton.touch(self, action: #selector(handleSubmit))
    ui.cancelButton.touch(self, action: #selector(handleBack))
  }
  
  // MARK: handleSend
  @IBAction func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    guard let id = ui.idInput.text, !id.isEmpty  else {
      ui.idInput.bottomMessage = Localized("login_username_error_empty")
      Toast.show(Localized("register_validation_issue"))
      ui.blocked = false
      return
    }
    
    if id.isNumber {
      if let i = Int32(id){
        self.mutateSubscriptionReset("\(i)")
      } else {
        ui.idInput.bottomMessage = Localized("abo_id_validation_error_digit")
        Toast.show(Localized("register_validation_issue"), .alert)
        ui.blocked = false
        return
      }
    }
    else if !id.isValidEmail(){
      ui.idInput.bottomMessage = Localized("error_invalid_email_or_abo_id")
      Toast.show(Localized("register_validation_issue"))
      ui.blocked = false
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
              self.updateParentIfApplyable(id)
              let ctrl = SubscriptionResetSuccessController()
              if let cdt = self.childDismissType { ctrl.dismissType = cdt}
              self.modalFlip(ctrl)
        }
        //ToDo #901
        case .failure:
          Toast.show(Localized("error"))
          self.log("An error occured in mutateSubscriptionReset: \(String(describing: result.error()))")
      }
      self.ui.blocked = false
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
              self.updateParentIfApplyable(id)
              let ctrl = PasswordResetRequestedSuccessController()
              if let cdt = self.childDismissType { ctrl.dismissType = cdt}
              self.modalFlip(ctrl)
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
      self.ui.blocked = false
    })
  }
  
  func updateParentIfApplyable(_ idOrMail:String){
    guard let parent = self.presentingViewController as? FormsController else { return;}
    if let loginView = parent.ui as? LoginView {
      loginView.idInput.text = idOrMail
    }
    else if let connectView = parent.ui as? ConnectTazIdView {
      connectView.mailInput.text = idOrMail
    }
    else if let trialSView = parent.ui as? TrialSubscriptionView {
      trialSView.mailInput.text = idOrMail
    }
  }
}

// MARK: - PasswordResetRequestedSuccessController
class PasswordResetRequestedSuccessController: FormsResultController {
  init(){
    super.init(nibName: nil, bundle: nil)
    self.dismissType = .two
    ui.views =  [
      Padded.Label(title: Localized("login_forgot_password_email_sent_header"),
              paddingTop: 30,
              paddingBottom: 30
      ),
      Padded.Button(title: Localized("login_forgot_password_email_sent_back"),
               target: self, action: #selector(handleBack)),
      
    ]
  }
  
  required init?(coder: NSCoder) { super.init(coder: coder)}
  
  // MARK: handleBack Action
  @IBAction override func handleBack(_ sender: UIButton?) {
    if let pwForgottCtrl = self.presentingViewController as? PwForgottController,
      let loginCtrl = self.presentingViewController?.presentingViewController as? LoginController{
      loginCtrl.ui.idInput.text = pwForgottCtrl.ui.idInput.text
    }
    super.handleBack(sender)
  }
}

// MARK: - SubscriptionResetSuccessController
class SubscriptionResetSuccessController: FormsResultController, MFMailComposeViewControllerDelegate {
  
  init(){
    super.init(nibName: nil, bundle: nil)
    self.dismissType = .two
    ui.views =   [
      Padded.Label(title: Localized("login_forgot_password_email_sent_header")
      ),
      Padded.Label(title: Localized("subscription_reset_found_link")
      ),
      Padded.Button(title: Localized("login_forgot_password_email_sent_back"),
               target: self, action: #selector(handleBack)),
      Padded.Label(title: Localized("login_subscription_taken_body")
      ),
      Padded.Button(type: .label, title: Localized("digiabo_email"),
               target: self, action: #selector(handleMail)),
      Padded.Button(type: .outline ,title: Localized("cancel_button"),
               target: self, action: #selector(handleBack))
    ]
  }
  
  required init?(coder: NSCoder) { super.init(coder: coder)}
  
  // MARK: handleBack Action
  @IBAction override func handleBack(_ sender: UIButton?) {
    if let pwForgottCtrl = self.presentingViewController as? PwForgottController,
      let loginCtrl = self.presentingViewController?.presentingViewController as? LoginController{
      loginCtrl.ui.idInput.text = pwForgottCtrl.ui.idInput.text
    }
    super.handleBack(sender)
  }
  
  // MARK: handleMail Action
  @IBAction func handleMail(_ sender: UIButton) {
    if MFMailComposeViewController.canSendMail() == false {
      if sender.isEnabled == false { return }
      sender.isEnabled = false
      Alert.message(title: Localized("no_mail_title"), message: Localized("no_mail_text"), closure: {
        sender.isEnabled = true
      })
      return
    }
    
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
