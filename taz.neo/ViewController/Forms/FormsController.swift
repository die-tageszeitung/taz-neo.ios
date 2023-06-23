//
//
// FormsController.swift
//
// Created by Ringo Müller-Gromes on 22.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib


/// #TODO: move to NorthLib String Extension
// MARK: - String extension
extension String{
  var isNumber : Bool {
    get {
      return CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: self))
    }
  }
}

// MARK: - FormsController
/**
 The Forms Controller is the Base Class for all Login, taz-ID Forms delivers an interface to acces
 the feeder via AuthMediator.
 
 **TODO Discussion**: Move the AuthMediator to Initially Presented VC (LoginController)
 
 **Initially** the **LoginController** will be presented.
 - using UIKit's default **ModalPresent to display ** further/relating Views(ViewController)
 - using UIKit's default **MVC** mechanism with View/ViewController
 - generic FormView for simple ui
 - concrete, inherited from FormView for more complex ui
 - inherited FormController for to Controll its FormView
 - the controllers are structured according to their base (API) functionalities
 - **FormsController** (no API functionality)
 - **FormsController_Result_Controller**
 - **SubscriptionIdElapsedController**
 - **LoginController**
 - **PwForgottController**
 - **ConnectTazIdController**
 - **TrialSubscriptionController**
 
 
 #Discussion TextView with Attributed String for format & handle Links/E-Mail Adresses
 or multiple Views with individual button/click Handler
 Pro: AttributedString Con: multiple views
 + minimal UICreation Code => solve by using compose views...
 - hande of link leaves the app => solve by using individual handler
 - ugly html & data handling
 + super simple add & exchange text
 */

