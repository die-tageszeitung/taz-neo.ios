//
//  Toolbar.swift
//
//  Created by Norbert Thies on 20.07.16.
//  Copyright © 2016 Norbert Thies. All rights reserved.
//
//  This file implements a UIToolbar subclass named Toolbar and some buttons
//  for use in toolbars.
//

import UIKit

/**
  A ButtonView is a generic view that is used by derived classes to
  offer some common properties. Button views are expected to have two states,
  an activated state (when the button has been pressed) and an inactive state
  (which is the default state). The following common properties are supported:
 
  * color (black)<br/>
    the color used to draw the button in inactive state
  * activeColor (green)<br/>
    the color used to draw the button in active state
  * lineWidth (0.04)<br/>
    the width of stroked lines if the button is drawn out of lines, the
    lineWidth is a factor to the width of the view.
  * isActivated (false)<br/>
    whether to show the button in activated or inactive mode.
  * hinset (0)<br/>
    horizontal distance from the edge of the view to the drawing (as a factor
    to the views width).
  * vinset (0)<br/>
    vertical distance from the edge of the view to the drawing (as a factor
    to the views height).
  * inset <br/>
    if set, it will set hinset and vinset alike. If requested it will
    return max(hinset, vinset).
 
  All ButtonViews use a clear background color.
*/

class ButtonView: UIView {

  /// Main color used in drawing the button
  @IBInspectable
  var color: UIColor = UIColor.black { didSet { setNeedsDisplay() } }
  
  /// Color used in drawing the button if isActivated
  @IBInspectable
  var activeColor: UIColor = UIColor.green { didSet { setNeedsDisplay() } }

  // the color used for stroking lines
  var strokeColor: UIColor { return isActivated ? activeColor : color }
  
  /// The line width used for drawings as factor to the width of the view
  @IBInspectable
  var lineWidth: CGFloat = 0.04 { didSet { setNeedsDisplay() } }

  /// Will be set to true if the button is pressed
  var isActivated: Bool = false { didSet { setNeedsDisplay() } }
  
  /// Horizontal inset
  @IBInspectable
  var hinset: CGFloat = 0 { didSet { setNeedsDisplay() } }
  
  /// Vertical inset
  @IBInspectable
  var vinset: CGFloat = 0 { didSet { setNeedsDisplay() } }
  
  /// max(hinset, vinset)
  @IBInspectable
  var inset: CGFloat {
    get { return max(hinset, vinset) }
    set { hinset = newValue; vinset = newValue }
  }
  
  fileprivate func setup() {
    contentMode = .redraw
    backgroundColor = UIColor.clear
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }

} // class ButtonView


/**
  A FilpFlopView is a ButtonView that offers two different icon drawings. 
  One is the primary and the other the secondary icon. Depending on the
  property isBistable the icons are switched when the button is activated.
  
  * isBistable (true)<br/>
    if true the icons are switched when the button is activated
  * isPrimary (true)<br/>
    whether the primary icon is drawn in inactive state
*/

class FlipFlopView: ButtonView {

  /// Whether to use bistable mode
  @IBInspectable
  var isBistable: Bool = true { didSet { setNeedsDisplay() } }
  
  /// Whether the primary icon is drawn in inactive state
  @IBInspectable
  var isPrimary: Bool = true { didSet { setNeedsDisplay() } }
  
  // draw primary icon?
  var isDrawPrimary: Bool {
    if isBistable { return isPrimary != isActivated }
    else { return isPrimary }
  }
  
  // the color used for drawing
  override var strokeColor: UIColor
    { return isBistable ? color : super.strokeColor }

} // class FliFlopView


/** 
  A FlipFlop is a FlipFlopView consisting of two ButtonView's. By default
  in non activated state the primary ButtonView is displayed. In activated
  state the primary view is hidden and the secondary view is displayed
  (i.e. unhidden).
*/

@IBDesignable
class FlipFlop<Primary:ButtonView, Secondary:ButtonView>: FlipFlopView {

  /// Primary view
  var primary: Primary
  
  /// Secondary view
  var secondary: Secondary
  
  override var color: UIColor
    { didSet { primary.color = color; secondary.color = color } }
  override var lineWidth: CGFloat
    { didSet { primary.lineWidth = lineWidth; secondary.lineWidth = lineWidth } }
  override var hinset: CGFloat
    { didSet { primary.hinset = hinset; secondary.hinset = hinset } }
  override var vinset: CGFloat
    { didSet { primary.vinset = vinset; secondary.vinset = vinset } }

  override func setup() {
    super.setup()
    primary.frame = bounds
    secondary.frame = bounds
    addSubview(primary)
    addSubview(secondary)
    secondary.isHidden = true
  }
  
  override init(frame: CGRect) {
    primary = Primary()
    secondary = Secondary()
    super.init(frame: frame)
  }
  
  required init?(coder aDecoder: NSCoder) {
    primary = Primary()
    secondary = Secondary()
    super.init(coder: aDecoder)
  }
  
