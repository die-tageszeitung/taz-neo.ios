//
//  HeaderView.swift
//
//  Created by Norbert Thies on 12.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

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
  
  /// Use large title font if in large mode
  var isLargeTitleFont = false { didSet { updateUI() } }
  
  //ui
  var firstValues:String?
  
  var titleLabel = Label()
  var line = DottedLineView()
  var subTitleLabel = Label()
  var pageNumberLabel = Label()
  var borderView:UIView?
  #warning("old flow!")
  var isLarge: Bool { return subTitle != nil }

  private var titleTopIndent: NSLayoutConstraint?
  private var titleBottomIndent: NSLayoutConstraint?
  var leftIndent: NSLayoutConstraint?
  
  let dist = 11.0
  var titleTopIndentUsed: CGFloat {
    get {
      return isExtraLargeTitle
      ? titleTopIndentLBig
      : titleTopIndentL
    }
  }
  
  
  
  var isExtraLargeTitle: Bool { get { return subTitle != nil && isLargeTitleFont }}
  let titleTopIndentL = Const.Size.DefaultPadding
  let titleTopIndentLBig = Const.Size.DefaultPadding - 11.0
  var titleBottomIndentL: CGFloat { (subTitle ?? "").isEmpty ? -10 : -21 }
  let titleBottomIndentS = 3.0
  let bottomIndentLNoSub = -2.5
  let titleTopIndentS = -5.0
    
  public var tapRecognizer = TapRecognizer()
    
  public func applyStyles() {
    titleLabel.textColor = Const.SetColor.HText.color
    subTitleLabel.textColor = Const.SetColor.HText.color
    pageNumberLabel.textColor = Const.SetColor.HText.color
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
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
    #warning("ToDO")
//    UIView.animate(seconds: 0.2) { [weak self] in
//      self?.titleTopIndent?.constant = self?.titleTopIndentUsed ?? 0
//      self?.layoutIfNeeded()
//    }
//
//    if subTitle == nil {
//      self.bottomIndent?.constant = bottomIndentLNoSub
//      borderView?.isHidden = true
//    }
//    else {
//      self.bottomIndent?.constant = bottomIndentL
//      borderView?.isHidden = false
//    }
  }

  func handleScrolling(withOffset: CGFloat){
    
  }
  
  
  func hide(_ hide: Bool){
    
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
    
    titleLabel.textAlignment = .right
    subTitleLabel.textAlignment = .right
    pageNumberLabel.textAlignment = .right
    
//    titleLabel.addBorder(.red)
//    subTitleLabel.addBorder(.green)
//    pageNumberLabel.addBorder(.blue)
//    self.addBorder(.green)
    
    titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    
    titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    pageNumberLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    line.pinHeight(DottedLineView.DottedLineDefaultHeight)
    line.backgroundColor = .clear
    line.fillColor = Const.SetColor.ios(.label).color
    line.strokeColor = Const.SetColor.ios(.label).color
    
    titleTopIndent
    = pin(titleLabel.top, to: self.topGuide(), dist: titleTopIndentL)
    
    titleBottomIndent
    = pin(titleLabel.bottom, to: self.bottom, dist:titleBottomIndentL)
    
    pin(subTitleLabel.bottom, to: self.bottom, dist: 5)
    
    pin(pageNumberLabel.top, to: titleLabel.bottom, dist: 4)
    leftIndent = pin(pageNumberLabel.left, to: self.left, dist:8)
    
    pin(titleLabel.left, to: pageNumberLabel.right, dist: 8)
    pin(titleLabel.right, to: self.right, dist: -dist)
    
    pin(line.left, to: self.left, dist:dist)
    pin(line.right, to: self.right, dist:-dist)
    pin(line.top, to: titleLabel.bottom)
    
    pin(subTitleLabel.left, to: self.left, dist:dist)
    pin(subTitleLabel.right, to: self.right, dist:-dist)
    
    borderView = self.addBorderView(.opaqueSeparator, 0.5, edge: .bottom)
    updateUI()
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
//  private func setHeader(scrollOffset: CGFloat, animate: Bool) {
//    if self.line.alpha == 0.0 && scrollOffset < 0 { return }
//    if self.line.alpha == 1.0 && scrollOffset > 0 { return }
    //scrollOffset DOWN -40...0...40 UP
    var ratio = max(0.0, min(1.0, abs(offsetDelta/maxOffset))) //0...1
    if offsetDelta > 0 { ratio = 1 - ratio }
    let alpha = 1 - ratio // maxi 1...0 mini
//    print("Scrolling: \(scrollOffset) ratio: \(ratio) alpha: \(alpha) oldAlpha: \(self.line.alpha)")
    let zoom = 1 - ratio/4 // maxi 1...0.5 mini
    //0.2 = 1-0.8 / 0.8 = 8/10 = 1 /
    /**
     
     ay = m*ax + n
     by = m*bx + n
     
     ay-by = m(ax-bx)
      font 34...10
     titleLabel.titleFont(size: Const.Size.LargeTitleFontSize)
     16..10
     
     
     */
    
    
    let titleZoom = isExtraLargeTitle ?  1 - ratio/2 : zoom // maxi 1...0.2 mini
    let titleTopIndentConst
    = alpha*(titleTopIndentUsed - titleTopIndentS) + titleTopIndentS
    let titleBottomIndentConst
    = alpha*(titleBottomIndentL - titleBottomIndentS) + titleBottomIndentS
//    let titleLabelTransformation = self.titleLabel.scaleTransform(scale: titleZoom)
//    let subTitleLabelTransformation = self.subTitleLabel.scaleTransform(scale: zoom)
//    let pageLabelTransformation = self.pageNumberLabel.scaleTransform(scale: zoom)
    if firstValues == nil {
      firstValues = "titleTopIndentConst: \(self.titleTopIndent?.constant) "
    + "titleBottomIndentConst: \(self.titleBottomIndent?.constant) "
    }
    
    
    let titleFontSize
    = alpha*(34 - 12) + 12
    
    let labelsFontSize
    = alpha*(15 - 9) + 9
    
    if animate == true {

      
      let now = "titleTopIndentConst: \(titleTopIndentConst) "
    + "titleBottomIndentConst: \(titleBottomIndentConst) "
      print("=========")
      print("Initial:\n\(firstValues)")
      print("=========")
      print("Now:\n\(now)")
      print("=========")
    }
    if self.line.alpha == 0.0 && offsetDelta < 0 { return }
    if self.line.alpha == 1.0 && offsetDelta > 0 { return }
    let handler = { [weak self] in
      self?.titleLabel.titleFont(size: titleFontSize)
      self?.pageNumberLabel.contentFont(size: labelsFontSize)
      self?.subTitleLabel.boldContentFont(size: labelsFontSize)
//      self?.titleLabel.transform = titleLabelTransformation
//      self?.pageNumberLabel.transform = pageLabelTransformation
//      self?.subTitleLabel.transform = subTitleLabelTransformation
      self?.titleTopIndent?.constant = titleTopIndentConst
      self?.titleBottomIndent?.constant = titleBottomIndentConst
      self?.subTitleLabel.alpha = alpha
      self?.line.alpha = alpha
    }
    animate
    ?  UIView.animate(seconds: 0.3) {  handler(); self.superview?.layoutIfNeeded() }
    : handler()
  }
  
}

extension UIView {
//
//  func scaleTransform(scale: CGFloat) -> CGAffineTransform {
//      let bounds = self.bounds
//    let relativeAnchorPoint = CGPoint(x: 0.5, y: 0.5)
//    let anchorPoint = CGPoint(x: bounds.width * relativeAnchorPoint.x, y: bounds.height * relativeAnchorPoint.y)
//      return CGAffineTransform.identity
//          .translatedBy(x: anchorPoint.x, y: anchorPoint.y)
//          .scaledBy(x: scale, y: scale)
//          .translatedBy(x: -anchorPoint.x, y: -anchorPoint.y)
//  }
  
  func addBlur(){
    if let v = self.subviews.valueAt(0), v.tag == 38317 {
      return // blur effect already added
    }
    let blurEffect = UIBlurEffect(style: .light)
    let blurEffectView = UIVisualEffectView(effect: blurEffect)
    blurEffectView.tag = 38317
    blurEffectView.frame = self.bounds
    
    blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.addSubview(blurEffectView)
  }
}
