//
//  PushNotification.Payload+Extension.swift
//  taz.neo
//
//  Created by Ringo Müller on 07.08.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

extension PushNotification.Payload {
  public var notificationType: NotificationType? {
    get {
      guard let data = self.custom["data"] as? [AnyHashable:Any] else { return nil }
      if data["articleMsId"] != nil && data["articleDate"] != nil {
        return NotificationType.articlePush
      }
      for case let (key, value) as (String, String) in data {
        if key == "perform" && value == "subscriptionPoll" {
          return NotificationType.subscription
        }
        else if key == "refresh" && value == "aboPoll" {
          return NotificationType.newIssue
        }
        else if key == "type" && value == "alert" {
          return NotificationType.textNotificationAlert
        }
        else if key == "type" && value == "toast" {
          return NotificationType.textNotificationToast
        }
      }
      return nil
    }
  }
  
  public var textNotificationMessage: String? {
    get {
      guard let data = self.custom["data"] as? [AnyHashable:Any] else { return nil }
      debug("found data: \(data)")
      guard data["type"] as? String == "alert" ||
              data["type"] as? String == "toast" else {
        debug("value for data.type is: \(data["type"] ?? "-")")
        return nil
      }
      guard let body = data["body"] as? String else {
        debug("no value for data.body")
        return nil
      }
      debug("data.body is: \(body)")
      return body
    }
  }
  
  typealias ArticlePushData = (articleMsId:Int,
                               articleTitle:String?,
                               articleBody:String?,
                               articleDate:Date,
                               payload: [AnyHashable:Any])
  
  var articlePushData: ArticlePushData? {
    get {
      guard let data = self.custom["data"] as? [AnyHashable:Any] else { return nil }
      return data.articlePushData
    }
  }
}

extension [AnyHashable:Any] {
  var articlePushData: PushNotification.Payload.ArticlePushData? {
    get {
      guard let articleMsId = self["articleMsId"] as? Int else { return nil }
      let articleTitle = self["articleTitle"] as? String
      let articleBody = self["articleBody"] as? String
      guard let articleDateString = self["articleDate"] as? String else { return nil }
      guard let articleDate = UsTime.parse(iso: articleDateString) else { return nil }
      return PushNotification.Payload.ArticlePushData(articleMsId, articleTitle, articleBody, articleDate.date, self)
    }
  }
}
