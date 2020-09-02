//
//  HeaderView.swift
//
//  Created by Norbert Thies on 12.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

fileprivate let LargeTitleFontSize = CGFloat(34)
fileprivate let LargeTitleReducedFontSize = CGFloat(25)
fileprivate let SmallTitleFontSize = CGFloat(18)
fileprivate let PageNumberFontSize = CGFloat(14)
fileprivate let SubTitleFontSize = CGFloat(16)
fileprivate let MiniTitleFontSize = CGFloat(14)
fileprivate let MiniPageNumberFontSize = CGFloat(12)

fileprivate let LargeTopMargin = CGFloat(3)
fileprivate let LargeReducedTopMargin = CGFloat(13)
fileprivate let LineTopMargin = CGFloat(45)
fileprivate let SmallTopMargin = CGFloat(19)
fileprivate let DottedLineHeight = CGFloat(2.4)
fileprivate let MiniViewHeight = CGFloat(20)
fileprivate let RightMargin = CGFloat(16)


/// The Header to show on top of sections and articles
open class HeaderView: UIView,  AdoptingColorSheme{
  func adoptColorSheme() {
    isDarkMode = Defaults.darkMode
  }
  
  
  class Regular: UIView {
    
    var title = Label()
    var titleFont: UIFont!
    var reducedTitleFont: UIFont!
    var line = DottedLineView()
    var subTitle: Label?
    var subTitleFont: UIFont!
    var pageNumber: Label?
    var pageNumberFont: UIFont!
    var isLarge: Bool { return subTitle != nil }
    var leftIndent: NSLayoutConstraint?
    var topIndent: NSLayoutConstraint?

    /// Use large title font if in large mode  
    var isLargeTitleFont = false {
      didSet {
        if isLarge {
          if isLargeTitleFont {
            title.font = titleFont
            topIndent?.isActive = false
            topIndent = pin(title.top, to: self.top, dist: LargeTopMargin)
          } 
          else {
            title.font = reducedTitleFont
            topIndent?.isActive = false
            topIndent = pin(title.top, to: self.top, dist: LargeReducedTopMargin)
          }
        }
      }
    }


    func setup(isLarge: Bool) {
      self.backgroundColor = UIColor.white
      self.addSubview(title)
      self.addSubview(line)
      title.textAlignment = .right
      title.adjustsFontSizeToFitWidth = true
      pin(title.right, to: self.right, dist: -RightMargin)
      pin(line.left, to: self.left, dist: 8)
      pin(line.right, to: self.right, dist: -RightMargin)
      pin(line.top, to: self.top, dist: LineTopMargin)
      line.pinHeight(DottedLineHeight)
      if isLarge {
        let sub = Label()
        subTitle = sub
        sub.textAlignment = .right
        self.addSubview(sub)
        titleFont = Const.Fonts.titleFont(size: LargeTitleFontSize)
        reducedTitleFont = Const.Fonts.titleFont(size: LargeTitleReducedFontSize)
        subTitleFont = Const.Fonts.contentFont(size: SubTitleFontSize)
        sub.font = subTitleFont
        isLargeTitleFont = false
        pin(sub.top, to: line.bottom, dist: 1)
        pin(sub.left, to: self.left, dist: 8)
        pin(sub.right, to: self.right, dist: -RightMargin)
        pin(self.bottom, to: sub.bottom, dist: 12)        
        leftIndent = pin(title.left, to: self.left, dist: 8)
      }
      else {
        let pgn = Label()
        pageNumber = pgn
        pageNumberFont = Const.Fonts.contentFont(size: PageNumberFontSize)
        pgn.font = pageNumberFont
        self.addSubview(pgn)
        pin(pgn.top, to: self.top, dist: SmallTopMargin + 2)
        pin(pgn.right, to: title.left, dist: -6)
        titleFont = Const.Fonts.titleFont(size: SubTitleFontSize)
        title.font = titleFont
        topIndent = pin(title.top, to: self.top, dist: SmallTopMargin)
        pin(self.bottom, to: title.bottom, dist: 20)        
      }
    }
  } // Regular
  