  override func draw(_ rect: CGRect) {
    primary.frame = bounds
    primary.isHidden = !isDrawPrimary
    secondary.frame = bounds
    secondary.isHidden = isDrawPrimary
  }
  
  override func layoutSubviews() {
    primary.frame = bounds
    secondary.frame = bounds
    super.layoutSubviews()
  }

} // class FlipFlop


/**
  A ButtonControl is a somewhat generic UIControl subclass intended as common base 
  class for various button UI controls. When the control is touched and released 
  inside its view, all target actions for *.TouchUpInside* are activated.
*/

@IBDesignable
class ButtonControl: UIControl {

  /// the ButtonView used to draw the button
  var view: ButtonView!
  
  /// Whether to show the primary or the secondary icon
  @IBInspectable
  var isPrimary: Bool {
    get {
      if let v = view as? FlipFlopView { return v.isPrimary }
      else { return true }
    }
    set {
      if let v = view as? FlipFlopView { v.isPrimary = newValue }
    }
  }
  
  /// Will in active mode the icon switch from primary to secondary icon?
  @IBInspectable
  var isBistable: Bool {
    get {
      if let v = view as? FlipFlopView { return v.isBistable }
      else { return false }
    }
    set {
      if let v = view as? FlipFlopView { v.isBistable = newValue }
    }
  }
  
  /// Main color used in drawing the button
  @IBInspectable
  var color: UIColor {
    get { return view.color }
    set { view.color = newValue }
  }
  
  /// Color used in drawing the button if isActivated
  @IBInspectable
  var activeColor: UIColor {
    get { return view.activeColor }
    set { view.activeColor = newValue }
  }

  /// The line width used for drawings as factor to the width of the view
  @IBInspectable
  var lineWidth: CGFloat {
    get { return view.lineWidth }
    set { view.lineWidth = newValue }
  }

  /// Horizontal inset
  @IBInspectable
  var hinset: CGFloat {
    get { return view.hinset }
    set { view.hinset = newValue }
  }
  
  /// Vertical inset
  @IBInspectable
  var vinset: CGFloat {
    get { return view.vinset }
    set { view.vinset = newValue }
  }
  
  /// max(hinset, vinset)
  @IBInspectable
  var inset: CGFloat {
    get { return view.inset }
    set { view.inset = newValue }
  }
  
  /// Closure will be called if the button has been pressed and is released
  var onPress: ((ButtonControl)->())? = nil
  
  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    view.isActivated = true
    return super.beginTracking(touch, with:event)
  }
  
  override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    view.isActivated = false
    super.endTracking( touch, with: event )
  }
  
  override func cancelTracking(with event: UIEvent?) {
    view.isActivated = false
    super.cancelTracking( with: event )
  }
  
  @objc fileprivate func buttonPressed() {
    if let closure = onPress {
      closure(self)
    }
  }
  
  func setup() {
    backgroundColor = UIColor.clear
    view.frame = bounds
    view.isUserInteractionEnabled = false
    addSubview(view)
    addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
  }
  
  init(view: ButtonView, frame: CGRect) {
    self.view = view
    super.init(frame: frame)
    setup()
  }
  
  convenience init( view: ButtonView, width: CGFloat, height: CGFloat? = nil ) {
    var h = width
    if height != nil { h = height! }
    self.init( view: view, frame: CGRect(x: 0, y: 0, width: width, height: h) )
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
 
  func barButton() -> UIBarButtonItem {
    let bb = UIBarButtonItem()
    bb.customView = self
    return bb
  }
  
}  // class ButtonControl


/**
  A Button is the generic version of a ButtonControl
*/

class Button<View: ButtonView>: ButtonControl {
  var button: View { return super.view as! View }
  init( frame: CGRect ) { super.init( view: View(), frame: frame ) }
  convenience init( width: CGFloat = 25, height: CGFloat = 25 ) {
    self.init( frame: CGRect(x: 0, y: 0, width: width, height: height) )
  }

  required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
  }
} // Button<View>


/**
  A SwitchControl is a ButtonControl subclass intended as common base class
  for various switch UI controls. When the control is touched, the property *on*
  (which is initially set to false) is set to its inverse value and all target
  actions for *.ValueChanged* are activated.
*/

@IBDesignable
class SwitchControl: ButtonControl {

  /// Defines the state of the switch (initially false)
  @IBInspectable
  var on: Bool = false {
    didSet {
      if on { view.isActivated = true }
      else { view.isActivated = false }
  } }
  
  /// Closure will be called if the state changes
  var onChange: ((SwitchControl)->())? = nil
  
  override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    super.endTracking( touch, with: event )
    if isTouchInside {
      on = !on
      sendActions( for: .valueChanged )
      if let closure = onChange {
        closure(self)
      }
    }
    else { cancelTracking(with: event) }
  }
  
} // class SwitchControl


/**
  A Switch is the generic version of a SwitchControl
*/

class Switch<View: ButtonView>: SwitchControl {
  var button: View { return super.view as! View }
  init( frame: CGRect ) { super.init( view: View(), frame: frame ) }
  convenience init( width: CGFloat = 25, height: CGFloat = 25 ) {
    self.init( frame: CGRect(x: 0, y: 0, width: width, height: height) )
  }

