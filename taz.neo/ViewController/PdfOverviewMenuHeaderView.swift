//
//  PdfOverviewMenuHeaderView.swift
//  taz.neo
//
//  Custom header for the new PDF overview menu: shows full-height cover on the left, title/date above, and controls right/bottom-aligned.
//

import UIKit
import NorthLib

class PdfOverviewMenuHeaderView: UIView {
    
  // MARK: - UI Elements
  let coverImageView = UIImageView()
  let dateLabel = UILabel()
  let modeSwitchButton: IconLabelButton
  let listenButton: IconLabelButton
  
  // Init
  override init(frame: CGRect) {
    modeSwitchButton = IconLabelButton(image: UIImage(named: "tiles"), text: "Listenansicht")
    listenButton = IconLabelButton(image: UIImage(named: "audio"), text: "Ausgabe hören")
    super.init(frame: frame)
    setupSubviews()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupSubviews() {
    // Cover image - left, full height
    coverImageView.contentMode = .scaleAspectFit
    coverImageView.clipsToBounds = true
    coverImageView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(coverImageView)
    coverImageView.shadow()
    
    // Date label - top, spanning right of cover
    dateLabel.contentFont()
    dateLabel.numberOfLines = 8
    dateLabel.textColor = .label
    dateLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(dateLabel)
    
    // Mode switch button
    modeSwitchButton.translatesAutoresizingMaskIntoConstraints = false
    modeSwitchButton.tintColor = .label
    addSubview(modeSwitchButton)
    // Listen button
    listenButton.translatesAutoresizingMaskIntoConstraints = false
    listenButton.tintColor = .label
    addSubview(listenButton)
    coverImageView.clipsToBounds = false
    // Layout constraints
    NSLayoutConstraint.activate([
      // Cover image: left, full height, fixed width ratio
      coverImageView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
      coverImageView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -5),
      coverImageView.widthAnchor.constraint(equalTo: coverImageView.heightAnchor, multiplier: 0.65),
      
      //from left to right
      coverImageView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 5.0),
      //...top
      dateLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 16),
      dateLabel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
      //...bottom
      modeSwitchButton.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 16),
      listenButton.leadingAnchor.constraint(greaterThanOrEqualTo: modeSwitchButton.trailingAnchor, constant: 2),
      listenButton.trailingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
      listenButton.trailingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
      //vertical...top
      dateLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 11),
      //vertical...bottom
      modeSwitchButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -9),
      listenButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -9),
    ])
  }
  
  // Helper to update the mode toggle icon
  func applyMode(isList: Bool) {
    // target is named, not state
    modeSwitchButton.label.text = isList ? "Seitenansicht" : "Listenansicht"
    let symbol = isList ? "tiles" : "list"
    modeSwitchButton.setImage(UIImage(named: symbol))
  }
  
  // Helper to set the cover image, e.g., from PdfModel's thumbnail
  func setCoverImage(_ image: UIImage?) {
    coverImageView.image = image
  }
}

