//
//  SearchHeaderView.swift
//  taz.neo
//
//  Created by Ringo Müller on 02.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

class SearchHeaderView: UIView {
  
  // MARK: *** Closures ***
  var searchClosure: (()->())?
  
  // MARK: *** Properties ***
  let cancelButtonRightOffsetVisible = 0.0
  let cancelButtonRightOffsetHidden = 90.0
  
  let resultCountViewTopOffsetVisible = 10.0
  let resultCountViewTopOffsetHidden = -40.0
  
  var textFieldBottomConstraint: NSLayoutConstraint?
  var topConstraint: NSLayoutConstraint?
  var cancelButtonRightConstraint: NSLayoutConstraint?
  var resultCountViewTopConstraint: NSLayoutConstraint?
  
  var filterActive:Bool = false { didSet {
      extendedSearchButton.buttonView.isActivated
      = filterActive
    }
  }
  
  // MARK: *** UI Components ***
  lazy var searchTextField: UITextField = {
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
    tf.returnKeyType = .search
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
    return button
  }()
  
  lazy var cancelButton: UIButton = {
    let button = UIButton()
    button.setTitle("Abbrechen", for: .normal)
    button.alpha = 0.0
    button.pinWidth(95)
    return button
  }()
  
  let resultCountLabel = UILabel()
  let miniHeaderLabel = UILabel()
  
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
    resultCountLabel.textColor = .white
    resultCountLabel.pinHeight(height)
    wrappedLabel.backgroundColor
    = Const.Colors.fabBackground.withAlphaComponent(0.9)

    return wrappedLabel
  }()

  // MARK: *** Lifecycle ***
  private func setup() {
    self.addSubview(resultCountView)
    self.resultCountView.alpha = 0.0
    self.addSubview(miniHeaderLabel)
    self.addSubview(searchTextField)
    self.addSubview(extendedSearchButton)
    self.addSubview(cancelButton)
    
    self.onTapping {[weak self] _ in
      self?.setHeader(showMaxi: true)
    }
        
    miniHeaderLabel.contentFont(size: 10)
    miniHeaderLabel.textAlignment = .center
    
    //label under Textfield
    pin(miniHeaderLabel.left, to: self.left, dist: 10)
    pin(miniHeaderLabel.right, to: self.right, dist: -10)
    
    pin(miniHeaderLabel.centerY, to: searchTextField.centerY)
    pin(extendedSearchButton.centerY, to: searchTextField.centerY)
    pin(cancelButton.centerY, to: searchTextField.centerY)
    
    pin(resultCountView.centerX, to: self.centerX)
    resultCountViewTopConstraint = pin(resultCountView.top,
                                       to: self.bottom,
                                       dist: resultCountViewTopOffsetVisible)
    
    pin(searchTextField.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(searchTextField.top, to: self.topGuide(), dist: 8)
    textFieldBottomConstraint = pin(searchTextField.bottom, to: self.bottom, dist: -Const.Size.DefaultPadding)
    
    pin(extendedSearchButton.left, to: searchTextField.right, dist: 5)
    pin(cancelButton.left, to: extendedSearchButton.right, dist: 5)
    cancelButtonRightConstraint = pin(cancelButton.right, to: self.right, dist: cancelButtonRightOffsetHidden)
    if #available(iOS 13.0, *) {
      self.addBorder(.opaqueSeparator, 0.5, only: .bottom)
    }
    registerForStyleUpdates(alsoForiOS13AndHigher: true)
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

// MARK: - UITextFieldDelegate -
extension SearchHeaderView : UIStyleChangeDelegate {
  public func applyStyles(){
    if #available(iOS 13.0, *),
       let clearButton = searchTextField.value(forKeyPath: "_clearButton") as? UIButton {
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
    
    searchTextField.backgroundColor
    = Const.SetColor.ios(.secondarySystemBackground).color
    
    (searchTextField.leftView?.subviews.first as? UIImageView)?.tintColor
    = Const.SetColor.ios(.placeholderText).color
    
    (searchTextField.rightView?.subviews.first as? UIImageView)?.tintColor
    = Const.SetColor.ios(.label).color
  }
}

// MARK: - UITextFieldDelegate -
extension SearchHeaderView : UITextFieldDelegate {
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    searchClosure?()
    return true
  }
  
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    onMainAfter { [weak self] in self?.checkCancelButton() }
    return true
  }
}

