//
//  SearchHeaderView.swift
//  taz.neo
//
//  Created by Ringo Müller on 02.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

class SearchHeaderView: UIView, UIStyleChangeDelegate {
  
  var filterActive:Bool = false {
    didSet {
      extendedSearchButton.buttonView.isActivated
      = filterActive
    }
  }
  
  lazy var textField: UITextField = {
    let tf = UITextField()
    tf.leftView
    = UIImageView(image: UIImage(named:"search-magnifier"))
      .wrapper(UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0))
    tf.leftView?.pinSize(CGSize(width: 40, height: 25))
    tf.leftViewMode = .always
    tf.font = Const.Fonts.contentFont
    tf.clearButtonMode = .always
    tf.pinHeight(Const.Size.NewTextFieldHeight)
    tf.clipsToBounds = true
    tf.layer.cornerRadius = Const.Size.NewTextFieldHeight/2
    tf.clipsToBounds = true
    tf.placeholder = "taz Archiv durchsuchen"
    tf.delegate = self
    return tf
  }()
  
  lazy var extendedSearchButton: Button<ImageView> = {
    let button = Button<ImageView>()
    button.pinSize(CGSize(width: 32, height: 32))
    button.buttonView.hinset = 0.1
    button.buttonView.name = "filter"
    button.buttonView.activeColor = Const.SetColor.ios(.tintColor).color
    button.buttonView.color = Const.SetColor.ios_opaque(.closeX).color
    button.buttonView.isActivated = false
    button.onTapping { [weak self]_ in
      self?.setHeader(showMaxi: true)
      self?.resultCountView.alpha ?? 0.0 == 1.0
      ? self?.hideResult()
      : self?.showResult()
    }
    return button
  }()
  
  lazy var cancelButton: UIButton = {
    let button = UIButton()
    button.setTitle("Abbrechen", for: .normal)
    button.alpha = 0.0
    button.pinWidth(95)
    button.addTarget(self,
                   action: #selector(self.handleCancelButton),
                   for: .touchUpInside)
    return button
  }()
  
  let resultCountLabel = UILabel()
  
  public private(set) lazy var resultCountView: UIView = {
    let padding = 5.0
    let height = 14.0
    let wrappedLabel = resultCountLabel.wrapper(UIEdgeInsets(top: padding,
                                                             left: padding,
                                                             bottom: -padding,
                                                             right: -padding))
    wrappedLabel.layer.cornerRadius = (height + 2*padding)/2
    
    resultCountLabel.text = "Keine Treffer"
    resultCountLabel.contentFont(size: Const.Size.MiniPageNumberFontSize)
    resultCountLabel.textColor = Const.Colors.iconButtonInactive
    resultCountLabel.pinHeight(height)
    wrappedLabel.backgroundColor
    = Const.Colors.fabBackground.withAlphaComponent(0.9)

    return wrappedLabel
  }()
  
  
  let label = UILabel()
  
  let cancelButtonRightOffsetVisible = 0.0
  let cancelButtonRightOffsetHidden = 90.0
  
  let resultCountViewTopOffsetVisible = 10.0
  let resultCountViewTopOffsetHidden = -40.0
  
  var textFieldBottomConstraint: NSLayoutConstraint?
  var topConstraint: NSLayoutConstraint?
  var cancelButtonRightConstraint: NSLayoutConstraint?
  var resultCountViewTopConstraint: NSLayoutConstraint?
  
  private func setup() {
    self.addSubview(resultCountView)
    self.addSubview(label)
    self.addSubview(textField)
    self.addSubview(extendedSearchButton)
    self.addSubview(cancelButton)
    
    label.onTapping {[weak self] _ in
      self?.textField.becomeFirstResponder()
      self?.setHeader(showMaxi: true)
    }
        
    label.text = "Platzhalter aktuelle Suche,,,"
    label.contentFont(size: 10)
    label.textAlignment = .center
    
    //label under Textfield
    pin(label.left, to: textField.left)
    pin(label.right, to: textField.right)
    
    pin(label.centerY, to: textField.centerY)
    pin(extendedSearchButton.centerY, to: textField.centerY)
    pin(cancelButton.centerY, to: textField.centerY)
    
    pin(resultCountView.centerX, to: self.centerX)
    resultCountViewTopConstraint = pin(resultCountView.top,
                                       to: self.bottom,
                                       dist: resultCountViewTopOffsetVisible)
    
    pin(textField.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(textField.top, to: self.top, dist: 8)
    textFieldBottomConstraint = pin(textField.bottom, to: self.bottom, dist: -Const.Size.DefaultPadding)
    
    pin(extendedSearchButton.left, to: textField.right, dist: 5)
    pin(cancelButton.left, to: extendedSearchButton.right, dist: 5)
    cancelButtonRightConstraint = pin(cancelButton.right, to: self.right, dist: cancelButtonRightOffsetHidden)
    if #available(iOS 13.0, *) {
      self.addBorder(.opaqueSeparator, 0.5, only: .bottom)
    }
    registerForStyleUpdates(alsoForiOS13AndHigher: true)
  }
  
  public func applyStyles(){
    if #available(iOS 13.0, *),
       let clearButton = textField.value(forKeyPath: "_clearButton") as? UIButton {
      let img
      = UIImage(named:"xmark")?.withTintColor(Const.SetColor.taz(.textFieldClear).color,
                                              renderingMode: .alwaysOriginal)
      clearButton.setImage(img, for: .normal)
//      clearButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -9, bottom: 0, right: 9)
    }
    
    cancelButton.titleLabel?.contentFont()
    cancelButton.setTitleColor(Const.SetColor.ios(.label).color, for: .normal)
    
    self.backgroundColor
    = Const.SetColor.ios(.systemBackground).color
    
    textField.backgroundColor
    = Const.SetColor.ios(.secondarySystemBackground).color
    
    (textField.leftView?.subviews.first as? UIImageView)?.tintColor
    = Const.SetColor.ios(.placeholderText).color
    
    (textField.rightView?.subviews.first as? UIImageView)?.tintColor
    = Const.SetColor.ios(.label).color
    
  }
  
  public override init(frame: CGRect) {
    super.init(frame:frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
} // SearchHeaderView

extension SearchHeaderView {
  @objc func handleCancelButton(){
    textField.resignFirstResponder()
    textField.text = nil
    hideCancel()
  }
}


extension SearchHeaderView : UITextFieldDelegate {
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    
    if cancelButtonRightConstraint?.constant ?? 0 > 50, string.isEmpty == false {
        showCancel()
    }
    return true
  }
}

