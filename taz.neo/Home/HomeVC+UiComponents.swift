//
//  HomeVC+UiComponents.swift
//  taz.neo
//
//  Created by Ringo Müller on 24.06.25.
//  Copyright © 2025 taz. All rights reserved.
//
import UIKit
import NorthLib

extension HomeVC {
  func createLoginButton() -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(named: "login"), for: .normal)
    button.setTitle("Anmelden", for: .normal)
    button.tintColor = Const.Colors.appIconGrey
    button.accessibilityLabel = "Anmelden"
    button.layoutVertically()
    button.pinHeight(42)
    button.onTapping { _ in
      self.feederContext.authenticate()
    }
    return button
  }
  
  func createViewModeButton() -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(named: "show"), for: .normal)
    button.setTitle("Darstellung", for: .normal)

    // Optional: Tintfarbe (Standard ist systemBlue)
    button.tintColor = Const.Colors.appIconGrey

    // Optional: Zugriffshilfe
    button.accessibilityLabel = "Ausgabenübersicht: Darstellungsoptionen öffnen"
    button.layoutVertically()
    button.pinHeight(42)
    return button
  }
  
  func createCalendarButton() -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(named: "calendar"), for: .normal)
    button.setTitle("Datumsauswahl", for: .normal)

    // Optional: Tintfarbe (Standard ist systemBlue)
    button.tintColor = Const.Colors.appIconGrey

    // Optional: Zugriffshilfe
    button.accessibilityLabel = "Datumsauswahl öffnen"
    button.layoutVertically()
    button.onTapping { _ in
      self.showDatePicker()
    }
    return button
  }
  
  func createDatePickerWrapperView() -> UIView {
    let overlay = UIView()
    let wrapper = UIView()
    
    let titleLabel = UILabel()
    titleLabel.text = "Gehe zur Ausgabe vom"
    titleLabel.contentFont()
    
    let confirmButton = UIButton(type: .system)
    confirmButton.setTitle("Übernehmen", for: .normal)
    confirmButton.setTitleColor(.white, for: .normal)
    confirmButton.titleLabel?.boldContentFont()
    confirmButton.translatesAutoresizingMaskIntoConstraints = false
    
    let cancelButton = UIButton(type: .system)
    cancelButton.setTitle("Abbrechen", for: .normal)
    cancelButton.setTitleColor(.white, for: .normal)
    cancelButton.titleLabel?.contentFont()
    confirmButton.translatesAutoresizingMaskIntoConstraints = false
    
    overlay.backgroundColor = UIColor.black.withAlphaComponent(0.84)
//    wrapper.backgroundColor = UIColor.black
    wrapper.backgroundColor = Const.Colors.darkSecondaryBG
    wrapper.layer.borderWidth = 0.3
    wrapper.layer.borderColor = Const.Colors.appIconGrey.cgColor
    wrapper.layer.cornerRadius = 8.0
    
    datePicker.minimumDate = feederContext.defaultFeed.firstIssue
    datePicker.maximumDate =  Date()
    datePicker.datePickerMode = .date
    
    datePicker.tintColor = .white
    
    if #available(iOS 14.0, *) {
      datePicker.preferredDatePickerStyle = .inline
    }
    datePicker.translatesAutoresizingMaskIntoConstraints = false
        
    wrapper.addSubview(titleLabel)
    wrapper.addSubview(confirmButton)
    wrapper.addSubview(cancelButton)
    wrapper.addSubview(datePicker)
    overlay.addSubview(wrapper)
    wrapper.centerX()
    wrapper.centerY(dist: 40.0)
    
    //T2B
    pin(titleLabel.top, to: wrapper.top, dist: 8.0)
    pin(datePicker.top, to: titleLabel.bottom, dist: 0.0)
    pin(cancelButton.top, to: datePicker.bottom, dist: Const.Dist2.m20)
    pin(confirmButton.top, to: datePicker.bottom, dist: Const.Dist2.m20)
    pin(confirmButton.bottom, to: wrapper.bottom, dist: -Const.Dist2.m15)
    
    ///L2R
    pin(titleLabel.left, to: wrapper.left, dist: 8.0)
    pin(datePicker.left, to: wrapper.left)
    pin(datePicker.right, to: wrapper.right)
    pin(confirmButton.right, to: wrapper.right, dist: -8.0)
    pin(cancelButton.left, to: wrapper.left, dist: 8.0)

    let tapGR = UITapGestureRecognizer(target: self, action: #selector(didTapOverlay(_:)))
    tapGR.delegate = self
    overlay.addGestureRecognizer(tapGR)
    
//    datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
    confirmButton.addTarget(self, action: #selector(dateChanged(_:)), for: .touchUpInside)
    cancelButton.addTarget(self, action: #selector(didTapOverlay(_:)), for: .touchUpInside)
    overlay.accessibilityElements = [titleLabel, cancelButton, confirmButton, datePicker]
    overlay.isAccessibilityElement = false
    datePickerOverlayTitleLabel = titleLabel
    return overlay
  }
  
  private func closeDatePickerOverlay() {
    datePickerOverlay.hideAnimated(completion: {[weak self] in
      self?.datePickerOverlay.removeFromSuperview()
      ///bring back focus to home
      ///hide&remove sets back overlay.accessibilityViewIsModal to false and evaluates order
      ///now we have
      self?.updateAccessibilityOrder()
      UIAccessibility.post(notification: .layoutChanged, argument: self?.viewModeButton)
    })
  }
  
  @objc private func didTapOverlay(_ sender: UITapGestureRecognizer) {
    closeDatePickerOverlay()
  }
  
  @objc func dateChanged(_ sender: Any) {
    let selectedDate = datePicker.date
    let idx = self.service.nextIndex(for: selectedDate)
    self.scrollTo(idx, animated: true)
    closeDatePickerOverlay()
  }
}

extension HomeVC: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                         shouldReceive touch: UITouch) -> Bool {
    //Falls der Touch in Wrapper ODER DatePicker liegt → ignorieren
    if let view = touch.view,
       let wrapper = datePickerOverlay.subviews.first,
       view.isDescendant(of: wrapper) {
      return false
    }
    return true
  }
}

