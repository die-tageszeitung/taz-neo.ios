//
//
// RegisterView.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

fileprivate let MiniPageNumberFontSize = CGFloat(12)
fileprivate let DefaultFontSize = CGFloat(16)
fileprivate let LargeTitleFontSize = CGFloat(34)
fileprivate let DottedLineHeight = CGFloat(2.4)

// MARK: - FormularView
/// A RegisterView displays an RegisterForm
public class FormularView: UIView {
  
  var views : [UIView] = []{
    didSet{
      addAndPin(views)
      self.backgroundColor = TazColor.CTBackground.color
    }
  }
  
  lazy var errorLabel: UILabel = {
    let lb = ErrorLabel()
    lb.font = AppFonts.contentFont(size: DefaultFontSize)
    lb.numberOfLines = 0
    lb.textColor = TazColor.CIColor.color
    lb.textAlignment = .center
    return lb
  }()
  
  fileprivate class ErrorLabel : UILabel {
    override init(frame: CGRect) {
      super.init(frame:frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      super.init(coder:coder)
      setup()
    }
    
    func setup(){
      heightConstraint = self.pinHeight(0)
      self.alpha = 0.0
    }
    var heightConstraint:NSLayoutConstraint?
    
    override var text: String?{
      didSet{
        let newHeight = self.sizeThatFits(CGSize(width: self.frame.size.width,
                                                 height: .infinity)).height
        self.heightConstraint?.constant = (self.text ?? "").isEmpty ? 0 : newHeight
        UIView.animate(withDuration: 0.2) {
          self.superview?.layoutIfNeeded()
          self.alpha = (self.text ?? "").isEmpty ? 0 : 1
        }
      }
    }
  }
  
  // MARK: Container for Content in ScrollView
  let container = UIView()
  // MARK: - init
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  func setup(){}
  
  static func header(paddingBottom: CGFloat = 30) -> UIView {
    let container = UIView()
    let title = UILabel()
    let line = DottedLineView()
    line.fillColor = TazColor.CTDate.color
    title.text = NSLocalizedString("die tageszeitung",
                                   comment: "taz_title")
    title.font = AppFonts.contentFont(size: LargeTitleFontSize)
    title.textAlignment = .right
    
    container.addSubview(title)
    container.addSubview(line)
    
    pin(title, to: container, dist: 0, exclude: .bottom)
    pin(line, to: container, dist: 0, exclude: .top)
    NorthLib.pin(line.top, to: title.bottom)
    line.pinHeight(DottedLineHeight)
    container.paddingBottom = paddingBottom
    return container
  }
  
  
  static func label(title: String? = nil,
                    font: UIFont = AppFonts.contentFont(size: DefaultFontSize),
                    paddingTop: CGFloat = 8,
                    paddingBottom: CGFloat = 8) -> UILabel {
    let lb = UILabel()
    lb.text = title
    lb.font = font
    lb.paddingTop = paddingTop
    lb.paddingBottom = paddingBottom
    lb.numberOfLines = 0
    lb.textAlignment = .center
    return lb
  }
  
  
  static func button(title: String? = NSLocalizedString("Senden", comment: "Send Button Title"),
                     color: UIColor = TazColor.CIColor.color,
                     textColor: UIColor = .white,
                     height: CGFloat = 40,
                     paddingTop: CGFloat = 20,
                     paddingBottom: CGFloat = 20,
                     target: Any? = nil,
                     action: Selector? = nil) -> UIButton {
    let btn = UIButton()
    if let title = title {
      btn.setTitle(title, for: .normal)
    }
    btn.backgroundColor = color
    btn.setTitleColor(textColor, for: .normal)
    btn.layer.cornerRadius = 4.0
    btn.pinHeight(height)
    btn.paddingTop = paddingTop
    btn.paddingBottom = paddingBottom
    if let target = target, let action = action {
      btn.addTarget(target, action: action, for: .touchUpInside)
    }
    return btn
  }
  
  static func outlineButton(title: String? = NSLocalizedString("Senden", comment: "Send Button Title"),
                            paddingTop: CGFloat = 20,
                            paddingBottom: CGFloat = 20,
                            target: Any? = nil,
                            action: Selector? = nil) -> UIButton {
    let btn = Self.button(title:title,
                          paddingTop: paddingTop,
                          paddingBottom: paddingBottom,
                          target: target,
                          action: action)
    btn.backgroundColor = .clear
    btn.addBorder(TazColor.CIColor.color, 1.0)
    btn.setTitleColor(TazColor.CIColor.color, for: .normal)
    return btn
  }
  
  static func labelLikeButton(title: String? = NSLocalizedString("Senden", comment: "Send Button Title"),
                              paddingTop: CGFloat = 20,
                              paddingBottom: CGFloat = 20,
                              target: Any? = nil,
                              action: Selector? = nil) -> UIButton {
    let btn = Self.button(title:title,
                          paddingTop: paddingTop,
                          paddingBottom: paddingBottom,
                          target: target,
                          action: action)
    btn.backgroundColor = .clear
    btn.setTitleColor(TazColor.CIColor.color, for: .normal)
    return btn
  }
  
  // MARK: pwInput
  static func textField(prefilledText: String? = nil,
                        placeholder: String? = nil,
                        textContentType: UITextContentType? = nil,
                        color: UIColor = TazColor.CIColor.color,
                        textColor: UIColor = TazColor.CIColor.color,
                        height: CGFloat = 40,
                        paddingTop: CGFloat = 40,
                        paddingBottom: CGFloat = 40,
                        isSecureTextEntry: Bool = false,
                        target: Any? = nil,
                        action: Selector? = nil) -> UITextField {
    let tf = TazTextField()
    tf.pinHeight(height)
    tf.paddingTop = paddingTop
    tf.paddingBottom = paddingBottom
    tf.placeholder = placeholder
    //tf.borderStyle = .line //Border Bottom Alternative
    //    tf.addBorder(.gray, 1.0, only:UIRectEdge.bottom)
    tf.textContentType = .password
    tf.isSecureTextEntry = isSecureTextEntry
    
    if #available(iOS 13.0, *), isSecureTextEntry {
      let imgEye = UIImage(systemName: "eye.fill")?
        .withRenderingMode(.alwaysOriginal)
        .withTintColor(TazColor.CTArticle.color)
      let imgEyeSlash = UIImage(systemName: "eye.slash.fill")?
        .withRenderingMode(.alwaysOriginal)
        .withTintColor(TazColor.CTArticle.color)
      let eye = UIImageView(image: imgEyeSlash)
      eye.onTapping(closure: { _ in
        tf.isSecureTextEntry = !tf.isSecureTextEntry
        eye.image = tf.isSecureTextEntry ? imgEyeSlash : imgEye
      })
      tf.rightView = eye
      tf.rightViewMode = .always
    }
    return tf
  }
  
