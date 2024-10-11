//
//  CoachmarkView.swift
//  taz.neo
//
//  Created by Ringo Müller on 16.02.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class CoachmarkView: UIView {

  fileprivate var closeClosure: (()->())? = nil
  public func onClose(closure: @escaping ()->()) {
    closeClosure = closure
  }
  
  var backgroundTapped = false
  
  var item: CoachmarkItem
  
  lazy var closeButton1: UIView = {
    var lbl = UILabel()
    lbl.text = "Tip schließen"
    lbl.boldContentFont(size: 22).white()
    return lbl
  }()

  lazy var closeButton: UIImageView = {
    return UIImageView(image: UIImage(named: "close")?.withRenderingMode(.alwaysOriginal))
  }()
  
  var targetView: UIView?///target view to mask
  var alternativeTarget: (UIImage, [UIView], [CGPoint])?///alternative Target if no direct target given
  var alternativeTargetImageViews: [UIImageView] = []
  var background = UIView()///bg for dimming and cutout
  let maskLayer = CAShapeLayer()///mask for target view
  let lineMask = CAShapeLayer()///mask for line to not start in targetview or text
  
  var textWidthConstraint: NSLayoutConstraint?
  
  private let titleLabel = UILabel()
  private let subLabel = UILabel()
  
  func setup(){
    NotificationCenter.default.addObserver(forName: UIAccessibility.voiceOverStatusDidChangeNotification,
                                           object: nil,
                                           queue: nil,
                                           using: { [weak self] _ in
      self?.closeClosure?()
    })
    alternativeTargetImageViews = []
    if let at = alternativeTarget {
      for _ in 0...max(0, at.1.count-1)  {
        let iv = UIImageView(image: at.0)
        iv.contentMode = .scaleAspectFit
        alternativeTargetImageViews.append(iv)
      }
    }
    
    self.addSubview(background)
    pin(background, to: self)
    self.addSubview(textLayer)
    textLayer.centerAxis()
    textLayer.transform = CGAffineTransformMakeRotation(-8 * .pi/180);
    textWidthConstraint = textLayer.pinWidth(UIWindow.size.width*0.7)
    self.layer.addSublayer(line)
    background.layer.mask = maskLayer
    background.backgroundColor = .black.withAlphaComponent(0.8)
    
    for iv in alternativeTargetImageViews {
      self.addSubview(iv)
    }
    
    if alternativeTarget?.1.count == 0,
    let onlyView = alternativeTargetImageViews.first {
      onlyView.centerX()
      pin(onlyView.top, to: textLayer.bottom, dist: 20)
    }
    Notification.receive(Const.NotificationNames.viewSizeTransition) { [weak self] notification in
      guard let _ = notification.content as? CGSize else { return }
      self?.hideAnimated{[weak self] in
        self?.updateCustomLayout()
        self?.showAnimated()
      }
    }
    
    self.addSubview(closeButton)
    ///WARNING NOT WORKING: underlaying view passes accessabillity items
    ///kiss solution: execute close coachmark on voiceover activation
    closeButton.accessibilityLabel = "Schliessen"
    pin(closeButton.right, to: self.right, dist: -10.0)
    pin(closeButton.top, to: self.topGuide(), dist: 10.0)
    
    closeButton.onTapping { [weak self] _ in self?.closeClosure?() }
    textLayer.onTapping { [weak self] _ in
      if self?.backgroundTapped == true { self?.closeClosure?() }
      self?.backgroundTapped = true
      self?.pulsateCloseX()
    }
    background.onTapping{ [weak self] _ in
      if self?.backgroundTapped == true { self?.closeClosure?() }
      self?.backgroundTapped = true
      self?.pulsateCloseX()
    }
  }
  
  func pulsateCloseX(){
    let pulseAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
    pulseAnimation.duration = 0.6
    pulseAnimation.fromValue = 0.1
    pulseAnimation.toValue = 1
    pulseAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
    pulseAnimation.autoreverses = true
    pulseAnimation.repeatCount = 1
    closeButton.layer.add(pulseAnimation, forKey: "animateOpacity")
  }
  
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    guard let sv = superview else {
      targetView = nil//cleanup, remove references
      NotificationCenter.default.removeObserver(self)
      self.closeClosure = nil
      return
    }
    pin(self, to: sv)
    onMainAfter {[weak self] in
      self?.updateCustomLayout()
    }
  }
  
