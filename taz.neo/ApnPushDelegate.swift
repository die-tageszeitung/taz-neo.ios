//
//  ApnPushDelegate.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.03.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

class ApnPushDelegate: NSObject {
  
  static func setup(){
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      Log.log("cannot setup Push Notifications")
      return
    }
    appDelegate.onReceivePush { (pn, payload) in
      Self.processPushNotification(pn: pn, payload: payload)
    }
  }
  
  static func processPushNotification(pn: PushNotification, payload: PushNotification.Payload){
    Log.log("cannot setup Push Notifications")
    
    switch payload.notificationType {
      case .subscription:
        Log.log("check subscription status")
        TazAppEnvironment.sharedInstance.feederContext?.doPolling()
      case .newIssue:
        if App.isAvailable(.AUTODOWNLOAD) == false {
          Log.log("Currently not handle new Issue Push Current App State: \(UIApplication.shared.stateDescription)")
          return
        }
        Log.log("Handle new Issue Push Current App State: \(UIApplication.shared.stateDescription)")
//
//          autol
//        let sfs = StoredFeed.get(name: defaultFeed.name, inFeeder: storedFeeder)
//        guard let sf0 = sfs.first else {
//          log("feed not found")
//          return
//        }
//        guard let sissue = StoredIssue.issuesInFeed(feed: sf0, count: 1).first else {
//          log("issue not found")
//          return
//        }
//
//        guard !sissue.isComplete else {
//          log("issue still downloaded")
//          return
//        }
//        log("Download Issue: \(sissue.date.short)")
//        self.getCompleteIssue(issue: sissue, isAutomatically: true)
      default:
        Log.debug("no action implemented for: \(payload.toString())")
    }
  }
}

extension PushNotification.Payload {
  public var notificationType: NotificationType? {
    get {
      guard let data = self.custom["data"] as? [AnyHashable:Any] else { return nil }
      for case let (key, value) as (String, String) in data {
        if key == "perform" && value == "subscriptionPoll" {
          return NotificationType.subscription
        }
        else if key == "refresh" && value == "aboPoll" {
          return NotificationType.newIssue
        }
      }
      return nil
    }
  }
}


