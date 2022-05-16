//
//  HeaderView.swift
//
//  Created by Norbert Thies on 12.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

enum TitleAlignment { case left, right }

/// The Header to show on top of sections and articles
open class HeaderView: UIView,  UIStyleChangeDelegate, Touchable {
  let maxOffset = 40.0
  
  private var beginScrollOffset: CGFloat?
  
  //vars
  var title: String? {
    get{ return titleLabel.text }
    set{ titleLabel.text = newValue }
  }
  var subTitle: String? {
    get{ return subTitleLabel.text }
    set{
      subTitleLabel.text = newValue
      updateUI()
    }
  }
  var pageNumber: String? {
    get{ return pageNumberLabel.text }
    set{ pageNumberLabel.text = newValue }
  }
  
  var titleAlignment: TitleAlignment? {
    didSet {
      if titleAlignment == .left {
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        pageNumberLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabel.textAlignment = .left
        pageNumberLabel.textAlignment = .left
      }
      else if titleAlignment == .right{
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        pageNumberLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.textAlignment = .right
        pageNumberLabel.textAlignment = .right
      }
    }
  }
  
  private var titleFontSizeDefault: CGFloat {
    (subTitle ?? "").isEmpty
    ? Const.Size.DefaultFontSize
    : isLargeTitleFont
    ? Const.Size.LargeTitleFontSize
    : Const.Size.TitleFontSize
  }
  //FontSize * 1.17 == LabelHeight with our Font
  private var titleFontSizeMini: CGFloat = 12.0
  private var subTitleFontSizeDefault: CGFloat = Const.Size.DefaultFontSize
  private var subTitleFontSizeMini: CGFloat = 12.0
  
  /// Use large title font if in large mode
  var isLargeTitleFont = false { didSet { updateUI() } }
  
  //ui
  var titleLabel = Label()
  var line = DottedLineView()
  var subTitleLabel = Label()
  var pageNumberLabel = HidingLabel()
  var borderView:UIView?

  private var titleTopConstraint: NSLayoutConstraint?
  private var titleBottomConstraint: NSLayoutConstraint?
  private var titlePageNumberLabelBottomConstraint: NSLayoutConstraint?
  var leftConstraint: NSLayoutConstraint?
  
  var isExtraLargeTitle: Bool { get { return subTitle != nil && isLargeTitleFont }}
  
  var lastAnimationRatio: CGFloat = 0.0
  
  let sidePadding = 11.0
  var titleTopIndentL: CGFloat {
    get {
      return isExtraLargeTitle
      ? Const.Size.DefaultPadding - 11.0
      : Const.Size.DefaultPadding
    }
  }
  
  var titleBottomIndentL: CGFloat {
    get {
      return (subTitle ?? "").isEmpty
      ? -18
      : -(subTitleFontSizeDefault * 1.17 + 6.0 + 6.0)
    }
  }
    
  let titleBottomIndentS = -6.0
  let titleTopIndentS = 4.0
    
  public var tapRecognizer = TapRecognizer()
    
  public func applyStyles() {
    titleLabel.textColor = Const.SetColor.ios(.label).color
    subTitleLabel.textColor = Const.SetColor.ios(.label).color
    pageNumberLabel.textColor = Const.SetColor.ios(.label).color
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
    line.fillColor = Const.SetColor.ios(.label).color
    line.strokeColor = Const.SetColor.ios(.label).color
  }
  
  func updateUI(){
    switch (subTitle, isLargeTitleFont) {
      case (nil, _)://in Article (missing subtitle) just a bold font
        titleLabel.boldContentFont()
      case (_, true)://extra large title for page1
        titleLabel.titleFont(size: Const.Size.LargeTitleFontSize)
      case (_, false)://medium large title for other sections
        titleLabel.titleFont(size: Const.Size.TitleFontSize)
    }
    UIView.animate(seconds: 0.2) { [weak self] in
      self?.titleTopConstraint?.constant = self?.titleTopIndentL ?? 0
      self?.layoutIfNeeded()
    }
    self.titleBottomConstraint?.constant = titleBottomIndentL
    subTitleLabel.contentFont(size: subTitleFontSizeDefault)
    pageNumberLabel.contentFont(size: subTitleFontSizeDefault)
    lastAnimationRatio = 0.0
    titlePageNumberLabelBottomConstraint?.constant =
    (pageNumberLabel.font.pointSize - titleLabel.font.pointSize)/3
    self.subTitleLabel.alpha = 1.0
    self.line.alpha = 1.0
  }

  private var onTitleClosure: ((String?)->())?
  
  /// Define closure to call if a title has been touched
  public func onTitle(closure: @escaping (String?)->()) {
    onTitleClosure = closure
  }
  
  @Default("articleTextSize")
   private var articleTextSize: Int {
     didSet{
       print("articleTextSize changed. in header..")
     }
   }
  
