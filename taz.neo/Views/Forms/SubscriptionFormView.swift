//
//  SubscriptionFormView.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.07.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public class SubscriptionFormView : FormView{

  // MARK: - All possible fields
  let formType: SubscriptionFormDataType
  
  var expireDate:Date?
  var customerType: GqlCustomerType?
  
  var mailInput = TazTextField(placeholder: "E-Mail-Adresse",
                                    textContentType: .emailAddress,
                                    enablesReturnKeyAutomatically: true,
                                    keyboardType: .emailAddress,
                                    autocapitalizationType: .none)
    
  var firstName = TazTextField(placeholder: "Vorname",
                               textContentType: .givenName,
                               enablesReturnKeyAutomatically: true,
                               keyboardType: .default,
                               autocapitalizationType: .words)
  
  var lastName = TazTextField(placeholder: "Nachname",
                               textContentType: .familyName,
                               enablesReturnKeyAutomatically: true,
                               keyboardType: .default,
                               autocapitalizationType: .words)
  
  var street = TazTextField(placeholder: "Straße, Hausnummer",
                               textContentType: .fullStreetAddress,
                               enablesReturnKeyAutomatically: true,
                               keyboardType: .default,
                               autocapitalizationType: .words)
  
  var city = TazTextField(placeholder: "Ort",
                               textContentType: .addressCity,
                               enablesReturnKeyAutomatically: true,
                               keyboardType: .default,
                               autocapitalizationType: .words)
  
  var postcode = TazTextField(placeholder: "Postleitzahl",
                               textContentType: .postalCode,
                               enablesReturnKeyAutomatically: true,
                               keyboardType: .numberPad,
                               autocapitalizationType: .none)
  
  var aboIdInput = TazTextField(placeholder: "Abo-Nummer (wenn vorhanden)",
                               textContentType: .none,
                               enablesReturnKeyAutomatically: true,
                               keyboardType: .numberPad,
                               autocapitalizationType: .none)
  
  var requestInfoCheckbox: CheckboxWithText = {
    let view = CheckboxWithText()
    view.textView.isEditable = false
    view.textView.isScrollEnabled = false
    view.textView.text = "Bitte informieren Sie mich zu aktuellen Abo-Möglichkeiten"
    view.textView.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
    view.textView.textColor = Const.SetColor.HText.color
    return view
  }()
  
  var message = TazTextView(topLabelText: "Ihre Nachricht",
                            placeholder: "Liegt Ihnen sonst was am Herzen? Hier ist Platz dafür.")

  var sendButton = Padded.Button(title: "Absenden")
  
  var title: UILabel? {
    
    var abo = ""
    
    switch customerType {
      case .sample: abo = "Probeabo"
      case .combo: abo = "Kombiabo"
      case .digital: abo = "Abonnement"
      case .deliveryBreaker: abo = "Print Ersatzabo"
      default: abo = "Abo"
    }
    
    var text: String? = nil
    
    switch formType {
      case .print2Digi:
        text = "Ja! Ich möchte nur noch digital lesen."
      case .printPlusDigi:
        text = "Ja! Schalten Sie die App zu meinem Abo frei!"
      default:
        if let d = expireDate {
          text = "Ihr \(abo) ist am \(d.gDate()) abgelaufen."
        }
        else {
          text = "Ihr \(abo) ist abgelaufen."
        }
    }
    guard let text = text else { return nil }
    return Padded.Label(title: text).titleFont(size: 21)
  }
  
  var subTitle: UILabel? {
    var abo = ""
    
    switch customerType {
      case .sample: abo = "kostenlosen Probeabos"
      case .combo: abo = "Kombiabos"
      case .digital: abo = "Abonnements"
      case .deliveryBreaker: abo = "Print Ersatzabos"
      default: abo = "Abos"
    }
    
    var text: String? = nil
    
    switch formType {
      case .print2Digi://Achtung anderer Text erst in Step 2 mit Taz-ID!!
        text = "Super! Auf in die Zukunft. Herzlichen Glückwunsch zu diesem Schritt. Um Sie einordnen zu können, brauchen wir ein paar Daten von Ihnen.\nWir kontaktieren Sie in den nächsten Tagen per Mail."
      case .printPlusDigi:
        text = "Das machen wir gerne! Geben Sie Ihre bei uns hinterlegten Kundendaten ein, so dass wir Sie zuordnen können.\nWir werden Sie dann kontaktieren."
      default:
        text = """
        Wir haben Ihnen zum Ablauf Ihres \(abo) Informationen zu unseren Abonnements an Ihre E-Mail-Adresse zugesandt.
        Falls Sie diese E-Mail nicht finden können, oder weitere Fragen haben, können Sie jetzt einfach unserem Service-Team eine Nachricht zusenden.
        
        Für weitere Fragen erreichen Sie unser Service-Team auch unter: fragen@taz.de
        """
    }
    
    guard let text = text else { return nil }
    return Padded.Label(title: text).contentFont()
  }
  
  override func createSubviews() -> [UIView] {
    var views:[UIView] = []
    if let v = title { views.append(v) }
    if let v = subTitle { views.append(v) }
  
    if !self.formType.expiredForm {
      views.append(contentsOf: [mailInput, firstName, lastName, street, city, postcode, aboIdInput])
    }
    views.append(message)
    views.append( UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10)))//spacer
    
    if self.formType.expiredForm {
      views.append(requestInfoCheckbox)
    }
    
    views.append(sendButton)
    return views
  }
  
  func handle(formError: SubscriptionFormDataError){
    switch formError {
      case .noMail(let msg):
        mailInput.bottomMessage = msg
      case .invalidMail(let msg): 
        mailInput.bottomMessage = msg
      case .noSurname(let msg):
        lastName.bottomMessage = msg
      case .noFirstName(let msg):
        firstName.bottomMessage = msg
      case .noCity(let msg):
        city.bottomMessage = msg
      case .employees(let msg):
        mailInput.bottomMessage = msg
      case .unexpectedResponse(_):
        fallthrough
      case .unknown(_):
        break
    }
  }
  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    //switch or zubuchen
    if !formType.expiredForm {
      if "\(postcode.text ?? "")\(city.text ?? "")\(street.text ?? "")".length < 12 {
        postcode.bottomMessage = "Bitte Adresse überprüfen"
        city.bottomMessage = "Bitte Adresse überprüfen"
        street.bottomMessage = "Bitte Adresse überprüfen"
        errors = true
      }
      else {
        postcode.bottomMessage = ""
        city.bottomMessage = ""
        street.bottomMessage = ""
      }
      
      if mailInput.text?.isEmpty == true {
        mailInput.bottomMessage = Localized("login_email_error_empty")
        errors = true
      }
      else if mailInput.text?.isValidEmail() == false {
        mailInput.bottomMessage = Localized("login_email_error_no_email")
        errors = true
      }
      else {
        mailInput.bottomMessage = ""
      }
      
      if firstName.text?.isEmpty == true {
        firstName.bottomMessage = Localized("forms_error_empty")
        errors = true
      }
      else {
        firstName.bottomMessage = ""
      }
      
      if lastName.text?.isEmpty == true {
        lastName.bottomMessage = Localized("forms_error_empty")
        errors = true
      }
      else {
        lastName.bottomMessage = ""
      }
    }
    
    if (message.text ?? "").isEmpty {
      errors = true
      message.errorMessage = "Bitte ausfüllen!"
    }
    else if (message.text?.length ?? 0) < 8 {
      errors = true
      message.errorMessage = "Ihre Nachricht ist zu kurz!"
    }
    else {
      message.errorMessage = nil
    }
    
    if errors {
      return Localized("register_validation_issue")
    }
    return nil
  }
  
  init(formType: SubscriptionFormDataType,
       expireDate:Date? = nil,
       customerType: GqlCustomerType? = nil) {
    self.formType = formType
    self.expireDate = expireDate
    self.customerType = customerType
    super.init(frame: .zero)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
