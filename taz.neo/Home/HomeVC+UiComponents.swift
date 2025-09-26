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
    button.accessibilityLabel = "Darstellungsoptionen anzeigen"
    button.layoutVertically()
    return button
  }
  
  func createHelpButton() -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(named: "tooltip"), for: .normal)
    button.setTitle("Hilfe", for: .normal)

    // Optional: Tintfarbe (Standard ist systemBlue)
    button.tintColor = Const.Colors.appIconGrey

    // Optional: Zugriffshilfe
    button.accessibilityLabel = "Hilfe anzeigen"
    button.layoutVertically()
    button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    button.pinHeight(54.0)
    button.pinWidth(54.0)
    button.layer.cornerRadius = 27.0
    return button
  }
  
  func createCalendarButton() -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(named: "calendar"), for: .normal)
    button.setTitle("Datumsauswahl", for: .normal)

    // Optional: Tintfarbe (Standard ist systemBlue)
    button.tintColor = Const.Colors.appIconGrey

    // Optional: Zugriffshilfe
    button.accessibilityLabel = "Datumsauswahl anzeigen"
    button.layoutVertically()
    button.onTapping { _ in
      self.showDatePicker()
    }
    return button
  }
  
  func createDatePickerWrapperView() -> UIView {
    let overlay = UIView()
    let wrapper = UIView()
    
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
        
    wrapper.addSubview(confirmButton)
    wrapper.addSubview(cancelButton)
    wrapper.addSubview(datePicker)
    overlay.addSubview(wrapper)
    wrapper.centerAxis()
    
    pin(datePicker, to: wrapper, exclude: .top)
    pin(confirmButton.right, to: wrapper.right, dist: -8.0)
    pin(confirmButton.top, to: wrapper.top, dist: 8.0)
    pin(cancelButton.left, to: wrapper.left, dist: 8.0)
    pin(cancelButton.top, to: wrapper.top, dist: 8.0)
    pin(datePicker.top, to: confirmButton.bottom, dist: 0.0)

    overlay.isHidden = true
    let tapGR = UITapGestureRecognizer(target: self, action: #selector(didTapOverlay(_:)))
    tapGR.delegate = self
    overlay.addGestureRecognizer(tapGR)
    
//    datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
    confirmButton.addTarget(self, action: #selector(dateChanged(_:)), for: .touchUpInside)
    cancelButton.addTarget(self, action: #selector(didTapOverlay(_:)), for: .touchUpInside)
    
    return overlay
  }
  
  @objc private func didTapOverlay(_ sender: UITapGestureRecognizer) {
      datePickerOverlay.hideAnimated()
  }
  
  @objc func dateChanged(_ sender: Any) {
    let selectedDate = datePicker.date
    let idx = self.service.nextIndex(for: selectedDate)
    self.scrollTo(idx, animated: true)
    datePickerOverlay.hideAnimated()
  }
}

extension HomeVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {

        // Falls der Touch in Wrapper ODER DatePicker liegt → ignorieren
        if let view = touch.view,
           let wrapper = datePickerOverlay.subviews.first,
           view.isDescendant(of: wrapper) {
            return false
        }
        return true
    }
}

fileprivate extension UIButton {
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

class FrostGradientView: UIVisualEffectView {

    private let gradientLayer = CAGradientLayer()
    var fadeHeight: CGFloat = 20 {
        didSet {
            setNeedsLayout()
        }
    }

    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradient()
    }

    private func setupGradient() {
        let maskLayer = CALayer()
        maskLayer.addSublayer(gradientLayer)
        self.layer.mask = maskLayer
    }

  private func updateGradient() {
      let height = bounds.height
      guard height > 0 else { return }

      gradientLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: height)

      let fadeStartY = height - fadeHeight
      let stopCount = 8

      // 1. Extra Farbe für obere Abdeckung
      var colors: [CGColor] = [UIColor.black.cgColor] // Deckend ab 0%

      // 2. Danach: Verlauf im Fade-Bereich
      let alphaSteps: [CGFloat] = [1.0, 0.9, 0.8, 0.6, 0.4, 0.2, 0.0]
      colors.append(contentsOf: alphaSteps.map { UIColor.black.withAlphaComponent($0).cgColor })

      // 3. Location: 0.0 (voll deckend), dann verteilt auf fadeHeight
      var locations: [NSNumber] = [0.0]
      for i in 0..<alphaSteps.count {
          let relative = CGFloat(i + 1) / CGFloat(alphaSteps.count)
          let y = fadeStartY + relative * fadeHeight
          locations.append(NSNumber(value: Float(y / height)))
      }

      gradientLayer.colors = colors
      gradientLayer.locations = locations
      gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
      gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1.0)
  }
}


