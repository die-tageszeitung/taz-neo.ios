//
//  DummyContentController.swift
//  anav01
//
//  Created by Norbert Thies on 24.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit

class DummyContentController: UIViewController, UIGestureRecognizerDelegate {
  
  @IBOutlet weak var shadeView: UIView!
  
  fileprivate var contentPressedClosure: ((String)->())?
  fileprivate var tazButtonPressedClosure: (()->())?
  fileprivate var backButtonPressedClosure: (()->())?
  
  fileprivate var shadeTapRecognizer: UITapGestureRecognizer!

  func onContent(closure: @escaping (String)->()) {
    contentPressedClosure = closure
  }
  
  func onTazButton(closure: @escaping ()->()) {
    tazButtonPressedClosure = closure
  }
  
  func onBackButton(closure: @escaping ()->()) {
    backButtonPressedClosure = closure
  }
  
  @IBAction func tazButtonPressed(_ sender: UIButton) {
    debug()
    if let closure = tazButtonPressedClosure { closure() }
  }
  
  @IBAction func backButtonPressed(_ sender: UIButton) {
    debug()
    if let closure = backButtonPressedClosure { closure() }
  }
  
  @IBAction func contentButtonPressed(_ sender: UIButton) {
    if let txt = sender.currentTitle {
      debug("\(txt) pressed")
      if let closure = contentPressedClosure { closure(txt) }
    }
  }
  
  @objc fileprivate func handleShadeTap(sender: UITapGestureRecognizer) {
    if sender.state == .ended {
      if let closure = tazButtonPressedClosure { closure() }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    shadeTapRecognizer = UITapGestureRecognizer(target: self,
      action: #selector(handleShadeTap))
    shadeTapRecognizer.numberOfTapsRequired = 1
    shadeView.addGestureRecognizer(shadeTapRecognizer)
  }

}
