//
//
// FormView.swift
//
// Created by Ringo Müller-Gromes on 01.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

// MARK: - FormularView
public class FormView: UIView {
  
  let DefaultFontSize = CGFloat(16)
  
  // MARK: Container for Content in ScrollView
  let container = UIView()
  let scrollView = UIScrollView()
  
  var leftSideConstraints: [NSLayoutConstraint] = []
  var rightSideConstraints: [NSLayoutConstraint] = []
  
  let blockingView = BlockingProcessView()
  
  public var hasUserInput : Bool {
    for v in views ?? [] {
      if (v as? TazTextField)?.text?.length ?? 0 > 0 { return true }
      if (v as? TazTextView)?.text?.length ?? 0 > 0 { return true }
    }
    return false
  }
  
  public var blocked : Bool = false {
    didSet{
      ensureMain { [weak self] in
        guard let self = self else { return }
        self.blockingView.enabled = self.blocked
      }
    }
  }
  
  ///Set views before added to superview otherwise createSubviews() is used
  var views : [UIView]?
  ///if not overwritten and no [views] provided, a taz header is used
  func createSubviews() -> [UIView] { return [TazHeader()] }
  
  var updatedConstrainsAtWidth: CGFloat = 0.0
  
  public override func layoutSubviews() {
    updateCustomConstraintsIfNeeded()
    super.layoutSubviews()
  }
  
  public func updateCustomConstraintsIfNeeded() {
    if abs(updatedConstrainsAtWidth - self.frame.size.width) < 10 { return }
    updatedConstrainsAtWidth = self.frame.size.width
    updateCustomConstraints()
  }
  
  var isTabletLayout: Bool {
    return self.frame.size.width > Const.Size.TabletFormMinWidth
  }
  
  public func updateCustomConstraints() {
    let dist
    = isTabletLayout
    ? Const.Size.TabletSidePadding
    : Const.Size.DefaultPadding
    leftSideConstraints.forEach { c in c.constant = dist }
    rightSideConstraints.forEach { c in c.constant = -dist }
  }
  
  // MARK: createSubviews need to be overwritten in inherited
  public override func willMove(toSuperview newSuperview: UIView?) {
    if newSuperview != nil {///do nothing if removed
      setKeyboardObserving()
      let _views = views ?? createSubviews()
      addAndPin(_views)
    }
    super.willMove(toSuperview: newSuperview)
  }
  
  // MARK: addAndPin
  func addAndPin(_ views: [UIView]){
    self.subviews.forEach({ $0.removeFromSuperview() })
    self.backgroundColor = Const.SetColor.taz2(.backgroundForms).color
    if views.isEmpty { return }
    self.views = views
    
    let margin : CGFloat = Const.Size.DefaultPadding
    var previous : UIView?
    
    var tfTags : Int = 100
    
    for v in views {
      if v is KeyboardToolbarForText {
        v.tag = tfTags
        tfTags += 1
      }
      //add
      container.addSubview(v)
      //pin
      if v is MarketingContainerWrapperView {
        pin(v.left, to: container.left)
        pin(v.right, to: container.right)
      }
      else {
        leftSideConstraints.append(pin(v.left, to: container.left, dist: margin))
        rightSideConstraints.append(pin(v.right, to: container.right, dist: -margin, priority: UILayoutPriority(950)))
      }

      if previous == nil {
        pin(v.top, to: container.top, dist: margin + 30)//Top Margin
      }
      else {
        pin(v.top, to: previous!.bottom, dist: padding(previous!, v))
      }
      previous = v
    }
    if previous is MarketingContainerWrapperView {
      pin(previous!.bottom, to: container.bottom, dist: Const.Dist2.l + Const.Dist2.m15)
    }
    else {
      pin(previous!.bottom, to: container.bottom, dist: -margin - 30.0)
    }
    scrollView.addSubview(container)
    NorthLib.pin(container, to: scrollView)
    self.addSubview(scrollView)
    NorthLib.pin(scrollView, to: self)
    self.addSubview(blockingView)
    NorthLib.pin(blockingView, to: self)
  }
}