  lazy var pwInput : UITextField = {
    return Self.textField(placeholder: NSLocalizedString("login_password_hint",
                                                         comment: "Passwort Input"),
                          textContentType: .password,
                          isSecureTextEntry: true
    )
  }()
  
  // MARK: agbAcceptLabel
  lazy var agbAcceptLabel : UILabel = {
    let lb = UILabel()
    lb.paddingTop = 120
    lb.text = NSLocalizedString("login_missing_credentials_header_registration",
                                comment: "taz Id Account Create")
    lb.numberOfLines = 0
    lb.textAlignment = .center
    return lb
  }()
  
  
  private func runPerformanceTest(){
    /* ************************
     Performance Test in Simulator
     Dauer auf 4.2GHZ 4Cores*2Threads < 10s
     **** Resultat: Kein Memory Impact! ****
     setzen der backgroundColor Max 200MB After 32MB
     setzen paddingTop& Max 180MB After 33MB
     ****************************/
    for _ in 0...500000 {
      //      print("Loop:", i)
      let v = UIView()
      //      v.backgroundColor = .red
      v.paddingTop = 1
      v.paddingBottom = 1
    }
  }
  
  
  // MARK: addAndPin
  func addAndPin(_ views: [UIView]){
    self.subviews.forEach({ $0.removeFromSuperview() })
    
    if views.isEmpty { return }
    
    var views = views
    if views.contains(errorLabel) == false {
      views.append(errorLabel)
    }
    
    let margin : CGFloat = 12.0
    var previous : UIView?
    for v in views {
      //add
      container.addSubview(v)
      //pin
      if previous == nil {
        pin(v, to: container, dist: margin, exclude: .bottom)
      }
      else {
        NorthLib.pin(v.left, to: container.left, dist: margin)
        NorthLib.pin(v.right, to: container.right, dist: -margin)
        NorthLib.pin(v.top, to: previous!.bottom, dist: padding(previous!, v))
      }
      previous = v
    }
    NorthLib.pin(previous!.bottom, to: container.bottom, dist: -margin)
    
    //    if true {
    let sv = UIScrollView()
    sv.addSubview(container)
    NorthLib.pin(container, to: sv)
    self.addSubview(sv)
    //      svHC = sv.pinHeight(0)
    //      svHC?.priority = .fittingSizeLevel
    NorthLib.pin(sv, to: self)
    //    }
    //    else {// not use ScrollView
    //      self.addSubview(container)
    //      NorthLib.pin(container, to: self)
    //    }
  }
  
