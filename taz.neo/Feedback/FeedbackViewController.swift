//
//  FeedbackViewController.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 02.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import MessageUI

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
  var feederContext: FeederContext?
  var doCloseClosure: (() -> ())?
  var requestCancel: (() -> ())?
  
  var feedbackView : FeedbackView?
  
  init(type: FeedbackType,
       screenshot: UIImage? = nil,
       deviceData: DeviceData? = nil,
       logData: Data? = nil,
       feederContext: FeederContext?,
       finishClosure: (() -> ())?) {
    self.feedbackView = FeedbackView(type: type,
                                     isLoggedIn: feederContext?.gqlFeeder?.authToken ?? nil != nil )
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
    
    guard let feeder = feederContext?.gqlFeeder else {
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
    if MFMailComposeViewController.canSendMail() {
      let recipient = "app@taz.de"
      let mail =  MFMailComposeViewController()
      mail.mailComposeDelegate = self
      mail.setToRecipients([recipient])
      
      var tazIdText = ""
      let data = DefaultAuthenticator.getUserData()
      if let tazID = data.id, tazID.isEmpty == false {
        tazIdText = " taz-Konto: \(tazID)"
      }
      
      mail.setSubject("\(type?.description ?? "UNERWARTETES VERHALTEN!") \"\(App.name)\" (iOS)\(tazIdText)")
      
      
      var body = "Per E-Mail gesendeter Fehlerbericht!"
      
      body.append("\nIhre Nachricht:\n\(feedbackView?.messageTextView.text ?? "-")\n")
      body.append("\nLetzte Interaktion:\n\(feedbackView?.lastInteractionTextView.text ?? "-")\n")
      body.append("\nZustand:\n\(feedbackView?.environmentTextView.text ?? "-")\n")
      body.append("\nGeräteinformationen:\n---------------------\n")
      body.append("App: \(App.name) \(App.bundleVersion)-\(App.buildNumber)\n")
      body.append("OS: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n")
      body.append("Gerät: \(Device.singleton), \(Utsname.machine)\n")
      body.append("installationId: \(App.installationId)\n")
      body.append("pushToken: \(Defaults.singleton["pushToken"] ?? "-")\n")
      var storageAvailable = "-"
      if let mem = deviceData?.storageAvailable, let iMem = Int(mem) {
        storageAvailable = "\(iMem/(1024*1024))MB"
      }
      body.append("storageAvailable: \(storageAvailable)\n")
      var ramAvailable = "-"
      if let mem = deviceData?.ramAvailable, let iMem = Int(mem) {
        ramAvailable = "\(iMem/(1024*1024))MB"
      }
      body.append("ramAvailable: \(ramAvailable)\n")
      var ramUsed = "-"
      if let mem = deviceData?.ramUsed, let iMem = Int(mem) {
        ramUsed = "\(iMem/(1024*1024))MB"
      }
      body.append("ramUsed: \(ramUsed)\n")

      mail.setMessageBody("\(body) \n\n\n\n",isHTML: false)
      
      let dateId = Date().ddMMyy_HHmmss
      
      if let screenshotData = screenshot?.jpeg {
        mail.addAttachmentData(screenshotData, mimeType: "image/jpeg",
                               fileName: "Screenshot_\(dateId).jpg")
      }
      
      if let logData = logString?.data(using: .utf8) {
        mail.addAttachmentData(logData, mimeType: "text/plain",
                               fileName: "Protokoll_\(dateId).txt")
      }
      self.present(mail, animated: true)
    }
    else {
      self.handleSendFail()
    }
  }
  
  func handleSendFail(){
    let retryAction =  UIAlertAction.init( title: "Erneut versuchen",
                                           style: .default) { [weak self] _ in
      self?.handleSend(true)
    }
    let mailAction =  UIAlertAction.init( title: "Per E-Mail senden",
                                          style: .default) {  [weak self] _ in
      self?.requestSendByMail()
    }
    let revertAction =  UIAlertAction.init( title: "Report Verwerfen",
                                            style: .destructive) {  [weak self] _ in
      self?.requestCancel?()
    }
    
    let cancelAction =  UIAlertAction.init( title: "Abbrechen",
                                            style: .cancel)
    
    var actions = [retryAction, revertAction, cancelAction]
    
    if MFMailComposeViewController.canSendMail() {
      actions.insert(mailAction, at: 1)
    }
    
    Alert.message(title: "Erneut versuchen?",
                      message: "Der Report konnte nicht gesendet werden!\nBitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.\nSollte das Problem weiter bestehen, senden Sie uns bitte eine E-Mail an:\n \(Localized("digiabo_email"))",
                      actions: actions, presentationController: self)
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
    menu.addMenuItem(title: "Löschen", icon: "trash.circle") {[weak self] (_) in
      self?.feedbackView?.logAttachmentButton.removeFromSuperview()
      self?.logData = nil
    }
    menu.iosHigher13?.addMenuItem(title: "Abbrechen", icon: "xmark.circle") { (_) in }
    return menu
  }()
  
  lazy var screenshotAttatchmentMenu : ContextMenu? = {
    guard let target = self.feedbackView?.screenshotAttachmentButton else { return nil}
    let menu = ContextMenu(view: target)
    menu.addMenuItem(title: "Ansehen", icon: "eye") { [weak self]  (_) in
      self?.showScreenshot()
    }
    menu.addMenuItem(title: "Löschen", icon: "trash.circle") {[weak self] (_) in
      self?.feedbackView?.screenshotAttachmentButton.removeFromSuperview()
      self?.screenshot = nil
      //self.screenshot = nil
    }
    menu.iosHigher13?.addMenuItem(title: "Abbrechen", icon: "xmark.circle") { (_) in }
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

extension FeedbackViewController : MFMailComposeViewControllerDelegate {
  public func mailComposeController(_ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true)
    if error != nil {
      self.log("Mail send failed with error: \(error?.description ?? "-")")
    }
    switch result {
      case .sent:
        Alert.message(title: "E-Mail gesendet.",
                      message: "Falls Sie offline sind, befindet sich die E-Mail noch im Postausgang.",
                      presentationController: self) { [weak self] in
          self?.handleClose()
        }
      case .saved:
        Alert.message(title: "E-Mail nicht gesendet!",
                      message: "Die E-Mail befindet sich im E-Mail Programm im Ordner \"Entwürfe\"\nBitte senden Sie uns die E-Mail zeitnah, damit wir Ihr Anliegen bearbeiten können.",
                      presentationController: self) { [weak self]  in
          self?.handleClose()
        }
      case .cancelled:
          self.handleSendFail()
      default:
        Alert.message(title: "Fehler!",
                      message: "Es gab einen Fehler, bitte versuchen Sie es apäter noch einmal.",
                      presentationController: self) { [weak self]  in
          self?.handleSendFail()
        }
    }
  }
}


class OverlayViewController : UIViewController{
  //REFACTOR!
  public func activateCloseX(){
    setupXButton()
    onX {
      self.dismiss(animated: true, completion: nil)
    }
  }
  
  var xButton = Button<ImageView>().tazX()
  
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