  required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
  }
} // Switch<View>


/**
  A PlusView is a FlipFlopView subclass showing a plus sign as its primary
  icon and a minus sign as secondary icon.
*/

@IBDesignable
class PlusView: FlipFlopView {
  
  override func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height, m = min(w,h),
        l = m * (1 - inset)
    let path = UIBezierPath()
    let a = CGPoint(x:(w-l)/2, y:h/2),
        b = CGPoint(x:a.x+l, y:a.y),
        c = CGPoint(x:w/2, y:(h-l)/2),
        d = CGPoint(x:c.x, y:c.y+l)
    path.move(to: a)
    path.addLine(to: b)
    if ( isDrawPrimary ) {
      path.move(to: c)
      path.addLine(to: d)
    }
    path.lineWidth = lineWidth * bounds.size.width
    strokeColor.setStroke()
    path.stroke()
  }
  
} // class PlusView


/**
  The MinusView is a convenience class derived from
  PlusView to draw the minus icon.
*/

class MinusView: PlusView {
  override func setup() {
    super.setup()
    isPrimary = false
  }
}


/**
  A RotatingTriangleView is a FlipFlop subclass containing a triangle filled
  with a certain color that can be rotated using an animation.
  Important:  In fact not the triangle but the complete view is rotated
  according to the property *angle*.
  As primary icon the triangle's tip is pointing east. The secondary icon
  is the same icon rotated animated by 90 degrees pointing south.
  This view is controlled by the following properties:
  * angle (0)<br/>
    Defines the rotation's angle in degrees (no animation)
  * animatedAngle (0)<br/>
    Defines the rotation's angle (in degrees) and triggers the rotation animation
  * color (black)<br/>
    The color used to fill the triangle
  * duration (0.2)<br/>
    The number of seconds the animation will last
    
  In active mode the angle is set to 90 degrees. An "active" color is not used.
*/

@IBDesignable
class RotatingTriangleView: FlipFlopView {

  fileprivate var _angle: Double = 0  // the real angle

  /// The angle (in degrees) by which the view is rotated
  @IBInspectable
  var angle:Double { // in degrees
    get { return _angle }
    set { rotate(newValue) }
  }
  
  /// The angle (in degrees) by which the view is rotated with animation
  var animatedAngle: Double {
    get { return _angle }
    set { rotate(newValue, isAnimated: true) }
  }
  
  override var isActivated: Bool
    { didSet { animatedAngle = isDrawPrimary ? 0 : 90 } }
  override var isPrimary: Bool
    { didSet { angle = isPrimary ? 0 : 90 } }
  
  /// The duration of the animated rotation in seconds (0.2)
  @IBInspectable
  var duration:Double = 0.2

  fileprivate func radians() -> CGFloat {
    return CGFloat( (angle/180) * Double.pi )
  }
  
  fileprivate func rotate(_ to:Double, isAnimated:Bool = false) -> Void {
    if ( to != _angle ) {
      _angle = to
      if ( isAnimated ) {
        UIView.animate(withDuration: duration, animations: {
          self.transform = CGAffineTransform(rotationAngle: self.radians())
      })  }
      else { self.transform = CGAffineTransform(rotationAngle: self.radians()) }
  } }

  override func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height, m = min(w,h),
        l = m * (1 - inset)
    let triangle = UIBezierPath()
    let a = CGPoint(x:(w-l)/2, y:(h-l)/2),
        b = CGPoint(x:a.x+l, y:h/2),
        c = CGPoint(x:a.x, y:h-(h-l)/2)
    triangle.move(to: a)
    triangle.addLine(to: b)
    triangle.addLine(to: c)
    triangle.close()
    strokeColor.setFill()
    triangle.fill()
    transform = CGAffineTransform(rotationAngle: radians())
  }
  
} // class RotatingTriangleView


/**
  A SelectionView is a UIView subclass showing a *V* inside a circle (indicating
  some kind of selection). This is the primary icon, if isPrimary==false, then the 
  primary icon is shown "crossed out" (meaning deselect something).
*/

@IBDesignable
class SelectionView: FlipFlopView {
  
  override fileprivate func setup() {
    super.setup()
    color = Param.innerColor
  }
  
  // ro = outer radius, ri = inner radius
  fileprivate struct Param {
    static let xRadius:CGFloat = 0.48       // of min(width,height)
    static let xInnerCircle:CGFloat = 0.8   // of ro
    static let x1:CGFloat = 2.0             // of ro-ri
    static let y1:CGFloat = 1.2             // of ro
    static let x2:CGFloat = 1.0             // of ro
    static let y2:CGFloat = 1.35            // of ro
    static let x3:CGFloat = 1.44            // of ro
    static let y3:CGFloat = 0.55            // of ro
    static let outerColor     = UIColor.rgb(0xffffff)
    static let innerColor     = UIColor.rgb(0xff0000)
    static let activeColor    = UIColor.rgb(0x00ff00)
    static let lineColor      = UIColor.rgb(0xffffff)
    static let crossLineColor = UIColor.rgb(0x000000)
    static let crossLineWidth:CGFloat = 0.4      // of ro-ri
    static let shadowBlur:CGFloat = 3.0
    static let bendLeft:CGFloat = -0.1
    static let bendRight:CGFloat = -0.1
  }
  
