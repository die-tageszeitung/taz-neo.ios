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
                                    textContentType: .emailAddress,
                                    enablesReturnKeyAutomatically: true,
                                    keyboardType: .default,
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
  
  var requestInfoCheckbox: CheckboxWithText = {
    let view = CheckboxWithText()
    view.textView.isEditable = false
    view.textView.text = "Bitte informieren Sie mich zu aktuellen Abo-Möglichkeiten"
    view.textView.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
    view.textView.textColor = Const.SetColor.HText.color
    return view
  }()
  
  var message:ViewWithTextView = {
    let ti
    = ViewWithTextView(text: nil,
                       font: Const.Fonts.contentFont(size: Const.Size.DefaultFontSize))
    ti.placeholder = "Ihre Nachricht"
    ti.border.isHidden = false
    return ti
  }()

  var sendButton = Padded.Button(title: "Absenden")
  var cancelButton =  Padded.Button(type:.outline, title: Localized("cancel_button"))
  
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
    switch type {
      case .expiredDigiPrint, .expiredDigiSubscription:
        if let d = expireDate {
          text = "Ihr \(abo) ist am \(d.gDate()) abgelaufen."
        }
        else {
          text = "Ihr \(abo) ist abgelaufen."
        }
      case .print2Digi:
        text = "Ja! Ich möchte nur noch digital lesen."
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
      case .digital: abo = "Abonnements"
      case .deliveryBreaker: abo = "Print Ersatzabos"
      default: abo = "Abos"
    }
    
    
    var text: String? = nil
    switch type {
      case .expiredDigiPrint, .expiredDigiSubscription:
        text = """
        Wir haben Ihnen zum Ablauf Ihres \(abo) Informationen zu unseren Abonnements an Ihre E-Mail-Adresse zugesandt.
        Falls Sie diese E-Mail nicht finden können, oder weitere Fragen haben, können Sie jetzt einfach unserem Service-Team eine Nachricht zusenden.
        
        Für weitere Fragen erreichen Sie unser Service-Team auch unter: fragen@taz.de
        """
      case .print2Digi://Achtung anderer Text erst in Step 2 mit Taz-ID!!
        text = "Super! Auf in die Zukunft. Herzlichen Glückwunsch zu diesem Schritt. Um Sie einordnen zu können, brauchen wir ein paar Daten von Ihnen.\nWir kontaktieren Sie in den nächsten Tagen per Mail."
      case .printPlusDigi:
        text = "Das machen wir gerne! Geben Sie Ihre bei uns hinterlegten Kundendaten ein, so dass wir Sie zuordnen können.\nWir werden Sie dann kontaktieren."
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
    
    if !(self.type == .expiredDigiPrint || self.type == .expiredDigiSubscription){
      views.append(contentsOf: [idInput, firstName, lastName])
    }
  
    if type == .print2Digi || type == .printPlusDigi || type == .weekendPlusDigi {
      views.append(contentsOf: [street, city, postcode])
    }
    
    views.append(message)
    
    if self.type == .expiredDigiPrint || self.type == .expiredDigiSubscription {
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
    }
    
    if (message.text ?? "").isEmpty {
      errors = true
      message.bottomMessage = "Bitte ausfüllen!"
    }
    else if (message.text?.length ?? 0) < 8 {
      errors = true
      message.bottomMessage = "Ihre Nachricht ist zu kurz!"
    }
    else {
      message.bottomMessage = nil
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