//  var targetFrame: CGRect? {
//    guard let targetView = targetView,
//          targetView.superview != nil,
//          let window = UIWindow.keyWindow else { return nil }
//    guard targetView.isDescendant(of: window) else {
//      return nil
//    }
//    
//    var frame
//    = item.isCircleCutout
//    ? targetView.frame.inset(by: UIEdgeInsets(top: -8, left: -8, bottom: -8, right: -8))
//    : targetView.frame
//    
//    var superview = targetView.superview
//    while superview != window {
//      frame = superview!.convert(frame, to: superview!.superview)
//      if superview!.superview == nil {
//        break
//      } else {
//        superview = superview!.superview
//      }
//    }
//    return superview!.convert(frame, to: self)
//  }

  var targetFrame: CGRect? {
    return targetFrame(tv: targetView)
  }
  
  func targetFrame(tv: UIView?) -> CGRect? {
    guard let tv = tv,
          tv.superview != nil,
          let window = UIWindow.keyWindow else { return nil }
    guard tv.isDescendant(of: window) else {
      return nil
    }
    
    var frame
    = item.isCircleCutout
    ? tv.frame.inset(by: UIEdgeInsets(top: -8, left: -8, bottom: -8, right: -8))
    : tv.frame
    
    var superview = tv.superview
    while superview != window {
      frame = superview!.convert(frame, to: superview!.superview)
      if superview!.superview == nil {
        break
      } else {
        superview = superview!.superview
      }
    }
    return superview!.convert(frame, to: self)
  }
  
  
  func updateCustomLayout(){
    textWidthConstraint?.constant = self.bounds.size.width * 0.75
    
    for i in 0...(alternativeTarget?.1.count ?? 0) where i > 0 {
      guard let v = alternativeTarget?.1.valueAt(i-1),
            let iv = alternativeTargetImageViews.valueAt(i-1),
            let offset = alternativeTarget?.2.valueAt(i-1),
            let f = targetFrame(tv: v) else { break }
      let imgSize = iv.image?.size ?? .zero
      iv.frame = CGRect(x: f.origin.x + offset.x,
                        y: f.origin.y + offset.y,
                        width: imgSize.width,
                        height: imgSize.width)
    }
    
    let tFrame = targetFrame ?? .zero
    
    let path = CGMutablePath()
    path.addRect(self.bounds)
    if item.isCircleCutout {
      path.addEllipse(in: tFrame)
    }
    else {
      path.addRect(tFrame)
    }
    
    maskLayer.path = path
    maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
    
    if alternativeTarget != nil { return }

    let linePath = UIBezierPath()
    let start: CGPoint = tFrame.center
    let end: CGPoint = textLayer.center
    linePath.move(to: start)
    linePath.addLine(to: end)
    
    let lineMaskPath = CGMutablePath()
    lineMaskPath.addRect(self.bounds)
    lineMaskPath.addRect(tFrame)
    lineMaskPath.addRect(self.textLayer.frame)
    lineMask.fillRule = CAShapeLayerFillRule.evenOdd
    lineMask.path = lineMaskPath
    
    line.mask = lineMask
    line.path = linePath.cgPath
  }
  
  
  let line:CAShapeLayer = {
    let line = CAShapeLayer()
    line.strokeColor = UIColor.white.cgColor
    line.lineWidth = 1.1
    line.lineJoin = CAShapeLayerLineJoin.round
    return line
  }()
  
  lazy var textLayer:UIView = {
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
//    wrapper.addBorder(.red)
//    titleLabel.addBorder(.green)
//    subLabel.addBorder(.yellow)
    wrapper.accessibilityLabel = "Hinweis Schliessen durch tap"
    return wrapper
  }()
  
  init(target: UIView?, item: CoachmarkItem, alternativeTarget: (UIImage, [UIView], [CGPoint])? = nil) {
    self.targetView = target
    self.item = item
    self.alternativeTarget = alternativeTarget
    super.init(frame: .zero)
    setup()
    titleLabel.text = item.title
    subLabel.text = item.text
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}


extension CGRect {
  var center: CGPoint {
    return CGPoint(x: origin.x + width/2, y: origin.y + height/2)
  }
}
