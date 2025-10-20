//
//  HeaderView.swift
//
//  Created by Norbert Thies on 12.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

enum TitleType { case bigLeft, article, section, section0, search  }

/// The Header to show on top of sections and articles
open class HeaderView: UIView,  Touchable, UIStyleChangeDelegate {
  let maxOffset = 40.0
  
  private var beginScrollOffset: CGFloat?
  
  var isWochentaz: Bool = false
  var isFromFacsimile: Bool = false
  var animateOnTitleChange: Bool = false
  
  //vars
  var title: String? {
    get{ return titleLabel.text }
    set{
      let animate
      = animateOnTitleChange
      && titleLabel.text != nil
      && titleLabel.text != newValue
      titleLabel.text = newValue
      if animate {
        //        titleLabel.animateMagnifyingLense()
        titleLabel.animateZoom()
      }
    }
  }
  var subTitle: String? {
    get{ return subTitleLabel.text }
    set{
      subTitleLabel.text = newValue
      setRatio(0, animated: false)
    }
  }
  ///due complex layout and multiple states in various use cases its more easy to add a help target
  ///otherwise in pdf the target is left of the text in the header == on a blank area
  public lazy var labelsHelpTarget: UIView = {
    let view = UIView()
    view.pinSize(CGSize(width: 30, height: 30))
    return view
  }()
  
  var pageNumber: String? {
    get{ return pageNumberLabel.text }
    set{ pageNumberLabel.text = newValue }
  }
  
  var titletype: TitleType? {
    didSet {
      guard let titletype = titletype else { return }
      
      switch titletype {
        case .bigLeft:
          pageNumberLabel.isHidden = true
          subTitleLabel.isHidden = true
          titleLeftConstraint?.constant = -2.0
          titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
          pageNumberLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
          titleLabel.textAlignment = .left
          titleFontSizeDefault = Const.Size.TitleFontSize
          titleTopIndentL = Const.Size.DefaultPadding - 11.0
          titleLineDistConstraint?.constant = 4.0
          titleBottomIndentL = -(titleLineDistConstraint?.constant ?? 0.0) - 0.5
          ///apply value otherwise it is not set due didScrolling ... if titletype == .bigLeft { return }
          titleBottomConstraint?.constant = titleBottomIndentL
        case .article:
          pageNumberLabel.isHidden = false
          subTitleLabel.isHidden = true
          titleLeftConstraint?.constant = 8.0
          titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
          pageNumberLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
          titleLabel.textAlignment = .right
          pageNumberLabel.textAlignment = .right
          subTitleLabel.textAlignment = .right
          titleFontSizeDefault = Const.Size.DefaultFontSize
          titleTopIndentL = Const.Size.DefaultPadding + 7.5
          titleBottomIndentL = titleBottomIndentS
          titleBottomSpaceL = 3
        case .section:
          pageNumberLabel.isHidden = true
          subTitleLabel.isHidden = false
          titleLeftConstraint?.constant = 8.0
          titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
          pageNumberLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
          titleLabel.textAlignment = .right
          pageNumberLabel.textAlignment = .right
          subTitleLabel.textAlignment = .right
          titleFontSizeDefault = Const.Size.TitleFontSize
          titleTopIndentL = Const.Size.DefaultPadding - 2
          titleBottomIndentL = -35
          titleBottomSpaceS = 2
          titleBottomSpaceL = -1
        case .section0:
          pageNumberLabel.isHidden = true
          subTitleLabel.isHidden = false
          titleLeftConstraint?.constant = 8.0
          titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
          pageNumberLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
          titleLabel.textAlignment = .right
          pageNumberLabel.textAlignment = .right
          titleFontSizeDefault = Const.Size.LargeTitleFontSize
          titleTopIndentL = 4
          titleBottomIndentL = -35
          titleBottomSpaceS = 4
          titleBottomSpaceL = -6
        case .search:
          pageNumberLabel.isHidden = false
          subTitleLabel.isHidden = false
          titleLeftConstraint?.constant = 8.0
          titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
          pageNumberLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
          titleLabel.textAlignment = .right
          pageNumberLabel.textAlignment = .left
          titleFontSizeDefault = Const.Size.DefaultFontSize
          titleTopIndentL = Const.Size.DefaultPadding
          titleBottomIndentL = -31
      }
      titleLabel.titleFont(size: titleFontSizeDefault)
      lastRatio = -1
      setRatio(0, animated: false)
    }
  }
  
