//
//
// RegisterView.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

/// A MomentView displays an Image, an optional Spinner and an
/// optional Menue.
public class RegisterView: UIView {
  
  // MARK: - init
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  
  //tageszeitung label + dotted line
  lazy var header : UIView = {
    let v = UIView()
    v.backgroundColor = .red
    v.pinHeight(70)
    v.addBorder(.green)
    return v
  }()
  
  //intro
  lazy var introLabel : UILabel = {
    let lb = UILabel()
    lb.paddingTop = 120
    lb.text = "Sollten sie bereits bei taz.de mit E-Mail-Adresse und Passwort registriert sein (um dort Texte zu kommentieren oder das Archiev zu nutzen) geben Sie hier bitte diese Daten an."
    lb.numberOfLines = 0
    lb.addBorder()
    return lb
  }()
  
  //intro
  lazy var switchToTazIdButton : UIButton = {
    let btn = UIButton()
    btn.setTitle("habe schon taz id", for: .normal)
    btn.backgroundColor = .clear
    btn.paddingBottom = 112
    btn.setTitleColor(.red, for: .normal)
    btn.addBorder(.purple)
    return btn
  }()

  //mail input
  lazy var mailInput : UITextField = {
    let tf = UITextField()
    tf.pinHeight(40)
    tf.paddingTop = 120
      tf.paddingBottom = 820
    tf.placeholder = "E-Mail *"
    tf.addBorder(.magenta)
    return tf
  }()
  
  //mail input
  lazy var pwInput : UITextField = {
    let tf = UITextField()
    tf.paddingTop = 110
    tf.pinHeight(40)
    tf.borderStyle = .line
    tf.placeholder = "Passwort *"
    tf.addBorder(.cyan)
    return tf
  }()
  // MARK: - setup
  func setup() {
    addAndPin(registerViews)
    self.backgroundColor = .yellow
  }
  
  lazy var registerViews : [UIView] = {
      return [header, introLabel, switchToTazIdButton, mailInput, pwInput]
  }()
  
  func addAndPin(_ views: [UIView]){
    let margin : CGFloat = 12.0
    var previous : UIView?
    for v in views {
      //add
      self.addSubview(v)
      //pin
      if previous == nil {
        pin(v, to: self, dist: margin, exclude: .bottom)
      }
      else {
        NorthLib.pin(v.left, to: self.left, dist: margin)
        NorthLib.pin(v.right, to: self.right, dist: -margin)
        NorthLib.pin(v.top, to: previous!.bottom, dist: padding(previous!, v))
      }
      previous = v
    }
    NorthLib.pin(previous!.bottom, to: self.bottom, dist: margin)
  }
}

/// Pin all edges, except one of one view to the edges of another view's safe layout guide
public func pin(_ view: UIView, to: UIView, dist: CGFloat = 0, exclude: UIRectEdge? = nil) {
  exclude != UIRectEdge.top ? _ = NorthLib.pin(view.top, to: to.top, dist: dist) : nil
  exclude != UIRectEdge.left ? _ = NorthLib.pin(view.left, to: to.left, dist: dist) : nil
  exclude != UIRectEdge.right ? _ = NorthLib.pin(view.right, to: to.right, dist: -dist) : nil
  exclude != UIRectEdge.bottom ? _ = NorthLib.pin(view.bottom, to: to.bottom, dist: -dist) : nil
}

/// borders
extension UIView {
  func addBorder(_ color:UIColor = .red, _ width:CGFloat=1.0){
    self.layer.borderColor = color.cgColor
    self.layer.borderWidth = width
  }
}

func padding(_ topView:UIView, _ bottomView:UIView) -> CGFloat{
  return max(topView.paddingBottom, bottomView.paddingTop)
}

extension UIView {
  private static var _paddingTop = [String:CGFloat]()
  private static var _paddingBottom = [String:CGFloat]()
  
  var paddingTop:CGFloat {
      get {
          let tmpAddress = String(format: "%p", unsafeBitCast(self, to: Int.self))
        return UIView._paddingTop[tmpAddress] ?? 12.0
      }
      set(newValue) {
          let tmpAddress = String(format: "%p", unsafeBitCast(self, to: Int.self))
          UIView._paddingTop[tmpAddress] = newValue
      }
  }
  
  var paddingBottom:CGFloat {
      get {
          let tmpAddress = String(format: "%p", unsafeBitCast(self, to: Int.self))
        return UIView._paddingBottom[tmpAddress] ?? 12.0
      }
      set(newValue) {
          let tmpAddress = String(format: "%p", unsafeBitCast(self, to: Int.self))
          UIView._paddingBottom[tmpAddress] = newValue
      }
  }
}
