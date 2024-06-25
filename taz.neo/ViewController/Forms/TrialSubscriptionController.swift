//
//
// TrialSubscriptionController.swift
//
// Created by Ringo Müller-Gromes on 29.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

// MARK: - ConnectTazIDController
/// Presents Register TazID Form and Functionallity
/// ChildViews/Controller are pushed modaly

/**
 **TBD** This Controller offers the option to create a Trial Subscription
 it has 3 characteristics for users which have no Abo-ID
 1. User has no Taz ID => TrialSubscriptionController with E-mail, new Password, Firstname, Lastname
 2. User with taz-ID
 a) with first/Lastname => This form will not be used, its just for the "Service"
 b) without first and/or Lastname
 
 */
class TrialSubscriptionController : FormsController {
  
  var onMissingNameRequested:(()->())?
  
  private var contentView = TrialSubscriptionView()
  override var ui : TrialSubscriptionView { get { return contentView }}
  
  // MARK: viewDidLoad
  override func viewDidLoad() {
    super.viewDidLoad()
    ui.registerButton.touch(self, action: #selector(handleSubmit))
    ui.agbAcceptTV.textView.delegate = self ///FormsController cares
  }
  
  // MARK: handleCancel Action
  @IBAction func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    
    if let errormessage = ui.validate() {
      Alert.message(message: errormessage)
      ui.blocked = false
      Usage.track(Usage.event.subscription.InquiryFormValidationError)
      return
    }
    
    let mail = ui.mailInput.text ?? ""
    let pass = ui.passInput.text ?? ""
    let lastName = ui.lastnameInput.text ?? ""
    let firstName = ui.firstnameInput.text ?? ""
    
    createTrialSubscription(tazId: mail, tazIdPassword: pass, lastName: lastName, firstName: firstName)
  }
  