// MARK: - Animations
extension SearchHeaderView {
  
  public func setHeader(scrollOffset: CGFloat, animateEnd: Bool = false){
    if animateEnd {
      switch scrollOffset {
        case ..<(-20): setHeader(showMaxi: false)
        case ..<0: setHeader(showMaxi: true)
        case ..<20: setHeader(showMaxi: false)
        default: setHeader(showMaxi: true)
      }
      return
    }
    setHeader(scrollOffset: scrollOffset, animate: false)
  }
  
  fileprivate func setHeader(showMaxi: Bool) {
    if !showMaxi { textField.resignFirstResponder() }
    setHeader(scrollOffset: showMaxi ? 100 : -100, animate: true)
  }
  
  ///negative when scroll down ...hide tf, show miniHeader
  ///positive when scroll up ...show tf, show big header
  private func setHeader(scrollOffset: CGFloat, animate: Bool) {
    if self.textField.alpha == 0.0 && scrollOffset < 0 { return }
    if self.textField.alpha == 1.0 && scrollOffset > 0 { return }
    //scrollOffset DOWN -40...0...40 UP
    let maxOffset = 32.0 //0:show...40?:mini
    var ratio = min(abs(scrollOffset), maxOffset)/maxOffset //0...1
    if scrollOffset > 0 { ratio = 1 - ratio }
    let targetOffset = ratio * maxOffset
    let alpha = 1 - ratio // maxi 1...0 mini
    let iconZoom = 1 - ratio/3 // maxi 1...0.66 mini
    let bottomOffset = -10 + 15*ratio // maxi -10...5 mini
    //print("scrollOffset+/-: \(scrollOffset) targetOffset (0...-50): \(targetOffset) alpha (1...0): \(alpha)  bottomOffset (15...-5): \(bottomOffset)")
    let handler = { [weak self] in
      if let tc = self?.topConstraint { tc.constant = -targetOffset }
      self?.textField.alpha = alpha
      self?.textFieldBottomConstraint?.constant = bottomOffset
      self?.extendedSearchButton.contentScaleFactor = iconZoom
      self?.extendedSearchButton.buttonView.transform
      = CGAffineTransform(scaleX: iconZoom, y: iconZoom);
      self?.superview?.layoutIfNeeded()
    }
    animate ?  UIView.animate(seconds: 0.3) {  handler() } : handler()
  }
  
  func showCancel(){
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.cancelButtonRightConstraint?.constant
      = self?.cancelButtonRightOffsetVisible ?? 0
      self?.cancelButton.alpha = 1.0
      self?.layoutIfNeeded()
    }
  }
  
  func hideCancel(){
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.cancelButtonRightConstraint?.constant
      = self?.cancelButtonRightOffsetHidden ?? 0
      self?.cancelButton.alpha = 0.0
      self?.layoutIfNeeded()
    }
  }
  
  func showResult(){
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.resultCountViewTopConstraint?.constant
      = self?.resultCountViewTopOffsetVisible ?? 0
      self?.resultCountView.alpha = 1.0
      self?.layoutIfNeeded()
    }
  }
  
  func hideResult(){
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.resultCountViewTopConstraint?.constant
      = self?.resultCountViewTopOffsetHidden ?? 0
      self?.resultCountView.alpha = 0.0
      self?.layoutIfNeeded()
    }
  }
}
