//
//  OfflineAlert.swift
//  taz.neo
//
//  Created by Ringo Müller on 15.04.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

enum OfflineAlertType { case initial, issueDownload }

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
  
  var actionButtonTitle : String? { didSet {
    if oldValue != actionButtonTitle { needsUpdate = true }
  }}
  
  var closures : [(()->())] = []
  
  lazy var alert:AlertController = {
    let actionButton = UIAlertAction(title: actionButtonTitle, style: .cancel) {   [weak self] _ in
      self?.buttonPressed()
    }
    let a = AlertController(title: nil, message: nil, preferredStyle: .alert)
    a.addAction(actionButton)
    return a
  }()
  
  func buttonPressed(){
    var oldClosures = closures
    closures = []
    needsUpdate = true //prepare for reuse

    while oldClosures.count > 0 {
      let closure = oldClosures.popLast()
      closure?()
    }
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
  
  static func show(type: OfflineAlertType, closure: (()->())? = nil) {
    var name = "\(TazAppEnvironment.sharedInstance.feederContext?.name ?? "")"
    if name.length > 1 { name = "\(name)-"}
    switch type {
      case .initial:
        sharedInstance.title = "Fehler"
        sharedInstance.actionButtonTitle = "Erneut versuchen"
        sharedInstance.message = """
        Ich kann den \(name)Server nicht erreichen, möglicherweise
        besteht keine Verbindung zum Internet. Oder Sie haben der App
        die Verwendung mobiler Daten nicht gestattet.
        Bitte versuchen Sie es zu einem späteren Zeitpunkt
        noch einmal.
        """
        if let c = closure { sharedInstance.closures = [c]}
      case .issueDownload:
        sharedInstance.title = "Warnung"
        sharedInstance.actionButtonTitle = "OK"
        sharedInstance.message = """
        Beim Laden der Ausgabe ist ein Fehler aufgetreten.
        Bitte versuchen Sie es zu einem späteren Zeitpunkt
        noch einmal.
        Sie können bereits heruntergeladene Ausgaben auch
        ohne Internet-Zugriff lesen.
        """
        if let c = closure { sharedInstance.closures.append(c)}
    }
    sharedInstance.updateIfNeeded()
  }
  
  /// enqueues callback to presented Alert
  /// - Parameter closure: closure to add to callback handlers
  /// - Returns: true if presented and closure added, otherwise false
  static func enqueueCallbackIfPresented(closure: (()->())? = nil) -> Bool {
    if sharedInstance.alert.presentingViewController != nil,
       let c = closure {
      sharedInstance.closures.append(c)
      return true
    }
    return false
  }
  
  
}