class FrostGradientView1: UIVisualEffectView {

    private let gradientLayer = CAGradientLayer()

    /// Anzahl der Pixel für den Blur-Fade an der unteren Kante
    var fadeHeight: CGFloat = 50 {
        didSet {
            updateGradient()
        }
    }

    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradient()
    }

    private func setupGradient() {
        let maskLayer = CALayer()
        maskLayer.addSublayer(gradientLayer)
        self.layer.mask = maskLayer
    }

    private func updateGradient() {
        let totalHeight = self.bounds.height

        // Vermeide Division durch 0 oder zu kleine Höhen
        guard totalHeight > 0, fadeHeight > 0 else { return }

        // Gradient wird über die gesamte Höhe gezogen
        gradientLayer.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: totalHeight))

        // Verhältnis des Übergangsbereichs (Fade) bezogen auf Gesamt-Höhe
        let fadeStop = (totalHeight - fadeHeight) / totalHeight

        // Farben: Schwarz (volle Deckung = voller Blur) → Transparent (kein Blur)
        gradientLayer.colors = [
          UIColor.black.cgColor,       // oben: 100% Blur
          UIColor.black.cgColor,       // bis zum Start des Fades
          UIColor.clear.cgColor        // unten: kein Blur
        ]

        // Positionen im Verlauf (0 = oben, 1 = unten)
        gradientLayer.locations = [
            NSNumber(value: 0.0),
            NSNumber(value: Float(fadeStop)),
            NSNumber(value: 1.0)
        ]

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0) // oben
        gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1.0) // unten
    }
}

class SoftFrostView: UIView {

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let overlayGradientView = UIView()
    private let gradientLayer = CAGradientLayer()

    /// Höhe des sichtbaren Frostbereichs (gesamte View)
    /// Der Verlauf findet in den letzten `fadeHeight` statt
    var fadeHeight: CGFloat = 50 {
        didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        addSubview(blurView)
        addSubview(overlayGradientView)

        overlayGradientView.isUserInteractionEnabled = false
        overlayGradientView.backgroundColor = .clear
        overlayGradientView.layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
        overlayGradientView.frame = bounds
        updateGradient()
    }

    private func updateGradient() {
        gradientLayer.frame = overlayGradientView.bounds

        let height = bounds.height
        let fadeStop = (height - fadeHeight) / height

        gradientLayer.colors = [
            UIColor.clear.cgColor,                             // oben: keine Abdunklung
            UIColor.black.withAlphaComponent(0.7).cgColor      // unten: leichte Überblendung
        ]

        gradientLayer.locations = [NSNumber(value: Float(fadeStop)), 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1.0)
    }
}

class SoftFrostView2: UIView {

    private let fullBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let fadingBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))

    /// Gesamthöhe des Views (z. B. 200), wird per AutoLayout von außen gesetzt
    /// blurFadeHeight ist die Höhe des unteren Fade-Bereichs
    var blurFadeHeight: CGFloat = 50 {
        didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        addSubview(fullBlurView)
        addSubview(fadingBlurView)
        setupFadeMask()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let totalHeight = bounds.height
        let fadeHeight = min(blurFadeHeight, totalHeight)

        // 1. Obere 100% Blur-Zone
        fullBlurView.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: totalHeight - fadeHeight
        )

        // 2. Untere Fade-Zone
        fadingBlurView.frame = CGRect(
            x: 0,
            y: totalHeight - fadeHeight,
            width: bounds.width,
            height: fadeHeight
        )

        updateFadeMask()
    }

    private let gradientMask = CAGradientLayer()

    private func setupFadeMask() {
        gradientMask.colors = [
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(0).cgColor
        ]
        gradientMask.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientMask.endPoint = CGPoint(x: 0.5, y: 1.0)
        fadingBlurView.layer.mask = gradientMask
    }

    private func updateFadeMask() {
        gradientMask.frame = fadingBlurView.bounds
        gradientMask.locations = [0.0, 1.0]
    }
}
