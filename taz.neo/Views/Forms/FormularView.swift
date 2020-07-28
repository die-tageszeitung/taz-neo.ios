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

fileprivate let DefaultPadding = CGFloat(15.0)
fileprivate let TextFieldPadding = CGFloat(10.0)

// MARK: - FormularView
/// A RegisterView displays an RegisterForm
public class FormularView: UIView {

  var views : [UIView] = []{
    didSet{
      addAndPin(views)
      self.backgroundColor = TazColor.CTBackground.color
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
  
  // MARK: setup
  /// override in subclasses if needed
  func setup(){}
  
  // MARK: static helper: header
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
  
  // MARK: static helper: label
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
  
  // MARK: static helper: button
  static func button(title: String? = NSLocalizedString("Senden", comment: "Send Button Title"),
                     color: UIColor = TazColor.CIColor.color,
                     textColor: UIColor = .white,
                     height: CGFloat = 40,
                     paddingTop: CGFloat = DefaultPadding,
                     paddingBottom: CGFloat = DefaultPadding,
                     target: Any? = nil,
                     action: Selector? = nil) -> UIButton {
    let btn = UIButton()
    if let title = title {
      btn.setTitle(title, for: .normal)
    }
    btn.backgroundColor = color
    btn.setBackgroundColor(color: color.withAlphaComponent(0.8), forState: .selected)
    
    btn.setTitleColor(textColor, for: .normal)
    btn.layer.cornerRadius = 3.0
    btn.pinHeight(height)
    btn.paddingTop = paddingTop
    btn.paddingBottom = paddingBottom
    if let target = target, let action = action {
      btn.addTarget(target, action: action, for: .touchUpInside)
    }
    return btn
  }
  
  // MARK: static helper: outlineButton
  static func outlineButton(title: String? = NSLocalizedString("Senden", comment: "Send Button Title"),
                            paddingTop: CGFloat = DefaultPadding,
                            paddingBottom: CGFloat = DefaultPadding,
                            target: Any? = nil,
                            action: Selector? = nil) -> UIButton {
    let btn = Self.button(title:title,
                          paddingTop: paddingTop,
                          paddingBottom: paddingBottom,
                          target: target,
                          action: action)
    btn.backgroundColor = .clear
    btn.setBackgroundColor(color: UIColor.lightGray.withAlphaComponent(0.2), forState: .selected)
    btn.addBorder(TazColor.CIColor.color, 1.0)
    btn.setTitleColor(TazColor.CIColor.color, for: .normal)
    return btn
  }
  
  // MARK: static helper: labelLikeButton
  static func labelLikeButton(title: String? = NSLocalizedString("Senden", comment: "Send Button Title"),
                              paddingTop: CGFloat = DefaultPadding,
                              paddingBottom: CGFloat = DefaultPadding,
                              target: Any? = nil,
                              action: Selector? = nil) -> UIButton {
    let btn = Self.button(title:title,
                          paddingTop: paddingTop,
                          paddingBottom: paddingBottom,
                          target: target,
                          action: action)
    btn.backgroundColor = .clear
    btn.setBackgroundColor(color: UIColor.lightGray.withAlphaComponent(0.2), forState: .selected)
    btn.setTitleColor(TazColor.CIColor.color, for: .normal)
    return btn
  }
  
  // MARK: agbAcceptLabel with Checkbox
    lazy var agbAcceptTV : CheckboxWithText = {
      let view = CheckboxWithText()
      view.textView.isEditable = false
      view.textView.attributedText = Localized("fragment_login_request_test_subscription_terms_and_conditions").htmlAttributed
      view.textView.linkTextAttributes = [.foregroundColor : TazColor.CIColor.color, .underlineColor: UIColor.clear]
      view.textView.font = AppFonts.contentFont(size: DefaultFontSize)
      view.textView.textColor = TazColor.HText.color
      return view
    }()
  
  // MARK: textView with htmlText as Attributed Text
  static func textView(htmlText: String,
                       additionalCss: String = "",
                       paddingTop: CGFloat = TextFieldPadding,
                       paddingBottom: CGFloat = TextFieldPadding,
                       font: UIFont = AppFonts.contentFont(size: DefaultFontSize),
                       textColor: UIColor = TazColor.HText.color,
                       linkTextAttributes: [NSAttributedString.Key : Any] = [.foregroundColor : TazColor.CIColor.color,
                                                                             .underlineColor: UIColor.clear]
    
    
  ) -> UITextView {
    let tv = CustomTextView()
    tv.paddingTop = paddingTop
    tv.paddingBottom = paddingBottom
    tv.attributedText = htmlText.htmlAttributed
    tv.linkTextAttributes = [.foregroundColor : TazColor.CIColor.color, .underlineColor: UIColor.clear]
    tv.font = font
    tv.textColor = textColor
    
    return tv
  }
 
  
  // MARK: pwInput
  static func textField(prefilledText: String? = nil,
                        placeholder: String? = nil,
                        textContentType: UITextContentType? = nil,
                        color: UIColor = TazColor.CIColor.color,
                        textColor: UIColor = TazColor.CIColor.color,
                        height: CGFloat = TazTextField.recomendedHeight,
                        paddingTop: CGFloat = TextFieldPadding,
                        paddingBottom: CGFloat = TextFieldPadding,
                        isSecureTextEntry: Bool = false,
                        target: Any? = nil,
                        action: Selector? = nil) -> TazTextField {
    let tf = TazTextField()
    tf.pinHeight(height)
    tf.paddingTop = paddingTop
    tf.paddingBottom = paddingBottom
    tf.placeholder = placeholder
    //tf.borderStyle = .line //Border Bottom Alternative
    //    tf.addBorder(.gray, 1.0, only:UIRectEdge.bottom)
    tf.textContentType = .password
    tf.isSecureTextEntry = isSecureTextEntry
    
    if isSecureTextEntry {
      let imgEye = UIImage(name: "eye.fill")
      let imgEyeSlash = UIImage(name: "eye.slash.fill")
      let eye = UIImageView(image: imgEyeSlash)
      eye.tintColor = TazColor.CTArticle.color
      eye.onTapping(closure: { _ in
        tf.isSecureTextEntry = !tf.isSecureTextEntry
        eye.image = tf.isSecureTextEntry ? imgEyeSlash : imgEye
      })
      tf.rightView = eye
      tf.rightViewMode = .always
    }
    return tf
  }
  
  lazy var pwInput : TazTextField = {
    return Self.textField(placeholder: NSLocalizedString("login_password_hint",
                                                         comment: "Passwort Input"),
                          textContentType: .password,
                          isSecureTextEntry: true
    )
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
  static let recomendedHeight:CGFloat = 56.0
  private let border = BorderView()
  let topLabel = UILabel()
  let bottomLabel = UILabel()
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
//    self.layoutMargins = UIEdgeInsets(top: 15, left: 0, bottom: 15, right: 0)
    self.addSubview(border)
    self.delegate = self
    self.border.backgroundColor = TazColor.CTArticle.color
    self.borderHeightConstraint = border.pinHeight(1)
    pin(border.left, to: self.left)
    pin(border.right, to: self.right)
    pin(border.bottom, to: self.bottom, dist: -15)
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
        topLabel.numberOfLines = 1
        self.addSubview(topLabel)
        pin(topLabel.left, to: self.left)
        pin(topLabel.right, to: self.right)
        pin(topLabel.top, to: self.top, dist: -2)
        topLabel.font = AppFonts.contentFont(size: MiniPageNumberFontSize)
        self.topLabel.textColor = TazColor.CTArticle.color
      
      }
    }
  }
  