  override func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height, s = min(h, w)*(1-inset)
    let ro = s * Param.xRadius, ri = ro * Param.xInnerCircle
    let center = convert(self.center, from: self.superview)
    let offset = CGPoint( x: (w-s)/2, y: (h-s)/2 ) + (s/2-ro)
    let p1 = CGPoint( x:(ro-ri)*Param.x1, y:ro*Param.y1 ) + offset,
        p2 = CGPoint( x:Param.x2, y:Param.y2 ) * ro + offset,
        p3 = CGPoint( x:Param.x3, y:Param.y3 ) * ro + offset
    let path = UIBezierPath()
    path.circle(center, radius: ro)
    Param.outerColor.setFill()
    path.fillWithShade( Param.shadowBlur )
    path.removeAllPoints()
    path.circle(center, radius: ri)
    //if isActivated { Param.activeColor.setFill() } else { color.setFill() }
    strokeColor.setFill()
    path.fill()
    path.removeAllPoints()
    path.lineWidth = (lineWidth + 0.04) * w
    path.lineJoinStyle = .miter
    path.curve(p1, to: p2, bending: Param.bendLeft)
    path.addCurve(p3, bending: Param.bendRight)
    Param.lineColor.setStroke()
    //path.strokeWithShade( Param.shadowBlur )
    path.stroke()
    if !isDrawPrimary {
      var p = offset
      path.removeAllPoints()
      path.move(to: p)
      p = p + (2*ro, 2*ro)
      path.addLine(to: p)
      p = offset + (0, 2*ro)
      path.move(to: p)
      p = offset + (2*ro, 0)
      path.addLine(to: p)
      path.lineWidth = Param.crossLineWidth * (ro-ri)
      Param.crossLineColor.setStroke()
      //path.strokeWithShade(Param.shadowBlur)
      path.stroke()
    }
  }

} // class SelectionView


/**
  A GearWheelView is a ButtonView subclass showing a gear wheel
  using following properties:
  * diameter (0.9)<br/>
    the outer diameter of the wheel (as factor to min(width,height) of the view)
  * cogLength (0.3)<br/>
    the length of the gear wheel's cogs (as a factor to the radius)
  * cogWidth (1.0)<br/>
    the width of the cogs as a factor to the cog width at the inner
    wheel
  * thickness (0.35)<br/>
    the thickness of the inner wheel (as factor to the diameter)
  * nCogs (7)<br/>
    the number of cogs to draw
*/

@IBDesignable
class GearWheelView: ButtonView {

  /// outer diameter of the wheel
  @IBInspectable
  var diameter: CGFloat = 0.9 { didSet { setNeedsDisplay() } }
  
  /// number of cogs
  @IBInspectable
  var nCogs: Int = 7 { didSet { setNeedsDisplay() } }
  
  /// length of the gear wheel's cogs
  @IBInspectable
  var cogLength: CGFloat = 0.3 { didSet { setNeedsDisplay() } }
  
  /// the width of the cogs
  @IBInspectable
  var cogWidth: CGFloat = 1.0 { didSet { setNeedsDisplay() } }
  
  /// thickness of the inner wheel
  @IBInspectable
  var thickness: CGFloat = 0.35 { didSet { setNeedsDisplay() } }
  
  /// whether to draw a round outer wheel
  @IBInspectable
  var isRound: Bool = true { didSet { setNeedsDisplay() } }

  
  fileprivate var viewCenter: CGPoint { return convert(center, from: superview) }
  fileprivate var realDiameter: CGFloat {
    return min(bounds.size.width, bounds.size.height) * (1 - inset) * diameter
  }
  
  func drawCog( _ path: UIBezierPath, _ n: Int ) {
    let c = viewCenter, d = realDiameter,
        ro = d / 2, ri = (d - d * cogLength) / 2,
        alpha = 2 * CGFloat.pi / CGFloat(nCogs),
        beta = alpha * ri * cogWidth / (2 * ro),
        gamma = (alpha/2 - beta) / 2,
        aStart = alpha * CGFloat(n), aHalf = aStart + alpha/2, aEnd = aStart + alpha,
        p1 = CGPoint(x:ri*sin(aStart), y:-ri*cos(aStart)) + c,
        p2 = CGPoint(x:ri*sin(aHalf), y:-ri*cos(aHalf)) + c,
        p3 = CGPoint(x:ro*sin(aHalf+gamma), y:-ro*cos(aHalf+gamma)) + c,
        p4 = CGPoint(x:ro*sin(aEnd-gamma), y:-ro*cos(aEnd-gamma)) + c,
        p5 = CGPoint(x:ri*sin(aEnd), y:-ri*cos(aEnd)) + c
    if n == 0 { path.move(to: p1) }
    if isRound {
      let a = aStart - CGFloat.pi/2,
          e = a + alpha/2
      path.addArc(withCenter: c, radius: ri, startAngle: a,
                            endAngle: e, clockwise: true)
    }
    else { path.addLine(to: p2) }
    path.addLine(to: p3)
    path.addLine(to: p4)
    path.addLine(to: p5)
  }
  
