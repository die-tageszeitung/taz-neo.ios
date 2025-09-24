//
//  FloatingPanelController.swift
//  taz.neo
//
//  Created by Ringo Müller on 16.09.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

/// Basisklasse für schwebende, temporäre Panels.
/// Verwaltet BottomSheet, Styling, Gesten und Ein-/Ausblenden.
class FloatingPanelController: UIViewController, UIStyleChangeDelegate, CanRotateFromUnderlying {
  
  lazy var contentView = FloatingPanelContentView()
  
  var isClosing = false

  // MARK: - UI
  var bottomSheet: Sheet? {
    didSet {
      guard let bottomSheet else { return }
      bottomSheet.handleColor = .clear
      bottomSheet.sliderView.clipsToBounds = false
      bottomSheet.xButton.tazX()
      bottomSheet.onX {[weak self] in self?.handleDismiss()}
      let io = TazAppEnvironment.sharedInstance.infoOffset
      bottomSheet.bottomOffset = io + Const.Dist.margin
      applyStyles()
    }
  }
  
  // MARK: - Gesture Recognizer
  private var tapRecognizerContent: UITapGestureRecognizer?
  private var tapRecognizerToolbar: UITapGestureRecognizer?
  private var tapRecognizerSliderButton: UITapGestureRecognizer?
  private var panRecognizerContent: UIPanGestureRecognizer?
  
  // target views for Gestures
  private var tapTargetView: UIView?
  private var tapTargetToolbar: UIView?
  private var tapTargetSliderButton: UIView?
  
  var finishHandler: ((Bool?)->())?
  
  private var answered: Bool? { contentView.hasOptions ? nil : true }
  
  // MARK: - Actions
  
  func handleAction(){
    guard !isClosing else { return }
    let handler = finishHandler
    let answered = self.answered
    cleanup()
    onMainAfter { handler?(answered) }//fix ugly animation with onMainAfter; no Effect in Dismiss
  }
  
  func handleDismiss(){
    guard !isClosing else { return }
    let handler = finishHandler
    let answered = self.answered
    cleanup()
    handler?(answered)
  }
  
  func cleanup(){
    guard !isClosing else { return }
    isClosing = true
    bottomSheet?.close()
    removeGestures()
    finishHandler = nil
  }

  
  
  // MARK: - Setup/Remove Gesture Recognizer
  func removeGestures(){
    if let tapRecognizer = tapRecognizerToolbar {
      tapTargetToolbar?.removeGestureRecognizer(tapRecognizer)
      tapRecognizerToolbar = nil
    }
    
    if let tapRecognizer = tapRecognizerSliderButton {
      tapTargetSliderButton?.removeGestureRecognizer(tapRecognizer)
      tapRecognizerSliderButton = nil
    }
    
    if let tapRecognizer = tapRecognizerContent {
      tapTargetView?.removeGestureRecognizer(tapRecognizer)
      tapRecognizerContent = nil
    }
    
    if let tapRecognizer = panRecognizerContent {
      tapTargetView?.removeGestureRecognizer(tapRecognizer)
      tapRecognizerContent = nil
    }
    tapTargetToolbar = nil
    tapTargetSliderButton = nil
    tapTargetView = nil
  }
  
  func setup(targetVc: UIViewController, sidePadding: CGFloat){
    view.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(contentView)
    pin(contentView, to: self.view)
    registerForStyleUpdates()
    
    bottomSheet = Sheet(slider: self,
                        into: targetVc,
                        maxWidth: Const.Size.OverlayMaxWidth,
                        sidePadding: sidePadding)
    contentView.setup()
    view.doLayout()
    bottomSheet?.coverage
    = contentView.frame.size.height + TazAppEnvironment.sharedInstance.infoOffset
    setupTouches()
    setupOutsideTouches(targetVc: targetVc)
    self.bottomSheet?.open()
  }
  