  func createTrialSubscription(tazId: String, tazIdPassword: String, lastName: String? = nil, firstName: String? = nil){
    let dfl = Defaults.singleton
    let pushToken = dfl["pushToken"]
    let installationId = dfl["installationId"] ?? App.installationId
    
    //Start mutationSubscriptionId2tazId
    auth.feeder.trialSubscription(tazId: tazId, password: tazIdPassword, surname: lastName, firstName: firstName, installationId: installationId, pushToken: pushToken, closure: { (result) in
      switch result {
        case .success(let info):
          switch info.status {
            case .waitForMail:
              /// we are waiting for eMail confirmation (using push/poll)
              self.showResultWith(message: Localized(keyWithFormat: "fragment_login_confirm_email_header", tazId),
                                  backButtonTitle: Self.backButtonTitle,
                                  dismissType: .allReal)
              self.auth.pollSubscription(tmpId: tazId,
                                         tmpPassword: tazIdPassword,
                                         requestSoon: false,
                                         resultSuccessText: Localized("trialsubscription_successful_header"))
            case .valid:
              if let token = info.token {
                DefaultAuthenticator.storeUserData(id: tazId,
                                      password: tazIdPassword,
                                      token: token)
                (self.auth as? DefaultAuthenticator)?.notifySuccess()
                self.ui.blocked = false
                return;
              }
              /// valid authentication
              self.showResultWith(message: Localized("trialsubscription_successful_header"),
                                  backButtonTitle: Self.backButtonTitle,
                                  dismissType: .allReal)
              self.auth.pollSubscription(tmpId: tazId,
                                         tmpPassword: tazIdPassword,
                                         requestSoon: false,
                                         resultSuccessText: Localized("trialsubscription_successful_header"))
            case .alreadyLinked:
              /// valid tazId connected to different AboId
              if let loginCtrl = self.presentingViewController as? LoginController {
                loginCtrl.ui.idInput.text = self.ui.mailInput.text
                loginCtrl.ui.passInput.text = self.ui.passInput.text
              }
              self.showResultWith(message: Localized("subscriptionId2tazId_alreadyLinked"),
                                  backButtonTitle: Localized("back_to_login"),
                                  dismissType: .leftFirst)
            case .invalidMail:
              /// invalid mail address (only syntactic check)
              self.ui.mailInput.bottomMessage = Localized("login_email_error_no_email")
              Alert.message(message: Localized("register_validation_issue"))
            case .waitForProc:
              self.showResultWith(message: Localized("wait_for_proc_result_Text"),
                                              backButtonTitle: Self.backButtonTitle,
                                              dismissType: .allReal)
              self.auth.pollSubscription(tmpId: tazId,
                                         tmpPassword: tazIdPassword,
                                         requestSoon: true,
                                         resultSuccessText: Localized("trialsubscription_successful_header"))
            case .invalidFirstname: //What if No Form and this Issue occours? @Test with: Web Change Name prepared the +12 Account
              self.ui.firstnameInput.bottomMessage = Localized("invalid_chars")
              Alert.message(message: Localized("register_validation_issue"))
            case .invalidSurname:
              self.ui.lastnameInput.bottomMessage = Localized("invalid_chars")
              Alert.message(message: Localized("register_validation_issue"))
            case .invalidAccountholder:
              self.ui.firstnameInput.bottomMessage = Localized("invalid_chars")
              self.ui.lastnameInput.bottomMessage = Localized("invalid_chars")
              Alert.message(message: Localized("register_validation_issue"))
            case .nameTooLong:
               self.ui.lastnameInput.bottomMessage = Localized("too_many_chars")
               self.ui.firstnameInput.bottomMessage = Localized("too_many_chars")
               Alert.message(title: Localized("info"), message: Localized("name_too_long_issue"))
            case .noFirstname, .noSurname:/// no surname provided - seems to be necessary fro trial subscriptions
              if self.onMissingNameRequested == nil { fallthrough }
              self.onMissingNameRequested?()
            case .subscriptionIdNotValid:/// from different context should not arrear here
              fallthrough
            case .invalidConnection:///should not arrear here
              /// AboId valid but connected to different tazId
              fallthrough
            case .noPollEntry:///should not arrear here
              /// user probably didn't confirm mail
              fallthrough
            case .expired:
              /// account provided by token is expired
              fallthrough
            case .unknown:
              /// decoded from unknown string
              fallthrough
            default:
              Alert.message(message: Localized("toast_login_failed_retry"))
              self.log("Succeed with status: \(info.status) message: \(info.message ?? "-")")
        }
        case .failure:
          Alert.message(title: "Fehler", message: Localized("toast_login_failed_retry"))
      }
      self.ui.blocked = false
    })
  }
}



/// This is a verry special version of the TrialSubscriptionController
/// it requests only firstname and lastname and
/// appears if a user tries to login with a taz-Id without connected Abo-Id and wants a trialSubscription
class TrialSubscriptionRequestNameCtrl : TrialSubscriptionController{
  
  var tazId:String
  var tazIdPassword:String
  
  init(tazId: String, tazIdPassword: String, auth:AuthMediator) {
    self.tazId = tazId
    self.tazIdPassword = tazIdPassword
    super.init(auth)
    
    ui.registerButton.setTitle(Localized("send_button"), for: .normal)
    // Dialog mit Probeabo
    ui.views = [
      Padded.Label(title: Localized("fragment_login_missing__names_header")),
      ui.firstnameInput,
      ui.lastnameInput,
      ui.agbAcceptTV,
      ui.registerButton,
      ui.registerTipsButton
      
    ]
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: handleLogin Action
  @IBAction override func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    
    if let errormessage = ui.validate() {
      Alert.message(message: errormessage)
      ui.blocked = false
      return
    }
    
    let inputFirstname = ui.firstnameInput.text ?? ""
    let inputLastname = ui.lastnameInput.text ?? ""
    
    self.createTrialSubscription(tazId: self.tazId, tazIdPassword: self.tazIdPassword, lastName: inputLastname, firstName: inputFirstname)
  }
}
