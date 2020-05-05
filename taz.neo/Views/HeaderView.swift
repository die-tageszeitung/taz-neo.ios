//
//  HeaderView.swift
//
//  Created by Norbert Thies on 12.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

fileprivate var LargeTitleFont = UIFont.boldSystemFont(ofSize: 28)
fileprivate var SmallTitleFont = UIFont.boldSystemFont(ofSize: 20)
fileprivate var SubTitleFont = UIFont.systemFont(ofSize: 14)
fileprivate var LargeTopMargin = CGFloat(8)
fileprivate var SmallTopMargin = CGFloat(16)
fileprivate var DottedLineHeight = CGFloat(3)
fileprivate var MiniViewHeight = CGFloat(20)


open class HeaderView: UIView {
  
  class Regular: UIView {
    
    var title = UILabel()
    var line = DottedLineView()
    var subTitle: UILabel?
    var isLarge: Bool { return subTitle != nil }
    var leftIndent: NSLayoutConstraint?

    func setup(isLarge: Bool) {
      self.backgroundColor = UIColor.white
      self.addSubview(title)
      self.addSubview(line)
      title.textAlignment = .right
      title.adjustsFontSizeToFitWidth = true
      leftIndent = pin(title.left, to: self.left, dist: 8)
      pin(title.right, to: self.right, dist: -8)
      pin(line.left, to: self.left, dist: 8)
      pin(line.right, to: self.right, dist: -8)
      pin(line.top, to: title.bottom, dist: 4)
      line.pinHeight(DottedLineHeight)
      if isLarge {
        let sub = UILabel()
        subTitle = sub
        sub.textAlignment = .right
        self.addSubview(sub)
        title.font = LargeTitleFont
        sub.font = SubTitleFont
        pin(sub.top, to: line.bottom, dist: 4)
        pin(sub.left, to: self.left, dist: 8)
        pin(sub.right, to: self.right, dist: -8)
        pin(title.top, to: self.top, dist: LargeTopMargin)
        pin(self.bottom, to: sub.bottom, dist: 8)        
      }
      else {
        title.font = SmallTitleFont
        pin(title.top, to: self.top, dist: SmallTopMargin)
        pin(self.bottom, to: line.bottom, dist: 8)        
      }
    }
  } // Regular
  
  class Mini: UIView {
    var title = UILabel()
    
    func setup() {
      self.backgroundColor = UIColor.white
      self.addSubview(title)
      title.textAlignment = .center
      title.adjustsFontSizeToFitWidth = true
      title.font = SubTitleFont
      pin(title.left, to: self.left, dist: 8)
      pin(title.right, to: self.right, dist: -8)
      pin(title.top, to: self.top)
    }
  } // Mini
  
  var regular = Regular()
  var mini = Mini()
  
  public var title: String {
    get { return regular.title.text ?? "" }
    set { 
      regular.title.text = newValue 
      if isAutoMini { mini.title.text = newValue }
    }
  }
  
  public var leftIndent: CGFloat {
    get { regular.leftIndent?.constant ?? 0 }
    set {
      regular.leftIndent?.isActive = false
      regular.leftIndent = pin(regular.title.left, to: regular.left, dist: newValue)
    }
  }
  
  public var subTitle: String? {
    get { return regular.subTitle?.text }
    set { regular.subTitle?.text = newValue }
  }  
  
  public var miniTitle: String? {
    get { return mini.title.text }
    set { mini.title.text = newValue }
  }
  
  private var isAutoMini = false
  public var isMini: Bool { return miniTitle != nil }
  
  private var regularTop: NSLayoutConstraint?
  private var miniTop: NSLayoutConstraint?
  
  private func setup(isLarge: Bool) {
    self.backgroundColor = UIColor.white
    regular.setup(isLarge: isLarge)
    mini.setup()
    addSubview(mini)
    pin(mini.left, to: self.left)
    pin(mini.right, to: self.right)
    miniTop = pin(mini.top, to: self.top, dist: -(40+MiniViewHeight))
    mini.pinHeight(MiniViewHeight)
    addSubview(regular)
    pin(regular.left, to: self.left)
    pin(regular.right, to: self.right)
    regularTop = pin(regular.top, to: self.top)
    miniTitle = nil
    title = ""
    subTitle = ""
  }
  
  func installIn(view: UIView, isLarge: Bool, isMini: Bool = false) {
    setup(isLarge: isLarge)
    if isMini {
      isAutoMini = true
      miniTitle = title
    }
    view.addSubview(self)
    pin(top, to: view.topGuide())
    pin(left, to: view.left)
    pin(right, to: view.right)
  }
  
  func hide(_ ishide: Bool = true) {
    guard let superview = self.superview else { return }
    if ishide {
      let height = regular.frame.size.height
      UIView.animate(seconds: 0.5) { [weak self] in
        guard let this = self else { return }
        this.regularTop?.isActive = false
        this.regularTop = pin(this.regular.top, to: this.top, dist: -(40+height))
        superview.layoutIfNeeded()
      }
      if isMini {
        UIView.animate(seconds: 0.3, delay: 0.3) { [weak self] in
          guard let this = self else { return }
          this.miniTop?.isActive = false
          this.miniTop = pin(this.mini.top, to: this.top)
          superview.layoutIfNeeded()
        }
      }
    }
    else {
      var delay: Double = 0
      if isMini {
        delay = 0.2
        UIView.animate(seconds: 0.3) { [weak self] in
          guard let this = self else { return }
          this.miniTop?.isActive = false
          this.miniTop = pin(this.mini.top, to: this.top, dist: -(40+MiniViewHeight))
          superview.layoutIfNeeded()
        }
      }
      UIView.animate(seconds: 0.5, delay: delay) { [weak self] in
        guard let this = self else { return }
        this.regularTop?.isActive = false
        this.regularTop = pin(this.regular.top, to: this.top)
        superview.layoutIfNeeded()
      }
    }
  }
  
  override open func layoutSubviews() {
    setNeedsDisplay()
  }

} // HeaderView

