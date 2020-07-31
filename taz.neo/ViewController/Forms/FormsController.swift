//
//
// FormsController.swift
//
// Created by Ringo Müller-Gromes on 22.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

extension String{
  var isNumber : Bool {
    get {
      return CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: self))
    }
  }
}

internal class SharedFeeder {
  // MARK: - Properties
  var feeder : GqlFeeder?
  static let shared = SharedFeeder()
  // Initialization
  
  private init() {
    feeder = MainNC.singleton.gqlFeeder
    //      self.setupFeeder { [weak self] _ in
    //        guard let self = self else { return }
    //        print("Feeder ready.\(String(describing: self.feeder?.toString()))")
    //      }
    Toast.alertBackgroundColor = TazColor.CIColor.color
  }
  
  // MARK: setupFeeder
  func setupFeeder(closure: @escaping (Result<Feeder,Error>)->()) {
    self.feeder = GqlFeeder(title: "taz", url: "https://dl.taz.de/appGraphQl") { [weak self] (res) in
      guard let self = self else { return }
      guard res.value() != nil else { return }
      //Notification.send("userLogin")
      if let feeder = self.feeder {
        print("success")
        closure(.success(feeder))
      }
      else {
        print("fail")
        closure(.failure(NSError(domain: "taz.test", code: 123, userInfo: nil)))
      }
    }
  }
  
}

class FormsController: UIViewController {
  var contentView = FormularView()
  
  //Overwrite this in child to have individual Content
  func getContentViews() -> [UIView] {
    return [TazHeader()]
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    _ = SharedFeeder.shared //setup once
    
    self.contentView.views = getContentViews()
    
    let wConstraint = self.contentView.container.pinWidth(to: self.view.width)
    wConstraint.constant = UIScreen.main.bounds.width
    wConstraint.priority = .required
    self.view.addSubview(self.contentView)
    pin(self.contentView, to: self.view)
  }
  
  func showResultWith(message:String, backButtonTitle:String,dismissType:dismissType){
    let successCtrl
      = FormsController_Result_Controller(message: message,
                                          backButtonTitle: backButtonTitle,
                                          dismissType: dismissType)
    modalFlip(successCtrl)
    
  }
  
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
}

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
  
  convenience init(message:String, backButtonTitle:String, dismissType:dismissType) {
    self.init(nibName:nil, bundle:nil)
    self.message = message
    self.backButtonTitle = backButtonTitle
    self.dismissType = dismissType
  }
  
  // MARK: handleBack Action
  @IBAction func handleBack(_ sender: UIButton) {
    var stack = self.modalStack
    switch dismissType {
      case .all:
        _ = stack.pop()//removes self
        stack.forEach { $0.view.isHidden = true }
        self.dismiss(animated: true) {
          stack.forEach { $0.dismiss(animated: false, completion: nil)}
          Notification.send("ExternalUserLogin")
      }
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

extension UIViewController{
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
  
  var rootModalViewController : UIViewController? {
    get{
      return self.rootPresentingViewController.presentedViewController
    }
  }
  
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
