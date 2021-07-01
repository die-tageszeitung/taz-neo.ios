//
//  ScrollDownAnimationView.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.06.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A MomentView displays an Image, an optional Spinner and an
/// optional Menue.
public class ScrollDownAnimationView: UIView {
  
  private lazy var bottomArrow = UpArrow()
  private lazy var topArrow = UpArrow()
  
  private var animating = false
  
  public func animate(repetitions:Int = 3) {
    if animating { return }
    doAnimate(repetitions: repetitions)
  }
  
  func doAnimate(repetitions:Int = 3) {
    if animating { return }
    let w = self.bounds.size.width
    self.bottomArrow.frame.origin.y = 0.4*w
    self.topArrow.alpha = 0.0
    self.bottomArrow.alpha = 0.0
    
    // b show, move // fin t show // fin b hide .. t hide
    UIView.animateKeyframes(withDuration: 1.3, delay: 0, animations: {
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.2) {
        self.bottomArrow.frame.origin.y = 0.22*self.bounds.size.height
        self.bottomArrow.alpha = 1.0
      }
      UIView.addKeyframe(withRelativeStartTime: 0.15, relativeDuration: 0.2) {
        self.topArrow.alpha = 1.0
      }
      
      UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.2) {
        self.bottomArrow.alpha = 0.0
      }
      UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
        self.topArrow.alpha = 0.0
      }
      
    }) {[weak self] _ in
      if repetitions > 0 { self?.doAnimate(repetitions: repetitions-1)}
    }
  }

  private func setup() {
    self.pinSize(CGSize(width: 40, height: 33))
    topArrow.alpha = 0.0
    bottomArrow.alpha = 0.0
    self.addSubview(topArrow)
    self.addSubview(bottomArrow)
  }
  
  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    bottomArrow.frame = CGRect(x: 0, y: rect.height/2,
                               width: rect.width, height: rect.height/2)
    topArrow.frame = CGRect(x: 0, y: 0,
                               width: rect.width, height: rect.height/2)
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}

fileprivate class UpArrow: UIView {
  
  var arrowLayer: CAShapeLayer?
  
  func drawArrow(strokeWidth: CGFloat = 3.0){
    arrowLayer?.removeFromSuperlayer()
    arrowLayer = CAShapeLayer()
    guard let arrowLayer = arrowLayer else { return }
    
    let sw:CGFloat = strokeWidth,
        h = frame.size.height,
        w = frame.size.width
    var pl: CGPoint, pt: CGPoint, pr: CGPoint
        
    pl = CGPoint(x:sw, y:h-sw)
    pt = CGPoint(x:w/2, y:sw)
    pr = CGPoint(x:w-sw, y:h-sw)

    let arrow =  UIBezierPath()
    arrow.move(to: pl)
    arrow.addLine(to: pt)
    arrow.addLine(to: pr)
    
    arrowLayer.path = arrow.cgPath
    arrowLayer.fillColor = UIColor.clear.cgColor
    arrowLayer.lineWidth = sw
    arrowLayer.lineJoin = .round
    arrowLayer.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
    self.layer.addSublayer(arrowLayer)
  }
  
  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    drawArrow()
  }
}
