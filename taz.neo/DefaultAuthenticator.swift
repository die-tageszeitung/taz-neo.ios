//
//
// DefaultAuthenticator.swift
//
// Created by Ringo Müller-Gromes on 07.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit
import NorthLib

public class DefaultAuthenticator: Authenticator {
  
  /// Ref to feeder providing Data
  public var feeder: GqlFeeder
  /// Root view controller
  private lazy var rootVC: UIViewController? = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return appDelegate.window?.rootViewController
  }()
  
  /// Closure to call when polling of suscription status is required
  private var performPollingClosure: (()->())?
  /// Define closure to call when polling is necessary
  public func whenPollingRequired(closure: @escaping ()->()) {
    performPollingClosure = closure
  }
  
  /// Closure to call when authentication succeeded
  private var authenticationSucceededClosure: (()->())?
  
  required public init(feeder: GqlFeeder) {
    self.feeder = feeder
  }
  
  public func pollSubscription(closure: (_ continue: Bool)->()) {
    // nothing to do in simple case
  }
  
  

  /// Ask user for id/password, check with GraphQL-Server and store in user defaults
  public func authenticate(closure: @escaping (Error?)->()) {
    guard let rootVC = rootVC else { return }
    rootVC.modalPresentationStyle = .formSheet
    let registerController = LoginController()
    if #available(iOS 13.0, *) {
      registerController.isModalInPresentation = true
    }
    rootVC.present(registerController, animated: true, completion: nil)
  }
}