  open var bottomMessage: String?{
    didSet{
      bottomLabel.text = bottomMessage
      if bottomLabel.superview == nil && bottomMessage?.isEmpty == false{
        bottomLabel.alpha = 0.0
        bottomLabel.numberOfLines = 1
        self.addSubview(bottomLabel)
        pin(bottomLabel.left, to: self.left)
        pin(bottomLabel.right, to: self.right)
        pin(bottomLabel.bottom, to: self.bottom)
        bottomLabel.font = AppFonts.contentFont(size: MiniPageNumberFontSize)
        bottomLabel.textColor = TazColor.CIColor.color
      }
      
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.bottomLabel.alpha = self?.bottomMessage?.isEmpty == false ? 1.0 : 0.0
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
      self?.topLabel.textColor = TazColor.CIColor.color
      self?.borderHeightConstraint?.constant = 2.0
    }
  }
  @objc public func textFieldEditingDidEnd(_ textField: UITextField) {
    //textField.text = textField.text?.trim //work not good "123 456" => "123"
    //push (e.g.) pw forgott child let end too late
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.border.backgroundColor = TazColor.CTArticle.color
      self?.topLabel.textColor = TazColor.CTArticle.color
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


// MARK: -  Checkbox
class Checkbox : UIButton {
  public override init(frame: CGRect) {
    super.init(frame: frame)
      setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  func setup(){
    self.setBackgroundImage(UIImage(name: "xmark"), for: .selected)
    self.tintColor = TazColor.CTArticle.color
    self.layer.borderColor = TazColor.CTArticle.color.cgColor
    self.layer.borderWidth = 1.0
    self.layer.cornerRadius = 3.0
    self.addTarget(self, action: #selector(toggle), for: .touchUpInside)
  }
  
  @IBAction func toggle(_ sender: UIButton) {
    self.isSelected = !self.isSelected
  }
}

class CustomTextView : UITextView{
  
  private var heightConstraint: NSLayoutConstraint?
  
  static var boldLinks : [NSAttributedString.Key : Any] {
    get {
      return [.foregroundColor : TazColor.CIColor.color,
              .font: AppFonts.titleFont(size: DefaultFontSize),
              .underlineColor: UIColor.clear]
    }
  }
  
  required init(htmlText: String,
       paddingTop: CGFloat = TextFieldPadding,
       paddingBottom: CGFloat = TextFieldPadding,
       font: UIFont = AppFonts.contentFont(size: DefaultFontSize),
       textColor: UIColor = TazColor.HText.color,
       textAlignment: NSTextAlignment = .left,
       linkTextAttributes: [NSAttributedString.Key : Any] = [.foregroundColor : TazColor.CIColor.color,
                                                             .underlineColor: UIColor.clear]) {
    super.init(frame: .zero, textContainer:nil)
    self.paddingTop = paddingTop
    self.paddingBottom = paddingBottom
    self.attributedText = htmlText.htmlAttributed
    self.font = font
    self.textColor = textColor
    self.textAlignment = textAlignment
    self.linkTextAttributes = linkTextAttributes
    
    //unfortunately link font is overwritten by self font so we need to toggle this attributes
    if let linkFont = linkTextAttributes[.font] {
      let originalText = NSMutableAttributedString(attributedString: self.attributedText)
      let newString = NSMutableAttributedString(attributedString: self.attributedText)
      originalText.enumerateAttributes(in: NSRange(0..<originalText.length), options: .reverse) { (attributes, range, pointer) in
          if let _ = attributes[.link] {
              newString.removeAttribute(NSAttributedString.Key.font, range: range)
              newString.addAttribute(NSAttributedString.Key.font, value: linkFont, range: range)
          }
      }
      self.attributedText = newString
    }
    heightConstraint = self.pinHeight(10)
    heightConstraint?.priority = .defaultLow
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public init(){
      super.init(frame: .zero, textContainer:nil)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    heightConstraint?.constant = self.sizeThatFits(self.frame.size).height
  }
  
}

// MARK: -  CheckboxWithText
class CheckboxWithText:UIView{
  public var checked : Bool { get {checkbox.isSelected}}
  public let textView = CustomTextView()
  public let checkbox = Checkbox()
  
  public var error : Bool = false {
    didSet {
      checkbox.layer.borderColor
        = error ? TazColor.CIColor.color.cgColor : TazColor.CTArticle.color.cgColor
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
      setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  func setup(){
    self.addSubview(checkbox)
    self.addSubview(textView)
    pin(checkbox.left, to: self.left)
    pin(textView.left, to: checkbox.right, dist: 8)
    pin(textView.right, to: self.right)
    pin(textView.top, to: self.top)
    pin(textView.bottom, to: self.bottom)
    checkbox.pinSize(CGSize(width: 20, height: 20))
    pin(checkbox.centerY, to: self.centerY)

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
  convenience init?(name:String) {
    if #available(iOS 13.0, *){
      self.init(systemName: name)
    }
    else{
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

// MARK: - Localized Helper without Comment
public func Localized(_ key: String) -> String {
  return NSLocalizedString(key, comment: "n/a")
}

public func Localized(keyWithFormat: String, _ arguments: CVarArg...) -> String {
  return String(format: Localized(keyWithFormat), arguments)
}