  override func draw(_ rect: CGRect) {
    let path = UIBezierPath()
    path.lineJoinStyle = .miter
    for n in 0 ..< nCogs {
      drawCog( path, n )
    }
    path.close()
    let d = realDiameter, r = (d - d*(cogLength + thickness))/2
    var p = viewCenter
    p.x += r
    path.move(to: p)
    path.circle( viewCenter, radius: r, clockwise: true )
    path.usesEvenOddFillRule = true
    strokeColor.setFill()
    path.fill()
  }

} // class GearWheelView


/**
  A BookmarkView is a FlipFlopView subclass modelling a bookmark that is either
  set (fills entire view) or unset (reduced height, fills partial view). The primary
  icon is the unset bookmark.
*/

@IBDesignable
class BookmarkView: FlipFlopView {

  /// Whether the bookmark is transparent
  @IBInspectable
  var isTransparent:Bool = true {
    didSet { setNeedsDisplay() }
    
  }
  
  /// The fill color
  @IBInspectable
  var fillColor: UIColor = Param.color
  
  /// Whether to draw a line around the bookmark
  var isDrawLine: Bool = false
    { didSet { if isDrawLine { isTransparent = false } else { isTransparent = true } } }
  
  override func setup() {
    super.setup()
    hinset = 0.3
  }
  
  fileprivate struct Param {
    static let offHeight:CGFloat = 0.4 /// height factor if !isBookmark
    static let indent:CGFloat = 0.2   /// bookmark indentation relative to total height
    static let color:UIColor = UIColor.rgb(0xf02020) // bookmark color
    static let onAlpha:CGFloat = 0.7   /// view alpha value if isBookmark
    static let offAlpha:CGFloat = 0.3  /// view alpha value if !isBookmark
  }
  
  override func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height, ainset = w * hinset/2,
        lw = lineWidth * w
    let bmark = UIBezierPath()
    let bh = isDrawPrimary ? h * Param.offHeight : h-lw/2,
        bhi = bh - h * Param.indent,
        indent = CGPoint(x:w/2, y:bhi)
    bmark.move( to: CGPoint(x:ainset, y:lw/2) )
    bmark.addLine( to: CGPoint(x:w-ainset, y:lw/2) )
    bmark.addLine( to: CGPoint(x:w-ainset, y:bh) )
    bmark.addLine( to: indent )
    bmark.addLine( to: CGPoint(x:ainset, y:bh) )
    bmark.close()
    bmark.lineWidth = lw
    fillColor.setFill()
    strokeColor.setStroke()
    if isDrawLine {
      bmark.stroke()
      bmark.fill()
    }
    else { bmark.fillWithShade(5.0) }
    if isTransparent {
      self.alpha = isDrawPrimary ? Param.offAlpha : Param.onAlpha
    }
    else {
      self.alpha = 1.0
    }
  }
  
} // class BookmarkView


/**
  A PageView is a ButtonView subclass containing a stylized
  page.
  This view is controlled by the following properties:
  * dogearWidth (0.2)<br/>
    Width of page dogear as a factor to the view's width.
*/

@IBDesignable
class PageView: ButtonView {

  /// The relative width of the dogear.
  @IBInspectable
  var dogearWidth:Double = 0.3 { didSet { setNeedsDisplay() } }

  override func setup() {
    super.setup()
    hinset = 0.15
  }
  
  override func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height,
        lw = lineWidth * w,
        l = w * (1 - hinset) - 2*lw,
        dw = l * CGFloat(dogearWidth),
        hi = w * (hinset/2) + lw,
        vi = h * (vinset/2) + lw
    let a = CGPoint(x:hi, y:vi),
        b = CGPoint(x:a.x+l-dw, y:a.y),
        c = CGPoint(x:a.x+l, y:a.y+dw),
        d = CGPoint(x:a.x+l, y:h-vi),
        e = CGPoint(x:a.x, y:d.y),
        f = CGPoint(x:b.x, y:c.y)
    let page = UIBezierPath()
    page.move(to: a)
    page.addLine(to: b)
    page.addLine(to: c)
    page.addLine(to: d)
    page.addLine(to: e)
    page.addLine(to: a)
    page.move(to: b)
    page.addLine(to: f)
    page.addLine(to: c)
    page.lineWidth = lw
    strokeColor.setStroke()
    page.stroke()
  }
  
} // class PageView


/**
  A MenuView is a ButtonView subclass containing three horizontal lines 
*/

@IBDesignable
class MenuView: ButtonView {

  override func setup() {
    super.setup()
    hinset = 0.10
  }

