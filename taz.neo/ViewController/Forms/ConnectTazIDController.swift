//
//
// ConnectTazIDController.swift
//
// Created by Ringo Müller-Gromes on 23.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

// MARK: - ConnectTazIDController
/// Presents Register TazID Form and Functionallity
/// ChildViews/Controller are pushed modaly
class ConnectTazIDController: FormsController {
  
  var aboId:String
  var aboIdPassword:String
  
  init(aboId:String, aboIdPassword:String) {
    self.aboId = aboId
    self.aboIdPassword = aboIdPassword
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  var mailInput
    = FormularView.textField(placeholder: Localized("login_email_hint")
  )
  var passInput
    = FormularView.textField(placeholder: Localized("login_password_hint"),
                             textContentType: .password,
                             isSecureTextEntry: true)
  
  var pass2Input
    = FormularView.textField(placeholder: Localized("login_password_confirmation_hint"),
                             textContentType: .password,
                             isSecureTextEntry: true)
  
  var firstnameInput
    = FormularView.textField(placeholder: Localized("login_first_name_hint"))
  
  var lastnameInput
    = FormularView.textField(placeholder: Localized("login_surname_hint"))
  
  // MARK: viewDidLoad Action
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =   [
      FormularView.header(),
      FormularView.label(title:
        Localized("fragment_login_missing_credentials_header_registration")),
      FormularView.labelLikeButton(title: Localized("fragment_login_missing_credentials_switch_to_login"),
                                   paddingTop: 0,
                                   paddingBottom: 0,
                                   target: self,
                                   action: #selector(handleAlreadyHaveTazID)),
      mailInput,
      passInput,
      pass2Input,
      firstnameInput,
      lastnameInput,
      contentView!.agbAcceptTV,
      FormularView.button(title: Localized("login_button"),
                          target: self,
                          action: #selector(handleSend)),
      FormularView.outlineButton(title: Localized("cancel_button"),
                                 target: self,
                                 action: #selector(handleCancel)),
    ]
    super.viewDidLoad()
  }
  
  // MARK: handleLogin Action
  @IBAction func handleSend(_ sender: UIButton) {
    sender.isEnabled = false
    var errors = false
    
    mailInput.bottomMessage = ""
    passInput.bottomMessage = ""
    pass2Input.bottomMessage = ""
    firstnameInput.bottomMessage = ""
    lastnameInput.bottomMessage = ""
    self.contentView?.agbAcceptTV.error = false
    
    let mail = mailInput.text ?? ""
    
    if mail.isEmpty {
      errors = true
      mailInput.bottomMessage = Localized("login_email_error_empty")
    } else if mail.isValidEmail() == false {
      errors = true
      mailInput.bottomMessage = Localized("login_email_error_no_email")
    }
    
    let pass = passInput.text ?? ""
    
    if pass.isEmpty {
      errors = true
      passInput.bottomMessage = Localized("login_password_error_empty")
    }
    
    if (pass2Input.text ?? "").isEmpty {
      errors = true
      pass2Input.bottomMessage = Localized("login_password_error_empty")
    }
    else if pass != pass2Input.text {
      pass2Input.bottomMessage = Localized("login_password_confirmation_error_match")
    }
    
    let firstname = firstnameInput.text ?? ""
    
    if firstname.isEmpty {
      errors = true
      firstnameInput.bottomMessage = Localized("login_first_name_error_empty")
    }
    
    let lastname = lastnameInput.text ?? ""
    
    if lastname.isEmpty {
      errors = true
      lastnameInput.bottomMessage = Localized("login_surname_error_empty")
    }
    
    var errormessage = Localized("register_validation_issue")
    
    if self.contentView?.agbAcceptTV.checked == false {
      self.contentView?.agbAcceptTV.error = true
      errors = true
      errormessage = Localized("register_validation_issue_agb")
    }
    
    if errors {
      Toast.show(errormessage, .alert)
      sender.isEnabled = true
      return
    }
    
    let dfl = Defaults.singleton
    let pushToken = dfl["pushToken"]
    let installationId = dfl["installationId"] ?? App.installationId
    
    //Start mutationSubscriptionId2tazId
//      spinner.enabler=true
    SharedFeeder.shared.feeder?.subscriptionId2tazId(tazId: mail, password: pass, aboId: self.aboId, aboIdPW: aboIdPassword, surname: lastname, firstName: firstname, installationId: installationId, pushToken: pushToken, closure: { (result) in
      //Re-Enable Button if needed
      sender.isEnabled = true
//      spinner.enabler=false
      switch result {
        case .success(let info):
          //ToDo #900
          switch info.status {
            /// we are waiting for eMail confirmation (using push/poll)
            case .waitForMail:
              let successCtrl
                = ConnectTazID_Result_Controller(message: Localized("fragment_login_confirm_email_header"),
                                                 backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                                 closeHandler: {
                                                  ///ToDO: THIS DID NOT WORK :-(
                                                  let parent = self.presentingViewController as? LoginController
                                                  self.dismiss(animated: true, completion: nil)
                                                  parent?.dismiss(animated: false, completion: nil)
                                                  
                                                  self.presentedViewController?.dismiss(animated: true, completion: nil)
                                                  self.presentingViewController?.dismiss(animated: false, completion: nil)
                                                  self.dismiss(animated: false, completion: nil)
                                                })
              successCtrl.modalPresentationStyle = .overCurrentContext
              successCtrl.modalTransitionStyle = .flipHorizontal
              self.present(successCtrl, animated: true, completion:{
                self.view.isHidden = true
              })
            /// valid authentication
            case .valid:
              let successCtrl
                = ConnectTazID_Result_Controller(message: Localized("fragment_login_registration_successful_header"),
                                                 backButtonTitle: Localized("fragment_login_success_login_back_article"),
                                                 closeHandler: {
                                                  self.presentedViewController?.dismiss(animated: true, completion: nil)
                                                  self.presentingViewController?.dismiss(animated: false, completion: nil)
                                                  self.dismiss(animated: false, completion: nil)
                                                })
              successCtrl.modalPresentationStyle = .overCurrentContext
              successCtrl.modalTransitionStyle = .flipHorizontal
//              if let token = token {
//                self.gqlFeeder.authToken = token
//                closure(nil)
//              }
              self.present(successCtrl, animated: true, completion:{
                self.view.isHidden = true
              })
            /// valid tazId connected to different AboId
            case .alreadyLinked:
              let successCtrl
                = ConnectTazID_Result_Controller(message: Localized("subscriptionId2tazId_alreadyLinked"),
                                                 backButtonTitle: Localized("back_to_login"),
                                                 closeHandler: {
                                                  self.presentedViewController?.dismiss(animated: true, completion: nil)
                                                  self.dismiss(animated: false, completion: nil)
                                                })
              successCtrl.modalPresentationStyle = .overCurrentContext
              successCtrl.modalTransitionStyle = .flipHorizontal
              self.present(successCtrl, animated: true, completion:{
                self.view.isHidden = true
              })
            /// invalid mail address (only syntactic check)
            case .invalidMail:
              self.mailInput.bottomMessage = Localized("login_email_error_no_email")
              Toast.show(Localized("register_validation_issue"))
            /// tazId not verified
            case .tazIdNotValid:
              Toast.show(Localized("toast_login_failed_retry"))//ToDo
            /// AboId not verified
            case .subscriptionIdNotValid:
              fallthrough
            /// AboId valid but connected to different tazId
            case .invalidConnection:
              fallthrough
            /// server will confirm later (using push/poll)
            case .waitForProc:
              fallthrough
            /// user probably didn't confirm mail
            case .noPollEntry:
              fallthrough
            /// account provided by token is expired
            case .expired:
              fallthrough
            /// no surname provided - seems to be necessary fro trial subscriptions
            case .noSurname:
              fallthrough
            /// no firstname provided
            case .noFirstname:
              fallthrough
            case .unknown:  /// decoded from unknown string
              fallthrough
            default:
              Toast.show(Localized("toast_login_failed_retry"))
              print("Succeed with status: \(info.status) message: \(info.message)")
        }
        case .failure:
          Toast.show("ein Fehler...")
      }
    })
  }
  
  // MARK: handleLogin Action
  @IBAction func handleCancel(_ sender: UIButton) {
    self.dismiss(animated: true, completion: nil)
  }
  
  @IBAction func handleAlreadyHaveTazID(_ sender: UIButton) {
    let child = LoginWithTazIDController()
    child.modalPresentationStyle = .overCurrentContext
    child.modalTransitionStyle = .flipHorizontal
    self.present(child, animated: true, completion: nil)
  }
}



// MARK: - ConnectTazID_WaitForMail_Controller
class ConnectTazID_WaitForMail_Controller: FormsController {
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =  [
      FormularView.header(),
      FormularView.label(title: Localized("fragment_login_confirm_email_header"),
                         paddingTop: 30,
                         paddingBottom: 30
      ),
      FormularView.button(title: Localized("fragment_login_success_login_back_article"),
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


// MARK: - ConnectTazID_WaitForMail_Controller
class ConnectTazID_Result_Controller: FormsController {
  
  let message:String
  let backButtonTitle:String
  let closeHandler: (()->())
  
  init(message:String, backButtonTitle:String, closeHandler: @escaping (()->())) {
    self.message = message
    self.backButtonTitle = backButtonTitle
    self.closeHandler = closeHandler
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  
  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views =  [
      FormularView.header(),
      FormularView.label(title: message,
                         paddingTop: 30,
                         paddingBottom: 30
      ),
      FormularView.button(title: backButtonTitle,
                          target: self, action: #selector(handleBack)),
      
    ]
    super.viewDidLoad()
  }
  
  // MARK: handleBack Action
  @IBAction func handleBack(_ sender: UIButton) {
    var vc:UIViewController = self
    while true {
      if let pc = vc.presentingViewController {
        vc=pc
      } else {
        vc.dismiss(animated: true, completion: nil)
      }
    }
    
//    self.dismiss(animated: true, completion: nil)
//    for vc in vcs {
//      vc.dismiss(animated: false, completion: nil)
//    }
    /**
     ToDo Errors: 2020-07-27 18:57:36.779450+0200 taz neo[37958:894911] Warning: Attempt to dismiss from view controller <taz_neo.LoginController: 0x7fad47722ab0> while a presentation or dismiss is in progress!
     2020-07-27 18:57:36.782304+0200 taz neo[37958:894911] [Assert] Trying to dismiss the presentation controller while transitioning already. (<_UIOverCurrentContextPresentationController: 0x7fad475235c0>)
     2020-07-27 18:57:36.788914+0200 taz neo[37958:894911] Null transitionViewForCurrentTransition block, aborting _scheduleTransition:
     
     
     */
  }
}
