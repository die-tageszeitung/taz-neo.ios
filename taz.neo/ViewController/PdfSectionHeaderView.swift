//
//  SectionHeaderView.swift
//  taz.neo
//
//  Created by Ringo Müller on 24.06.26.
//  Copyright © 2026 taz. All rights reserved.
//


// Simple reusable section header with a label
import UIKit
import NorthLib

class PdfSectionHeaderView: UICollectionReusableView {
  static let reuseIdentifier = "PdfSectionHeaderView"
  let label = UILabel()
  let dottedLine = DottedLineView()
  let topLine = UIView()
  
  func configure(with title: String?, pageMode: Bool) {
    label.text = title
    topLine.isHidden = pageMode
    dottedLine.isHidden = pageMode || title == nil
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.boldContentFont(size: 20)
    addSubview(label)
    addSubview(topLine)
    addSubview(dottedLine)
    pin(topLine.right, to: self.right, dist: 16, priority: .defaultLow)
    pin(dottedLine.right, to: self.right, dist: 16, priority: .defaultLow)
    pin(label.bottom, to: self.bottom, dist: -24, priority: .defaultLow)
    
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
      label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
      topLine.heightAnchor.constraint(equalToConstant:0.7),
      topLine.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      topLine.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      dottedLine.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      dottedLine.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
      dottedLine.heightAnchor.constraint(equalToConstant:1.6),
    ])
    registerForStyleUpdates()
    applyStyles()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension PdfSectionHeaderView: UIStyleChangeDelegate{
  public func applyStyles() {
    label.textColor = Const.SetColor.HText.color
    dottedLine.fillColor = Const.SetColor.HText.color
    dottedLine.strokeColor = Const.SetColor.HText.color
    dottedLine.setNeedsLayout()//apply color on mode change, if already displayed
    topLine.backgroundColor = Const.SetColor.HText.color
  }
}