  func setupTouches(){
    contentView.onTapping(closure: { [weak self] _ in self?.handleAction() })
    
    guard contentView.hasOptions else { return }
    
    contentView.confirmLabel.onTapping {[weak self] _ in
      self?.finishHandler?(true)
      self?.cleanup()
    }
    contentView.declineLabel.onTapping {[weak self] _ in
      self?.finishHandler?(true)
      self?.cleanup()
    }
  }
  
  func setupOutsideTouches(targetVc: UIViewController){
    let targetView = targetVc.targetView
    bottomSheet?.shadeView.removeFromSuperview()
    self.tapTargetView = targetView
    let tapRecognizer = UITapGestureRecognizer(target: self,
                                               action: #selector(handleTapBackground))
    tapRecognizer.numberOfTapsRequired = 1
    tapRecognizer.cancelsTouchesInView = false
    tapRecognizer.delegate = self
    
    targetView.addGestureRecognizer(tapRecognizer)
    self.tapRecognizerContent = tapRecognizer
    
    if let targetVc = targetVc as? ContentVC {
      self.tapTargetToolbar = targetVc.toolBar
      let tapRecognizer1 = UITapGestureRecognizer(target: self,
                                                 action: #selector(handleTapBackground))
      tapRecognizer1.numberOfTapsRequired = 1
      tapRecognizer1.cancelsTouchesInView = false
      tapRecognizer1.delegate = self
      
      self.tapTargetToolbar?.addGestureRecognizer(tapRecognizer1)
      self.tapRecognizerToolbar = tapRecognizer1
      
      
      self.tapTargetSliderButton = targetVc.slider?.button
      let tapRecognizer2 = UITapGestureRecognizer(target: self,
                                                 action: #selector(handleTapBackground))
      tapRecognizer2.numberOfTapsRequired = 1
      tapRecognizer2.cancelsTouchesInView = false
      tapRecognizer2.delegate = self
      
      self.tapTargetSliderButton?.addGestureRecognizer(tapRecognizer2)
      self.tapRecognizerSliderButton = tapRecognizer2
    }
    else if let targetVc = targetVc as? TazPdfPagesViewController {
      self.tapTargetToolbar = targetVc.toolBar
      let tapRecognizer1 = UITapGestureRecognizer(target: self,
                                                 action: #selector(handleTapBackground))
      tapRecognizer1.numberOfTapsRequired = 1
      tapRecognizer1.cancelsTouchesInView = false
      tapRecognizer1.delegate = self
      
      self.tapTargetToolbar?.addGestureRecognizer(tapRecognizer1)
      self.tapRecognizerToolbar = tapRecognizer1
      
      
      self.tapTargetSliderButton = targetVc.slider?.button
      let tapRecognizer2 = UITapGestureRecognizer(target: self,
                                                 action: #selector(handleTapBackground))
      tapRecognizer2.numberOfTapsRequired = 1
      tapRecognizer2.cancelsTouchesInView = false
      tapRecognizer2.delegate = self
      
      self.tapTargetSliderButton?.addGestureRecognizer(tapRecognizer2)
      self.tapRecognizerSliderButton = tapRecognizer2
    }
    
    let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleTapBackground))
    panRecognizer.cancelsTouchesInView = false
    panRecognizer.delegate = self
    targetView.addGestureRecognizer(panRecognizer)
    self.panRecognizerContent = panRecognizer
  }
  
  
  // MARK: - Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    setupGestures()
    applyStyles()
  }
  
  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    if let sv = view.superview{
      pin(view, to: sv)
    }
  }
  
  // MARK: - Styles
  func applyStyles() {
    bottomSheet?.color = Const.SetColor.taz(.popoverSheetBackground).color
    if Defaults.darkMode {
      bottomSheet?.sliderView.addBorder(Const.Colors.appIconGrey, 0.3)
    } else {
      bottomSheet?.sliderView.shadow()
      bottomSheet?.sliderView.layer.shadowOffset = CGSize(width: 1, height: 1)
    }
  }
  
  // MARK: - Gestures
  private func setupGestures() {
    if let target = tapTargetView {
      tapRecognizerContent = UITapGestureRecognizer(target: self, action: #selector(handleTapContent))
      target.addGestureRecognizer(tapRecognizerContent!)
    }
    
    if let toolbar = tapTargetToolbar {
      tapRecognizerToolbar = UITapGestureRecognizer(target: self, action: #selector(handleTapToolbar))
      toolbar.addGestureRecognizer(tapRecognizerToolbar!)
    }
    
    if let sliderButton = tapTargetSliderButton {
      tapRecognizerSliderButton = UITapGestureRecognizer(target: self, action: #selector(handleTapSliderButton))
      sliderButton.addGestureRecognizer(tapRecognizerSliderButton!)
    }
    
    if let target = tapTargetView {
      panRecognizerContent = UIPanGestureRecognizer(target: self, action: #selector(handlePanContent))
      target.addGestureRecognizer(panRecognizerContent!)
    }
  }

  @objc private func handleTapBackground() {
    handleDismiss()
  }
  
  @objc func handleTapContent() {
    dismissPanel()
  }
  
  @objc func handleTapToolbar() {
    // Default: Panel schließen
    dismissPanel()
  }
  
  @objc func handleTapSliderButton() {
    // Default: Panel schließen
    dismissPanel()
  }
  
  @objc func handlePanContent(_ recognizer: UIPanGestureRecognizer) {
    // Default-Implementierung leer – Subklassen können überschreiben
  }
  
  // MARK: - Panel Control
  func presentPanel(in parent: UIViewController) {
    parent.present(self, animated: true, completion: nil)
  }
  
  func dismissPanel() {
    dismiss(animated: true, completion: nil)
  }
  
  @discardableResult
  init(title: String,
       text: String,
       confirmText: String,
       declineText: String,
       targetVc: UIViewController,
       finishHandler: @escaping (Bool?)->()){
    super.init(nibName: nil, bundle: nil)

    contentView.padding = 12.0 //bigger font bigger padding
    contentView.rightPadding = 12.0
    contentView.topLabel.text = title
    contentView.bottomLabel.text = text
    contentView.topLabel.textColor = UIColor.label
    contentView.bottomLabel.textColor = UIColor.label
    contentView.confirmText = confirmText
    contentView.declineText = declineText
    contentView.topLabel.boldContentFont()
    contentView.bottomLabel.contentFont()
    
    self.finishHandler = finishHandler
    
    setup(targetVc: targetVc, sidePadding: 9.0)//not Padding to match with PlayerUI == 9.0
  }
  
  
  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension FloatingPanelController : UIGestureRecognizerDelegate {
  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                         shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return true
  }
}

fileprivate extension UIViewController {
  var targetView: UIView {
    if let cvc = self as? ContentVC {
      return cvc.currentWebView ?? cvc.view
    }
    if let pcvc = self as? PageCollectionVC,
       let currentView = pcvc.collectionView?.optionalView(at: pcvc.index ?? 0) {
      /// pcvc.currentView returns nil if index is not set yet
      return currentView.mainView ?? currentView.waitingView ?? pcvc.view
    }
    return self.view
  }
}

extension TazAppEnvironment {
  var infoOffset: CGFloat {
    if let aPlayer = ArticlePlayer.singleton.ui, let window = aPlayer.window {
      let frameInWindow = aPlayer.convert(aPlayer.bounds, to: window)
      let distanceFromBottom = window.bounds.height - frameInWindow.origin.y
      return distanceFromBottom
    }
    guard let tabVc = self.rootViewController as? MainTabVC else { return 0 }
    let screenHeight = UIScreen.main.bounds.height
    
    if let topVc = (tabVc.selectedViewController as? UINavigationController)?.topViewController {
      if let contentVc = topVc as? ContentVC {
        return screenHeight - contentVc.toolBar.frame.origin.y
      }
      if let cpdfVc = topVc as? TazPdfPagesViewController {
        return screenHeight - cpdfVc.toolBar.frame.origin.y
      }
    }
    
    if tabVc.tabBar.isVisible == false { return UIWindow.safeInsets.bottom }
    
    let tabBarFrame = tabVc.tabBar.convert(tabVc.tabBar.bounds, to: nil)
    return screenHeight - tabBarFrame.origin.y
  }
}