  class Mini: UIView {
    var title = Label()
    var titleFont: UIFont!
    var pageNumber = Label()
    var pageNumberFont: UIFont!
    
    func setup() {
      self.backgroundColor = UIColor.white
      self.addSubview(title)
      title.textAlignment = .center
      title.adjustsFontSizeToFitWidth = true
      titleFont = Const.Fonts.contentFont(size: MiniTitleFontSize)
      title.font = titleFont
      pageNumberFont = Const.Fonts.contentFont(size: MiniPageNumberFontSize)
      pageNumber.font = pageNumberFont
      pin(title.right, to: self.right, dist: -RightMargin)
      pin(title.top, to: self.top)
      self.addSubview(pageNumber)
      pin(pageNumber.bottom, to: title.bottom, dist: -1)
      pin(pageNumber.right, to: title.left, dist: -4)
    }
  } // Mini
  
  var regular = Regular()
  var mini = Mini()

  /// Use large title font if in large mode  
  public var isLargeTitleFont: Bool {
    get { return regular.isLargeTitleFont }
    set { regular.isLargeTitleFont = newValue }
  }
  
  public var isDarkMode: Bool = false {
    didSet {
      let bgcol: UIColor = Const.SetColor.HBackground.color
      let txtcol: UIColor = Const.SetColor.HBackground.color
//      if isDarkMode {
//        bgcol = Const.Colors.Dark.HBackground
//        txtcol = Const.Colors.Dark.HText
//      }
//      else {
//        bgcol = Const.Colors.Light.HBackground
//        txtcol = Const.Colors.Light.HText
//      }
      self.backgroundColor = bgcol
      regular.backgroundColor = bgcol
      regular.title.textColor = txtcol
      regular.subTitle?.textColor = txtcol
      regular.line.backgroundColor = bgcol
      regular.line.fillColor = txtcol
      regular.line.strokeColor = txtcol
      mini.backgroundColor = bgcol
      mini.title.textColor = txtcol
    }
  }
  
  public var title: String {
    get { return regular.title.text ?? "" }
    set { 
      regular.title.text = newValue 
      if isAutoMini { mini.title.text = newValue }
    }
  }
  
  public var pageNumber: String? {
    get { return regular.pageNumber?.text ?? "" }
    set { 
      regular.pageNumber?.text = newValue 
      if isAutoMini { mini.pageNumber.text = newValue }
    }
  }
  
  public var leftIndent: CGFloat {
    get { regular.leftIndent?.constant ?? 0 }
    set {
      if regular.isLarge {
        regular.leftIndent?.isActive = false
        regular.leftIndent = pin(regular.title.left, to: regular.left, dist: newValue)
      }
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
  private var mainBottom: NSLayoutConstraint?
  
  private var onTitleClosure: ((String?)->())?
  
  /// Define closure to call if a title has been touched
  public func onTitle(closure: @escaping (String?)->()) {
    onTitleClosure = closure
    setupTap()
  }
  
  private func setupTap() {
    regular.title.onTap {_ in 
      self.onTitleClosure?(self.regular.title.text)
    }
    mini.title.onTap {_ in 
      self.onTitleClosure?(self.regular.title.text)
    }
  }
  
  @DefaultInt(key: "articleTextSize")
   private var articleTextSize: Int {
     didSet{
       print("articleTextSize changed. in header..")
     }
   }
  
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
    mainBottom = pin(self.bottom, to: regular.bottom)
    miniTitle = nil
    title = ""
    subTitle = ""
    registerHandler()
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
          this.mainBottom?.isActive = false
          this.mainBottom = pin(this.bottom, to: this.mini.bottom)
          superview.layoutIfNeeded()
        }
      }
    }
    else { // unhide
      var delay: Double = 0
      if isMini {
        delay = 0.2
        UIView.animate(seconds: 0.3) { [weak self] in
          guard let this = self else { return }
          this.miniTop?.isActive = false
          this.miniTop = pin(this.mini.top, to: this.top, dist: -(40+MiniViewHeight))
          this.mainBottom?.isActive = false
          this.mainBottom = pin(this.bottom, to: this.regular.bottom)
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

