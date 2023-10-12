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
  public static func showWith(image : UIImage,
                              title : String?,
                              text : String?,
                              button1Text:String,
                              button2Text:String,
                              button1Handler : @escaping (()->()),
                              button2Handler : @escaping (()->()),
                              dataPolicyHandler : @escaping (()->())) {
    onMain {
      guard let delegate = UIApplication.shared.delegate,
            let window = delegate.window as? UIWindow else {  return }
      let toast = NewInfoToast(image : image,
                               title :title,
                               text : text,
                               button1Text:button1Text,
                               button2Text:button2Text,
                               button1Handler : button1Handler,
                               button2Handler : button2Handler,
                               dataPolicyHandler : dataPolicyHandler)
      func showAnimated(){
        UIView.animate(withDuration: 0.9,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.8,
                       options: UIView.AnimationOptions.curveEaseInOut,
                       animations: {
                        toast.shadeView.alpha = 1.0
                        toast.scrollViewYConstraint?.constant = 0
                        toast.layoutIfNeeded()
                       }, completion: { (_) in
                        if toast.isTopmost == false {
                          window.bringSubviewToFront(toast)
                        }
                       })
      }
      toast.shadeView.alpha = 0.0
      toast.isHidden = true
      window.addSubview(toast)
      toast.scrollViewYConstraint?.constant = window.frame.size.height
      toast.layoutIfNeeded()
      toast.isHidden = false
      showAnimated()
    }
  }

  // MARK: - Constants / Default Environment
  private let maxWidth:CGFloat = 360
  private let maxHeight:CGFloat = 420
  private let linePadding:CGFloat = 15
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
    pin(imageView.left, to: container.leftGuide(), dist: 20)
    pin(imageView.top, to: pinTopAnchor, dist: -5)
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
    pin(privacyText.top, to: pinTopAnchor, dist: linePadding)
    pinTopAnchor = privacyText.bottom
    
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
    self.scrollViewYConstraint = scrollView.center().y
    
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
    view.pinHeight(270)
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
    view.linkTextAttributes = [.foregroundColor : Const.SetColor.HText.color, .underlineColor: Const.SetColor.HText.color]
    view.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
    view.textColor = Const.SetColor.HText.color
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
