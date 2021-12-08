//
//  FeedbackViewController.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 02.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

public class FeedbackViewController : UIViewController{
  
  deinit {
    print("deinit: FeedbackViewController ;-)")
  }
  
  var type: FeedbackType?
  var screenshot: UIImage? {
    didSet{
      feedbackView?.screenshotAttachmentButton.image = screenshot
    }
  }
  
  var sendSuccess:Bool = false
  
  let blockingView = BlockingProcessView()
  
  var uiBlocked:Bool = false {
    didSet{
      feedbackView?.sendButton.isEnabled = !uiBlocked
      blockingView.isHidden = !uiBlocked
      blockingView.enabled = uiBlocked
    }
  }
  
  var logData: Data? = nil
  var deviceData: DeviceData?
  var feederContext: FeederContext
  var doCloseClosure: (() -> ())?
  var requestCancel: (() -> ())?
  
  public var feedbackView : FeedbackView?
  
  init(type: FeedbackType,
       screenshot: UIImage? = nil,
       deviceData: DeviceData? = nil,
       logData: Data? = nil,
       feederContext: FeederContext,
       finishClosure: (() -> ())?) {
    self.feedbackView = FeedbackView(type: type,
                                     isLoggedIn: feederContext.gqlFeeder?.authToken != nil )
    self.screenshot = screenshot
    self.type = type
    self.deviceData = deviceData
    self.logData = logData
    self.feederContext = feederContext
    self.doCloseClosure = finishClosure
    super.init(nibName: nil, bundle: nil)
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateViewSize(self.view.bounds.size)
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    self.presentedViewController?.viewWillTransition(to: size, with: coordinator)
    updateViewSize(size)
  }
  
  private var initialParent: UINavigationController?
  private var initialParentInteractivePopGestureRecognizerEnabled: Bool = false
  
  
  /// Disable swipe back to close function and restore it on close
  public override func willMove(toParent parent: UIViewController?) {
    super.willMove(toParent: parent)
    if let parent = parent as? UINavigationController, parent != initialParent {
      initialParent = parent
      initialParentInteractivePopGestureRecognizerEnabled
      = parent.interactivePopGestureRecognizer?.isEnabled ?? false
      parent.interactivePopGestureRecognizer?.isEnabled = false
    }
    else if parent == nil, initialParent != nil {
      initialParent?.interactivePopGestureRecognizer?.isEnabled
      = initialParentInteractivePopGestureRecognizerEnabled
      initialParent = nil
    }
    /// the simplier way: handleClose()  here has 2 issues:
    /// 1. user is not requested if he wants to close feedback
    /// 2. on close presenting vc is maybe in wrong size
  }
  
  private var wConstraint:NSLayoutConstraint?

  /// update size for changed traits
  func updateViewSize(_ newSize:CGSize){
    guard let feedbackView = feedbackView else { return }
    if let constraint = wConstraint{
      feedbackView.stack.removeConstraint(constraint)
    }
    wConstraint = feedbackView.stack.pinWidth(newSize.width - 24, priority: .required)
  }
  
//  public override func viewDidDisappear(_ animated: Bool) {
//    ///Warning Not Working when Presented wirh Overlay!
//    super.viewDidDisappear(animated)
//  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    guard let feedbackView = self.feedbackView else { return; }
    //didSet not called in init, so set the button`s image here
    feedbackView.screenshotAttachmentButton.image = screenshot
    feedbackView.cancelButton.addTarget(self,
                                        action: #selector(handleCancel),
                                        for: .touchUpInside)
    
    if let img = screenshot, img.size.height > 0, img.size.width > 0 {
      feedbackView.logAttachmentButton.pinWidth(feedbackView.attachmentButtonHeight * img.size.width / img.size.height, priority: .required)
    }
    
    self.view.addSubview(feedbackView)
    pin(feedbackView, to:self.view)
    self.view.addSubview(blockingView)
    pin(blockingView, to:self.view)
    
    feedbackView.screenshotAttachmentButton.onTapping { [weak self] (_) in
      self?.showScreenshot()
    }
    
    feedbackView.logAttachmentButton.onTapping {  [weak self] (_) in
      self?.showLog()
    }
    
    /// Setup Attatchment Menus
    _ = logAttatchmentMenu
    _ = screenshotAttatchmentMenu
    
