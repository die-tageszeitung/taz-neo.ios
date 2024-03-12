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
  
  private lazy var arrow = ArrowView()
  
  private var animating = false
  
  public func animate(repetitions:Int = 3) {
    if animating { return }
    doAnimate(repetitions: repetitions)
  }
  
  func doAnimate(repetitions:Int) {
    if animating { return }
    self.arrow.frame.origin.y = 0
    self.arrow.alpha = 0.0
    
    // b show, move // fin t show // fin b hide .. t hide
    UIView.animateKeyframes(withDuration: 1.8,
                            delay: 0.8,
                            animations: {
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.2) {
        self.arrow.alpha = 1.0
        self.arrow.frame.origin.y = self.bounds.size.height - self.arrow.frame.height
      }
      UIView.addKeyframe(withRelativeStartTime: 0.9, relativeDuration: 0.1) {
        self.arrow.alpha = 0.0
        self.arrow.frame.origin.y -= 3
      }
      
    }) {[weak self] _ in
      if repetitions > 1 { self?.doAnimate(repetitions: repetitions-1)}
    }
  }

  private func setup() {
    self.pinSize(CGSize(width: 28, height: 20))
    arrow.alpha = 0.0
    self.addSubview(arrow)
  }
  
  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    arrow.frame = CGRect(x: 0, y: 0,
                         width: rect.width, height: 0.55*rect.height)
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

fileprivate class ArrowView: UIView {
  
  var arrowLayer: CAShapeLayer?
  
  func drawArrow(strokeWidth: CGFloat = 3.5){
    arrowLayer?.removeFromSuperlayer()
    arrowLayer = CAShapeLayer()
    guard let arrowLayer = arrowLayer else { return }
    
    let sw:CGFloat = strokeWidth,
        h = frame.size.height,
        w = frame.size.width
    var pl: CGPoint, pt: CGPoint, pr: CGPoint
        
    pl = CGPoint(x:sw, y:sw)
    pt = CGPoint(x:w/2, y:h-sw)
    pr = CGPoint(x:w-sw, y:sw)

    let arrow =  UIBezierPath()
    arrow.move(to: pl)
    arrow.addLine(to: pt)
    arrow.addLine(to: pr)
    
    arrowLayer.path = arrow.cgPath
    arrowLayer.fillColor = UIColor.clear.cgColor
    arrowLayer.lineWidth = sw
    arrowLayer.lineJoin = .round
    arrowLayer.lineCap = .round
    arrowLayer.strokeColor 
    = App.isLMD
    ? UIColor.black.withAlphaComponent(0.5).cgColor
    : UIColor.white.withAlphaComponent(0.5).cgColor
    self.layer.addSublayer(arrowLayer)
  }
  
  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    drawArrow()
  }
}
