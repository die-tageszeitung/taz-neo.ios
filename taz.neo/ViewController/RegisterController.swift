//
//
// RegisterController.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//

import UIKit
import NorthLib

fileprivate class SharedFeeder {
    // MARK: - Properties
    var feeder : GqlFeeder?
    static let shared = SharedFeeder()
    // Initialization

    private init() {
      self.setupFeeder { [weak self] _ in
        guard let self = self else { return }
        print("Feeder ready.\(String(describing: self.feeder?.toString()))")
      }
    }
  
  // MARK: setupFeeder
  func setupFeeder(closure: @escaping (Result<Feeder,Error>)->()) {
    self.feeder = GqlFeeder(title: "taz", url: "https://dl.taz.de/appGraphQl") { [weak self] (res) in
      guard let self = self else { return }
      guard res.value() != nil else { return }
      //Notification.send("userLogin")
      if let feeder = self.feeder {
        print("success")
        closure(.success(feeder))
      }
      else {
        print("fail")
        closure(.failure(NSError(domain: "taz.test", code: 123, userInfo: nil)))
      }
    }
  }

}

class FormsController: UIViewController {
  var contentView : FormularView?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    _ = SharedFeeder.shared //setup once
    guard let content = contentView else {
      return
    }
    
    let wConstraint = content.container.pinWidth(to: self.view.width)
    wConstraint.constant = UIScreen.main.bounds.width
    wConstraint.priority = .required
    self.view.addSubview(content)
    pin(content, to: self.view)
  }
}

/// A view controller to show introductory HTML-files
class LoginController: FormsController {
  lazy var loginView = LoginView()
  
  override func viewDidLoad() {
    contentView = loginView
    super.viewDidLoad()
    loginView.loginClosure = { [weak self] (id, password) in
      self?.handleLogin(id: id, password: password)
    }
    loginView.pwForgotClosure = { [weak self] id in
      self?.handlePwForgot(id: id)
    }
  }
  
  func handleLogin(id: String?, password:String?) {
    print("handle login with: \(id), pass: \(password)")
  }

  func handlePwForgot(id: String?) {
    let child = SubscriptionResetSuccess()
//    child.pwForgotView.idInput.text = id
    child.modalPresentationStyle = .overCurrentContext
    child.modalTransitionStyle = .flipHorizontal
    self.present(child, animated: true, completion: nil)
  }
}


class SubscriptionResetSuccess: FormsController {
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

extension String{
  var isNumber : Bool {
    get {
      return CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: self))
    }
  }
}