  private func setup() {
    registerForStyleUpdates()
    self.addSubview(titleLabel)
    self.addSubview(line)
    self.addSubview(subTitleLabel)
    self.addSubview(pageNumberLabel)
    
    titleLabel.adjustsFontSizeToFitWidth = true
    
    subTitleLabel.textAlignment = .right
    
    titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    titleAlignment = .right
    line.pinHeight(DottedLineView.DottedLineDefaultHeight)
    line.backgroundColor = .clear
    line.fillColor = Const.SetColor.ios(.label).color
    line.strokeColor = Const.SetColor.ios(.label).color
    
    titleTopConstraint
    = pin(titleLabel.top, to: self.topGuide(), dist: titleTopIndentL)
    
    titleBottomConstraint
    = pin(titleLabel.bottom, to: self.bottom, dist:titleBottomIndentL)
    
    pin(subTitleLabel.bottom, to: self.bottom, dist: -5)
    
    titlePageNumberLabelBottomConstraint =
    pin(pageNumberLabel.bottom, to: titleLabel.bottom, dist: 0)
    leftConstraint = pin(pageNumberLabel.left, to: self.left, dist:8)
    
    pin(titleLabel.left, to: pageNumberLabel.right, dist: 8)
    pin(titleLabel.right, to: self.right, dist: -sidePadding)
    
    pin(line.left, to: self.left, dist:sidePadding)
    pin(line.right, to: self.right, dist:-sidePadding)
    pin(line.top, to: titleLabel.bottom)
    
    pin(subTitleLabel.left, to: self.left, dist:sidePadding)
    pin(subTitleLabel.right, to: self.right, dist:-sidePadding)
    borderView = self.addBorderView(.opaqueSeparator, 0.5, edge: .bottom)
    updateUI()
    registerForStyleUpdates(alsoForiOS13AndHigher: true)
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  

} // HeaderView

// MARK: - Scroll delegation
extension HeaderView {
  
  func scrollViewWillBeginDragging(_ offset: CGFloat) {
    beginScrollOffset = offset
  }
  
  func scrollViewDidEndDragging(_ offset: CGFloat) {
    guard let beginScrollOffset = beginScrollOffset else { return }
    didScrolling(offsetDelta: beginScrollOffset - offset, end: true)
    self.beginScrollOffset = nil
    
  }
  
  func scrollViewDidScroll(_ offset: CGFloat) {
    guard let beginScrollOffset = beginScrollOffset else { return }
    didScrolling(offsetDelta: beginScrollOffset - offset, end: false)
  }
  
  private func didScrolling(offsetDelta:CGFloat, end: Bool){
    
    switch (end, offsetDelta) {
      case (false, _)://on drag
        handleScrolling(offsetDelta: offsetDelta, animate: false)
      case (_, ..<(-maxOffset/2)):
        handleScrolling(offsetDelta: -maxOffset, animate: true)
      case (_, ..<0):
        handleScrolling(offsetDelta: maxOffset, animate: true)
      case (_, ..<(maxOffset/2)):
        handleScrolling(offsetDelta: -maxOffset, animate: true)
      default:
        handleScrolling(offsetDelta: maxOffset, animate: true)
    }
    if end {
      self.beginScrollOffset = nil
    }
  }
  
  func showAnimated(){
    handleScrolling(offsetDelta: maxOffset, animate: true)
  }
  
  ///negative when scroll down ...hide tf, show miniHeader
  ///positive when scroll up ...show tf, show big header
  private func handleScrolling(offsetDelta: CGFloat, animate: Bool){
    if lastAnimationRatio == 1.0 && offsetDelta < 0 { return }
    if lastAnimationRatio == 0.0 && offsetDelta > 0 { return }
    var ratio = max(0.0, min(1.0, abs(offsetDelta/maxOffset))) //0...1
    if offsetDelta > 0 { ratio = 1 - ratio }
    lastAnimationRatio = ratio
    let alpha = 1 - ratio // maxi 1...0 mini
    let fastAlpha = max(0, 1 - 2*ratio) // maxi 1...0 mini
    let titleTopIndentConst
    = alpha*(titleTopIndentL - titleTopIndentS) + titleTopIndentS
    let titleBottomIndentConst
    = alpha*(titleBottomIndentL - titleBottomIndentS) + titleBottomIndentS
    
    let titleFontSize
    = alpha*(titleFontSizeDefault - titleFontSizeMini) + titleFontSizeMini
    let labelsFontSize
    = alpha*(subTitleFontSizeDefault - subTitleFontSizeMini) + subTitleFontSizeMini
    print("scroll animate: \(animate) alpha: \(alpha) fastAlpha: \(fastAlpha)")
    let handler = { [weak self] in
      self?.titleLabel.titleFont(size: titleFontSize)
      self?.pageNumberLabel.contentFont(size: labelsFontSize)
      self?.subTitleLabel.contentFont(size: labelsFontSize)
      self?.titleTopConstraint?.constant = titleTopIndentConst
      self?.titleBottomConstraint?.constant = titleBottomIndentConst
      self?.subTitleLabel.alpha = fastAlpha
      self?.line.alpha = fastAlpha
    }
    animate
    ?  UIView.animate(seconds: 0.3) {  handler(); self.superview?.layoutIfNeeded() }
    : handler()
  }
}