  private var titleFontSizeDefault: CGFloat = Const.Size.TitleFontSize
  //FontSize * 1.17 == LabelHeight with our Font
  private var titleFontSizeMini: CGFloat = 13.0
  private let subTitleFontSizeDefault: CGFloat = Const.Size.DefaultFontSize//16
  private var subTitleFontSizeMini: CGFloat = 12.0
  
  //ui
  var titleLabel = Label()
  var line = DottedLineView()
  var subTitleLabel = Label()
  var pageNumberLabel = HidingLabel()
  
  private var titleTopConstraint: NSLayoutConstraint?
  private var titleBottomConstraint: NSLayoutConstraint?
  private var titlePageNumberLabelBottomConstraint: NSLayoutConstraint?
  private var titleLeftConstraint: NSLayoutConstraint?
  private var titleLineDistConstraint: NSLayoutConstraint?
  
  var leftConstraint: NSLayoutConstraint?
  
  var lastRatio: CGFloat?
  
  public private(set) var sidePadding: CGFloat = 18.0
  var titleTopIndentL: CGFloat = 12
  var titleBottomIndentL: CGFloat = -18//-18 or if subtitle set: -16*1.17-12 = -31
  let titleBottomIndentS = -DottedLineView.DottedLineDefaultHeight/2
  var titleBottomSpaceS = 0.0
  var titleBottomSpaceL = 0.0
  let titleTopIndentS: CGFloat = 6.5
  
  public var tapRecognizer = TapRecognizer()
  
  public func applyStyles() {
    titleLabel.textColor = Const.SetColor.ios(.label).color
    subTitleLabel.textColor = Const.SetColor.ios(.label).color
    pageNumberLabel.textColor = Const.SetColor.ios(.label).color
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
    line.fillColor = Const.SetColor.ios(.label).color
    line.strokeColor = Const.SetColor.ios(.label).color
    line.setNeedsDisplay()
  }
  
  private var onTitleClosure: ((String?)->())?
  
  /// Define closure to call if a title has been touched
  public func onTitle(closure: @escaping (String?)->()) {
    self.onTitleClosure = closure
    self.titleLabel.onTap { [weak self] _ in
      self?.onTitleClosure?(self?.title ?? "")
    }
  }
  
  private func setup() {
    self.addSubview(labelsHelpTarget)
    self.addSubview(titleLabel)
    self.addSubview(line)
    self.addSubview(subTitleLabel)
    self.addSubview(pageNumberLabel)
    
    titleLabel.adjustsFontSizeToFitWidth = true
    
    subTitleLabel.textAlignment = .right
    
    titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    line.pinHeight(DottedLineView.DottedLineDefaultHeight)
    line.backgroundColor = .clear
    line.fillColor = Const.SetColor.ios(.label).color
    line.strokeColor = Const.SetColor.ios(.label).color
    
    titleTopConstraint
    = pin(titleLabel.top, to: self.topGuide(), dist: titleTopIndentL)
    
    titleBottomConstraint
    = pin(titleLabel.bottom, to: self.bottom, dist:titleBottomIndentL, priority: .defaultHigh)
    
    pin(subTitleLabel.bottom, to: self.bottom, dist: -5)
    
    titlePageNumberLabelBottomConstraint =
    pin(pageNumberLabel.bottom, to: titleLabel.bottom, dist: 0)
    leftConstraint = pin(pageNumberLabel.left, to: self.left, dist:sidePadding)
    
    titleLeftConstraint = pin(titleLabel.left, to: pageNumberLabel.right, dist: 8)
    pin(titleLabel.right, to: self.right, dist: -sidePadding).priority = .defaultHigh
    
    pin(labelsHelpTarget.centerY, to: titleLabel.centerY)
    pin(labelsHelpTarget.right, to: titleLabel.left, dist:-20)
    
    pin(line.left, to: self.left, dist:sidePadding)
    pin(line.right, to: self.right, dist:-sidePadding).priority = .defaultHigh
    titleLineDistConstraint =
    pin(line.top, to: titleLabel.bottom, dist: 0)
    
    pin(subTitleLabel.left, to: self.left, dist:sidePadding)
    pin(subTitleLabel.right, to: self.right, dist:-sidePadding).priority = .defaultHigh
    registerForStyleUpdates()
  }
  