// MARK: - Animations
extension SearchHeaderView {
  func setHeader(scrollOffset: CGFloat, animateEnd: Bool = false){
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
  
  func setHeader(showMaxi: Bool) {
    if !showMaxi {
      searchTextField.resignFirstResponder()
    }
    setHeader(scrollOffset: showMaxi ? 100 : -100, animate: true)
  }
  
  ///negative when scroll down ...hide tf, show miniHeader
  ///positive when scroll up ...show tf, show big header
  private func setHeader(scrollOffset: CGFloat, animate: Bool) {
    if self.searchTextField.alpha == 0.0 && scrollOffset < 0 { return }
    if self.searchTextField.alpha == 1.0 && scrollOffset > 0 { return }
    //scrollOffset DOWN -40...0...40 UP
    let maxOffset = 32.0 //0:show...40?:mini
    var ratio = min(abs(scrollOffset), maxOffset)/maxOffset //0...1
    if scrollOffset > 0 { ratio = 1 - ratio }
    let targetOffset = ratio * maxOffset
    let alpha = 1 - ratio // maxi 1...0 mini
    miniHeaderLabel.text = searchTextField.text
    let iconZoom = 1 - ratio/3 // maxi 1...0.66 mini
    let cancelButtonRightOffset = cancelButtonRightOffsetHidden*ratio // maxi 0...90 mini
    let bottomOffset = -10 + 15*ratio // maxi -10...5 mini
    //print("scrollOffset+/-: \(scrollOffset) targetOffset (0...-50): \(targetOffset) alpha (1...0): \(alpha)  bottomOffset (15...-5): \(bottomOffset)")
    let handler = { [weak self] in
      if let tc = self?.topConstraint { tc.constant = -targetOffset }
      self?.searchTextField.alpha = alpha
      self?.textFieldBottomConstraint?.constant = bottomOffset
      self?.extendedSearchButton.contentScaleFactor = iconZoom
      self?.extendedSearchButton.buttonView.transform
      = CGAffineTransform(scaleX: iconZoom, y: iconZoom);
      self?.cancelButtonRightConstraint?.constant
      = cancelButtonRightOffset
      self?.cancelButton.alpha = alpha
      self?.superview?.layoutIfNeeded()
    }
    animate ?  UIView.animate(seconds: 0.3) {  handler() } : handler()
  }
  
  func checkCancelButton(){
    if searchTextField.text?.isEmpty == false || filterActive == true  {
      if cancelButton.alpha != 1.0 {
        UIView.animate(seconds: 0.3) { [weak self] in
          self?.cancelButtonRightConstraint?.constant
          = self?.cancelButtonRightOffsetVisible ?? 0
          self?.cancelButton.alpha = 1.0
          self?.layoutIfNeeded()
        }
      }
    }
    else if cancelButton.alpha != 0.0 {
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.cancelButtonRightConstraint?.constant
        = self?.cancelButtonRightOffsetHidden ?? 0
        self?.cancelButton.alpha = 0.0
        self?.layoutIfNeeded()
      }
    }
  }
  
  func showResult(text: String){
    if self.resultCountView.alpha == 1.0 {
      UIView.animateKeyframes(withDuration: 0.5, delay: 0.0, animations: {
        UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) { [weak self] in
          self?.resultCountView.alpha = 0.0
        }
        UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.1) { [weak self] in
          self?.resultCountLabel.text = text
        }
        UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.4) { [weak self] in
          self?.resultCountView.alpha = 1.0
        }
      })
      return
    }
    self.resultCountLabel.text = text
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
