//
//  UIAlertAction+Extension.swift
//  taz.neo
//
//  Created by Ringo Müller on 07.08.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

extension UIAlertAction {
  static func developerPushActions(callback: @escaping (Bool) -> ()?) -> [UIAlertAction] {
    let newIssue:UIAlertAction = UIAlertAction(title: "Simulator: NewIssuePush",
                                                 style: .default){_ in
      let payload:[AnyHashable : Any] = [
        "aps":[
          "content-available" : 1,
          "sound": nil],
        "data":[
          "refresh": "aboPoll"
        ]
      ]
      TazAppEnvironment.sharedInstance.feederContext?.processPushNotification(pn: PushNotification(),
                                                                              payload: PushNotification.Payload(payload),
                                                                              fetchCompletionHandler: nil)
      callback(false)
    }
    
    let article:UIAlertAction = UIAlertAction(title: "Simulator: ArticlePush",
                                                 style: .default){_ in
      let payload:[AnyHashable : Any] = [
        "aps":[
          "content-available" : 1,
          "sound": nil],
        "data":[
          "articleMsId" : 6022610,
          "articleTitle" : "Resilienz für die Roten Roben",
          "articleBody" : "Das Bundesverfassungsgericht soll vor einer Übernahme durch die AfD geschützt werden. SPD, Grüne, FDP und CDU/CSU berufen sich auf die Erfahrungen aus Polen und Ungarn",
          "refresh" : "aboPoll",
          "articleDate" : "2024-07-24"
        ]
      ]
      TazAppEnvironment.sharedInstance.feederContext?.processPushNotification(pn: PushNotification(),
                                                                              payload: PushNotification.Payload(payload),
                                                                              fetchCompletionHandler: nil)
      callback(false)
    }

    let textPushAlert:UIAlertAction = UIAlertAction(title: "Simulator: TextPush Alert",
                                                    style: .default){_ in
      let payload:[AnyHashable : Any] = [
        "aps":[
          "alert":[
            "title": "2 Test",
            "body": "Hallo dies ist ein zweiter Test"],
          "sound": "default"],
        "data":[
          "type": "alert",
          "title": " ",
          "body": "<h1>Testüberschrift</h1><h2>Subhead</h2><p><b>Hallo</b> <i>dies <del>ist</del> ein <mark>zweiter</mark></i><br/><u>Test!</u></p>\n"
        ]
      ]
      TazAppEnvironment.sharedInstance.feederContext?.processPushNotification(pn: PushNotification(),
                                                                              payload: PushNotification.Payload(payload),
                                                                              fetchCompletionHandler: nil)
      callback(false)
    }

    let textPushToast:UIAlertAction = UIAlertAction(title: "Simulator: TextPush Toast",
                                                    style: .default){_ in
      let payload:[AnyHashable : Any] = [
        "aps":[
          "alert":[
            "title": "2 Test",
            "body": "Hallo dies ist ein zweiter Test"],
          "sound": "default"],
        "data":[
          "type": "toast",
          "title": " ",
          "body": "<h1>Testüberschrift</h1><h2>Subhead</h2><p><b>Hallo</b> <i>dies <del>ist</del> ein <mark>zweiter</mark></i><br/><u>Test!</u></p>\n"
        ]
      ]
      TazAppEnvironment.sharedInstance.feederContext?.processPushNotification(pn: PushNotification(),
                                                                              payload: PushNotification.Payload(payload),
                                                                              fetchCompletionHandler: nil)
      callback(false)
    }

    return [newIssue, article, textPushAlert, textPushToast]
  }
}