extension FormView {
  func openFaqAction() -> UIAlertAction {
    return UIAlertAction(title: Localized("open_faq_in_browser"), style: .default) { _ in
      if StoreBusiness.canRegister == false {
        Alert.message(message: "Leider können wir Ihnen keinen direkten Link zu unseren häufig gestellten Fragen zur App (App-FAQ) anbieten. Sie finden diese Informationen auf unserer Webseite.")
        return
      }
      guard let url = Const.Urls.faqUrl else { return }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
      
  @objc public func showRegisterTips(_ textField: UITextField) {
     Alert.message(title: Localized("register_tips_button"),
                   message: Localized("register_tips_text"),
                   additionalActions: [openFaqAction()])
    Usage.track(Usage.event.dialog.SubscriptionHelp)
  }
  
  var registerTipsButton:UIButton{
    get{
      return Padded.Button(type: .label,
                           title: Localized("register_tips_button"),
                           target: self,
                           action: #selector(showRegisterTips))
    }
  }
}


// MARK: Keyboard Action, set ScrollView Insets if Keyboard appears
extension FormView {
  fileprivate func setKeyboardObserving(){
    let notificationCenter = NotificationCenter.default
    
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardWillShow),
                                   name:UIResponder.keyboardWillShowNotification,
                                   object: nil)
    notificationCenter.addObserver(self,
                                   selector: #selector(keyboardWillHide),
                                   name:UIResponder.keyboardWillHideNotification,
                                   object: nil)
  }
  
  @objc func keyboardWillShow(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    
    // Get the keyboard height
    guard let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
    let keyBoardOffset = keyboardFrame.origin.y
    let popoverYOffset = self.convert(CGPoint.zero, to: window).y
    let visibleHeight = keyBoardOffset - popoverYOffset
    // Identify the active input field
    guard let field = UIResponder.currentFirstResponder() as? UIView else { return }
    // Get the position of the input field relative to the entire screen
    let fieldBottom = field.maxY
    // Get the position of the Send button and extend the scroll area if needed
    if let bottomItem = self.scrollView.subviews.last {
      let bottomItemBottom = bottomItem.maxY + 10
      self.scrollView.contentSize.height += bottomItemBottom
    }
    // Check if the input field is covered by the keyboard
    if fieldBottom > visibleHeight {
      let offset = fieldBottom - visibleHeight
      self.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyBoardOffset, right: 0)
      self.scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
    }
  }
  
  @objc func keyboardWillHide(_ notification: Notification) {
    UIView.animate(withDuration: 0.3) {
      self.scrollView.contentInset = .zero
      // Reset content size to the height of the container
      self.scrollView.contentSize.height = self.container.frame.height
    }
  }

}

extension UIView {
  func centeredWrapper(maxWidth: CGFloat = Const.Size.TabletFormMinWidth/2) -> Padded.View {
    self.pinWidth(maxWidth,
                  relation: .lessThanOrEqual,
                  priority: .required)
    let wrapper = Padded.View()
    wrapper.addSubview(self)
    pin(self.top, to: wrapper.top)
    pin(self.bottom, to: wrapper.bottom)
    pin(self.left, to: wrapper.left, priority: .defaultLow)
    pin(self.right, to: wrapper.right, priority: .defaultLow)
    self.centerX()
    wrapper.paddingTop = Const.Dist2.m30
    wrapper.paddingBottom = Const.Dist2.l
    return wrapper
  }
}

extension UIResponder {
    private static weak var currentResponder: UIResponder?

    static func currentFirstResponder() -> UIResponder? {
        currentResponder = nil
        UIApplication.shared.sendAction(#selector(findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return currentResponder
    }

    @objc private func findFirstResponder(_ sender: Any) {
        UIResponder.currentResponder = self
    }
}

fileprivate extension UIView {
  var maxY: CGFloat {
    if self is TazTextView.GrowableTextView {
        return self.frame.origin.y + self.frame.size.height + (self.superview?.frame.origin.y ?? 0.0)
    }
    return self.frame.origin.y + self.frame.size.height
  }
}
