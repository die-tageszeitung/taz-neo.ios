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
  let type: GqlSubscriptionFormDataType
  
  var expireDate:Date?
  var customerType: GqlCustomerType?
  
  var idInput = TazTextField(placeholder: "E-Mail-Adresse oder Abonummer (wenn vorhanden)",
                                    textContentType: .name,
                                    enablesReturnKeyAutomatically: true,
                                    keyboardType: .default,
                                    autocapitalizationType: .words)
    
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
  
  var country = TazTextField(placeholder: "Land",
                               textContentType: .countryName,
                               enablesReturnKeyAutomatically: true,
                               keyboardType: .default,
                               autocapitalizationType: .words)
  
  var requestInfoCheckbox: CheckboxWithText = {
    let view = CheckboxWithText()
    view.textView.isEditable = false
    view.textView.text = "Bitte informieren Sie mich zu aktuellen Abo Möglichkeiten"
    view.textView.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
    view.textView.textColor = Const.SetColor.HText.color
    return view
  }()
  
  var messageLabel = Padded.Label(title: "Ihre Nachricht:").contentFont(size: Const.Size.SmallerFontSize).align(.left)

  var message:UITextView = {
    let ti = UITextView()
    ti.pinHeight(50)
    ti.addBorder(.lightGray, 0.5)
    ti.layer.cornerRadius = 8.0
    return ti
  }()

  var sendButton = Padded.Button(title: "Absenden")
  var cancelButton =  Padded.Button(type:.outline, title: Localized("cancel_button"))
  
  var title: UILabel? {
    
    var abo = ""
    
    switch customerType {
      case .sample: abo = "Probeabo"
      case .combo: abo = "Kombiabo"
      case .digital: abo = "Abo"
      case .deliveryBreaker: abo = "Print Ersatzabo"
      default: abo = "Abo"
    }
    
    var text: String? = nil
    switch type {
      case .expiredDigiPrint, .expiredDigilSubscription:
        if let d = expireDate {
          text = "Ihr \(abo) ist am \(d.gDate()) abgelaufen."
        }
        else {
          text = "Ihr \(abo) ist abgelaufen."
        }
      case .print2Digi:
        text = "Ja!Ich möchte nur noch digital lesen."
      case .printPlusDigi:
        text = "Ja! Schalten Sie die App zu meinem Abo frei!"
      default:
        break
    }
    guard let text = text else { return nil }
    return Padded.Label(title: text).titleFont(size: 18)
  }
  
  var subTitle: UILabel? {
    var abo = ""
    
    switch customerType {
      case .sample: abo = "kostenlosen Probeabos"
      case .combo: abo = "Kombiabos"
      case .digital: abo = "Abos"
      case .deliveryBreaker: abo = "Print Ersatzabos"
      default: abo = "Abos"
    }
    
    
    var text: String? = nil
    switch type {
      case .expiredDigiPrint, .expiredDigilSubscription:
        text = """
        Wir haben Ihnen zum Ablauf Ihres \(abo) Informationen zu unseren Abonnements an Ihre E-Mail-Adresse zugesandt.
        Falls Sie diese E-Mail nicht finden können, oder weitere Fragen an unsere Aboabteilung haben, können Sie jetzt einfach der Abo Abteilung eine Nachricht zusenden.
        
        Für weitere Fragen, wenden Sie sich bitte an unseren Service unter: fragen@taz.de
        """
      case .print2Digi://Achtung anderer Text erst in Step 2 mit Taz-ID!!
        text = "Das machen wir gerne! Geben Sie Ihre bei uns hinterlegten Kundendaten ein, so dass wir Sie zuordnen können. Wir werden sie dann kontaktieren, so dass Sie schnell an Ihre Zugangsdaten kommen."
      case .printPlusDigi:
        text = "Das machen wir gerne! Geben Sie Ihre bei uns hinterlegten Kundendaten ein, so dass wir Sie zuordnen können. Wir werden sie dann kontaktieren, so dass Sie schnell an Ihre Zugangsdaten kommen."
      default:
        break
    }
    guard let text = text else { return nil }
    return Padded.Label(title: text).contentFont()
  }
  
  override func createSubviews() -> [UIView] {
    var views:[UIView] = []
    if let v = title { views.append(v) }
    if let v = subTitle { views.append(v) }
    
    if !(self.type == .expiredDigiPrint || self.type == .expiredDigilSubscription){
      views.append(contentsOf: [idInput, firstName, lastName])
    }
  
    if type == .print2Digi || type == .printPlusDigi || type == .weekendPlusDigi {
      views.append(contentsOf: [street, city, postcode, country])
    }
    
    views.append(contentsOf: [messageLabel, message])
    
    if self.type == .expiredDigiPrint || self.type == .expiredDigilSubscription {
      views.append(requestInfoCheckbox)
    }
    
    views.append(contentsOf: [sendButton, cancelButton])
    return views
  }
  
  ///Validates the Form returns translated Errormessage String for Popup/Toast
  ///Mark issue fields with hints
  func validate() -> String?{
    var errors = false
    //switch or zubuchen
    if type == .print2Digi || type == .printPlusDigi || type == .weekendPlusDigi {
      if "\(postcode.text ?? "")\(city.text ?? "")\(street.text ?? "")\(country.text ?? "")".length < 15 {
        postcode.bottomMessage = "Bitte Adresse überprüfen"
        city.bottomMessage = "Bitte Adresse überprüfen"
        street.bottomMessage = "Bitte Adresse überprüfen"
        country.bottomMessage = "Bitte Adresse überprüfen"
        errors = true
      }
      else {
        postcode.bottomMessage = ""
        city.bottomMessage = ""
        street.bottomMessage = ""
        country.bottomMessage = ""
      }
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
  
  init(type: GqlSubscriptionFormDataType,
       expireDate:Date? = nil,
       customerType: GqlCustomerType? = nil) {
    self.type = type
    self.expireDate = expireDate
    self.customerType = customerType
    super.init(frame: .zero)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