  override func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height,
        lw = (lineWidth+0.01) * w,
        l = w * (1 - 2*hinset),
        hi = w * (hinset/2) + lw,
        vi = h * (vinset/2+0.1) + lw
    let a = CGPoint(x:hi, y:vi),
        b = CGPoint(x:a.x, y:h/2),
        c = CGPoint(x:a.x, y:h - vi)
    let lines = UIBezierPath()
    lines.move(to: a)
    lines.addLine(to: CGPoint(x:a.x + l, y:a.y))
    lines.move(to: b)
    lines.addLine(to: CGPoint(x:b.x + l, y:b.y))
    lines.move(to: c)
    lines.addLine(to: CGPoint(x:c.x + l, y:c.y))
    lines.lineWidth = lw
    strokeColor.setStroke()
    lines.stroke()
  }
  
} // class MenuView


/**
 A ContentsView is a ButtonView subclass containing five horizontal lines
 depicting a table of contents
 */

@IBDesignable
class ContentsTableView: ButtonView {
  
  override func setup() {
    super.setup()
    hinset = 0.10
  }
  
  override func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height,
    lw = (lineWidth+0.01) * w,
    l = w * (1 - 2*hinset),
    hi = w * (hinset/2) + lw,
    vi = h * (vinset/2+0.1) + lw,
    dist = (h - 2*vi)/4,
    sub = 0.2 * l
    let a = CGPoint(x:hi, y:vi),
    b = CGPoint(x:a.x+sub, y:a.y+dist),
    c = CGPoint(x:a.x, y:b.y+dist),
    d = CGPoint(x:a.x+sub, y:c.y+dist),
    e = CGPoint(x:a.x, y:d.y+dist)
    let lines = UIBezierPath()
    lines.move(to: a)
    lines.addLine(to: CGPoint(x:a.x + l, y:a.y))
    lines.move(to: b)
    lines.addLine(to: CGPoint(x:b.x + l - sub, y:b.y))
    lines.move(to: c)
    lines.addLine(to: CGPoint(x:c.x + l, y:c.y))
    lines.move(to: d)
    lines.addLine(to: CGPoint(x:d.x + l - sub, y:d.y))
    lines.move(to: e)
    lines.addLine(to: CGPoint(x:e.x + l, y:e.y))
    lines.lineWidth = lw
    strokeColor.setStroke()
    lines.stroke()
  }
  
} // class ContentsTableView


/**
  An ExportView is a ButtonView subclass drawing either a stylized
  export or import icon.
  This view is controlled by following properties:
  * arrowLength (0.6)<br/>
    length of the arrow as a factor to the view's height.
  * isImport (false)
    whether to draw import icon
*/

@IBDesignable
class ExportView: ButtonView {

  /// Draw import icon?
  @IBInspectable
  var isImport: Bool = false { didSet { setNeedsDisplay() } }

  /// The relative length of the arrow.
  @IBInspectable
  var arrowLength:Double = 0.6 { didSet { setNeedsDisplay() } }
 
  override func setup() {
    super.setup()
    hinset = 0.15
  }
  
  func drawArrow( _ icon: UIBezierPath ) {
    let w = bounds.size.width, h = bounds.size.height,
        vi = h * (vinset/2),
        al = h * CGFloat(arrowLength), // real arrow length
        ap = al * 0.4, // length of point
        xi = ap / CGFloat(sqrt(2.0))
    let a = CGPoint(x:w/2, y:vi),
        b = CGPoint(x:a.x, y:a.y+al)
    icon.move(to: a)
    icon.addLine(to: b)
    if ( !isImport ) {
      let c = CGPoint(x:a.x-xi, y:a.y+xi),
          d = CGPoint(x:a.x+xi, y:c.y)
      icon.move(to: a)
      icon.addLine(to: c)
      icon.move(to: a)
      icon.addLine(to: d)
    }
    else {
      let c = CGPoint(x:a.x-xi, y:b.y-xi),
          d = CGPoint(x:a.x+xi, y:c.y)
      icon.move(to: b)
      icon.addLine(to: c)
      icon.move(to: b)
      icon.addLine(to: d)
    }
  }
  
  func drawIcon() {
    let w = bounds.size.width, h = bounds.size.height,
        lw = lineWidth * w, // linewidth
        al = h * CGFloat(arrowLength), // real arrow length
        hi = w * (hinset/2) + lw,
        vi = h * (vinset/2) + lw
    let icon = UIBezierPath()
    // draw box
    let a = CGPoint(x:hi, y:vi+al/2),
        b = CGPoint(x:w/2-lw*2, y:a.y),
        c = CGPoint(x:w/2+lw*2, y:a.y),
        d = CGPoint(x:w-hi, y:a.y),
        e = CGPoint(x:d.x, y:h-vi),
        f = CGPoint(x:a.x, y:e.y)
    icon.move(to: a)
    icon.addLine(to: b)
    icon.move(to: c)
    icon.addLine(to: d)
    icon.addLine(to: e)
    icon.addLine(to: f)
    icon.addLine(to: a)
    drawArrow(icon)
    icon.lineWidth = lw
    icon.lineJoinStyle = .miter
    strokeColor.setStroke()
    icon.stroke()
  }
  
