//
//  NewInfoToast.swift
//  taz.neo
//
//  Duplicate of InfoToast used as long, until the old one will be removed
//
//  Created by Ringo Müller on 12.10.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//
import UIKit
import NorthLib

public class NewInfoToast : UIView {
  
  /// Helper to generate and show Info Toast on Application Window
  /// - Parameters:
  ///   - image: image for the Toast
  ///   - title: Title text
  ///   - text: Content text
  ///   - buttonText: text for bottom Button
  ///   - hasCloseX: should top right close x be displayed
  ///   - autoDisappearAfter: TODO Automatic disappear after Timeout in seconds
  ///   - dismissHandler: handler to be called after toast dismissed
  ///   **WARNING** latest adjustments for Matomo Opt In Popover and iPhone SE1
  public static func showWith(image : UIImage,
                              title : String?,
                              text : String?,
                              button1Text:String,
                              button2Text:String,
                              button1Handler : @escaping (()->()),
                              button2Handler : @escaping (()->()),
                              dataPolicyHandler : @escaping (()->())) -> NewInfoToast {
    return NewInfoToast(image : image,
                             title :title,
                             text : text,
                             button1Text:button1Text,
                             button2Text:button2Text,
                             button1Handler : button1Handler,
                             button2Handler : button2Handler,
                             dataPolicyHandler : dataPolicyHandler)
  }

  // MARK: - Constants / Default Environment
  private let maxWidth:CGFloat = 430
  private let maxHeight:CGFloat = 670
  private var linePadding:CGFloat = UIWindow.size.height < 580 ? 10 : 15
  private let sidePadding:CGFloat = 20
  
  private var image : UIImage
  private var title : String?
  private var text : String?
  private var button1Text:String
  private var button2Text:String
  private var button1Handler : (()->())
  private var button2Handler : (()->())
  private var dataPolicyHandler : (()->())
  
  // MARK: - LayoutConstrains
  private var scrollViewWidthConstraint : NSLayoutConstraint?
  private var scrollViewHeightConstraint : NSLayoutConstraint?
  private var scrollViewYConstraint : NSLayoutConstraint?
  private var contentWidthConstraint : NSLayoutConstraint?
  private var widthConstraint : NSLayoutConstraint?
  private var heightConstraint : NSLayoutConstraint?
  private var imageHeightConstraint : NSLayoutConstraint?
  private var adjustSmallDevice = UIWindow.size.height < 580
  
  // MARK: - Lifecycle
  
  init(image : UIImage,
       title : String?,
       text : String?,
       button1Text:String,
       button2Text:String,
       button1Handler : @escaping (()->()),
       button2Handler : @escaping (()->()),
       dataPolicyHandler : @escaping (()->())) {
    self.image = image
    self.title = title
    self.text = text
    self.button1Text = button1Text
    self.button2Text = button2Text
    self.button1Handler = button1Handler
    self.button2Handler = button2Handler
    self.dataPolicyHandler = dataPolicyHandler
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
    container.addSubview(imageView)
    pin(imageView.right, to: container.rightGuide(), dist:0)
    pin(imageView.left, to: container.leftGuide(), dist: 0)
    pin(imageView.top, to: pinTopAnchor, dist: -10)
    pinTopAnchor = imageView.bottom
    
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
    
    container.addSubview(button1)
    pin(button1.right, to: container.rightGuide(), dist: -sidePadding)
    pin(button1.left, to: container.leftGuide(), dist: sidePadding)
    pin(button1.top, to: pinTopAnchor, dist: linePadding)
    pinTopAnchor = button1.bottom
    
    container.addSubview(button2)
    pin(button2.right, to: container.rightGuide(), dist: -sidePadding)
    pin(button2.left, to: container.leftGuide(), dist: sidePadding)
    pin(button2.top, to: pinTopAnchor, dist: linePadding)
    pinTopAnchor = button2.bottom
    
    container.addSubview(privacyText)
    pin(privacyText.right, to: container.rightGuide(), dist: -sidePadding)
    pin(privacyText.left, to: container.leftGuide(), dist: sidePadding)
    pin(privacyText.top, to: pinTopAnchor, dist: adjustSmallDevice ? 0 : linePadding)
    pinTopAnchor = privacyText.bottom
    
    pin(pinTopAnchor, to: container.bottomGuide(), dist: -sidePadding)
    
    ///Container, ScrollView and global Layout
    var scrollViewSize = UIWindow.size
    
    if adjustSmallDevice {
      titleLabel.font = Const.Fonts.titleFont(size: Const.Size.ContentTableFontSize * 0.8)
      textLabel.contentFont(size: Const.Size.DefaultFontSize * 0.9)
      privacyText.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize * 0.9)
      privacyText.layoutMargins = .zero
      imageView.pinHeight(200)
    }
    imageView.pinHeight(adjustSmallDevice ? 200 : 270)
      
