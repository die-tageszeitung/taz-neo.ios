//
// UIHelper.swift
//
// Created by Ringo Müller-Gromes on 31.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//

import UIKit
import NorthLib



public typealias tblrConstrains = (
  top: NSLayoutConstraint?,
  bottom: NSLayoutConstraint?,
  left: NSLayoutConstraint?,
  right: NSLayoutConstraint?)

// MARK: - pinnAll Helper
///borders Helper
/// Pin all edges, except one of one view to the edges of another view's safe layout guide
@discardableResult
public func pin(_ view: UIView, to: UIView, dist: CGFloat = 0, exclude: UIRectEdge? = nil) -> tblrConstrains {
  var top:NSLayoutConstraint?, left:NSLayoutConstraint?, bottom:NSLayoutConstraint?, right:NSLayoutConstraint?
  exclude != UIRectEdge.top ? top = NorthLib.pin(view.top, to: to.top, dist: dist) : nil
  exclude != UIRectEdge.left ? left = NorthLib.pin(view.left, to: to.left, dist: dist) : nil
  exclude != UIRectEdge.right ? right = NorthLib.pin(view.right, to: to.right, dist: -dist) : nil
  exclude != UIRectEdge.bottom ? bottom = NorthLib.pin(view.bottom, to: to.bottom, dist: -dist) : nil
  return (top, bottom, left, right)
}

public func pin(_ view: UIView, toSafe: UIView, dist: CGFloat = 0, exclude: UIRectEdge? = nil) -> tblrConstrains {
  var top:NSLayoutConstraint?, left:NSLayoutConstraint?, bottom:NSLayoutConstraint?, right:NSLayoutConstraint?
  exclude != UIRectEdge.top ? top = NorthLib.pin(view.top, to: toSafe.topGuide(), dist: dist) : nil
  exclude != UIRectEdge.left ? left = NorthLib.pin(view.left, to: toSafe.leftGuide(), dist: dist) : nil
  exclude != UIRectEdge.right ? right = NorthLib.pin(view.right, to: toSafe.rightGuide(), dist: -dist) : nil
  exclude != UIRectEdge.bottom ? bottom = NorthLib.pin(view.bottom, to: toSafe.bottomGuide(), dist: -dist) : nil
  return (top, bottom, left, right)
}


// MARK: - BorderView
/// Just to detect by Classname for borders Helper
class BorderView : UIView {}

// MARK: - borders Helper
///borders Helper
extension UIView {
  
  
  func addBorder(_ color:UIColor = TazColor.CIColor.color,
                 _ width:CGFloat=1.0,
                 only: UIRectEdge? = nil){
    if only == nil {
      self.layer.borderColor = color.cgColor
      self.layer.borderWidth = width
      return
    }
    
    removeBorders()
    
    let b = BorderView()
    b.backgroundColor = color
    
    self.addSubview(b)
    if only == UIRectEdge.top || only == UIRectEdge.bottom {
      b.pinHeight(width)
      pin(b.left, to: self.left)
      pin(b.right, to: self.right)
    }
    else {
      b.pinWidth(width)
      pin(b.top, to: self.top)
      pin(b.bottom, to: self.bottom)
    }
    
    if only == UIRectEdge.top {
      pin(b.top, to: self.top)
    }
    else if only == UIRectEdge.bottom {
      pin(b.bottom, to: self.bottom)
    }
    else if only == UIRectEdge.left {
      pin(b.left, to: self.left)
    }
    else if only == UIRectEdge.right {
      pin(b.right, to: self.right)
    }
  }
  
  func removeBorders(){
    self.layer.borderColor = UIColor.clear.cgColor
    self.layer.borderWidth = 0.0
    
    for case let border as BorderView in self.subviews {
      border.removeFromSuperview()
    }
  }
  
  func onTapping(closure: @escaping (UITapGestureRecognizer)->()){
    let gr = TapRecognizer()
    gr.onTap(view: self, closure: closure)
  }
}




// MARK: -  PaddingHelper
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

extension UILabel {
  /// sets the new text animate height and alpha with a smooth Animation
  /// - Parameter newText: text to set
  func setTextAnimated(_ newText:String?){
    ///usually animate 3 levels heigher in case of ugly behaviour look for an scrollview
    /// or container that is not pinned top and bottom
    let viewToAnimate =
      self.superview?.superview ?? self.superview ?? self
    
    //animate hight while hiding using snaphot
    if true, let snapshot = self.snapshotView(afterScreenUpdates: false){
      snapshot.frame = self.frame
      self.superview?.addSubview(snapshot)
      self.alpha = 0.0
      self.text = newText
      viewToAnimate.setNeedsUpdateConstraints()
       
      UIView.animateKeyframes(withDuration: 2.0, delay: 0.0, animations: {
        UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.55) {
          snapshot.alpha = 0.0 //hide 0...0.4
        }
        UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.5) {
          viewToAnimate.layoutIfNeeded()//height 0.2...0.8
        }
        UIView.addKeyframe(withRelativeStartTime: 0.45, relativeDuration: 0.55) {
          self.alpha = 1.0// show 0.6 ...1
        }
      }, completion:{ (_) in
        snapshot.removeFromSuperview()
      })
    }
    else {//animate in steps, 1st hide then size&alpha
      UIView.animate(withDuration: 1.0, animations: {
        self.alpha = 0.0
      }, completion: { (_) in
        self.text = newText
        viewToAnimate.setNeedsUpdateConstraints()
        UIView.animate(withDuration: 1.5,animations: {
          viewToAnimate.layoutIfNeeded()
        })
        UIView.animate(withDuration: 0.7, delay: 1.3, animations: {
          self.alpha = 1.0
        })
      })
    }
  }
}