  override func draw(_ rect: CGRect) {
    drawIcon()
  }
  
} // class ExportView


/**
  The ImportView is a convenience class derived from 
  ExportView to draw the import icon.
*/

class ImportView: ExportView {
  override func setup() {
    super.setup()
    isImport = true
  }
}


/**
  A TextView is a ButtonView subclass drawing text into a UILabel
  that just fits the bounds minus insets.
*/

@IBDesignable
class TextView: ButtonView {

  var label = UILabel()
  
  @IBInspectable
  var text: String? {
    get { return label.text }
    set { label.text = newValue }
  }
  
  override func setup() {
    super.setup()
    label.font = UIFont.boldSystemFont(ofSize: 40.0)
    label.adjustsFontSizeToFitWidth = true
    label.textAlignment = .center
    label.numberOfLines = 0
    addSubview(label)
  }
  
  override func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height,
        vi = h * (vinset/2),
        hi = w * (hinset/2)
    var frame = bounds
    frame.size.width -= 2*hi
    frame.size.height -= 2*vi
    frame.origin.x = hi
    frame.origin.y = vi
    label.frame = frame
    label.textColor = strokeColor
  }
  
} // class TextView


/**
  A TrashBinView is a ButtonView subclass drawing  a stylized
  trash bin icon.
*/

@IBDesignable
class TrashBinView: ButtonView {

  override func setup() {
    super.setup()
    color = UIColor.red
  }
  
  func drawBin() {
    let bw = bounds.size.width, bh = bounds.size.height,
        lw = (lineWidth+0.02) * bw, // linewidth
        hi = bw * (hinset/2) + lw,
        vi = bh * (vinset/2) + lw,
        h = bw - 2*vi,
        w = bw - 2*hi,
        a = 0.15 * h,  // height of handle
        b = 0.35 * w,  // width of handle
        c = 0.8 * w,   // upper width of box
        d = 0.65 * w,  // lower width of box
        e = 0.1 * h,   // vertical spacing
        f = 0.05 * w   // horizontal spacing
    let bin = UIBezierPath()
    // draw box
    let p1 = CGPoint(x:(w-c)/2+hi, y:a+vi),
        p2 = CGPoint(x:(w-d)/2+hi, y:bh-e-vi),
        p3 = CGPoint(x:p2.x+f, y:p2.y+e),
        p4 = CGPoint(x:p2.x+d-f, y:p3.y),
        p5 = CGPoint(x:p4.x+f, y:p2.y),
        p6 = CGPoint(x:p1.x+c, y:p1.y),
        p7 = CGPoint(x:p1.x+c/3, y:p1.y+e),
        p8 = CGPoint(x:p2.x+d/3, y:p2.y),
        p9 = CGPoint(x:p6.x-c/3, y:p7.y),
        p10 = CGPoint(x:p5.x-d/3, y:p5.y),
        p11 = CGPoint(x:hi, y:p1.y),
        p12 = CGPoint(x:bw-hi, y:p1.y),
        p13 = CGPoint(x:(bw-b)/2, y:p1.y),
        p14 = CGPoint(x:p13.x, y:a/3+vi),
        p15 = CGPoint(x:p13.x+a/3, y:vi),
        p16 = CGPoint(x:p13.x+b-a/3, y:vi),
        p17 = CGPoint(x:p13.x+b, y:a/3+vi),
        p18 = CGPoint(x:p17.x, y:p1.y)
    bin.move(to: p1)
    bin.addLine(to: p2)
    bin.addCurve(p3, bending: 0.2)
    bin.addLine(to: p4)
    bin.addCurve(p5, bending: 0.2)
    bin.addLine(to: p6)
    bin.move(to: p7)
    bin.addLine(to: p8)
    bin.move(to: p9)
    bin.addLine(to: p10)
    bin.move(to: p11)
    bin.addLine(to: p12)
    bin.move(to: p13)
    bin.addLine(to: p14)
    bin.addCurve(p15, bending: -0.1)
    bin.addLine(to: p16)
    bin.addCurve(p17, bending: -0.1)
    bin.addLine(to: p18)
    bin.lineWidth = lw
    bin.lineJoinStyle = .miter
    strokeColor.setStroke()
    bin.stroke()
  }
  
  override func draw(_ rect: CGRect) {
    drawBin()
  }
  
} // class TrashBinView


/**
  A Toolbar is a UIToolbar subclass managing an array of subtoolbars.
  Each subtoolbar consists of a left, center and right section:
    toolbar:
      left section  <->  center section  <->  right section
  Each section in turn is an array of ButtonControl's. 
  By default one subtoolbar is created upon init. To create additional
  subtoolbars either use the method 'createBars' or add a ButtonControl
  via 'addButton' to a non existing toolbar.
 
  The following properties are available:
    * bar: Int (0)<br/>
      controls which subtoolbar is to display.
    * translucentColor: UIColor (black)<br/>
      defines the color of the translucent background view
    * translucentAlpha: CGFloat (0.1)<br/>
      defines the alpha of the translucent background view
*/

