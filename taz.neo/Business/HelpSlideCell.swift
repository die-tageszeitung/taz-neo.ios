//
//  HelpSlideCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.09.25.
//  Copyright © 2025 taz. All rights reserved.
//

//
//  CoachmarkCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.09.25.
//  Copyright © 2025 Norbert Thies.
//

import UIKit
import NorthLib

/// Eine UICollectionViewCell-Variante des bisherigen CoachmarkView.
/// Funktionalität (Maskierung, Close, Layout) bleibt weitgehend erhalten.
class CoachmarkCell: UICollectionViewCell {
  var item: HelpItem? {
    didSet {
      guard let item = item else { return }
      self.targetView = item.targetView
//      self.alternativeTarget = alternativeTarget
      titleLabel.text = item.title
      subLabel.text = item.text
      updateCustomLayout()
    }
  }
  
  private var targetView: UIView?
  var alternativeTarget: (UIImage, [UIView], [CGPoint])?
  var alternativeTargetImageViews: [UIImageView] = []
  
  let backgroundDim = UIView()
  let maskLayer = CAShapeLayer()
  let lineMask = CAShapeLayer()
  
  private let titleLabel = UILabel()
  private let subLabel = UILabel()
  
  var textWidthConstraint: NSLayoutConstraint?
  
  let line: CAShapeLayer = {
    let line = CAShapeLayer()
    line.strokeColor = UIColor.white.cgColor
    line.lineWidth = 1.1
    line.lineJoin = .round
    return line
  }()
  
  lazy var textLayer: UIView = {
    let wrapper = UIView()
    titleLabel.americanTypewriter(size: 32).white().centerText()
    subLabel.contentFont().white().centerText()
    wrapper.addSubview(titleLabel)
    wrapper.addSubview(subLabel)
    titleLabel.numberOfLines = 0
    subLabel.numberOfLines = 0
    pin(titleLabel, to: wrapper, exclude: .bottom)
    pin(subLabel, to: wrapper, exclude: .top)
    pin(subLabel.top, to: titleLabel.bottom)
    return wrapper
  }()
  
  lazy var closeButton: UIImageView = {
    let iv = UIImageView(image: UIImage(named: "close")?.withRenderingMode(.alwaysOriginal))
    iv.isUserInteractionEnabled = true
    iv.accessibilityLabel = "Schließen"
    return iv
  }()
  
  // MARK: - Init
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  // MARK: - Setup
  private func setup() {
    self.backgroundColor = .clear
    contentView.addSubview(backgroundDim)
    pin(backgroundDim, to: contentView)
    
    contentView.addSubview(textLayer)
    textLayer.centerAxis()
    textWidthConstraint = textLayer.pinWidth(UIWindow.size.width * 0.7)
    contentView.layer.addSublayer(line)
    
    contentView.addBorder(.red)
    self.addBorder(.green)
    textLayer.addBorder(.green)
    
    backgroundDim.layer.mask = maskLayer
    backgroundDim.backgroundColor = .black.withAlphaComponent(0.8)
    
    contentView.addSubview(closeButton)
    pin(closeButton.right, to: contentView.right, dist: -10)
    pin(closeButton.top, to: contentView.topGuide(), dist: 10)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    targetView = nil
    alternativeTarget = nil
    alternativeTargetImageViews.forEach { $0.removeFromSuperview() }
    alternativeTargetImageViews = []
  }
  
  // MARK: - Layout
  override func layoutSubviews() {
    super.layoutSubviews()
    updateCustomLayout()
  }
  
  func updateCustomLayout() {
    guard let item = item else { return }
    print("CoachmarkCell: updateCustomLayout for cell with title '\(item.title)'")
    textWidthConstraint?.constant = bounds.size.width * 0.75
    
    let tFrame = targetFrame ?? .zero
    let path = CGMutablePath()
    path.addRect(bounds)
    if item.isCircleCutout {
      path.addEllipse(in: tFrame)
    } else {
      path.addRect(tFrame)
    }
    maskLayer.path = path
    maskLayer.fillRule = .evenOdd
    
    // Verbindungslinie
    let linePath = UIBezierPath()
    let start: CGPoint = tFrame.center
    let end: CGPoint = textLayer.center
    linePath.move(to: start)
    linePath.addLine(to: end)
    
    let lineMaskPath = CGMutablePath()
    lineMaskPath.addRect(bounds)
    lineMaskPath.addRect(tFrame)
    lineMaskPath.addRect(textLayer.frame)
    lineMask.fillRule = .evenOdd
    lineMask.path = lineMaskPath
    
    line.mask = lineMask
    line.path = linePath.cgPath
  }
  
  // MARK: - Helpers
  var targetFrame: CGRect? {
    guard let tv = targetView,
          tv.superview != nil,
          let window = UIWindow.keyWindow,
          tv.isDescendant(of: window) else { return nil }
    
    var frame = item?.isCircleCutout == true
      ? tv.frame.inset(by: UIEdgeInsets(top: -8, left: -8, bottom: -8, right: -8))
      : tv.frame
    
    var superview = tv.superview
    while superview != window {
      frame = superview!.convert(frame, to: superview!.superview)
      superview = superview!.superview
    }
    return superview!.convert(frame, to: contentView)
  }
}


