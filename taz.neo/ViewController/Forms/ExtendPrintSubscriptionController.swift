//
//  ExtendPrintSubscriptionController.swift
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
class ExtendPrintSubscriptionController : FormsController {
  
  var onMissingNameRequested:(()->())?
  
  private var contentView = ExtendPrintSubscriptionView()
  override var ui : ExtendPrintSubscriptionView { get { return contentView }}
  
  // MARK: viewDidLoad
  override func viewDidLoad() {
    super.viewDidLoad()
    ui.sendButton.touch(self, action: #selector(handleSubmit))
    ui.cancelButton.touch(self, action: #selector(handleBack))
  }
  
  // MARK: handleCancel Action
  @IBAction func handleSubmit(_ sender: UIButton) {
    ui.blocked = true
    
    if let errormessage = ui.validate() {
      Toast.show(errormessage, .alert)
      ui.blocked = false
      return
    }
    
    let name = ui.nameInput.text ?? ""
    let address = ui.address.text ?? ""
    let message = ui.message.text ?? ""
    let id = ui.idInput.text ?? ""
    
    
    
    let msg = """
    Error Report Zweckentfremded zum testen der Formulare
    Kopie geht bereits automatisch an ringo
    ===
    name: \(name)
    address: \(address)
    message: \(message)
    id: \(id)
    """
    
    
    
    
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
}



public class ExtendPrintSubscriptionView : FormView{
  
  var exchangeResponder = false
  
  var nameInput = TazTextField(placeholder: "Vor- und Nachname",
                                    textContentType: .name,
                                    enablesReturnKeyAutomatically: true,
                                    keyboardType: .default,
                                    autocapitalizationType: .words)
  
  var address:UITextView = {
    let ti = UITextView()
    ti.text = "Ihre Adresse"
    ti.pinHeight(50)
    ti.backgroundColor = .blue
    return ti
  }()
  
  var message:UITextView = {
    let ti = UITextView()
    ti.text = "Ihre Nachricht"
    ti.pinHeight(50)
    ti.addBorder(.red)
    return ti
  }()
  
  var idInput = TazTextField(placeholder: "E-Mail-Adresse oder Abonummer (wenn vorhanden)",
                                    textContentType: .name,
                                    enablesReturnKeyAutomatically: true,
                                    keyboardType: .default,
                                    autocapitalizationType: .words)
  

  var sendButton = Padded.Button(title: "Absenden")
  var cancelButton =  Padded.Button(type:.outline, title: Localized("cancel_button"))
    
  override func createSubviews() -> [UIView] {
    return   [
      Padded.Label(title: "Umwandlung meines Print Abos in ein Digital Abonement").boldContentFont(),
      Padded.Label(title: "Sie sind taz Print AbonementIn und möchten die taz digital am Abend vor erscheinen der Print Ausgabe lesen. Gerne informieren wir Sie über die Möglichkeiten."),
      nameInput,
      address,
      message,
      idInput,
      sendButton,
      cancelButton
    ]
  }
  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    
    nameInput.bottomMessage = ""
    
    if (nameInput.text ?? "").isEmpty {
      errors = true
      nameInput.bottomMessage = "Bitte NAmen eintragen"
    }
    
    if (address.text ?? "").isEmpty || address.text.length < 12 {
      errors = true
      Toast.show("Bitte Feld Adresse ausfüllen!", .alert)
    }
    
    if (message.text ?? "").isEmpty || message.text.length < 8 {
      errors = true
      Toast.show("Bitte Feld Nachricht ausfüllen!", .alert)
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    return nil
  }
}
