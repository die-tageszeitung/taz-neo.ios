//
//  HelpView.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.09.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

/// A horizontally scrolling help/onboarding UICollectionView with page control.
/// Self-contained: no need for a view controller.
class HelpView: UIView, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
  
  static let cellYoffset: CGFloat = UIWindow.activeKeyWindow?.isTinyHeight ?? false ? -20.0 : -40.0
  
  var pageControllBottomOffset: CGFloat
  = UIWindow.activeKeyWindow?.isTinyHeight ?? false ? -50.0 : -70.0 {
    didSet {
      pageControllBottomOffsetConstraint?.constant = pageControllBottomOffset
    }
  }
  private var pageControllBottomOffsetConstraint: NSLayoutConstraint?
    
  
  private let collectionView = PageCollectionView()
  private let pageControl = UIPageControl()
  private let prevLabel = UILabel()
  private let nextLabel = UILabel()
  
  // MARK: - Subviews
  
  private let maskLayer = CAShapeLayer()
  private let lineMask = CAShapeLayer()
  private let dimmedBackground = UIView()
  
  private let line: CAShapeLayer = {
    let l = CAShapeLayer()
    l.strokeColor = UIColor.white.cgColor
    l.lineWidth = 1.1
    l.lineJoin = .round
    return l
  }()
  
  private lazy var closeButtonWrapper: UIView = {
    let wrapper = UIView()
    wrapper.onTapping{[weak self] _ in self?.onCloseHandler?()}
    wrapper.addSubview(closeButton)
    pin(closeButton, to: wrapper, dist: 4.0)
    return wrapper
  }()
  
  private lazy var closeButton: UIView = {
    let xButton = Button<ImageView>()
    xButton.tazX(isPermanentDark: true)
    return xButton
  }()
  
  var doNotShowHelpInThisAreaAnymoreLabel = UILabel("Hilfe für diesen Bereich nicht mehr anzeigen.")
  
  lazy var doNotShowHelpInThisAreaAnymore: UIView = {
    let wrapper = UIView()
    let lbl = doNotShowHelpInThisAreaAnymoreLabel
    lbl.addBorder(.white, only: .bottom)
    wrapper.addSubview(lbl)
    pin(lbl, to: wrapper, exclude: .bottom)
    pin(lbl.bottom, to: wrapper.bottom, dist: -10.0)
    lbl.contentFont(size: Const.ASize.SmallerFontSize).white().centerText()
    lbl.text = "Hilfe für diesen Bereich nicht mehr anzeigen."
    wrapper.isHidden = true
    wrapper.isAccessibilityElement = false
    lbl.isAccessibilityElement = false
    return wrapper
  }()
  
  fileprivate var onDisplayClosure: ((Int)->())? = nil
   
  /// Define closure to call when a cell is newly displayed
  public func onDisplay(closure: ((Int)->())?) {
    onDisplayClosure = closure
  }
  
  private var onCloseHandler: (() -> ())?
  
  func setLastMaxIndex(idx: Int?) {
    guard let idx = idx,
          items.count > idx else { return }
    collectionView.scrollToIndex(idx)
    collectionView.doLayout()
  }
  
  var items: [HelpItem] = []{
    didSet {
      pageControl.numberOfPages = items.count
      collectionView.count = items.count
      collectionView.reloadData()
    }
  }
  
  // MARK: - onClose/onCloseHandler
  public func onClose(closure: (() -> ())?) {
    self.onCloseHandler = closure
  }
  
  override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    doLayout()
  }
  
  var currentCoachmarkView: HelpViewCell? {
    let idx = collectionView.lastIndex
    guard let cv = (collectionView.view(at: idx) as? HelpViewCell) else { return nil }
    return cv
  }
    
  override func layoutSubviews() {
    super.layoutSubviews()
    guard let cv = currentCoachmarkView else { return }
    updateCustomLayout(view: cv)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.addSubview(dimmedBackground)
    pin(dimmedBackground, to: self)
    dimmedBackground.layer.mask = maskLayer
    dimmedBackground.backgroundColor = .black.withAlphaComponent(0.8)
    collectionView.onTapping {[weak self] _ in
      self?.closeButton.animateFocus()
    }
    collectionView.showsHorizontalScrollIndicator = false
    
    _ = self.collectionView.onDisplay {[weak self] (idx, v) in
      self?.onDisplayClosure?(idx)
      self?.updateControls(currentPage: idx)
      if let cv = (v?.activeView ?? self?.collectionView.view(at: idx)) as? HelpViewCell {
        self?.updateCustomLayout(view: cv)
        self?.currentCell = cv
      }
    }
    self.collectionView.viewProvider {[weak self] idx, view in
      let cv = view as? HelpViewCell ?? HelpViewCell()
      cv.item = self?.items.valueAt(idx)
      if self?.currentCell == nil { self?.currentCell = cv }
      return cv
    }
    layer.addSublayer(line)
    collectionView.backgroundColor = .clear
    collectionView.count = items.count
    collectionView.isPagingEnabled = true
    addSubview(collectionView)
    pin(collectionView, to: self)
    collectionView.scrollToIndex(0)
    
    addSubview(closeButtonWrapper)
    pin(closeButtonWrapper.right, to: right, dist: -7.0)
    pin(closeButtonWrapper.top, to: topGuide(), dist: 7.0)
    
    setupPageControl()
    addSubview(doNotShowHelpInThisAreaAnymore)
    doNotShowHelpInThisAreaAnymore.centerX()
    pin(doNotShowHelpInThisAreaAnymore.top, to: controlsContainer.bottom, dist: 7.0)
    
    Notification.receive(Const.NotificationNames.viewSizeTransition) {[weak self] _ in
      onMainAfter {[weak self] in
        self?.frame = UIApplication.shared.activeKeyWindow?.bounds ?? .zero
        self?.collectionView.collectionViewLayout.invalidateLayout()
        self?.collectionView.layoutIfNeeded()
        self?.layoutIfNeeded()
        self?.collectionView.reloadData()
      }
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private let controlsContainer = UIView()
  
  private func setupPageControl() {
    pageControl.hidesForSinglePage = true
    pageControl.isUserInteractionEnabled = true
    pageControl.numberOfPages = items.count
    // Container vorbereiten
    controlsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.8)
    controlsContainer.layer.cornerRadius = 12
    controlsContainer.clipsToBounds = true
    addSubview(controlsContainer)
    
    // Subviews in Container
    controlsContainer.addSubview(pageControl)
    controlsContainer.addSubview(prevLabel)
    controlsContainer.addSubview(nextLabel)
    controlsContainer.addBorder(Const.Colors.appIconGrey, 0.3)
    // Entferne alle Targets (falls vorhanden), wir benutzen stattdessen einen Tap-Gesture.
    pageControl.removeTarget(nil, action: nil, for: .allEvents)
    
    // Eigene Tap-Handler — zuverlässiger als die eingebaute Touch-Logik in komplexen Layouts
    let tapGR = UITapGestureRecognizer(target: self, action: #selector(pageControlTapped(_:)))
    tapGR.cancelsTouchesInView = false
    pageControl.addGestureRecognizer(tapGR)
    
    // Labels konfigurieren
    prevLabel.text = "Zurück"
    prevLabel.isUserInteractionEnabled = true
    prevLabel.onTapping { [weak self] _ in self?.goToPrevious() }
    prevLabel.contentFont(size: Const.ASize.SmallerFontSize).white().textAlignment = .center
    
    nextLabel.text = "Weiter"
    nextLabel.isUserInteractionEnabled = true
    nextLabel.onTapping { [weak self] _ in self?.goToNextOrClose() }
    nextLabel.contentFont(size: Const.ASize.SmallerFontSize).white().textAlignment = .center
    
    pin(pageControl.top, to: controlsContainer.top, dist: 2)
    pin(pageControl.bottom, to: controlsContainer.bottom, dist: -2)
    pin(prevLabel.centerY, to: pageControl.centerY)
    pin(nextLabel.centerY, to: pageControl.centerY)
    
    pin(pageControl.centerX, to: controlsContainer.centerX)
    
    prevLabel.pinWidth(75)
    nextLabel.pinWidth(75)
    
    nextLabel.isAccessibilityElement = true
    prevLabel.isAccessibilityElement = true
    pageControl.isAccessibilityElement = false
    
    pin(prevLabel.left, to: controlsContainer.left)
    pin(pageControl.left, to: prevLabel.right, dist: -15)
    pin(nextLabel.left, to: pageControl.right, dist: -15)
    pin(nextLabel.right, to: controlsContainer.right)
    
    // Container soll sich nicht ausdehnen, wenn Inhalte breiter werden
    controlsContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    controlsContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    
    // Layout Container
    controlsContainer.centerX()
    pageControllBottomOffsetConstraint
    = pin(controlsContainer.bottom, to: self.bottomGuide(),  dist: pageControllBottomOffset)
  }
  
  
  // MARK: - PageControl Tap (eigene Berechnung)
  @objc private func pageControlTapped(_ gr: UITapGestureRecognizer) {
    print("HelpView: tapped pages \(items.count) with gesture \(pageControl.bounds.width) at \(gr.location(in: pageControl).x)")
    guard items.count > 0 else { return }
    let location = gr.location(in: pageControl)
    let width = pageControl.bounds.width
    guard width > 0 else { return }
    
    // einfache, robuste Zuordnung: proportionale Position -> Seite
    var tappedPage = Int((location.x / width) * CGFloat(pageControl.numberOfPages))
    // sicher clampen
    tappedPage = max(0, min(pageControl.numberOfPages - 1, tappedPage))
    print("HelpView: tapped page \(tappedPage) width \(width) at x=\(location.x)")
    collectionView.scrollToIndex(tappedPage, animated: true)
  }
  
  // MARK: - Navigation
  private func goToPrevious() {
    let idx = collectionView.lastIndex ?? 0
    guard idx > 0 else { return }
    collectionView.scrollToIndex(idx - 1, animated: true)
  }
  
  private func goToNextOrClose() {
    let idx = collectionView.lastIndex ?? 0
    if idx < items.count - 1 {
      collectionView.scrollToIndex(idx + 1, animated: true)
    }
    else {
      onCloseHandler?()
    }
  }
    
  private func updateControls(currentPage: Int) {
    pageControl.currentPage = currentPage
    prevLabel.alpha = (currentPage == 0) ? 0.3 : 1.0
    if currentPage == items.count - 1 {
      nextLabel.text = "Schließen"
      nextLabel.accessibilityLabel = "Hilfe Schließen"
    } else {
      nextLabel.text = "Weiter"
    }
  }
  
  var currentCell: HelpViewCell? {
    didSet {
      guard oldValue != currentCell else { return }
      currentCell?.isAccessibilityElement = true
      onMainAfter {[weak self] in
        self?.updateAccessibilityOrder()
        oldValue?.isAccessibilityElement = false
      }
    }
  }
  
  func updateAccessibilityOrder() {
    var elms:[Any] = []
    if let cell = currentCell {
      cell.accessibilityLabel
      = "\(cell.item?.accessibilityTitle ?? cell.item?.title ?? ""), \(cell.item?.accessibilityLabelText ?? cell.item?.text ?? "")"
      elms.append(cell)
    }
    if prevLabel.isAccessibilityElement {
      elms.append(prevLabel)
    }
    if nextLabel.isAccessibilityElement {
      elms.append(nextLabel)
    }
    elms.append(closeButton)
    self.accessibilityElements = elms
    UIAccessibility.post(notification: .layoutChanged, argument: self)
  }
}


extension HelpView {
  func updateCustomLayout(view: HelpViewCell) {
    line.path = nil
    
    guard let item = view.item,
          let targetView = item.targetView else {
      let path = CGMutablePath()
      path.addRect(bounds)
      maskLayer.path = path
      return
    }
    
    //    textWidthConstraint?.constant = bounds.size.width * 0.75
    //?.asCenteredSquare()
    let tFrame = targetFrame(tv: targetView, isCircleCutout: item.isCircleCutout, circleCutoutInsetAdjustment: item.circleCutoutInsetAdjustment) ?? .zero
    
    let path = CGMutablePath()
    path.addRect(bounds)
    if item.isCircleCutout {
      path.addEllipse(in: tFrame)
    } else {
      path.addRect(tFrame)
    }
    maskLayer.path = path
    maskLayer.fillRule = .evenOdd
    
    // Linien zeichnen
    let linePath = UIBezierPath()
    linePath.move(to: tFrame.center)
    linePath.addLine(to: view.textLayer.center)
    var center = self.center
    center.y += HelpView.cellYoffset
    linePath.addLine(to: center)
    
    let lineMaskPath = CGMutablePath()
    lineMaskPath.addRect(bounds)
    lineMaskPath.addRect(tFrame)
    lineMaskPath.addRect(view.textLayer.frame)
    lineMask.fillRule = .evenOdd
    lineMask.path = lineMaskPath
    
    line.mask = lineMask
    line.path = linePath.cgPath
  }
  
  // MARK: - Layout
  
  
  private func targetFrame(tv: UIView?, isCircleCutout: Bool = false, circleCutoutInsetAdjustment: CGFloat? = nil) -> CGRect? {
    guard let tv = tv,
          tv.superview != nil,
          let window = UIWindow.activeKeyWindow else { return nil }
    guard tv.isDescendant(of: window) else { return nil }
    
    let inset = circleCutoutInsetAdjustment ?? -8.0
    
    var frame = isCircleCutout
    ? tv.frame.insetBy(dx: inset, dy: inset)
    : tv.frame
    
    var superview = tv.superview
    while superview != window {
      frame = superview!.convert(frame, to: superview!.superview)
      if superview!.superview == nil { break }
      superview = superview!.superview
    }
    return isCircleCutout
    ? superview?.convert(frame, to: self).asCenteredSquare()
    : superview?.convert(frame, to: self)
  }
  
}

extension CGRect {
  /// Gibt ein Quadrat zurück, das im aktuellen CGRect zentriert liegt.
  func asCenteredSquare() -> CGRect {
    let side = min(width, height)
    let originX = origin.x + (width  - side) / 2
    let originY = origin.y + (height - side) / 2
    return CGRect(x: originX, y: originY, width: side, height: side)
  }
}


extension UIWindow {
    var availableHeight: CGFloat {
        bounds.height
        - safeAreaInsets.top
        - safeAreaInsets.bottom
    }
  
  var isTinyHeight: Bool {
    availableHeight < 740.0
  }
}