  open override func layoutSubviews() {
    super.layoutSubviews()
    applyStyles()
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
    if titletype == .bigLeft { return }
    
    let isMaxi = lastRatio == 0.0
    let isMini = lastRatio == 1.0
    
    if offsetDelta > 0 && isMaxi { return }
    if offsetDelta < 0 && isMini { return }
    
    switch (end, offsetDelta) {
      case (false, _)://on drag
        handleScrolling(offsetDelta: offsetDelta, animated: false)
      case (_, ..<(-maxOffset/2)):
        handleScrolling(offsetDelta: -maxOffset, animated: true)
      case (_, ..<0):
        handleScrolling(offsetDelta: -maxOffset, animated: true)
      case (_, 0.0):
        break
      default:
        handleScrolling(offsetDelta: maxOffset, animated: true)
    }
    if end {
      self.beginScrollOffset = nil
    }
  }
  
  func show(show:Bool, animated:Bool){
    setRatio(show ? 0 : 1, animated: animated)
  }
  
  ///negative when scroll down ...hide tf, show miniHeader
  ///positive when scroll up ...show tf, show big header
  private func handleScrolling(offsetDelta: CGFloat, animated: Bool){
    var ratio = max(0.0, min(1.0, abs(offsetDelta/maxOffset))) //0...1
    if offsetDelta > 0 { ratio = 1 - ratio }
    setRatio(ratio, animated: animated)
  }
  
  func updateFonts(titleFontSize: CGFloat? = nil,
                   labelsFontSize: CGFloat? = nil) {
    let titleSize = titleFontSize ?? titleFontSizeDefault
    let labelSize = labelsFontSize ?? subTitleFontSizeDefault
    let isWochentazTitle = isWochentaz && (titletype != .section0 || titletype == .article)
    
    let contentFont = isWochentazTitle
      ? Const.Fonts.knileRegularFont(size: labelSize)
      : Const.Fonts.contentFont(size: labelSize)
    
    let titleFont = isWochentazTitle
      ? Const.Fonts.knileSemiBoldFont(size: titleSize)
      : Const.Fonts.titleFont(size: titleSize)

    titleLabel.font = isFromFacsimile ? contentFont : titleFont
    subTitleLabel.font = contentFont
    pageNumberLabel.font = isFromFacsimile ? titleFont : contentFont
    
    if isFromFacsimile,
       traitCollection.horizontalSizeClass != .compact,
        let txt = titleLabel.text,
        txt.contains("Impressum") == false
    {
      titleLabel.text = txt.prepend("Seite ")
    }
  }
  
  /// set ratio between (Initial/Big Header) 0...1 (Mini Header)
  private func setRatio(_ ratio: CGFloat, animated: Bool){
    if ratio == lastRatio { return }
    lastRatio = ratio
    
    let alpha = 1 - ratio // maxi 1...0 mini
    let titleTopIndentConst
    = alpha*(titleTopIndentL - titleTopIndentS) + titleTopIndentS
    let titleBottomSpace = titleBottomSpaceS + titleBottomSpaceL*alpha
    let titleBottomIndentConst
    = alpha*(titleBottomIndentL - titleBottomIndentS) - titleBottomSpace + titleBottomIndentS
    
    let titleFontSize
    = alpha*(titleFontSizeDefault - titleFontSizeMini) + titleFontSizeMini
    let labelsFontSize
    = alpha*(subTitleFontSizeDefault - subTitleFontSizeMini) + subTitleFontSizeMini
    let handler = { [weak self] in
      self?.updateFonts(titleFontSize: titleFontSize, labelsFontSize: labelsFontSize)
      self?.titleTopConstraint?.constant = titleTopIndentConst
      self?.titleBottomConstraint?.constant = titleBottomIndentConst
      self?.titleLineDistConstraint?.constant = titleBottomSpace
      if ratio <= 0.5 {
        let a = 1 - 2*ratio
        self?.subTitleLabel.alpha = a
      }
      else {
        self?.subTitleLabel.alpha = 0.0
      }
      if self?.titletype == .search {
      }
    }
    animated
    ?  UIView.animate(seconds: 0.3) {handler(); self.superview?.layoutIfNeeded() }
    : handler();self.superview?.layoutIfNeeded()
  }
}