class FormsController: FormsResultController {
  //Reference for AuthMediator to interact with the rest of the App
  var auth:AuthMediator
  /// **TODO** Try to create a convience init out of it!!
  init(_ auth:AuthMediator) {
    self.auth = auth
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension FormsController {
  static var backButtonTitle:String {
    guard let nc = UIViewController.currentRootController as? UINavigationController,
          let vc = nc.viewControllers.last else {
            return "Zurück"
          }
    switch vc {
      case _ as ArticleVC:
        return "Zurück zum Artikel"
      case _ as TazPdfPagesViewController:
        return "Zurück zur Ausgabe"
      case _ as SettingsVC:
        return "Zurück zu den Einstellungen"
      case _ as HomeTVC://Currently due Settings are presented modal
        return "Zurück zu den Einstellungen"
      default:
        return "Zurück"
    }
  }
}

// MARK: - Modal dismissType
enum dismissType {case allReal, all, current, leftFirst, two}
//enum dismissUntilType {case left, dismiss, all} @Idea

class FormsResultController: UIViewController {
  //Acces to related View, overwritten in subclasses with concrete view
  private var contentView = FormView()
  private var wConstraint:NSLayoutConstraint?
  
  var dismissAllFinishedClosure: (()->())?
  
  private var messageLabel = Padded.Label(paddingTop: 30, paddingBottom: 15)
  private var messageLabel2 = Padded.Label(paddingTop: 15, paddingBottom: 30)
  
  /// Exchange the displayed text with the new one
  /// - Parameters:
  ///   - newText: text to exchange
  ///   - showBoth: show both text for a while
  func exchangeWith(_ newText:String?, _ showBoth:Bool = true){
    if showBoth == false {
      self.messageLabel.setTextAnimated(newText)
      return
    }
    
    self.messageLabel2.setTextAnimated(newText)
    delay(seconds: 2) {
      self.messageLabel.setTextAnimated("")
    }
  }
  
  let xButton = Button<ImageView>()
  
  /// Setup the xButton
  func setupXButton() {
    xButton.tazX()
    self.view.addSubview(xButton)
    pin(xButton.right, to: self.view.rightGuide(), dist: -15)
    pin(xButton.top, to: self.view.topGuide(), dist: 15)
    xButton.onPress { [weak self] _ in
      self?.handleBack(nil)
    }
  }
    
  var ui : FormView { get { return contentView }}
  
  var dismissType:dismissType = .current
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = Const.SetColor.CTBackground.color
    self.view.addSubview(ui)
    pin(ui, to: self.view).top.constant = 0
    setupXButton()
    self.isModalInPresentation = true
  }
  
  override var preferredContentSize: CGSize {
    get{
      let windowSize = UIApplication.shared.windows.first?.bounds.size ?? UIScreen.main.bounds.size
      updateViewSize(windowSize)
      ui.container.doLayout()
      let h = min(ui.container.frame.size.height, windowSize.height)
      return  CGSize(width: 540, height: h)
    }
    set{
      log("not implemented")
    }
 
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateViewSize(self.view.bounds.size)
  }
    
  /// Updates the Controllers View Size for changed traits
  ///
  /// In this Case height did not matter
  /// - Parameter newSize: new Size for hosted view
  func updateViewSize(_ newSize:CGSize){
    if let constraint = wConstraint{
      ui.container.removeConstraint(constraint)
    }
    
    let windowSize = UIApplication.shared.windows.first?.bounds.size ?? UIScreen.main.bounds.size
    
    ///Fix Form Sheet Size
    if newSize.width > 540 && Device.isIpad {
      let formSheetSize = CGSize(width: 540,
                                 height: windowSize.height)
      wConstraint = ui.container.pinWidth(formSheetSize.width, priority: .required)
    } else {
      wConstraint = ui.container.pinWidth(newSize.width, priority: .required)

    }
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    /// Unfortulatly the presented VC's did not recice the msg. no matter which presentation style
    self.presentedViewController?.viewWillTransition(to: size, with: coordinator)
    updateViewSize(size)
  }
  
  
  convenience init(message:String,
                   backButtonTitle:String,
                   dismissType:dismissType) {
    self.init()
    messageLabel.text = message
    messageLabel.numberOfLines = 0
    
    messageLabel2.text = ""
    messageLabel2.numberOfLines = 0
    
    ui.views = [
      messageLabel,
      messageLabel2,
      Padded.Button(title: backButtonTitle,
               target: self, action: #selector(handleBack)),
      
    ]
    self.dismissType = dismissType
  }
  
  
  /// Flips (Modal Push) a new FormsResultController on existinf Form* Controller
  /// - Parameters:
  ///   - message: Message displayed in FormsResultController
  ///   - backButtonTitle: -
  ///   - dismissType: action on back e.g. dismiss all or leftFirst
  ///   - dismissAllFinishedClosure: closure for dismissAll
  ///     currently there is only a closure for dismiss all but more is not needed yet
  ///     currently only UIViewController.dismiss provides needed functionallity
  func showResultWith(message:String,
                      backButtonTitle:String,
                      dismissType:dismissType,
                      showSpinner:Bool = false,
                      validExchangedText:String? = nil,
                      dismissAllFinishedClosure: (()->())? = nil){
    let successCtrl
      = FormsResultController(message: message,
                              backButtonTitle: backButtonTitle,
                              dismissType: dismissType)
    successCtrl.dismissAllFinishedClosure = dismissAllFinishedClosure
    modalFromBottom(successCtrl)
  }
  
  func handleRequestCancelUserInput(){
    let dismissAction = UIAlertAction(title: "Ja, Änderungen verwerfen",
                                      style: .destructive) { [weak self] _ in
      self?.dismiss()
    }
    let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel)
    
    Alert.message(message:  "Änderungen verwerfen?",
                  actions: [dismissAction,  cancelAction],
                  presentationController: self)
  }
  
  // MARK: handleBack Action
  @IBAction func handleBack(_ sender: UIButton?) {
    if self.ui.hasUserInput {
      handleRequestCancelUserInput()
    } else {
      dismiss()
    }
  }
    
    // MARK: handleBack Action
  func dismiss() {
    var stack = self.modalStack
    switch dismissType {
      case .allReal:
        stack.forEach {
          if $0.isKind(of: FormsResultController.self){
            $0.view.isHidden = $0 != self ? true : false
          }
        }
        UIViewController.dismissForms(stack: stack, animated: false, completion: self.dismissAllFinishedClosure)
      case .leftFirst, .all:
        //remove first, to kept it on vc stack!
        //currently the firt item in stack is maybe Settungs and a return was maybe not possible
        if let root = stack.popLast(), root.isKind(of: FormsResultController.self) == false {
          _ = stack.popLast()
        }
        stack.pop()//removes self
        stack.forEach { $0.view.isHidden = true }
        self.dismiss(animated: true) {
          stack.forEach { $0.dismiss(animated: false, completion: nil)}
      }
      case .current:
        self.dismiss(animated: true, completion: nil)
      case .two:
        if let parent = self.presentingViewController, parent.presentingViewController != nil {
          parent.view.isHidden = true
          self.dismiss(animated: true, completion: {
            parent.dismiss(animated: false, completion: nil)
          })
        } else {
          self.dismiss(animated: true, completion: nil)
        }
    }
  }
}

extension UIViewController {
  var topmostModalVc : UIViewController {
    get {
      var topmostModalVc : UIViewController = self
      while true {
        if let modal = topmostModalVc.presentedViewController {
          topmostModalVc = modal
        }
        else{
          return topmostModalVc
        }
      }
    }
  }
  
