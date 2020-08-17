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
 
 
 
 #TODO REMOVE AFTER REFACTOR
 We have the following inheritance
 - FormsController: UIViewController
 - **LoginController**
 - FormsController_Result_Controller
 - AskForTrial_Controller
 - SubscriptionIdElapsedController
 - PwForgottController
 - SubscriptionResetSuccessController
 - PasswordResetRequestedSuccessController
 - TrialSubscriptionController
 - CreateTazIDController
 - ConnectExistingTazIdController
 
 
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

// MARK: - Modal dismissType
enum dismissType {case all, current, leftFirst, two}
//enum dismissUntilType {case left, dismiss, all} @Idea

class FormsResultController: UIViewController {
  //Acces to related View, overwritten in subclasses with concrete view
  private var contentView = FormView()
  var ui : FormView { get { return contentView }}
  
  var dismissType:dismissType = .current
  /// dispisses all modal until the first occurence of given type
  /// so dismissUntil should be a UIViewController
//  var dismissUntil:Any.Type?@Idea
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let wConstraint = ui.container.pinWidth(to: self.view.width)
    wConstraint.constant = UIScreen.main.bounds.width
    wConstraint.priority = .required
    
    self.view.backgroundColor = TazColor.CTBackground.color
    self.view.addSubview(ui)
    if #available(iOS 13.0, *) {
      pin(ui, to: self.view)
    } else{
      pin(ui, toSafe: self.view)
    }
  }
  
  convenience init(message:String, backButtonTitle:String, dismissType:dismissType) {
    self.init()
    ui.views = [
      TazHeader(),
      UILabel(title: message,
              paddingTop: 30,
              paddingBottom: 30
      ),
      UIButton(title: backButtonTitle,
               target: self, action: #selector(handleBack)),
      
    ]
    self.dismissType = dismissType
  }
  
  func showResultWith(message:String, backButtonTitle:String,dismissType:dismissType){
    let successCtrl
      = FormsResultController(message: message,
                              backButtonTitle: backButtonTitle,
                              dismissType: dismissType)
    modalFlip(successCtrl)
  }
  
  // MARK: handleBack Action
  @IBAction func handleBack(_ sender: UIButton) {
    var stack = self.modalStack
    //Idea
//    if let dismissStay = dismissUntil {
//      let arr = stack.split(separator: dismissStay)
//      arr[0]
//      stack.po
//    }
    
    switch dismissType {
      case .all:
        stack.forEach { $0.view.isHidden = $0 != self ? true : false }
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

// MARK: - Modal Present extension for FormsResultController
extension FormsResultController{
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