    if scrollViewSize.width > maxWidth { scrollViewSize.width = maxWidth }
    if scrollViewSize.height > maxHeight { scrollViewSize.height = maxHeight }
    scrollView.isScrollEnabled = true
    scrollView.addSubview(container)
    contentWidthConstraint = container.pinWidth(scrollViewSize.width)
    scrollViewWidthConstraint = scrollView.pinWidth(scrollViewSize.width)
    scrollViewHeightConstraint = scrollView.pinHeight(scrollViewSize.height)
    
    (widthConstraint, heightConstraint) = self.pinSize(UIWindow.size)
    
    self.addSubview(scrollView)
    self.scrollViewYConstraint = scrollView.centerAxis().y
    
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
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    self.scrollView.contentSize = container.frame.size
  }
  
  func show(fromBottom:Bool = false){
    if Thread.isMainThread == false {
      onMain {[weak self] in self?.show()}
      return
    }
    guard let delegate = UIApplication.shared.delegate,
          let window = delegate.window as? UIWindow else {  return }
    
    self.shadeView.alpha = 0.0
    self.isHidden = true
    window.addSubview(self)
    if fromBottom {
      self.scrollViewYConstraint?.constant = window.frame.size.height
    }
    self.layoutIfNeeded()
    self.isHidden = false
    
    var yTarget = 0.0
    let offset = scrollView.frame.size.height - UIWindow.size.height
    if adjustSmallDevice, offset < 0, offset > -50 {
      yTarget = -offset
    }
    
    UIView.animate(withDuration: 0.9,
                   delay: 0,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.8,
                   options: UIView.AnimationOptions.curveEaseInOut,
                   animations: {[weak self] in
      self?.shadeView.alpha = 1.0
      self?.scrollViewYConstraint?.constant = yTarget
      self?.layoutIfNeeded()
    }, completion: {[weak self](_) in
      guard let self = self else { return }
      if self.isTopmost == false {
        window.bringSubviewToFront(self)
      }
    })
  }
  
  func dismiss(){
    UIView.animate(withDuration: 0.7,
                   delay: 0,
                   usingSpringWithDamping: 0.6,
                   initialSpringVelocity: 0.8,
                   options: UIView.AnimationOptions.curveEaseInOut,
                   animations: {
                    self.scrollViewYConstraint?.constant = UIWindow.size.height + 50
                    self.shadeView.alpha = 0.0
                    self.layoutIfNeeded()
                   }, completion: { _ in
                    self.removeFromSuperview()
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
    return view
  }()
    
  
  lazy var imageView: UIImageView  = {
    var view = UIImageView()
    view.image = image
    return view
  }()
  
  lazy var titleLabel: UILabel  = {
    var label = UILabel()
    label.font = Const.Fonts.titleFont(size: Const.Size.ContentTableFontSize)
    label.textAlignment = .left
    label.numberOfLines = 0
    label.text = title
    label.textColor = .black
    return label
  }()
  
  lazy var textLabel: UILabel  = {
    var label = UILabel()
    label.contentFont().textAlignment = .left
    label.numberOfLines = 0
    label.text = text
    label.textColor = .black
    return label
  }()
  
  @objc public func handleButton1Action(){
    button1Handler()
    dismiss()
  }
  
  lazy var button1 = Padded.Button(type: .newBlackOutline,
                                title: button1Text,
                                   target: self,
                                   action: #selector(handleButton1Action))
    
  @objc public func handleButton2Action(){
    button2Handler()
    dismiss()
  }
  
  lazy var button2 = Padded.Button(type: .newBlackOutline,
                                title: button2Text,
                                   target: self,
                                   action: #selector(handleButton2Action))
  
  lazy var privacyText : CustomTextView = {
    let view = CustomTextView()
    view.isEditable = false
    view.attributedText = Localized("fragment_tracking_privacy_info").htmlAttributed
    view.linkTextAttributes = [.foregroundColor : Const.SetColor.HText.brightColor, .underlineColor: Const.SetColor.HText.brightColor]
    view.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
    view.textColor = Const.SetColor.HText.brightColor
    view.textAlignment = .center
    view.delegate = self ///FormsController cares
    return view
  }()
  
  
}
// MARK: - ext: FormsController:UITextViewDelegate
extension NewInfoToast: UITextViewDelegate {
  public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
    dataPolicyHandler()
    return false
  }
}
