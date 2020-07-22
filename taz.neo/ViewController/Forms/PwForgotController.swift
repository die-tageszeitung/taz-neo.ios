//
//
// FILENAME
//
// Created by Ringo Müller-Gromes on 22.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit

class PwForgottController: FormsController {
  lazy var pwForgotView = PwForgotView()
    
    override func viewDidLoad() {
     contentView = pwForgotView
      super.viewDidLoad()
      pwForgotView.sendClosure = { [weak self] (id) in
        guard let id = id else {return}
        if id.isEmpty { return }
        if id.isNumber {
          self?.mutateSubscriptionReset(id)
        }
        else{
          self?.mutatePasswordReset(id)
        }
       print("request pw...\(id)")
      }
      pwForgotView.cancelClosure = { [weak self] in
        self?.dismiss(animated: true, completion:nil)
      }
    }
  
  func mutateSubscriptionReset(_ id: String){
    SharedFeeder.shared.feeder?.subscriptionReset(aboId: id, closure: { (result) in
      switch result {
          case .success:
               let child = SubscriptionResetSuccess()
               child.modalPresentationStyle = .overCurrentContext
               child.modalTransitionStyle = .flipHorizontal
               self.parent?.present(child, animated: true, completion: {
                self.dismiss(animated: false, completion: nil)
               })
        case .failure:
          print("An error occured: \(result.error())")
      }
      
    })
  }
  
  func mutatePasswordReset(_ id: String){
    
  }
}

class SubscriptionResetSuccess: FormsController {
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =  [
         FormularView.header(),
         FormularView.label(title: NSLocalizedString("login_forgot_password_email_sent_header", comment: "mail to reset send")),
         FormularView.button(title: NSLocalizedString("login_forgot_password_email_sent_back", comment: "zurück"),
                              target: self, action: #selector(handleBack)),
         
       ]
    super.viewDidLoad()
  }
  
  @IBAction func handleBack(_ sender: UIButton) {
    let parent = self.presentingViewController as? PwForgottController
    self.dismiss(animated: true, completion: nil)
    parent?.dismiss(animated: false, completion: nil)
  }
}


//Concept Idea deleta if applied
class SubscriptionResetSuccessA: FormsController {
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =  [
         FormularView.header(),
         FormularView.label(title: "dsfgdfsghjklgfdsadghjfdsafdsh"),
         FormularView.labelLikeButton(title: NSLocalizedString("cancel_button", comment: "abbrechen"),
                              target: self, action: #selector(handleCancel)),
         FormularView.outlineButton(title: NSLocalizedString("push another", comment: "sss"),
                              target: self, action: #selector(handleSend)),
       ]
    super.viewDidLoad()
  }
  
 
  @IBAction func handleSend(_ sender: UIButton) {
    let vc = SubscriptionResetSuccess2()
        vc.modalPresentationStyle = .overCurrentContext
     vc.modalTransitionStyle = .flipHorizontal
              self.present(vc, animated: true, completion:{
                self.view.isHidden = true
              })
  }
  
  @IBAction func handleCancel(_ sender: UIButton) {
    self.dismiss(animated: true, completion: nil)
  }
}

class SubscriptionResetSuccess2: FormsController {
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =  [
         FormularView.header(),
         FormularView.label(title: "dsfgdfsghjklgfdsadghjfdsafdsh"),
         FormularView.labelLikeButton(title: NSLocalizedString("cancel_button", comment: "abbrechen"),
                              target: self, action: #selector(handleCancel)),
 
       ]
    super.viewDidLoad()
  }
  
  
  @IBAction func handleCancel(_ sender: UIButton) {
    let parent = self.presentingViewController as? SubscriptionResetSuccess
    self.dismiss(animated: true, completion: nil)
    parent?.dismiss(animated: false, completion: nil)
   }
}
