//
//  InfoToast.swift
//  taz.neo
//
//  Created by Ringo Müller on 31.03.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//
import UIKit
import NorthLib

public class InfoToast : UIView {
  /// <#Description#>
  /// - Parameters:
  ///   - image: <#image description#>
  ///   - title: <#title description#>
  ///   - text: <#text description#>
  ///   - buttonText: <#buttonText description#>
  ///   - hasCloseX: <#hasCloseX description#>
  ///   - autoDisappearAfter: <#autoDisappearAfter description#>
  ///   - dismissHandler: <#dismissHandler description#>
  public static func showWith(image : UIImage?, title : String?, text : String?, buttonText:String = "OK", hasCloseX : Bool = true, autoDisappearAfter : Float? = nil, dismissHandler : (()->())? = nil) {
    onMain {
      guard let window = UIApplication.shared.delegate?.window as? UIWindow else {  return }
      let toast = InfoToast(image: image,
                            title: title,
                            text: text,
                            buttonText: buttonText,
                            hasCloseX: hasCloseX,
                            autoDisappearAfter: autoDisappearAfter,
                            dismissHandler: dismissHandler)
      toast.shadeView.alpha = 0.0
      toast.scrollView.frame.origin.y = window.frame.size.height
      window.addSubview(toast)
      
      UIView.animate(withDuration: 0.9,
                     delay: 0,
                     usingSpringWithDamping: 0.6,
                     initialSpringVelocity: 0.8,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
                      toast.shadeView.alpha = 1.0
                      toast.scrollView.frame.origin.y = 0
                     }, completion: { (_) in
                      if toast.isTopmost == false {
                        window.bringSubviewToFront(toast)
                      }
                     })
    }
  }

  // MARK: - Constants / Default Environment
  private let maxWidth:CGFloat = 400
  private let maxHeight:CGFloat = 400
  private let linePadding:CGFloat = 15
  private let sidePadding:CGFloat = 20
  
  // MARK: - Properties
  private var image : UIImage?
  private var title : String?
  private var text : String?
  private var buttonText:String
  private var hasCloseX : Bool
  private var autoDisappearAfter : Float?
  private var dismissHandler : (()->())?
  
  // MARK: - LayoutConstrains
  private var scrollViewWidthConstraint : NSLayoutConstraint?
  private var scrollViewHeightConstraint : NSLayoutConstraint?
  private var contentWidthConstraint : NSLayoutConstraint?
  private var widthConstraint : NSLayoutConstraint?
  private var heightConstraint : NSLayoutConstraint?
  
  // MARK: - Lifecycle
  
  init(image : UIImage?, title : String?, text : String?, buttonText:String = "OK", hasCloseX : Bool = true, autoDisappearAfter : Float? = nil, dismissHandler : (()->())? = nil) {
    self.image = image
    self.title = title
    self.text = text
    self.buttonText = buttonText
    self.hasCloseX = hasCloseX
    self.autoDisappearAfter = autoDisappearAfter
    self.dismissHandler = dismissHandler
    super.init(frame: .zero)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func willMove(toSuperview newSuperview: UIView?) {
    if newSuperview != nil { setupIfNeeded() }
    super.willMove(toSuperview: superview)
  }
  
  func setupIfNeeded(){
    if container.superview != nil { return }
    
    self.addSubview(shadeView)
    pin(shadeView, to: self)
    
    ///Layout Components
    var pinTopAnchor:LayoutAnchorY = container.topGuide()
    
    if let img = image {
      container.addSubview(imageView)
      pin(imageView.right, to: container.rightGuide(), dist: -sidePadding)
      pin(imageView.left, to: container.leftGuide(), dist: sidePadding)
      pin(imageView.top, to: pinTopAnchor, dist: 35)
      imageView.pinAspect(ratio: img.size.width/img.size.height)
      pinTopAnchor = imageView.bottom
    }
    
    if (title != nil) {
      container.addSubview(titleLabel)
      pin(titleLabel.right, to: container.rightGuide(), dist: -sidePadding)
      pin(titleLabel.left, to: container.leftGuide(), dist: sidePadding)
      pin(titleLabel.top, to: pinTopAnchor, dist: linePadding)
      pinTopAnchor = titleLabel.bottom
    }
    
    if (text != nil) {
      container.addSubview(textLabel)
      pin(textLabel.right, to: container.rightGuide(), dist: -sidePadding)
      pin(textLabel.left, to: container.leftGuide(), dist: sidePadding)
      pin(textLabel.top, to: pinTopAnchor, dist: linePadding)
      pinTopAnchor = textLabel.bottom
    }
    
    if hasCloseX {
      container.addSubview(xButton)
      pin(xButton.right, to: container.rightGuide(), dist: -10)
      pin(xButton.top, to: container.topGuide(), dist: 10)
    }
    
    container.addSubview(defaultButton)
    pin(defaultButton.right, to: container.rightGuide(), dist: -sidePadding)
    pin(defaultButton.left, to: container.leftGuide(), dist: sidePadding, priority: .fittingSizeLevel)
    pin(defaultButton.top, to: pinTopAnchor, dist: linePadding)
    pinTopAnchor = defaultButton.bottom
    
    pin(pinTopAnchor, to: container.bottomGuide(), dist: -sidePadding)
    
    ///Container, ScrollView and global Layout
    var scrollViewSize = UIWindow.size
      
    if scrollViewSize.width > maxWidth { scrollViewSize.width = maxWidth }
    if scrollViewSize.height > maxHeight { scrollViewSize.height = maxHeight }
    
    scrollView.addSubview(container)
    contentWidthConstraint = container.pinWidth(scrollViewSize.width)
    scrollViewWidthConstraint = scrollView.pinWidth(scrollViewSize.width)
    pin(container, to: scrollView)
    scrollView.centerY()
    scrollViewHeightConstraint = pin(scrollView.height, to: container.height)
    
    (widthConstraint, heightConstraint) = self.pinSize(UIWindow.size)
    
    self.addSubview(scrollView)
    scrollView.center()
    
    Notification.receive(Const.NotificationNames.viewSizeTransition) {   [weak self] notification in
      guard let self = self else { return }
      guard let newSize = notification.content as? CGSize else { return }
      if newSize.height < self.maxHeight {
        self.scrollViewHeightConstraint?.constant = newSize.height
      }
      if newSize.width < self.maxWidth {
        self.scrollViewWidthConstraint?.constant = newSize.width
        self.contentWidthConstraint?.constant = newSize.width
      }
      self.widthConstraint?.constant = newSize.width
      self.heightConstraint?.constant = newSize.height
    }
  }
  
  func dismiss(){
    UIView.animate(withDuration: 0.7,
                   delay: 0,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.8,
                   options: UIView.AnimationOptions.curveEaseInOut,
                   animations: {
                    self.scrollView.frame.origin.y = UIWindow.size.height + 50
                    self.shadeView.alpha = 0.0
                   }, completion: { _ in
                    self.removeFromSuperview()
                    self.dismissHandler?()
                   })
  }
  
  
  // MARK: - UI Components
  
  lazy var container: UIView  = UIView()
  lazy var shadeView: UIView  = {
    var view = UIView()
    view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    return view
  }()
  
  lazy var scrollView: UIScrollView  = {
    var view = UIScrollView()
    view.backgroundColor = UIColor.white
    view.layer.cornerRadius = 7.0
//    view.addBorder(.red)
    return view
  }()
  
  lazy var xButton: Button<CircledXView>  = {
    var x = Button<CircledXView>()
    x.pinHeight(35)
    x.pinWidth(35)
    x.color = .black
    x.buttonView.isCircle = false
    x.buttonView.circleColor = UIColor.clear
    x.buttonView.color = Const.Colors.iOSLight.secondaryLabel
    x.buttonView.activeColor = Const.Colors.ciColor
    x.buttonView.innerCircleFactor = 0.5
    x.onPress { [weak self] _ in self?.dismiss() }
    return x
  }()
  
  lazy var imageView: UIImageView  = {
    var view = UIImageView()
    view.image = image
    view.contentMode = .scaleAspectFit
    return view
  }()
  
  lazy var titleLabel: UILabel  = {
    var label = UILabel()
    label.font = Const.Fonts.titleFont(size: Const.Size.SmallTitleFontSize)
    label.textAlignment = .left
    label.numberOfLines = 0
    label.text = title
    return label
  }()
  
  lazy var textLabel: UILabel  = {
    var label = UILabel()
    label.contentFont().textAlignment = .left
    label.numberOfLines = 0
    label.text = text
    return label
  }()
  
  lazy var defaultButton: Button<TextView> = {
    var btn = Button<TextView>()
    btn.buttonView.text = buttonText
    btn.onPress { [weak self] _ in self?.dismiss() }
    btn.buttonView.label.textAlignment = .right
    btn.buttonView.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
    btn.buttonView.color = Const.Colors.ciColor
    btn.buttonView.activeColor = Const.Colors.iOSLight.secondaryLabel
    btn.pinHeight(27)
    return btn
  }()
    
}
