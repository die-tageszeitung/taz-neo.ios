//
//  OfflineAlert.swift
//  taz.neo
//
//  Created by Ringo Müller on 15.04.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class OfflineAlert {
  static let sharedInstance = OfflineAlert()
  
  private init(){}
  
  var needsUpdate : Bool = false
  
  var title : String? { didSet {
    if oldValue != title { needsUpdate = true }
  }}
  var message : String? { didSet {
    if oldValue != title { needsUpdate = true }
  }}
  
  var closures : [(()->())] = []
  
  lazy var alert:UIAlertController = {
    let okButton = UIAlertAction(title: "OK", style: .cancel) {   [weak self] _ in
      self?.okPressed()
    }
    let a = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
    a.addAction(okButton)
    return a
  }()
  
  func okPressed(){
    while closures.count > 0 {
      let closure = closures.popLast()
      closure?()
    }
    needsUpdate = true //prepare for reuse
  }
  
  func updateIfNeeded(){
    if needsUpdate == false { return }
    onMain {   [weak self]  in
      guard let self = self else { return }
      self.alert.title = self.title
      self.alert.message = self.message
      
      if self.alert.presentingViewController == nil {
        UIViewController.top()?.present(self.alert, animated: true, completion: nil)
      }
      self.needsUpdate = false
    }
  }
  
  static func message(title: String? = nil, message: String, closure: (()->())? = nil) {
    sharedInstance.title = title
    sharedInstance.message = message
    if let c = closure { sharedInstance.closures.append(c)}
    sharedInstance.updateIfNeeded()
  }
}
