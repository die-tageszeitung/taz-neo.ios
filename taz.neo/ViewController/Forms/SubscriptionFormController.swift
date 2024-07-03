//
//  SubscriptionFormController.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.07.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
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
class SubscriptionFormController : FormsController {
  var onMissingNameRequested:(()->())?
  
  private var contentView:SubscriptionFormView
  override var ui : SubscriptionFormView { get { return contentView }}
  
  // MARK: viewDidLoad
  override func viewDidLoad() {
    super.viewDidLoad()
    ui.sendButton.touch(self, action: #selector(handleSubmit))
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    switch contentView.formType {
      case .expiredDigiPrint, .expiredDigiSubscription:
        Usage.track(Usage.event.dialog.SubscriptionElapsed)
      default: break;
    }
  }
  
  // MARK: handleSubmit Action
  @IBAction func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    
    if let errormessage = ui.validate() {
      Alert.message(message: errormessage)
      ui.blocked = false
      ui.scrollView.scrollRectToVisible(CGRect(x: 1, y: 1, width: 1, height: 1), animated: true)
      Usage.track(Usage.event.subscription.InquiryFormValidationError)
      return
    }
    
    var subscriptionId: Int32?
    
    if let sidText = ui.aboIdInput.text,
       let sid = Int32(sidText) {
      subscriptionId = sid
    }
    
    auth.feeder.subscriptionFormData(type: ui.formType,
                                     mail: ui.mailInput.text,
                                     surname: ui.lastName.text,
                                     firstName: ui.firstName.text,
                                     street: ui.street.text,
                                     city: ui.city.text,
                                     postcode: ui.postcode.text,
                                     subscriptionId: subscriptionId,
                                     message: ui.message.text,
                                     requestCurrentSubscriptionOpportunities: ui.requestInfoCheckbox.checked){ [weak self] (result) in
      self?.ui.blocked = false
      switch result{
        case .success(let msg):
          self?.showResultWith(message: "Ihre Anfrage wurde an unser Serviceteam übermittelt. Für weitere Fragen erreichen Sie unser Service-Team unter: fragen@taz.de",
                              backButtonTitle: "Schließen",
                              dismissType: .allReal)
          Usage.track(Usage.event.subscription.InquirySubmitted)
          self?.log("Success: \(msg)")
        case .failure(let err):
          if (err as NSError).domain == NSURLErrorDomain {
            Usage.track(Usage.event.subscription.InquiryNetworkError, name: err.description)
          }
          else {
            Usage.track(Usage.event.subscription.InquiryServerError, name: err.description)
          }
          var message = ""
          if let fe = err as? SubscriptionFormDataError, let msg = fe.associatedValue {
            self?.ui.handle(formError: fe)
            message = msg
          }
          else if err is URLError {
            ///(err as? URLError)?.description is probably: "Es besteht anscheinend keine Verbindung zum Internet."
            message = Localized("communication_breakdown")
          }
          else{
            message = Localized("unknown_communication_error")
          }
          Alert.message(title: "Fehler beim senden", message: message)
          self?.log("Failed: \(err)")
      }
    }
  }
  
  func setupDismissOnAccountReactivation(){
    Notification.receive(Const.NotificationNames.removeLoginRefreshDataOverlay) {_ in
      onMainAfter(1.7) {[weak self] in self?.dismiss() }
    }
  }
    
  required init(formType: SubscriptionFormDataType,
                auth:AuthMediator,
                expireDate:Date? = nil,
                customerType: GqlCustomerType? = nil) {
    self.contentView
    = SubscriptionFormView(formType: formType,
                           expireDate: expireDate,
                           customerType: customerType)
    super.init(auth)
    switch formType {
      case .print2Digi, .printPlusDigi: break; //do Nothing
      case .expiredDigiSubscription, .trialSubscription, .expiredDigiPrint:
        setupDismissOnAccountReactivation()
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}


/// Subscription Form Data Type
enum SubscriptionFormDataType: String {
  case expiredDigiPrint = "expiredDigiPrint" //request info for expired subscription with print and digital
  case trialSubscription = "trialSubscription" //request info for current trial digital subscription
  case expiredDigiSubscription = "expiredDigiSubscription" //request info for expired digital subscription
  case print2Digi = "print2Digi" //request info for switch
  case printPlusDigi = "printPlusDigi" //request info to extend
} // SubscriptionFormDataType

extension SubscriptionFormDataType {
  //Prevent API to App Mapping due not all API Cases are implemented in UI
  //thats why unknown case also not exists here, to make switches exhaustive
  func toString() -> String { rawValue }
}

extension SubscriptionFormDataType {
  var expiredForm : Bool {
    switch self {
      case .trialSubscription, .expiredDigiSubscription, .expiredDigiPrint:
        return true
      default:
        return false
    }
  }
}

/// GqlCustomerType to SubscriptionFormDataType
extension GqlCustomerType {
  var formDataType : SubscriptionFormDataType {
    switch self {
      case .sample:
        return .trialSubscription
      case .digital:
        return .expiredDigiSubscription
      case .combo:
        return .expiredDigiPrint
      default://deliveryBreaker,unknown
        return .expiredDigiSubscription
    }
  }
}