// MARK: - ShowPDF Info Toast
extension HomeVC {
  func showRequestTrackingIfNeeded() {
    guard Defaults.usageTrackingAllowed == nil else { return   }
    guard let image = UIImage(named: "BundledResources/UsagePopover.png")else {
      log("Bundled UsagePopover.png not found!")
      return
    }
    var fromBottom = false
    if dataPolicyToast == nil {
      fromBottom = true
      dataPolicyToast = NewInfoToast.showWith(image: image,
                            title: "Eine noch bessere taz App? Sie haben es in der Hand",
                            text: "Anonyme Nutzungsdaten helfen uns, noch besser zu werden. Wir wissen natürlich: Wer Daten will, muss freundlich sein – deshalb behandeln wir diese mit größtmöglicher Sorgfalt und absolut vertraulich. Ihre Einwilligung zur Nutzung kann zudem jederzeit widerrufen werden.",
                            button1Text: "Ja, ich helfe mit",
                            button2Text: "Nein, keine Daten senden",
                            button1Handler: { Defaults.usageTrackingAllowed = true; Usage.shared.setup() },
                            button2Handler: { Defaults.usageTrackingAllowed = false },
                            dataPolicyHandler: {[weak self] in self?.showDataPolicyModal()})
    }
    dataPolicyToast?.accessibilityViewIsModal = true
    dataPolicyToast?.button1.accessibilityLabel = "Tracking zustimmen"
    dataPolicyToast?.button2.accessibilityLabel = "Tracking verweigern"
    ///unfortunately links are not accessible @see: https://stackoverflow.com/a/49366620
    #warning("accessibility: Change Component")
    dataPolicyToast?.privacyText.accessibilityLabel = "Hinweise zum Datenschutz finden Sie in den Einstellungen"
    dataPolicyToast?.privacyText.isAccessibilityElement = false
    dataPolicyToast?.privacyText.accessibilityTraits = .none
    dataPolicyToast?.show(fromBottom: fromBottom)
  }
  
  func showDataPolicyModal(){
    let localResource = File(feederContext.gqlFeeder.dataPolicy)
    guard localResource.exists else {log("dataPolicy not found");  return }
    
    let introVC = TazIntroVC()
    introVC.topOffset = Const.Dist.margin
    introVC.isModalInPresentation = true
    introVC.webView.webView.load(url: localResource.url)
    self.modalPresentationStyle = .fullScreen
    introVC.modalPresentationStyle = .fullScreen
    introVC.webView.webView.scrollDelegate.atEndOfContent {_ in }
    introVC.webView.onX {_ in
      introVC.dismiss(animated: true, completion: nil)
    }
    self.present(introVC, animated: true) {
      //Overwrite Default in: IntroVC viewDidLoad
      introVC.webView.buttonLabel.text = nil
    }
  }
}

extension UIButton {
  func layoutVertically(){
    titleLabel?.contentFont(size: 11)
    
    contentHorizontalAlignment = .center
    let spacing: CGFloat = 0
    if let imageSize = imageView?.intrinsicContentSize,
       let titleSize = titleLabel?.intrinsicContentSize {
      
      titleEdgeInsets = UIEdgeInsets(
        top: spacing,
        left: -imageSize.width,
        bottom: -imageSize.height,
        right: 0
      )
      imageEdgeInsets = UIEdgeInsets(
        top: -titleSize.height - spacing,
        left: 0,
        bottom: 0,
        right: -titleSize.width
      )
    }
  }
}