extension UILabel {
  func animateMagnifyingLense(
    scale: CGFloat = 1.8,
    perCharDuration: CFTimeInterval = 0.2,
    fadeDuration: CFTimeInterval = 0.3
  ) {
    superview?.layoutIfNeeded()
    guard let text = self.text, !text.isEmpty else { return }
    guard let superview = self.superview else { return }
    
    // Alte Animation entfernen
    superview.subviews
      .filter { $0.tag == 999_999 }
      .forEach { $0.removeFromSuperview() }
    
    // Container über dem Original-Label
    let containerFrame = superview.convert(self.frame, from: self.superview)
    let container = UIView(frame: containerFrame)
    container.tag = 999_999
    container.isUserInteractionEnabled = false
    container.clipsToBounds = false
    superview.addSubview(container)
    
    // Original-Label ausblenden, aber alpha = 0
    self.isHidden = false
    self.alpha = 0
    
    // Buchstaben einfügen
    var letterLabels: [UILabel] = []
    var xOffset: CGFloat = 0
    for char in text {
      let letterLabel = UILabel()
      letterLabel.text = String(char)
      letterLabel.font = self.font
      letterLabel.textColor = self.textColor
      letterLabel.sizeToFit()
      letterLabel.center = CGPoint(
        x: xOffset + letterLabel.bounds.width / 2,
        y: container.bounds.height / 2
      )
      xOffset += letterLabel.bounds.width
      container.addSubview(letterLabel)
      letterLabels.append(letterLabel)
    }
    
    var currentIndex = 0
    let stepTime = perCharDuration / 3.0
    
    Timer.scheduledTimer(withTimeInterval: stepTime, repeats: true) { timer in
      // Reset vorherige Buchstaben
      UIView.animate(withDuration: perCharDuration,
                     delay: 0,
                     options: [.curveEaseInOut, .allowUserInteraction],
                     animations: {
        for letter in letterLabels {
          letter.transform = .identity
        }
      })
      
      // Aktueller Buchstabe skalieren
      if currentIndex < letterLabels.count {
        UIView.animate(withDuration: perCharDuration,
                       delay: 0,
                       options: [.curveEaseInOut, .allowUserInteraction],
                       animations: {
          letterLabels[currentIndex].transform = CGAffineTransform(scaleX: scale, y: scale)
        })
      }
      
      currentIndex += 1
      if currentIndex >= letterLabels.count {
        timer.invalidate()
        
        // Sanftes Fade-Out aller Buchstaben, Original fade-in
        UIView.animate(withDuration: fadeDuration, delay: 0, options: [.curveEaseInOut], animations: {
          for letter in letterLabels {
            letter.alpha = 0
          }
          self.alpha = 1
        }, completion: { _ in
          container.removeFromSuperview()
        })
      }
    }
  }
}

fileprivate extension UIView {
  
  func animateZoom() {
    // Ausgangszustand sicherstellen
    self.transform = .identity
    
    UIView.animateKeyframes(withDuration: 0.8, delay: 0, options: [], animations: {
      
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.9) {
        self.transform = CGAffineTransform(scaleX: 20, y: 20)
        self.alpha = 0.0
      }
      
      UIView.addKeyframe(withRelativeStartTime: 0.91, relativeDuration: 0.01) {
        self.transform = .identity
      }
      UIView.addKeyframe(withRelativeStartTime: 0.93, relativeDuration: 0.01) {
        self.alpha = 1.0
      }
    }, completion: nil)
  }
}
