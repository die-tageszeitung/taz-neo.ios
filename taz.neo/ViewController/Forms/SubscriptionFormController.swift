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
  
  let type: GqlSubscriptionFormDataType
  
  private var contentView:SubscriptionFormView
  override var ui : SubscriptionFormView { get { return contentView }}
  
  // MARK: viewDidLoad
  override func viewDidLoad() {
    super.viewDidLoad()
    ui.sendButton.touch(self, action: #selector(handleSubmit))
    ui.cancelButton.touch(self, action: #selector(handleBack))
  }
  
  // MARK: handleCancel Action
  @IBAction func handleSubmit1(_ sender: UIButton) {
    ui.blocked = true
    
//    if let errormessage = ui.validate() {
//      Toast.show(errormessage, .alert)
//      ui.blocked = false
//      return
//    }
      
    
    let msg = """
    Error Report Zweckentfremded zum testen der Kontaktformulare
    Kopie geht bereits automatisch an ringo
    ===
        id: \(ui.idInput.text ?? "")
        firstName: \(ui.firstName.text ?? "")
        lastName: \(ui.lastName.text ?? "")
        street: \(ui.street.text ?? "")
        city: \(ui.city.text ?? "")
        postcode: \(ui.postcode.text ?? "")
        country: \(ui.country.text ?? "")
        requestInfoCheckbox: \(ui.requestInfoCheckbox.checked ? "Bitte Infos" : "Keine Infos")
    """
        
    return;
    
    auth.feeder.errorReport(message: msg,
                           lastAction: nil,
                           conditions: nil,
                           deviceData: nil,
                           errorProtocol: nil,
                           eMail: "ringo.mueller@taz.de",
                           screenshotName: nil,
                           screenshot: nil) { (result) in
                            self.ui.blocked = false
                            switch result{
                              case .success(let msg):
                                self.showResultWith(message: "Anfrage übermittelt",
                                                    backButtonTitle: Self.backButtonTitle,
                                                    dismissType: .allReal)
                              case .failure(let err):
                                Toast.show("Fekhler beim senden", .alert)
                            }
    }
  }
  
  // MARK: handleCancel Action
  @IBAction func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    
    if let errormessage = ui.validate() {
      Toast.show(errormessage, .alert)
      ui.blocked = false
      return
    }
    
    auth.feeder.subscriptionFormData(type: ui.type,
                                     mail: ui.idInput.text,
                                     surname: ui.lastName.text,
                                     firstName: ui.firstName.text,
                                     street: ui.street.text,
                                     city: ui.city.text,
                                     postcode: ui.postcode.text,
                                     country: ui.country.text,
                                     message: ui.message.text,
                                     requestCurrentSubscriptionOpportunities: ui.requestInfoCheckbox.checked){ [weak self] (result) in
      self?.ui.blocked = false
      switch result{
        case .success(let msg):
          self?.showResultWith(message: "Anfrage übermittelt",
                              backButtonTitle: Self.backButtonTitle,
                              dismissType: .allReal)
          self?.log("Success: \(msg)")
        case .failure(let err):
          Toast.show("Fehler beim senden", .alert)
          self?.log("Failed: \(err)")
      }
    }
  }
    
  required init(type: GqlSubscriptionFormDataType,
                auth:AuthMediator,
                expireDateMessage:String? = nil,
                customerType: GqlCustomerType? = nil) {
    self.type = type
    self.contentView = SubscriptionFormView(type: type)
    super.init(auth)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
