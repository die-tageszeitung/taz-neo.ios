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
  
  
  // MARK: tageszeitung label + dotted line
  lazy var header : UIView = {
    let v = UIView()
    v.backgroundColor = .red
    v.pinHeight(70)
    v.addBorder(.green)
    return v
  }()
  
  // MARK: intro
  lazy var introLabel : UILabel = {
    let lb = UILabel()
    lb.paddingTop = 120
    lb.text = NSLocalizedString("login_missing_credentials_header_registration", comment: "taz Id Account Create")
    lb.numberOfLines = 0
    lb.textAlignment = .center
    return lb
  }()
  
  // MARK: switchToTazIdButton
  lazy var switchToTazIdButton : UIButton = {
    let btn = UIButton()
    let txt = NSLocalizedString("login_missing_credentials_switch_to_login", comment: "taz Id Account Create")
    btn.setTitle(txt, for: .normal)
    btn.backgroundColor = .clear
    //    btn.paddingBottom = 112
    btn.setTitleColor(.red, for: .normal)
    btn.addBorder(.purple)
    return btn
  }()
  
  // MARK: mail input
  lazy var mailInput : UITextField = {
    let tf = UITextField()
    tf.pinHeight(40)
    tf.paddingTop = 120
    //      tf.paddingBottom = 820
    tf.placeholder = "E-Mail *"
    tf.addBorder(.magenta)
    return tf
  }()
  
  // MARK: pwInput
  lazy var pwInput : UITextField = {
    let tf = UITextField()
    //    tf.paddingTop = 110
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

    /*
     Performance Test in Simulator
     Dauer auf 4.2GHZ 4Cores*2Threads < 10s
     Resultat: Kein Memory Impact!
    for i in 0...500000 {
//      print("Loop:", i)
      let v = UIView()
      //200MB => 32MB
//      v.backgroundColor = .red
      //178MB => 33MB
      v.paddingTop = 1
      v.paddingBottom = 1
    }
     */
    
    
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
    NorthLib.pin(previous!.bottom, to: self.bottom, dist: -margin)
  }
}

/// Pin all edges, except one of one view to the edges of another view's safe layout guide
public func pin(_ view: UIView, to: UIView, dist: CGFloat = 0, exclude: UIRectEdge? = nil) {
  exclude != UIRectEdge.top ? _ = NorthLib.pin(view.top, to: to.top, dist: dist) : nil
  exclude != UIRectEdge.left ? _ = NorthLib.pin(view.left, to: to.left, dist: dist) : nil
  exclude != UIRectEdge.right ? _ = NorthLib.pin(view.right, to: to.right, dist: -dist) : nil
  exclude != UIRectEdge.bottom ? _ = NorthLib.pin(view.bottom, to: to.bottom, dist: -dist) : nil
}

/// borders Helper
extension UIView {
  func addBorder(_ color:UIColor = .red, _ width:CGFloat=1.0){
    self.layer.borderColor = color.cgColor
    self.layer.borderWidth = width
  }
}

/// Max PaddingHelper
func padding(_ topView:UIView, _ bottomView:UIView) -> CGFloat{
  return max(topView.paddingBottom, bottomView.paddingTop)
}

/// View additional Properties (Padding) Helper, add static properties to Instances
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
