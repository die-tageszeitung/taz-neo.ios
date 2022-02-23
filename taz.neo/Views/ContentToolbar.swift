//
//  ContentToolbar.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.04.21.
//  originally created in ContentVC.swift by Norbert Thies on 25.09.18.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// The ContentToolBar consists of a ToolBar and an encompassing view to position
/// the toolbar with enough distance to the bottom safe area
open class ContentToolbar: UIView {
  
  private var toolbar = Toolbar()
  private(set) var heightConstraint: NSLayoutConstraint?

  public var totalHeight: CGFloat {
    return Toolbar.ContentToolbarHeight + UIWindow.bottomInset
  }
  
  public override var backgroundColor: UIColor? {
    didSet { toolbar.backgroundColor = self.backgroundColor }
  }
  
  /// alpha for transluent color of the whole Toolbar Area
  /// needed to ensure Home Indicator has same Background like Toolbar above
  public var translucentAlpha: CGFloat {
    get { return toolbar.translucentAlpha }
    set { toolbar.translucentAlpha = newValue }
  }
  
  public var translucentColor: UIColor {
    get { return toolbar.translucentColor }
    set { toolbar.translucentColor = newValue }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(toolbar)
    pin(toolbar.top, to: self.top)
    pin(toolbar.left, to: self.left)
    pin(toolbar.right, to: self.right)
    toolbar.pinHeight(Toolbar.ContentToolbarHeight)
    toolbar.createBars(2)
    self.clipsToBounds = true
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  public func pinTo(_ view: UIView) {
    view.addSubview(self)
    pin(self.left, to: view.left)
    pin(self.right, to: view.right)
    pin(self.bottom, to: view.bottom)
    heightConstraint = self.pinHeight(totalHeight)
  }
  
  public func hide(_ isHide: Bool = true) {
    if isHide {
      UIView.animate(withDuration: 0.5) { [weak self] in
        self?.heightConstraint?.isActive = false
        self?.heightConstraint = self?.pinHeight(0)
        self?.layoutIfNeeded()
      }
    }
    else {
      UIView.animate(withDuration: 0.5) { [weak self] in
        self?.heightConstraint?.isActive = false
        self?.heightConstraint = self?.pinHeight(self!.totalHeight)
        self?.layoutIfNeeded()
      }
    }
  }
  
  public func addButton(_ button: ButtonControl, direction: Toolbar.Direction) {
    toolbar.addButton(button, direction: direction)
  }
  
  func setArticleBar() { toolbar.bar = 1 }
  func setSectionBar() { toolbar.bar = 0 }
  
  public func setButtonColor(_ color: UIColor) { toolbar.setButtonColor(color) }
  
  public func setActiveButtonColor(_ color: UIColor) {
    toolbar.setActiveButtonColor(color)
  }
  
  public func applyDefaultTazSyle() {
    self.setButtonColor(Const.Colors.darkSecondaryText.withAlphaComponent(0.9))
    self.setActiveButtonColor(Const.Colors.darkSecondaryText.withAlphaComponent(0.35))
    self.backgroundColor = Const.Colors.iOSDark.secondarySystemBackground
    self.translucentAlpha = 0.0
  }
}

// MARK: - Helper for ContentToolbar
extension ContentToolbar {
  
  enum ContentToolbarType { case section, article}
  
  func addSpacer(_ direction:Toolbar.Direction,
                 toolbar:ContentToolbarType? = nil) {
    addButton(Toolbar.Spacer(),
              direction: direction,
              toolbar: toolbar)
  }

  @discardableResult
  func addImageButton(name:String,
                      onPress:@escaping ((ButtonControl)->()),
                      direction: Toolbar.Direction,
                      symbol:String? = nil,
                      accessibilityLabel:String? = nil,
                      buttonSize:CGSize = CGSize(width: 50, height: 50),
                      imageWidth:CGFloat = 32,
                      toolbar:ContentToolbarType? = nil) -> Button<ImageView> {
    let button = Button<ImageView>()
    button.pinSize(buttonSize)
    button.buttonView.imageView.pinWidth(imageWidth)
    button.buttonView.name = name
    button.buttonView.symbol = symbol
    
//    button.addBorder(.red)
//    button.buttonView.imageView.addBorder(.green)
    
    if let al = accessibilityLabel {
      button.isAccessibilityElement = true
      button.accessibilityLabel = al
    }
    button.onPress(closure: onPress)
    addButton(button, direction: direction, toolbar: toolbar)
    return button
  }
  
  func addButton(_ button:ButtonControl,
                 direction:Toolbar.Direction,
                 toolbar:ContentToolbarType? = nil){
    if toolbar == .article {
      self.toolbar.addButton(button, direction: direction, at: 1)
    }
    else if toolbar == .section {
      self.toolbar.addButton(button, direction: direction, at: 0)
    }
    else {
      self.addButton(button, direction: direction)
    }
  }
}

// MARK: - AnimatedContentToolbar
/// ContentToolbar with easier constraint animation and changed animation target
public class AnimatedContentToolbar : ContentToolbar {
  public override func hide(_ isHide: Bool = true) {
    if isHide {
      UIView.animate(withDuration: 0.5) { [weak self] in
        self?.heightConstraint?.constant = 0
        self?.superview?.layoutIfNeeded()
      }
    }
    else if self.heightConstraint?.constant != self.totalHeight {
      UIView.animate(withDuration: 0.5) { [weak self] in
        self?.heightConstraint?.constant = self!.totalHeight
        self?.superview?.layoutIfNeeded()
      }
    }
  }
}
