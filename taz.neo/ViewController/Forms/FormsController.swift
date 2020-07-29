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
  var contentView : FormularView?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    _ = SharedFeeder.shared //setup once
    guard let content = contentView else {
      return
    }
    
    let wConstraint = content.container.pinWidth(to: self.view.width)
    wConstraint.constant = UIScreen.main.bounds.width
    wConstraint.priority = .required
    self.view.addSubview(content)
    pin(content, to: self.view)
  }
  
  func showResultWith(message:String, backButtonTitle:String,dismissType:dismissType){
    let successCtrl
       = FormsController_Result_Controller(message: message,
                                        backButtonTitle: backButtonTitle,
                                       dismissType: dismissType)
    modalFlip(successCtrl)

  }
  
  func modalFlip(_ controller:UIViewController){
    controller.modalPresentationStyle = .overCurrentContext
    controller.modalTransitionStyle = .flipHorizontal
    self.present(controller, animated: true, completion:nil)
  }
}

enum dismissType {case all, current, leftFirst}

// MARK: - ConnectTazID_Result_Controller
class FormsController_Result_Controller: FormsController {
  var views : [UIView] = []
  var dismissType:dismissType = .current

  convenience init(message:String, backButtonTitle:String, dismissType:dismissType) {
    self.init(nibName:nil, bundle:nil)
    self.dismissType = dismissType
    self.views =  [
         FormularView.header(),
         FormularView.label(title: message,
                            paddingTop: 30,
                            paddingBottom: 30
         ),
         FormularView.button(title: backButtonTitle,
                             target: self, action: #selector(handleBack)),
         
       ]
  }

  override func viewDidLoad() {
    self.contentView = FormularView()
    self.contentView?.views = self.views
    super.viewDidLoad()
  }
  
  // MARK: handleBack Action
  @IBAction func handleBack(_ sender: UIButton) {
    var stack = self.modalStack
    switch dismissType {
      case .all:
        _ = stack.popLast()//removes self
        stack.forEach { $0.view.isHidden = true }
        self.dismiss(animated: true) {
          stack.forEach { $0.dismiss(animated: false, completion: nil)}
        }
      case .leftFirst:
        _ = stack.popLast()//removes self
        _ = stack.pop()//removes first
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
            return stack.reversed()
          }
      }
     }
   }
}
