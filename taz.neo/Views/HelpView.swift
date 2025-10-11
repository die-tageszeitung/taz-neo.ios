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
  
  private let collectionView = PageCollectionView()
  private let pageControl = UIPageControl()
  private let prevLabel = UILabel()
  private let nextLabel = UILabel()
  
  // MARK: - Subviews
  
  private let maskLayer = CAShapeLayer()
  private let lineMask = CAShapeLayer()
  
  private let line: CAShapeLayer = {
    let l = CAShapeLayer()
    l.strokeColor = UIColor.white.cgColor
    l.lineWidth = 1.1
    l.lineJoin = .round
    return l
  }()
  
  private lazy var closeButton: UIView = {
    let xButton = Button<ImageView>()
    xButton.tazX(isPermanentDark: true)
    xButton.onPress {[weak self] _ in self?.onCloseHandler?() }
    return xButton
  }()
  
  fileprivate var onDisplayClosure: ((Int)->())? = nil
   
  /// Define closure to call when a cell is newly displayed
  public func onDisplay(closure: ((Int)->())?) {
    onDisplayClosure = closure
  }
  
  private var onCloseHandler: (() -> ())?
  
//  func setLastMaxIndex(idx: Int) { NOT WORKING
//    guard items.count > idx + 1 else { return }
//    collectionView.index = idx + 1
//  }
  
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
  
  var currentCoachmarkView: CoachmarkView? {
    guard let idx = collectionView.index,
          let cv = (collectionView.view(at: idx) as? CoachmarkView) else { return nil }
    return cv
  }
    
#warning("Required? multiple times?")
  override func layoutSubviews() {
    super.layoutSubviews()
    guard let cv = currentCoachmarkView else { return }
    updateCustomLayout(view: cv)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.layer.mask = maskLayer
    self.backgroundColor = .black.withAlphaComponent(0.8)
    
    collectionView.relativeSpacing = 0.0
    collectionView.relativePageWidth = 1.0
    collectionView.showsHorizontalScrollIndicator = false
    
    _ = self.collectionView.onDisplay {[weak self] (idx, v, isFromScroll) in
      self?.onDisplayClosure?(idx)
      let itm = self?.items.valueAt(idx)
      print("HELP: ondisplay id: \(idx) view: \(v) fromScroll: \(isFromScroll), item: \(itm?.title ?? "-")")
      self?.updateControls(currentPage: idx)
      if let cv = (v?.activeView ?? self?.collectionView.view(at: idx)) as? CoachmarkView {
        self?.updateCustomLayout(view: cv)
      }
    }
    self.collectionView.viewProvider {[weak self] idx, view in
      let cv = view as? CoachmarkView ?? CoachmarkView()
      cv.item = self?.items.valueAt(idx)
      return cv
    }
    layer.addSublayer(line)
    collectionView.backgroundColor = .clear
    collectionView.count = items.count
    collectionView.isPagingEnabled = true
    addSubview(collectionView)
    pin(collectionView, to: self)
    collectionView.index = 0
    
    addSubview(closeButton)
    pin(closeButton.right, to: right, dist: -10.0)
    pin(closeButton.top, to: topGuide(), dist: 10.0)
    
    setupPageControl()
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
    prevLabel.contentFont(size: 12.0).white().textAlignment = .center
    
    nextLabel.text = "Weiter"
    nextLabel.isUserInteractionEnabled = true
    nextLabel.onTapping { [weak self] _ in self?.goToNextOrClose() }
    nextLabel.contentFont(size: 12.0).white().textAlignment = .center
    
    pin(pageControl.top, to: controlsContainer.top, dist: 2)
    pin(pageControl.bottom, to: controlsContainer.bottom, dist: -2)
    pin(prevLabel.centerY, to: pageControl.centerY)
    pin(nextLabel.centerY, to: pageControl.centerY)
    
    pin(pageControl.centerX, to: controlsContainer.centerX)
    
    prevLabel.pinWidth(75)
    nextLabel.pinWidth(75)
    
    pin(prevLabel.left, to: controlsContainer.left)
    pin(pageControl.left, to: prevLabel.right, dist: -15)
    pin(nextLabel.left, to: pageControl.right, dist: -15)
    pin(nextLabel.right, to: controlsContainer.right)
    
    // Container soll sich nicht ausdehnen, wenn Inhalte breiter werden
    controlsContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    controlsContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    
    // Layout Container
    controlsContainer.centerX()
    pin(controlsContainer.bottom, to: self.bottomGuide(),  dist: -80)
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
    collectionView.scrollto(tappedPage, animated: true)
  }
  
  // MARK: - Navigation
  private func goToPrevious() {
    guard let idx = collectionView.index,
            idx > 0 else { return }
    collectionView.scrollto(idx - 1, animated: true)
  }
  
  private func goToNextOrClose() {
    guard let idx = collectionView.index else { return }
    if idx < items.count - 1 {
      collectionView.scrollto(idx + 1, animated: true)
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
    } else {
      nextLabel.text = "Weiter"
    }
  }
}


extension HelpView {
  func updateCustomLayout(view: CoachmarkView) {
    print("HelpView: updateCustomLayout for \(view.item?.title ?? "-"))")
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
    linePath.addLine(to: self.center)
    
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
          let window = UIWindow.keyWindow else { return nil }
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
