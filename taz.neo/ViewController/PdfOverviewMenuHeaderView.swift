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
  let waitingSpinner = UIActivityIndicatorView()
  let loadInfoLabel = UILabel()
  let pageLabel = UILabel()
  let modeSwitchButton: IconLabelButton
  let listenButton: IconLabelButton
  
  var isLoading = false {
    didSet {
      guard isLoading != oldValue else { return }
      if isLoading {
        waitingSpinner.startAnimating()
        loadInfoLabel.showAnimated()
      }
      else {
        waitingSpinner.stopAnimating()
        loadInfoLabel.hideAnimated()
      }
    }
  }
  var coverBottomConstraint: NSLayoutConstraint?
  
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
    dateLabel.numberOfLines = 8
    dateLabel.textColor = Const.Colors.appIconGrey
    dateLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(dateLabel)
    pageLabel.text = "seite 1"
    pageLabel.boldContentFont(size: Const.Size.SmallerFontSize)
    pageLabel.numberOfLines = 1
    pageLabel.textColor = Const.Colors.appIconGrey
    pageLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(pageLabel)
    // Mode switch button
    modeSwitchButton.translatesAutoresizingMaskIntoConstraints = false
    modeSwitchButton.tintColor = .label
    addSubview(modeSwitchButton)
    // Listen button
    listenButton.translatesAutoresizingMaskIntoConstraints = false
    listenButton.tintColor = .label
    addSubview(listenButton)
    coverImageView.clipsToBounds = false
    coverBottomConstraint = coverImageView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -23)
    
    // Layout constraints
    NSLayoutConstraint.activate([
      // Cover image: left, full height, fixed width ratio
      coverImageView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
      coverBottomConstraint!,
      coverImageView.widthAnchor.constraint(equalTo: coverImageView.heightAnchor, multiplier: Const.Size.PageAspectRatio),
      pageLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -24),
      //from left to right
      pageLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 0.0),
      coverImageView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 0.0),
      //...top
      dateLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: PdfDisplayOptions.Overview.interItemSpacing),
      dateLabel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
      //...bottom
      modeSwitchButton.leadingAnchor.constraint(equalTo: self.centerXAnchor),
      listenButton.leadingAnchor.constraint(greaterThanOrEqualTo: modeSwitchButton.trailingAnchor, constant: 2),
      listenButton.trailingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
      listenButton.trailingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
      //vertical...top
      dateLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 0.0),
      //vertical...bottom
      modeSwitchButton.bottomAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 0.0),
      listenButton.bottomAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 0.0),
    ])
    loadInfoLabel.isHidden = !isLoading
    waitingSpinner.isHidden = !isLoading
    addSubview(waitingSpinner)
    addSubview(loadInfoLabel)
    addSubview(loadInfoLabel)
    pin(waitingSpinner.centerY, to: coverImageView.centerY, dist: -30.0)
    pin(waitingSpinner.right, to: listenButton.left, dist: -15.0)
    pin(loadInfoLabel.centerX, to: waitingSpinner.centerX)
    pin(loadInfoLabel.top, to: waitingSpinner.bottom, dist: 5)
    loadInfoLabel.text = "Lade Ausgabe"
    loadInfoLabel.contentFont(size: Const.Size.SmallerFontSize)
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