  /// dismiss helper for stack of modal presented VC's
  public static func dismissForms(stack:[UIViewController], animated:Bool, completion: (() -> Void)?){
    var stack = stack
    let vc = stack.pop()
    if vc?.isKind(of: FormsResultController.self) == false{
      completion?()
      return
    }
    vc?.dismiss(animated: animated, completion: {
      if stack.count > 0 {
        UIViewController.dismissForms(stack: stack, animated: false, completion: completion)
      } else {
        completion?()
      }
    })
  }
}

// MARK: - Modal Present extension for FormsResultController
extension FormsResultController{
  func modalFromBottom(_ controller:UIViewController, completion: (() -> Void)? = nil){
    controller.modalPresentationStyle = .overCurrentContext
    controller.modalTransitionStyle = .coverVertical
    
    var topmostModalVc : UIViewController = self
    while true {
      if let modal = topmostModalVc.presentedViewController {
        topmostModalVc = modal
      }
      else{
        ensureMain {
          topmostModalVc.present(controller, animated: true, completion:completion)
        }
        break
      }
    }
  }
}


// MARK: - ext: FormsController:UITextViewDelegate
extension FormsController: UITextViewDelegate {
  func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
    var localResource:File?
    if URL.absoluteString.contains("taz.de/\(Const.Filename.dataPolicy)"){
      localResource = File(auth.feeder.dataPolicy)
    }
    else if URL.absoluteString.contains("taz.de/\(Const.Filename.revocation)"){
      localResource = File(auth.feeder.revocation)
    }
    else if URL.absoluteString.contains("taz.de/\(Const.Filename.terms)"){
      localResource = File(auth.feeder.terms)
    }
    
    if let localResource = localResource, localResource.exists {
      let introVC = IntroVC()
      introVC.topOffset = Const.Dist.margin
      introVC.isModalInPresentation = true
      introVC.webView.webView.load(url: localResource.url)
      modalFromBottom(introVC) {
        //Overwrite Default in: IntroVC viewDidLoad
        introVC.webView.buttonLabel.text = nil
        //fix X-Button color due meta pages (terms, privacy) are currently not in darkmode
        guard let bv = introVC.webView.xButton as? Button<ImageView> else { return }
        bv.buttonView.color =  Const.Colors.iOSLight.secondaryLabel
        bv.layer.backgroundColor = Const.Colors.iOSLight.secondarySystemFill.cgColor
      }
      introVC.webView.onX {_ in 
        introVC.dismiss(animated: true, completion: nil)
      }
      introVC.webView.webView.scrollDelegate.atEndOfContent {_ in }
      return false
    }
    
    return true//If not yet downloaded open in Safari, so the url is called
    //and we see how often app users cannot open the AGB etc from local resources
  }
}

// MARK: - ext: UIViewController
extension UIViewController{
  /// helper for stack of modal presented VC's, to get all modal presented VC's below self
  var baseLoginController : LoginController? {
    get{
      if let lc = self.modalStack.last as? LoginController {
        return lc //login in Article
      }
      if let lc = self.modalStack.valueAt(-1, allowReverseSearch: true) as? LoginController {
        return lc //login in Settings
      }
      return nil
    }
  }
}