    feedbackView.sendButton.addTarget(self,
                                      action: #selector(handleSend),
                                      for: .touchUpInside)
  }
  
  func handleClose(){
    if let closure = doCloseClosure {
      closure()
    }
    self.feedbackView = nil
    self.type = nil
    self.screenshot = nil
    self.logData = nil
    self.doCloseClosure = nil
    self.requestCancel = nil
    self.log("FeedbackViewController closed")
  }
  
  
  @objc func handleCancel(){
    requestCancel?()
  }
  
  //MARK: handleSend()
  @objc public func handleSend(_ force : Bool = false){
    //Wollen Sie den Report ohne weitere Angaben senden?
    
    if feedbackView == nil, let fv = self.view.subviews.first as? FeedbackView {
      feedbackView = fv
    }
        
    guard let feedbackView = feedbackView else {
      log("No Form, send not possible")
      return;
    }
    uiBlocked = true
    feedbackView.endEditing(false)//Resign First Responder
    
    if feedbackView.canSend == false {
      log("Send not possible")
      return;
    }
    
    var emptyFields:[String] = []
    let err = type != FeedbackType.feedback
    
    if !feedbackView.messageTextView.isFilled{ emptyFields.append("Nachricht")}
    if err && !feedbackView.lastInteractionTextView.isFilled{
      emptyFields.append("Letzte Interaktion")
    }
    if err && !feedbackView.environmentTextView.isFilled{
      emptyFields.append("Zustand")
    }
    
    if force == false && emptyFields.count > 0 {
      var message = emptyFields.count == 1
        ? "Das Feld \(emptyFields.joined()) ist leer."
        : "Die Felder \(emptyFields.joined(separator: ", ")) sind leer."
      message += " Möchten Sie das Formular trotzdem senden?"
      
      Alert.confirm(title: "Wirklich senden?", message: message, okText: "Senden") { [weak self] (send) in
        if send == true {
          self?.handleSend(true)
        }
        else {
          self?.uiBlocked = false
        }
      }
      return 
    }
    
    var screenshotData : String?
    var screenshotName : String?
    
    if let sc = screenshot {
      let img
        = sc.resized(targetSize: CGSize(width: UIScreen.main.bounds.size.width*0.6,
                                        height: UIScreen.main.bounds.size.height*0.6))
      screenshotData = img.pngData()?.base64EncodedString()
      screenshotName = "Screenshot_\(Date())"
    }
        
    let message = type == FeedbackType.feedback
      ? "Feedback\n=============\n\(feedbackView.messageTextView.text ?? "-")"
      : feedbackView.messageTextView.text
    
    guard let feeder = feederContext.gqlFeeder else {
      requestSendByMail()
      return
    }
     
    feeder.errorReport(message: message,
                           lastAction: feedbackView.lastInteractionTextView.text,
                           conditions: feedbackView.environmentTextView.text,
                           deviceData: deviceData,
                           errorProtocol: logString,
                           eMail: feedbackView.senderMail.text,
                           screenshotName: screenshotName,
                           screenshot: screenshotData) { (result) in
                            self.uiBlocked = false
                            switch result{
                              case .success(let msg):
                                self.log("Error Report send success: \(msg)")
                                self.sendSuccess = msg
                                self.handleClose()
                              case .failure(let err):
                                self.log("Error Report send failure: \(err)")
                                self.handleSendFail()
                            }
    }
  }
  
  func requestSendByMail(){
    //#warning("ToDo: 0.9.4 ToDo implement send by mail if offline, in prev versions nothing happen, now alert will be shown")
    log("ToDo: implement alternative send by mail")
    self.handleSendFail()
  }
  
  func handleSendFail(){
     Alert.confirm(title: "Erneut versuchen?",
      message: "Report konnte nicht gesendet werden!\nBitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.\nSollte das Problem weiter bestehen, senden Sie uns bitte eine E-Mail an:\n \(Localized("digiabo_email"))",
                       isDestructive: false) { (try_again) in
                         if try_again {
                           self.handleSend(true)
                         } else {
                           self.handleClose()
                        }
         }
  }
  
  
  
  //overlay+zoomed image view => wrong target has unwanted paddings
  func showScreenshotZiV(){
    print("Open detail View")
    let oi = OptionalImageItem()
    oi.image = screenshot
    let ziv = ZoomedImageView(optionalImage:oi)
    let vc = OverlayViewController()
    
    vc.view.addSubview(ziv)
    pin(ziv, to: vc.view)
    let overlay = Overlay(overlay: vc, into: self)
    vc.view.frame = self.view.frame
    vc.view.setNeedsLayout()
    vc.view.layoutIfNeeded()
    overlay.overlaySize = self.view.frame.size
    self.view.addBorder(.magenta)
    let openToRect = self.view.frame
    
    
    guard let child = self.feedbackView?.screenshotAttachmentButton else {
      //tapped button disapeared - impossible
      return;
    }
    let fromFrame = child.convert(child.frame, to: self.view)
    
    overlay.openAnimated(fromFrame: fromFrame,
                         toFrame: openToRect)
  }
  
  ///zoomed image in Modal VC => no Good due some edge cases let the image stay - uggly handling
  func showScreenshotSimple(){
    let vc = UIViewController()
    let oi = OptionalImageItem()
    oi.image = screenshot
    let ziv = ZoomedImageView(optionalImage:oi)
    
    vc.view.addSubview(ziv)
    pin(ziv, to: vc.view)
    self.present(vc, animated: true) {
    }
  }
  
  ///imageView in Modal VC the simple solution pan down to close like log => add close x!
  func showScreenshot(){
    let vc = OverlayViewController()
    let imageView = UIImageView(image: screenshot)
    imageView.contentMode = .scaleAspectFit
    vc.view.addSubview(imageView)
    vc.view.backgroundColor = UIColor(white: 0.0, alpha: 0.8)//hide the transparent Background from App's Screenshot
    pin(imageView, to: vc.view)
    vc.activateCloseX()
    self.present(vc, animated: true) {
    }
  }
  
  ///try to combine log presentation style (modal) with overlay and zoomable Image
  func showScreenshotHasSomeUIIssues(){
    let avc = UIViewController()
    let oi = OptionalImageItem()
    oi.image = screenshot
    let ziv = ZoomedImageView(optionalImage:oi)
    let vc = OverlayViewController()
    
    vc.view.addSubview(ziv)
    pin(ziv, to: vc.view)
    let overlay = Overlay(overlay: vc, into: avc)
    vc.view.frame = self.view.frame
    vc.view.setNeedsLayout()
    vc.view.layoutIfNeeded()
    overlay.overlaySize = self.view.frame.size
    self.view.addBorder(.magenta)
    overlay.open(animated: false, fromBottom: false)
    self.present(avc, animated: true) {
    }
  }
  
  lazy var logString: String? = {
    var log = ""
    if let data = logData,
        let lString = String(data:data , encoding: .utf8) {
      log = lString
    }
    else {
      //Feedback need no Log!
      return nil
    }
    
    let lastLog = File(Log.FileLogger.lastLogfile)
    if lastLog.exists,
       let lString = String(data:lastLog.data, encoding: .utf8) {
      let created = lastLog.cTime.dateAndTime
      log += "\n###################################"
      log += "\n     L A S T - E X E C U T I O N"
      log += "\n     \(created)"
      log += "\n###################################\n\n"
      log += lString
    }
    return log
  }()
  
  func showLog(){
    let logVc = OverlayViewController()
    let logView = SimpleLogView()
    logView.append(txt: logString ?? "")
    logVc.view.addSubview(logView)
    pin(logView, to: logVc.view)
    logVc.activateCloseX()
    self.present(logVc, animated: true) {
      print("done!!")
    }
  }
  
  lazy var logAttatchmentMenu : ContextMenu? = {
    guard let target = self.feedbackView?.logAttachmentButton else { return nil }
    let menu = ContextMenu(view: target)
    guard logData != nil else { return menu } //Called even in Feedback!
    menu.addMenuItem(title: "Ansehen", icon: "eye") {[weak self]  (_) in
      self?.showLog()
    }
    menu.addMenuItem(title: "Kopieren", icon: "doc.on.doc") {[weak self]  (_) in
      guard let log = self?.logString else { return }
      UIPasteboard.general.string = log
      Toast.show("In Zwischenablage kopiert!")
    }
    menu.addMenuItem(title: "Löschen", icon: "trash.circle") { (_) in
      self.feedbackView?.logAttachmentButton.removeFromSuperview()
      self.logData = nil
    }
    menu.iosHigher13?.addMenuItem(title: "Abbrechen", icon: "multiply.circle") { (_) in }
    return menu
  }()
  
  lazy var screenshotAttatchmentMenu : ContextMenu? = {
    guard let target = self.feedbackView?.screenshotAttachmentButton else { return nil}
    let menu = ContextMenu(view: target)
    menu.addMenuItem(title: "Ansehen", icon: "eye") { [weak self]  (_) in
      self?.showScreenshot()
    }
    menu.addMenuItem(title: "Löschen", icon: "trash.circle") { (_) in
      self.feedbackView?.screenshotAttachmentButton.removeFromSuperview()
      self.screenshot = nil
      //self.screenshot = nil
    }
    menu.iosHigher13?.addMenuItem(title: "Abbrechen", icon: "multiply.circle") { (_) in }
    return menu
  }()
  
  /// Define the menu to display on long touch of a MomentView
  public var attatchmentMenu: [(title: String, icon: String, closure: (String)->())] = []
  
  /// Add an additional menu item
  public func addMenuItem(title: String, icon: String, closure: @escaping (String)->()) {
    attatchmentMenu += (title: title, icon: icon, closure: closure)
  }
  
  public var mainmenu1 : ContextMenu?
  public var mainmenu2 : ContextMenu?
  
}

class OverlayViewController : UIViewController{
  //REFACTOR!
  public func activateCloseX(){
    setupXButton()
    onX {
      self.dismiss(animated: true, completion: nil)
    }
  }
  
  var xButton = Button<CircledXView>().tazX()
  
  func onX(closure: @escaping ()->()) {
    xButton.isHidden = false
    xButton.onPress {_ in closure() }
  }
  
  /// Setup the xButton
  func setupXButton() {
    self.view.addSubview(xButton)
    pin(xButton.right, to: self.view.rightGuide(), dist: -Const.Size.DefaultPadding)
    pin(xButton.top, to: self.view.topGuide(), dist: Const.Size.DefaultPadding)
    xButton.isHidden = true
  }
  
  deinit {
    print("deinit OverlayViewController")
  }
}
