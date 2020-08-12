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
class FormsController: UIViewController {
  
  //Subview where the COntent/Form is displayed
  var contentView = FormView()
  //Reference for AuthMediator to interact with the rest of the App
  var auth:AuthMediator
  
  lazy var defaultCancelButton:UIButton = {
    return UIButton(type: .outline,
                    title: Localized("cancel_button"),
                    target: self,
                    action: #selector(handleDefaultCancel))
  }()
  
  public var uiBlocked : Bool = false {
    didSet{
      contentView.blockingView.enabled = uiBlocked
    }
  }
  
  init(_ auth:AuthMediator) {
     self.auth = auth
     super.init(nibName: nil, bundle: nil)
   }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  //Overwrite this in child to have individual Content
  func getContentViews() -> [UIView] {
    return [TazHeader()]
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.contentView.views = getContentViews()
    
    let wConstraint = self.contentView.container.pinWidth(to: self.view.width)
    wConstraint.constant = UIScreen.main.bounds.width
    wConstraint.priority = .required
    
    self.view.backgroundColor = TazColor.CTBackground.color
    self.view.addSubview(self.contentView)
    if #available(iOS 13.0, *) {
      pin(self.contentView, to: self.view)
    } else{
      pin(self.contentView, toSafe: self.view)
    }
  }
  
  func showResultWith(message:String, backButtonTitle:String,dismissType:dismissType){
    let successCtrl
      = FormsController_Result_Controller(message: message,
                                          backButtonTitle: backButtonTitle,
                                          dismissType: dismissType, auth: self.auth)
    modalFlip(successCtrl)
  }
  
  // MARK: handleCancel Action
   @IBAction func handleDefaultCancel(_ sender: UIButton) {
    self.dismiss(animated: true, completion: nil)
   }
}

// MARK: - Modal Present extension for FormsController
extension FormsController{
  /// Present given VC on topmost Viewcontroller with flip transition
  func modalFlip(_ controller:UIViewController){
    controller.modalPresentationStyle = .overCurrentContext
    controller.modalTransitionStyle = .flipHorizontal
    
    var topmostModalVc : UIViewController = self
    while true {
      if let modal = topmostModalVc.presentedViewController {
        topmostModalVc = modal
      }
      else{
        topmostModalVc.present(controller, animated: true, completion:nil)
        break
      }
    }
  }
  
  func modalFromBottom(_ controller:UIViewController){
    controller.modalPresentationStyle = .overCurrentContext
    controller.modalTransitionStyle = .coverVertical
    
    var topmostModalVc : UIViewController = self
    while true {
      if let modal = topmostModalVc.presentedViewController {
        topmostModalVc = modal
      }
      else{
        topmostModalVc.present(controller, animated: true, completion:nil)
        break
      }
    }
  }
}

// MARK: - Modal dismissType
enum dismissType {case all, current, leftFirst}

// MARK: - ConnectTazID_Result_Controller
class FormsController_Result_Controller: FormsController {
  var message:String = ""
  var backButtonTitle:String = ""
  var dismissType:dismissType = .current
  
  override func getContentViews() -> [UIView] {
    return  [
      TazHeader(),
      UILabel(title: message,
              paddingTop: 30,
              paddingBottom: 30
      ),
      UIButton(title: backButtonTitle,
               target: self, action: #selector(handleBack)),
      
    ]
  }
  
  convenience init(message:String, backButtonTitle:String, dismissType:dismissType, auth:AuthMediator) {
    self.init(auth)
    self.message = message
    self.backButtonTitle = backButtonTitle
    self.dismissType = dismissType
  }
  
  // MARK: handleBack Action
  @IBAction func handleBack(_ sender: UIButton) {
    var stack = self.modalStack
    switch dismissType {
      case .all:
        stack.forEach { $0.view.isHidden = true }
        UIViewController.dismiss(stack: stack, animated: false, completion: {
          Notification.send("ExternalUserLogin")
        })
      case .leftFirst:
        _ = stack.popLast()//removes first
        _ = stack.pop()//removes self
        stack.forEach { $0.view.isHidden = true }
        self.dismiss(animated: true) {
          stack.forEach { $0.dismiss(animated: false, completion: nil)}
      }
      case .current:
        self.dismiss(animated: true, completion: nil)
    }
  }
}

// MARK: - ext: FormsController:UITextViewDelegate
extension FormsController: UITextViewDelegate {
  func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
    ///Handle AGB Demo Url come from Localizable.strings
    ///"fragment_login_request_test_subscription_terms_and_conditions" = "Ich akzeptiere die <a href='https://taz.de/!106726'>AGB</a> sowie die Hinweise zum <a href='https://taz.de'>Widerruf (N/A)</a> und <a href='https://taz.de/!166598'>Datenschutz</a>.";
    if URL.absoluteString.contains("taz.de/!106726"){
      let introVC = IntroVC()
      let resdir = auth.feeder.resourcesDir.path
      let dataPolicy = File(resdir + "/welcomeSlidesDataPolicy.html")
      introVC.webView.webView.load(url: dataPolicy.url)
      modalFromBottom(introVC)
      introVC.webView.onX {
        introVC.dismiss(animated: true, completion: nil)
      }
      if false /*Use footer close Button*/{
        introVC.webView.buttonLabel.text = Localized("back_button")
        introVC.webView.onTap {_ in
        introVC.dismiss(animated: true, completion: nil)
        }
      }
      else{//Or
        introVC.webView.webView.atEndOfContent {_ in
          //Do nothing overwrite appear Bottom Label/View
        }
      }
      
      
      return false
    }
    else if URL.absoluteString.contains("taz.de/datenschutz"){
      //ToDo
    }
    else if URL.absoluteString.contains("taz.de/hinweisewiderruf"){
      
    }
    else{
      Toast.show(Localized(keyWithFormat: "prevent_open_url",
                           URL.absoluteString),
                 .alert)
    }
    return true//Open in Safari
  }
}

// MARK: - ext: UIViewController
extension UIViewController{
  /// dismiss helper for stack of modal presented VC's
  static func dismiss(stack:[UIViewController], animated:Bool, completion: @escaping(() -> Void)){
    var stack = stack
    let vc = stack.pop()
    vc?.dismiss(animated: animated, completion: {
      if stack.count > 0 {
        UIViewController.dismiss(stack: stack, animated: false, completion: completion)
      } else {
        completion()
      }
    })
  }
  
  /// helper to find presenting VC for stack of modal presented VC's
  var rootPresentingViewController : UIViewController {
    get{
      var vc = self
      while true {
        if let pvc = vc.presentingViewController {
          vc = pvc
        }
        return vc
      }
    }
  }
  
  /// helper to find 1st presended VC in stack of modal presented VC's
  var rootModalViewController : UIViewController? {
    get{
      return self.rootPresentingViewController.presentedViewController
    }
  }
  
  /// helper for stack of modal presented VC's, to get all modal presented VC's below self
  var modalStack : [UIViewController] {
    get{
      var stack:[UIViewController] = []
      var vc:UIViewController = self
      while true {
        if let pc = vc.presentingViewController {
          stack.append(vc)
          vc = pc
        }
        else {
          return stack
        }
      }
    }
  }
}
