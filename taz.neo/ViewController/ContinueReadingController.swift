//
//  ContinueReadingController.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.07.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

class ContinueReadingController: UIViewController, UIStyleChangeDelegate {
  func applyStyles() {
    bottomSheet?.color = Const.SetColor.taz(.popoverSheetBackground).color
    if Defaults.darkMode{
      bottomSheet?.sliderView.addBorder(Const.Colors.appIconGrey, 0.3)
    }
    else {
      bottomSheet?.sliderView.shadow()
      bottomSheet?.sliderView.layer.shadowOffset = CGSize(width: 1, height: 1)
    }
  }
  
  var padding = 9.0
  var rightPadding = 9.0
  
  var bottomSheet: Sheet?
  private var tapRecognizer: UITapGestureRecognizer?
  private var panRecognizer: UIPanGestureRecognizer?
  private var tapTargetView: UIView?
  
  private var finishHandler: ((Bool?)->())?
  
  var isClosing = false
    
  private lazy var imageView: UIImageView = {
    let v = UIImageView()
    v.pinHeight(32.0, priority: .required)
    v.pinAspect(ratio: 1.0)
    v.clipsToBounds = true
    return v
  }()
  
  private lazy var topLabel: UILabel = {
    let lbl = UILabel()
    lbl.contentFont(size: 13)
    lbl.text = "Weiterlesen:"
    return lbl
  }()
  
  private lazy var bottomLabel: UILabel = {
    let lbl = UILabel()
    lbl.numberOfLines = 0
    lbl.boldContentFont(size: 13)
    return lbl
  }()
  
  private lazy var confirmLabel: UILabel = {
    let lbl = UILabel()
    lbl.tazPrimaryButtonStyle()
    lbl.onTapping {[weak self] _ in
      self?.finishHandler?(true)
      self?.cleanup()
    }
    return lbl
  }()
  
  private lazy var declineLabel: UILabel = {
    let lbl = UILabel()
    lbl.tazSecondaryButtonStyle()
    lbl.onTapping {[weak self] _ in
      self?.finishHandler?(false)
      self?.cleanup()
    }
    return lbl
  }()
  
  override func viewDidLoad() {
    ///Warning: bottomSheet is not available yet!
    super.viewDidLoad()
    self.view.addSubview(topLabel)
    self.view.addSubview(bottomLabel)
    self.view.addSubview(imageView)
    self.view.translatesAutoresizingMaskIntoConstraints = false
    pin(imageView.top, to: view.top, dist: padding)
    pin(imageView.left, to: view.left, dist: padding)
    
    pin(topLabel.top, to: view.top, dist: padding)
    pin(bottomLabel.top, to: topLabel.bottom, dist: 2.0)
    
    let leftAnchor = imageView.image == nil ? view.left : imageView.right
    
    pin(topLabel.left, to: leftAnchor, dist: padding)
    pin(bottomLabel.left, to: leftAnchor, dist: padding)
    
    pin(topLabel.right, to: view.right, dist: -rightPadding )
    pin(bottomLabel.right, to: view.right, dist: -rightPadding)
    
    view.onTapping(closure: { [weak self] _ in self?.handleAction() })
    registerForStyleUpdates()
  }
  
  func cleanup(){
    guard !isClosing else { return }
    isClosing = true
    bottomSheet?.close()
    removeGestures()
    finishHandler = nil
  }
  
  func handleAction(){
    guard !isClosing else { return }
    let handler = finishHandler
    let answer:Bool? = declineLabel.superview == nil ? true : nil
    cleanup()
    onMainAfter { handler?(answer) }//fix ugly animation with onMainAfter; no Effect in Dismiss
  }
  
  func handleDismiss(){
    guard !isClosing else { return }
    let handler = finishHandler
    let answer:Bool? = declineLabel.superview == nil ? false : nil
    cleanup()
    handler?(answer)
  }
  
  func setupButtons(){
    self.view.addSubview(confirmLabel)
    self.view.addSubview(declineLabel)
    pin(confirmLabel.top, to: bottomLabel.bottom, dist: padding)
    pin(declineLabel.top, to: confirmLabel.bottom, dist: padding)
    
    pin(confirmLabel.left, to: view.left, dist: padding)
    pin(declineLabel.left, to: view.left, dist: padding)
    
    pin(confirmLabel.right, to: view.right, dist: -padding)
    pin(declineLabel.right, to: view.right, dist: -padding)
  }
  
