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
  func createLoginButton() -> UIView {
    let login = UILabel()
    login.accessibilityLabel = "Anmelden"
    login.isAccessibilityElement = true
    login.contentFont()
    login.textColor = Const.SetColor.HomeText.dynamicColor
    login.text = "Anmelden"
    
    let arrow
    = UIImageView(image: UIImage(name: "arrow.right")?
      .withTintColor(Const.Colors.appIconGrey,
                     renderingMode: .alwaysTemplate))
    arrow.tintColor = Const.SetColor.HomeText.dynamicColor
    
    let wrapper = UIView()
    wrapper.addSubview(login)
    wrapper.addSubview(arrow)
    pin(login, to: wrapper, dist:Const.Size.DefaultPadding, exclude: .right)
    pin(arrow, to: wrapper, dist:Const.Size.DefaultPadding, exclude: .left)
    pin(login.right, to: arrow.left, dist: -5.0)

    wrapper.onTapping { [weak self] _ in
       self?.feederContext.authenticate()
    }
    return wrapper
  }
  
  func createViewModeButton() -> UIButton {
    let menuButton = UIButton(type: .system)

    // Set SF Symbol as image
    let icon = UIImage(systemName: "ellipsis")
    menuButton.setImage(icon, for: .normal)

    // Optional: Tintfarbe (Standard ist systemBlue)
    menuButton.tintColor = Const.Colors.appIconGrey

    // Optional: Zugriffshilfe
    menuButton.accessibilityLabel = "Ansicht umschalten"
    
    menuButton.pinSize(CGSize(width: 40, height: 40))
    menuButton.addBorder(Const.Colors.appIconGrey, 1.5)
    menuButton.layer.cornerRadius = 20
    return menuButton
  }
}

class FrostGradientView: UIVisualEffectView {

    private let gradientLayer = CAGradientLayer()
    var fadeHeight: CGFloat = 50 {
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