  //  var svHC : NSLayoutConstraint?
  //
  //  public override func layoutSubviews() {
  //    super.layoutSubviews()
  //    container.setNeedsLayout()
  //    container.layoutIfNeeded()
  //    svHC?.constant = min(UIScreen.main.bounds.height, container.frame.size.height)
  //  }
}

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

// MARK: - TazTextField
class TazTextField : UITextField, UITextFieldDelegate{
  
  private let border = BorderView()
  private let topLabel = UILabel()
  private var borderHeightConstraint: NSLayoutConstraint?
  
  public override init(frame: CGRect){
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  func setup(){
    self.addSubview(border)
    self.delegate = self
    self.border.backgroundColor = TazColor.CTArticle.color
    self.borderHeightConstraint = border.pinHeight(1)
    pin(border.left, to: self.left)
    pin(border.right, to: self.right)
    pin(border.bottom, to: self.bottom)
    self.addTarget(self, action: #selector(textFieldEditingDidChange),
                   for: UIControl.Event.editingChanged)
    self.addTarget(self, action: #selector(textFieldEditingDidBegin),
                   for: UIControl.Event.editingDidBegin)
    self.addTarget(self, action: #selector(textFieldEditingDidEnd),
                   for: UIControl.Event.editingDidEnd)
  }
  
  override open var placeholder: String?{
    didSet{
      super.placeholder = placeholder
      topLabel.text = placeholder
      if topLabel.superview == nil && placeholder?.isEmpty == false{
        topLabel.alpha = 0.0
        self.addSubview(topLabel)
        pin(topLabel.left, to: self.left)
        pin(topLabel.right, to: self.right)
        pin(topLabel.bottom, to: self.top)
        topLabel.font = AppFonts.contentFont(size: MiniPageNumberFontSize)
        topLabel.textColor = TazColor.CIColor.color
      }
    }
  }
  
  @objc public func textFieldEditingDidChange(_ textField: UITextField) {
    if let _text = textField.text, _text.isEmpty {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = 0.0
      }
    }
    else {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = 1.0
      }
    }
  }
  
  @objc public func textFieldEditingDidBegin(_ textField: UITextField) {
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.border.backgroundColor = TazColor.CIColor.color
      self?.borderHeightConstraint?.constant = 2.0
    }
  }
  @objc public func textFieldEditingDidEnd(_ textField: UITextField) {
    //textField.text = textField.text?.trim //work not good "123 456" => "123"
    //push (e.g.) pw forgott child let end too late
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.border.backgroundColor = TazColor.CTArticle.color
      self?.borderHeightConstraint?.constant = 1.0
    }
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
public func NSLocalizedString(_ key: String) -> String {
  return NSLocalizedString(key, comment: "n/a")
}