  func setup(){
    let bottomView = declineLabel.superview != nil ? declineLabel : bottomLabel
    pin(bottomView.bottom, to: view.bottom, dist: -padding)
    bottomSheet?.handleColor = .clear
    bottomSheet?.sliderView.clipsToBounds = false
    bottomSheet?.xButton.tazX()
    bottomSheet?.onX {[weak self] in self?.handleDismiss()}
    let io = TazAppEnvironment.sharedInstance.infoOffset
    self.bottomSheet?.bottomOffset = io + Const.Dist.margin
    applyStyles()
    self.view.doLayout()
    bottomSheet?.coverage = view.frame.size.height
    
    self.bottomSheet?.open()
  }
  
  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    if let sv = view.superview{
      pin(view, to: sv)
    }
  }

  init(title: String,
       text: String,
       image: UIImage? = nil,
       targetVc: UIViewController,
       bottomOffset: CGFloat? = nil,
       finishHandler: @escaping (Bool?)->()){
    super.init(nibName: nil, bundle: nil)
    rightPadding = 2*padding + 33.0 //for close x with a width of 28px
    imageView.image = image
    imageView.contentMode = .scaleAspectFit
    self.finishHandler = finishHandler
    bottomSheet = Sheet(slider: self,
                        into: targetVc,
                        maxWidth: Const.Size.OverlayMaxWidth,
                        sidePadding: 12.0)
    topLabel.text = title
    bottomLabel.text = text
    setup()
    setupTouches(targetVc: targetVc)
  }
  
  init(article:Article?,
       targetVc: UIViewController,
       bottomOffset: CGFloat? = nil,
       finishHandler: @escaping (Bool?)->()){
    super.init(nibName: nil, bundle: nil)
    rightPadding = 2*padding + 33.0 //for close x with a width of 28px
    imageView.image = article?.firstImage
    self.finishHandler = finishHandler
    bottomSheet = Sheet(slider: self,
                        into: targetVc,
                        maxWidth: Const.Size.OverlayMaxWidth,
                        sidePadding: 12.0)
    bottomLabel.text = article?.title ?? "(kein Titel angegeben)"
    setup()
    setupTouches(targetVc: targetVc)
  }
  
  @discardableResult
  init(title: String,
       text: String,
       confirmText: String,
       declineText: String,
       targetVc: UIViewController,
       finishHandler: @escaping (Bool?)->()){
    super.init(nibName: nil, bundle: nil)
    padding = 12.0 //bigger font bigger padding
    rightPadding = 12.0
    self.finishHandler = finishHandler
    bottomSheet = Sheet(slider: self,
                        into: targetVc,
                        maxWidth: Const.Size.OverlayMaxWidth,
                        sidePadding: 12.0)
    topLabel.text = title
    bottomLabel.text = text
    topLabel.textColor = UIColor.label
    bottomLabel.textColor = UIColor.label
    
    confirmLabel.text = confirmText
    declineLabel.text = declineText
    
    topLabel.boldContentFont()
    bottomLabel.contentFont()
    setupButtons()
    setup()
    bottomSheet?.xButton.isHidden = true
    setupTouches(targetVc: targetVc)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func removeGestures(){
    guard let tapRecognizer = self.tapRecognizer,
          let panRecognizer = self.panRecognizer else { return }
    self.tapRecognizer = nil
    self.panRecognizer = nil
    tapTargetView?.removeGestureRecognizer(tapRecognizer)
    tapTargetView?.removeGestureRecognizer(panRecognizer)
  }
  
  func setupTouches(targetVc: UIViewController){
    let targetView = targetVc.targetView
    bottomSheet?.shadeView.removeFromSuperview()
    self.tapTargetView = targetView
    let tapRecognizer = UITapGestureRecognizer(target: self,
                                               action: #selector(handleTapBackground))
    tapRecognizer.numberOfTapsRequired = 1
    tapRecognizer.cancelsTouchesInView = false
    tapRecognizer.delegate = self
    
    targetView.addGestureRecognizer(tapRecognizer)
    self.tapRecognizer = tapRecognizer
    
    let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleTapBackground))
    panRecognizer.cancelsTouchesInView = false
    panRecognizer.delegate = self
    targetView.addGestureRecognizer(panRecognizer)
    self.panRecognizer = panRecognizer
  }
  
  @objc private func handleTapBackground() {
    Usage.track(Usage.event.dialog.OpenLastArticleAgain, name: "Cancel")
    handleDismiss()
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

extension ContinueReadingController : UIGestureRecognizerDelegate {
  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                         shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return true
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

extension ContentToolbar {
  var yOffset: CGFloat {
    let frame = self.convert(self.bounds, to: nil)
    return frame.size.height - frame.origin.y
  }
}

extension UIView{
  var oiD:String { ObjectIdentifier(self).debugDescription }
}

extension UILabel {
  
  private static var btnHeight = 30.0
  
  func tazPrimaryButtonStyle() {
    self.boldContentFont(size: Const.Size.SmallerFontSize)
    self.textColor = .white
    self.textAlignment = .center
    self.numberOfLines = 1
    self.layer.cornerRadius = Self.btnHeight/2 + 1.0
    self.layer.masksToBounds = true
    self.layer.borderColor = UIColor.white.cgColor
    self.layer.borderWidth = 1
    self.backgroundColor = .black
    self.pinHeight(Self.btnHeight + 2.0)
  }
  
  func tazSecondaryButtonStyle() {
    self.contentFont(size: Const.Size.SmallerFontSize)
    self.textColor = .black
    self.textAlignment = .center
    self.numberOfLines = 1
    self.layer.cornerRadius = Self.btnHeight/2
    self.layer.masksToBounds = true
    self.layer.borderColor = UIColor.black.cgColor
    self.layer.borderWidth = 1
    self.backgroundColor = .white
    self.pinHeight(Self.btnHeight)
  }
}
