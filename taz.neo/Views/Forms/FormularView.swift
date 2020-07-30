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
  let scrollView = UIScrollView()
  
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
  
  @objc func keyboardWillShow(_ notification: Notification) {
    if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
      let keyboardRectangle = keyboardFrame.cgRectValue
      let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardRectangle.height, right: 0)
      scrollView.contentInset = contentInsets
    }
  }
  
  @objc func keyboardWillHide(notification:NSNotification){
    let contentInset:UIEdgeInsets = UIEdgeInsets.zero
    scrollView.contentInset = contentInset
  }
  
  
  // MARK: addAndPin
  func addAndPin(_ views: [UIView]){
    self.subviews.forEach({ $0.removeFromSuperview() })
    
    if views.isEmpty { return }
    
    let margin : CGFloat = 12.0
    var previous : UIView?
    
    var tfTags : Int = 100
    
    for v in views {
      
      if v is UITextField {
        v.tag = tfTags
        tfTags += 1
      }
      
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
    
    let notificationCenter = NotificationCenter.default
    
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardWillShow),
                                   name:UIResponder.keyboardWillShowNotification,
                                   object: nil)
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardWillHide),
                                   name:UIResponder.keyboardWillHideNotification,
                                   object: nil)
    scrollView.addSubview(container)
    NorthLib.pin(container, to: scrollView)
    self.addSubview(scrollView)
    NorthLib.pin(scrollView, to: self)
  }
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
  
  lazy var inputToolbar: UIToolbar = {
    /// setting toolbar width fixes the h Autolayout issue, unfortunatly not the v one no matter which height
    var toolbar =  UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0))
    toolbar.barStyle = .default
    toolbar.isTranslucent = true
    toolbar.sizeToFit()
    
    /// Info: Issue with Autolayout
    /// the solution did not solve our problem:
    /// https://developer.apple.com/forums/thread/121474
    /// because we use autocorection/password toolbar also
    /// also the following options did not worked:
    ///   UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
    ///   toolbar.setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
    ///   toolbar.setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
    ///   toolbar.autoresizesSubviews = false
    ///   toolbar.translatesAutoresizingMaskIntoConstraints = true/false
    ///   ....
    ///   toolbar.sizeToFit()
    ///   toolbar.pinHeight(toolbar.frame.size.height).priority = .required
    ///   ....
    /// Maybe extend: CustomToolbar : UIToolbar and invoke updateConstraints/layoutSubviews
    /// to reduce constraint priority or set frame/size
    
    var doneButton  = UIBarButtonItem(image: UIImage(name: "checkmark")?.withRenderingMode(.alwaysTemplate),
                                      style: .done,
                                      target: self,
                                      action: #selector(textFieldToolbarDoneButtonPressed))
    
    var prevButton  = UIBarButtonItem(title: "❮",
                                      style: .plain,
                                      target: self,
                                      action: #selector(textFieldToolbarPrevButtonPressed))
    
    
    var nextButton  = UIBarButtonItem(title: "❯",
                                      style: .plain,
                                      target: self,
                                      action: #selector(textFieldToolbarNextButtonPressed))
    
    prevButton.tintColor = AppColors.ciColor
    nextButton.tintColor = AppColors.ciColor
    doneButton.tintColor = AppColors.ciColor
    
    var flexibleSpaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    var fixedSpaceButton = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
    fixedSpaceButton.width = 30
    
    toolbar.setItems([prevButton, fixedSpaceButton, nextButton, flexibleSpaceButton, doneButton], animated: false)
    toolbar.isUserInteractionEnabled = true
    
    return toolbar
  }()
  
  @objc func textFieldToolbarDoneButtonPressed(sender: UIBarButtonItem) {
    self.resignFirstResponder()
  }
  
  @objc func textFieldToolbarPrevButtonPressed(sender: UIBarButtonItem) {
    if let nextField = self.superview?.viewWithTag(self.tag - 1) as? UITextField {
      nextField.becomeFirstResponder()
    } else {
      self.resignFirstResponder()
    }
  }
  
  @objc func textFieldToolbarNextButtonPressed(sender: UIBarButtonItem) {
    nextOrEndEdit()
  }
  
  func nextOrEndEdit(){
    if let nextField = self.superview?.viewWithTag(self.tag + 1) as? UITextField {
      nextField.becomeFirstResponder()
    } else {
      self.resignFirstResponder()
    }
  }
  
  @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
     nextOrEndEdit()
     return true
  }
  
  @objc public func textFieldEditingDidBegin(_ textField: UITextField) {
    textField.inputAccessoryView = inputToolbar
    
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
    self.backgroundColor = .clear
    
    var attributedString = htmlText.mutableAttributedStringFromHtml
    let all = NSRange(location: 0, length: attributedString?.length ?? 0)
    
    /// unfortunately underlines are cut-off with our custom font
    /// fix it by set .lineHeightMultiple = 1.2
    let style = NSMutableParagraphStyle()
    style.lineHeightMultiple = 1.12
    style.alignment = textAlignment
    
    /// prefer setting styles of the attributedString instead of self.font due this overwrites the whole
    /// attributed string whis needs to be set first
    attributedString?.addAttribute(.paragraphStyle, value: style, range: all)
    attributedString?.addAttribute(.font, value: font, range: all)
    attributedString?.addAttribute(.foregroundColor, value: textColor, range: all)
    
    self.linkTextAttributes = linkTextAttributes
    //unfortunately link font is overwritten by self font so we need to toggle this attributes
    //esspecially the combination with different link font did not work
    if let linkFont = linkTextAttributes[.font], let originalText = attributedString {
      let newString = NSMutableAttributedString(attributedString: originalText)
      originalText.enumerateAttributes(in: NSRange(0..<originalText.length), options: .reverse) { (attributes, range, pointer) in
        if let _ = attributes[.link] {
          newString.removeAttribute(.font, range: range)
          newString.addAttribute(.font, value: linkFont, range: range)
        }
      }
      attributedString = newString
    }
    
    self.attributedText = attributedString
    
    heightConstraint = self.pinHeight(10)
    heightConstraint?.priority = .defaultLow
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public init(){
    super.init(frame: .zero, textContainer:nil)
    heightConstraint = self.pinHeight(50)
    heightConstraint?.priority = .defaultLow
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
  /// Creates an image
  /// iOS 13 and later: object containing a system symbol image referenced by given name
  /// earlier: using the named image asset
  ///
  /// Example
  /// ```
  /// UIImage(name: "checkmark") // Creates image
  /// ```
  ///
  /// - Warning: May return nil if Image for given name does not exist
  /// - Parameter name: the image name
  /// - Returns: UIImage related to `name`.
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
public func Localized(keyWithFormat: String, _  arguments: CVarArg...) -> String {
  return String(format: Localized(keyWithFormat), arguments: arguments)
}
