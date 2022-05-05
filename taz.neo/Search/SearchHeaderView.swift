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
  
  var topConstraint: NSLayoutConstraint?
  var cancelButtonRightConstraint: NSLayoutConstraint?
  var statusLabelTopConstraint: NSLayoutConstraint?
  
  var filterActive:Bool = false { didSet {
    extendedSearchButton.tintColor
    = filterActive
    ? Const.SetColor.ios(.tintColor).color
    : Const.SetColor.ios_opaque(.closeX).color
    }
  }
  
  // MARK: *** UI Components ***
  private(set) lazy var searchTextField: UITextField = {
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
  
  private(set) lazy var extendedSearchButton: UIImageView = {
    let button = UIImageView()
    button.pinSize(CGSize(width: 26, height: 26))
    button.image = UIImage(named: "filter")
    button.tintColor = Const.SetColor.ios_opaque(.closeX).color
    return button
  }()
  
  private(set) lazy var cancelButton: UIButton = {
    let button = UIButton()
    button.setTitle("Abbrechen", for: .normal)
    button.alpha = 0.0
    button.pinWidth(95)
    return button
  }()
  
  private(set) lazy var miniHeaderLabel: UILabel = {
    let label = UILabel()
    label.boldContentFont(size: 10)
    label.textAlignment = .center
    label.alpha = 0.0
    return label
  }()
  
  
  private(set) lazy var statusLabel: UILabel = {
    let label = UILabel()
    label.contentFont(size: Const.Size.SmallerFontSize)
    label.textAlignment = .center
    label.alpha = 0.0
    return label
  }()
  
  // MARK: *** Lifecycle ***
  private func setup() {
    self.addSubview(statusLabel)
    self.addSubview(miniHeaderLabel)
    self.addSubview(searchTextField)
    self.addSubview(extendedSearchButton)
    self.addSubview(cancelButton)
    
    self.onTapping {[weak self] _ in
      self?.setHeader(showMaxi: true)
    }
            
    //from left to right
    pin(statusLabel.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(statusLabel.right, to: self.right, dist: -Const.Size.DefaultPadding)
    pin(searchTextField.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(extendedSearchButton.left, to: searchTextField.right, dist: 8)
    pin(cancelButton.left, to: extendedSearchButton.right, dist: 8)
    cancelButtonRightConstraint = pin(cancelButton.right, to: self.right, dist: cancelButtonRightOffsetHidden)
    
    //miniHeaderLabel under Search Textfield
    pin(miniHeaderLabel.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(miniHeaderLabel.right, to: self.right, dist: -Const.Size.DefaultPadding)

    //From top to bottom
    pin(searchTextField.top, to: self.topGuide(), dist: 2)
    statusLabelTopConstraint = pin(statusLabel.top, to: searchTextField.bottom, dist: 12)
    pin(statusLabel.bottom, to: self.bottom, dist: -8)
    
    //in horizontal line with textField
    pin(miniHeaderLabel.centerY, to: searchTextField.centerY)
    pin(extendedSearchButton.centerY, to: searchTextField.centerY)
    pin(cancelButton.centerY, to: searchTextField.centerY)

    if #available(iOS 13.0, *) {
      self.addBorder(.opaqueSeparator, 0.5, only: .bottom)
    }
    registerForStyleUpdates(alsoForiOS13AndHigher: true)
    setStatusLabelTopConstraint()
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
    let iconZoom = 1 - ratio/3 // maxi 1...0.66 mini
    let handler = { [weak self] in
      //alphas
      self?.cancelButton.alpha = alpha
      self?.searchTextField.alpha = alpha
      self?.filterActive == false ? self?.extendedSearchButton.alpha = alpha : nil
      self?.miniHeaderLabel.alpha = ratio
      //zooms
      self?.extendedSearchButton.contentScaleFactor = iconZoom
      self?.extendedSearchButton.transform
      = CGAffineTransform(scaleX: iconZoom, y: iconZoom);
      self?.statusLabel.transform
      = CGAffineTransform(scaleX: iconZoom, y: iconZoom);
      //distances
      self?.topConstraint?.constant = -targetOffset/2
      self?.cancelButtonRightConstraint?.constant
      = (self?.cancelButtonRightOffsetHidden ?? 0)*ratio // maxi 0...90 mini
      self?.setStatusLabelTopConstraint(ratio)
    }
    animate
    ?  UIView.animate(seconds: 0.3) {  handler(); self.superview?.layoutIfNeeded() }
    : handler()
  }
  
  func setStatusLabelTopConstraint(_ ratio: CGFloat? = nil){
    let ratio = ratio ?? 1 - searchTextField.alpha
    let offset = statusLabel.text?.isEmpty == true ? -10.0 : 0.0
    self.statusLabelTopConstraint?.constant
    = 12 - 22*ratio - offset // maxi 12...-3 mini
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
  
  func updateHeaderStatusWith(text: String?,
                              color: UIColor?){
    let color = color ?? Const.SetColor.CTArticle.color
    if text == statusLabel.text { return }
    self.statusLabel.hideAnimated(duration: 0.3,
                                  completion: { [weak self] in
      self?.statusLabel.text = text
      self?.statusLabel.textColor = color
      self?.statusLabel.showAnimated()
    })
  }
}