@IBDesignable
class Toolbar: UIToolbar {

  class TButtons {
  
    var left:   Array<ButtonControl> = []
    var center: Array<ButtonControl> = []
    var right:  Array<ButtonControl> = []
    
    func buttonItems() -> Array<UIBarButtonItem> {
      var ret: Array<UIBarButtonItem> = []
      for b in left {
        ret.append(b.barButton())
      }
      ret.append(Toolbar.space())
      if center.count > 0 {
        for b in center {
          ret.append(b.barButton())
      } }
      ret.append(Toolbar.space())
      if right.count > 0 {
        for b in right {
          ret.append(b.barButton())
      } }
      return ret
    }
    
  } // class Toolbar.TButtons
  
  fileprivate var bars = [ TButtons() ]
  
  fileprivate var _bar = 0

  /// number of the bar to display
  var bar: Int {
    get { return _bar }
    set {
      if (newValue < bars.count) && (newValue != _bar) {
        _bar = newValue;
        items = nil
        items = bars[_bar].buttonItems()
  } } }
  
  /// color of translucent background
  @IBInspectable
  var translucentColor: UIColor = UIColor.black { didSet { setNeedsDisplay() } }
  
  /// alpha of translucent background
  @IBInspectable
  var translucentAlpha: CGFloat = 0.1 { didSet { setNeedsDisplay() } }
  
  /// perform closure on all buttons
  func doButtons( _ closure: (ButtonControl)->() ) {
    for b in bars {
      for bt in b.left {
        closure(bt)
      }
      for bt in b.center {
        closure(bt)
      }
      for bt in b.right {
        closure(bt)
      }
  } }
  
  /// set color of buttons
  func setButtonColor( _ color: UIColor ) {
    doButtons { (b: ButtonControl) in b.color = color }
  }

  /// set active color of buttons
  func setActiveButtonColor( _ color: UIColor ) {
    doButtons { (b: ButtonControl) in b.activeColor = color }
  }
  
  /// create the given number of bars
  func createBars( _ n: Int ) {
    if n > bars.count {
      for _ in bars.count..<n { bars.append( TButtons() ) }
    }
  }
  
  /// section to use for adding a button
  enum Direction { case left; case center; case right }
  
  /// adds a button to a subtoolbar
  func addButton( _ button: ButtonControl, direction: Direction, at: Int ) {
    createBars( at+1 )
    switch direction {
      case .left:   bars[at].left.append(button)
      case .center: bars[at].center.append(button)
      case .right:  bars[at].right.append(button)
    }
  }
  
  /// adds a button to all subtoolbars
  func addButton( _ button: ButtonControl, direction: Direction ) {
    let n = bars.count
    for i in 0..<n {
      addButton(button, direction: direction, at: i)
  } }
  
  fileprivate var translucentBackground = UIView()

  func setup() {
    contentMode = .redraw
    backgroundColor = UIColor.clear
    setBackgroundImage(UIImage(), forToolbarPosition: UIBarPosition.any,
      barMetrics: UIBarMetrics.default)
    setShadowImage(UIImage(), forToolbarPosition: UIBarPosition.any)
    addSubview(translucentBackground)
    translucentBackground.translatesAutoresizingMaskIntoConstraints = false
    translucentBackground.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    translucentBackground.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    translucentBackground.topAnchor.constraint(equalTo: topAnchor).isActive = true
    translucentBackground.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
  }

  override func draw(_ rect: CGRect) {
    translucentBackground.backgroundColor = translucentColor
    translucentBackground.alpha = translucentAlpha
    if items == nil { items = bars[_bar].buttonItems() }
    super.draw(rect)
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }
  
  convenience init() { self.init(frame:CGRect(x: 0, y: 0, width: 0, height: 0)) }
  
  /// Returns a flexible space to put into Toolbars
  class func space() -> UIBarButtonItem {
    return UIBarButtonItem( barButtonSystemItem: .flexibleSpace,
      target: nil, action: nil)
  }
  
  /// places the Toolbar via autolayout either to the top or to the bottom
  /// of the given view.
  func placeInView( _ view: UIView, isTop: Bool = true ) {
    view.addSubview(self)
    translatesAutoresizingMaskIntoConstraints = false
    leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    if isTop {
      topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    }
    else {
      bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
  }

  /// places the Toolbar via autolayout either to the top or to the bottom
  /// of the given view controllers layout guides.
  func placeInViewController( _ vc: UIViewController, isTop: Bool = true ) {
    vc.view.addSubview(self)
    translatesAutoresizingMaskIntoConstraints = false
    leadingAnchor.constraint(equalTo: vc.view.leadingAnchor).isActive = true
    trailingAnchor.constraint(equalTo: vc.view.trailingAnchor).isActive = true
    if isTop {
      topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor).isActive = true
    }
    else {
      bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }
  }
  
} // class Toolbar
