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
      self.setupFeeder { [weak self] _ in
        guard let self = self else { return }
        print("Feeder ready.\(String(describing: self.feeder?.toString()))")
      }
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
}