// MARK: - extension UIButton:setBackgroundColor
extension UIButton {
  func setBackgroundColor(color: UIColor, forState: UIControl.State) {
    self.clipsToBounds = true  // support corner radius
    UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
    if let context = UIGraphicsGetCurrentContext() {
      context.setFillColor(color.cgColor)
      context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
      let colorImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      self.setBackgroundImage(colorImage, for: forState)
    }
  }
}

// MARK: - extension UIImage with systemName fallback named
extension UIImage {
  /// Creates an image
  /// iOS 13 and later: object containing a system symbol image referenced by given name
  /// earlier: using the named image asset
  ///
  /// Example
  /// ```
  /// UIImage(name: "checkmark") // Creates image
  /// ```
  ///
  /// #challenge: SFSymbol's images for iOS 12
  ///  using: https://github.com/davedelong/sfsymbols
  ///  but currently it has an issue, and uses Thin Symbol Images
  ///  so convert images that way:
  ///  sfsymbols --symbol-name eye.slash.fill  --font-file /Library/Fonts/SF-Pro-Display-Regular.otf --font-size 18 --format pdf --output converted
  ///  to ensure same "eye" size eye.slash has font-size 17 and eye font-size 18 ;-)
  ///
  ///  While import to xcassets ensure:
  ///  - Scales: single scale
  ///  - Render as: Template Image
  ///
  /// - Warning: May return nil if Image for given name does not exist
  /// - Parameter name: the image name
  /// - Returns: UIImage related to `name`.
  convenience init?(name:String) {
    if #available(iOS 13.0, *){
      self.init(systemName: name)
    }
    else{
      ///Symbol Names with a dot like eye.slash cannot be loaded from asset catalog
      let name = name.replacingOccurrences(of: ".", with: "_")
      self.init(named: name)
    }
  }
}

// MARK: - extension String isValidEmail
extension String {
  func isValidEmail() -> Bool {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
    return emailPred.evaluate(with: self)
  }
}

extension UIButton {
  func touch(_ target: Any?, action:Selector){
    self.addTarget(target, action: action, for: .touchUpInside)
  }
}

// MARK: - Localized Helper without Comment
public func Localized(_ key: String) -> String {
  return NSLocalizedString(key, comment: "n/a")
}
public func Localized(keyWithFormat: String, _  arguments: CVarArg...) -> String {
  return String(format: Localized(keyWithFormat), arguments: arguments)
}

// MARK: - Color Helper to use iOS Build in Dark/LightMode
enum TazColor{
  case CTBackground
  case CTSection
  case CTArticle
  case CTDate
  case HBackground
  case HText
  case Test
  case CIColor
  
  var color : UIColor {
    get{
      let set = colors(name: self)
      if #available(iOS 13, *) {
        return UIColor { (traitCollection: UITraitCollection) -> UIColor in
          switch(traitCollection.userInterfaceStyle,
                 traitCollection.accessibilityContrast)
          {
            case (.dark, .high): return ((set.darkHigh != nil) ? set.darkHigh : set.dark) ?? set.light
            case (.dark, _):     return set.dark ?? set.light
            case (_, .high):     return  set.lightHigh ?? set.light
            default:             return set.light
          }
        }
      }
      else {
        return set.light
      }
    }
  }
  
  fileprivate typealias ColorSet = ( light: UIColor, dark: UIColor?, lightHigh: UIColor?, darkHigh: UIColor?)
  
  fileprivate func colors(name: TazColor) -> ColorSet {
    switch name {
      case .CTBackground:
        return (UIColor.white, Const.Colors.darkSecondaryBG,nil,nil)
      case .CTSection:
        return (Const.Colors.ciColor, Const.Colors.darkSecondaryText,nil,nil)
      case .CTArticle:
        return (UIColor.darkGray, UIColor.rgb(0xacace0),nil,nil)
      case .CTDate:
        return (UIColor.black, UIColor.white,nil,nil)
      case .HBackground:
        return (UIColor.white, Const.Colors.darkSecondaryBG,nil,nil)
      case .HText:
        return (UIColor.black, Const.Colors.darkSecondaryText,nil,nil)
      case .Test://Rainbow: use to test Light/Darkmode with lightHigh & darkHigh
        return (UIColor.red, UIColor.green, UIColor.blue,UIColor.magenta)
      case .CIColor:
        return (Const.Colors.ciColor,nil,nil,nil)
    }
  }
}
