//
//  CoreGraphicsExtensions.swift
//
//  Created by Norbert Thies on 15.04.16.
//  Copyright © 2016 Norbert Thies. All rights reserved.
//

import UIKit

/// CGSize extensions
extension CGSize {
  
  /// isPortrait returns true if width <= height
  public var isPortrait: Bool { return width <= height }
  
  /// isLandscape returns true if width > height
  public var isLandscape: Bool { return width > height }
  
  /// toString returns a String representation
  public func toString() -> String { return "(w:\(width),h:\(height))" }
  
  /// description simply calls toString
  public var description: String { return toString() }
  
}

/// A CGPoint transformation
public struct CGPointTransform {
  var rowX: CGPoint
  var rowY: CGPoint
  init( x: CGPoint, y: CGPoint ) { rowX = x; rowY = y }
  static func rotation( _ a: CGFloat ) -> CGPointTransform {
    return CGPointTransform( x: CGPoint(x:cos(a), y:sin(a)),
                             y: CGPoint(x:-sin(a), y:cos(a)) )
  }
  static func scale( x: CGFloat, y: CGFloat ) -> CGPointTransform {
    return CGPointTransform( x: CGPoint(x:x, y:0), y: CGPoint(x:0, y:y) )
  }
}

// Some CGPoint operators

public func * ( t:CGPointTransform, p:CGPoint ) -> CGPoint {
  return CGPoint( x: p.x*t.rowX.x + p.y*t.rowX.y,
                  y: p.x*t.rowY.x + p.y*t.rowY.y)
}

public func * ( t1:CGPointTransform, t2:CGPointTransform ) -> CGPointTransform {
  return CGPointTransform(
    x: CGPoint( x: t1.rowX.x * t2.rowX.x + t1.rowX.y * t2.rowY.x,
                y: t1.rowX.x * t2.rowX.y + t1.rowX.y * t2.rowY.y ),
    y: CGPoint( x: t1.rowY.x * t2.rowX.x + t1.rowY.y * t2.rowY.x,
                y: t1.rowY.x * t2.rowX.y + t2.rowY.y * t2.rowY.y )
  )
}

public func + ( p1:CGPoint, p2:CGPoint ) -> CGPoint {
  return CGPoint( x: p1.x + p2.x, y: p1.y + p2.y )
}

public func + ( p1:CGPoint, p2:(x:CGFloat, y:CGFloat) ) -> CGPoint {
  return CGPoint( x: p1.x + p2.x, y: p1.y + p2.y )
}

public func + ( p1:CGPoint, v:CGFloat ) -> CGPoint {
  return CGPoint( x: p1.x + v, y: p1.y + v )
}

public func + ( v:CGFloat, p1:CGPoint ) -> CGPoint {
  return p1 + v
}

public func - ( p1:CGPoint, v:CGFloat ) -> CGPoint {
  return p1 + -v
}

public prefix func - ( p:CGPoint ) -> CGPoint {
  return CGPoint( x:-p.x, y:-p.y )
}

public func - ( p1:CGPoint, p2:CGPoint ) -> CGPoint {
  return p1 + -p2
}

public func - ( p1:CGPoint, p2:(x:CGFloat, y:CGFloat) ) -> CGPoint {
  return p1 + (-p2.x,-p2.y)
}

public func * ( p:CGPoint, s:CGFloat ) -> CGPoint {
  return CGPoint( x:p.x*s, y:p.y*s )
}

public func * ( s:CGFloat, p:CGPoint ) -> CGPoint { return p*s }

extension CGPoint {

  /// returns the length of the vector
  var abs:CGFloat { get { return sqrt(x*x + y*y) } }
  
  /// returns vector from self to *to*
  func vector( _ to:CGPoint ) -> CGPoint { return to-self }
  
  /// returns a perpendicular vector
  func perpendicular( _ length: CGFloat ) -> CGPoint {
    let a = self.abs
    if a != 0 {
      var ret = CGPoint(x:0, y:0)
      let angle = CGFloat.pi/2 - asin(y/abs)
      ret.x = Swift.abs( length*cos(angle) )
      ret.y = Swift.abs( length*sin(angle) )
      if x > 0 {
        if y > 0 { ret.x = -ret.x }
      }
      else {
        if y > 0 { ret = -ret }
        else { ret.y = -ret.y }
      }
      if length < 0 { ret = -ret }
      return ret
    }
    else {
      return CGPoint(x:0, y:0)
    }
  }
  
  /** returns a pair of Bezier points for a curve from *self* to *to*.
    - parameter: bending ([0.0, 1.0])
  */
  func bezierPoints( _ to:CGPoint, bending:CGFloat ) -> (CGPoint, CGPoint) {
    let vec = self.vector(to)
    let perp = vec.perpendicular(vec.abs*bending)
    let rp1 = perp + 0.33*vec, rp2 = perp + 0.66*vec
    return (self + rp1, self + rp2)
  }
  
  /// toString returns a String representation
  public func toString() -> String { return "(x:\(x),y:\(y))" }
  
  /// description simply calls toString
  public var description: String { return toString() }
  
}

public extension UIBezierPath {

  /// draw a circle at center with radius either clockwise (default)
  /// or anti clockwise
  func circle( _ center:CGPoint, radius:CGFloat, clockwise:Bool = true ) {
    addArc(withCenter: center, radius: radius, startAngle: 0,
                     endAngle: 2*CGFloat.pi, clockwise: clockwise)
  }
  
  func addCurve( _ to:CGPoint, bending:CGFloat ) {
    let (p1,p2) = currentPoint.bezierPoints(to, bending: bending)
    self.addCurve(to: to, controlPoint1: p1, controlPoint2: p2)
  }
  
  func curve( _ from:CGPoint, to:CGPoint, bending:CGFloat ) {
    move(to: from)
    addCurve(to, bending: bending)
  }
    
  func strokeWithShade( _ blur: CGFloat ) {
    if let ctx = UIGraphicsGetCurrentContext() {
      UIGraphicsPushContext(ctx)
      ctx.setShadow(offset: CGSize(width: 0.0, height: 0.0), blur: blur)
      ctx.addPath(self.cgPath)
      ctx.setLineWidth(self.lineWidth)
      ctx.setLineJoin(self.lineJoinStyle)
      ctx.strokePath()
      UIGraphicsPopContext()
    }
  }
  
  func fillWithShade( _ blur: CGFloat ) {
    if let ctx = UIGraphicsGetCurrentContext() {
      UIGraphicsPushContext(ctx)
      ctx.setShadow(offset: CGSize(width: 0.0, height: 0.0), blur: blur)
      ctx.addPath(self.cgPath)
      ctx.drawPath(using: .fill)
      UIGraphicsPopContext()
    }
  }

}
