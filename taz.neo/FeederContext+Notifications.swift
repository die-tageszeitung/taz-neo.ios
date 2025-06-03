//
//  FeederContext+Notifications.swift
//  taz.neo
//
//  Created by Ringo Müller on 07.08.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import UIKit

// MARK: - Messaging, NotificationCenter
extension FeederContext {
  
  /// notify sends a Notification to all objects listening to the passed
  /// String 'name'. The receiver closure gets the sending FeederContext
  /// as 'sender' argument.
  func notify(_ name: String, content: Any? = nil) {
    Notification.send(name, content: content, sender: self)
  }
  
  /// This notify sends a Result<Type,Error>
  func notify<Type>(_ name: String, result: Result<Type,Error>) {
    Notification.send(name, result: result, sender: self)
  }
}
  
// MARK: - RemoteNotifications (Push)
extension FeederContext {
  
  /// Ask for push token and report it to server
  public func setupRemoteNotifications(force: Bool? = false) {
    let nd = UIApplication.shared.delegate as! AppDelegate
    let dfl = Defaults.singleton
    let oldToken = dfl["pushToken"] ?? Defaults.lastKnownPushToken
    Defaults.lastKnownPushToken = oldToken
    pushToken = oldToken
    nd.onReceivePush { [weak self] (pn, payload, completion) in
      self?.processPushNotification(pn: pn, payload: payload, fetchCompletionHandler: completion)
    }
    nd.onOpenApplicationFromNotification {[weak self] center, response, handler in
      self?.onOpenApplicationFromNotification(center: center,
                                              response: response,
                                              completionHandler: handler)
    }
    nd.permitPush {[weak self] pn in
      guard let self = self else { return }
      if pn.isPermitted {
        self.debug("Push permission granted")
        self.pushToken = pn.deviceId
        Defaults.lastKnownPushToken = self.pushToken
      }
      else {
        self.debug("No push permission")
        self.pushToken = nil
      }
      dfl["pushToken"] = self.pushToken
     
      //not send request if no change and not force happens eg. on every App Start
      if force == false && oldToken == self.pushToken { return }
      // if force ensure not to send old token if oldToken == newToken
      let oldToken = (force == true && oldToken == self.pushToken) ? nil : oldToken
            
      let isTextNotification = dfl["isTextNotification"]!.bool
      
      self.gqlFeeder.notification(pushToken: self.pushToken, oldToken: oldToken,
                                  isTextNotification: isTextNotification) { [weak self] res in
        if let err = res.error() { self?.error(err) }
        else {
          Defaults.lastKnownPushToken = self?.pushToken
          self?.debug("Updated PushToken")
        }
      }
    }
  }
  
  func processPushNotification(pn: PushNotification, payload: PushNotification.Payload, fetchCompletionHandler: FetchCompletionHandler?){
    ///process incomming Push Notifications within 30s!
    ///@see:
    ///https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:didreceiveremotenotification:fetchcompletionhandler:)
    log("Processing: \(payload) AppState: \(UIApplication.shared.stateDescription)")
    switch payload.notificationType {
      case .subscription:
        log("check subscription status")
        doPolling(fetchCompletionHandler)
      case .newIssue:
        handleNewIssuePush(fetchCompletionHandler)
      case .articlePush:
        handleArticlePush(pn: pn, payload: payload, fetchCompletionHandler: fetchCompletionHandler)
      case .textNotificationAlert:
        ///the deactivated code triggers a local notification if App would be started
        ///there is user feedback that the notification only appears in notification center if App is just started
        ///that makes no sense > so deactivated
        //if UIApplication.shared.applicationState == .active {
        //  LocalNotifications.notify(payload: payload)
        //}
        fetchCompletionHandler?(.noData)
      case .textNotificationToast:
        if UIApplication.shared.applicationState == .active,
           let msg = payload.textNotificationMessage {
          Toast.show(msg)
        }
        fetchCompletionHandler?(.noData)
      default:
        fetchCompletionHandler?(.noData)
    }
  }
  
  ///handle application started from NotificationCenter, if app already running
  func onOpenApplicationFromNotification(center: UNUserNotificationCenter,
                                         response: UNNotificationResponse,
                                         completionHandler:()->()){
    guard let data = response.notification.request.content.userInfo.articlePushData else { return }
    debug("open article: \(data.articleTitle ?? "\(data.articleMsId)") in issue with date: \(data.articleDate.short)")
    Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
  }
  
  ///handle incomming push notification
  ///due no Background Issue download available, just add a local notification with the info; download will happen after App Foreground start
  public func handleArticlePush(pn: PushNotification,
                                payload: PushNotification.Payload,
                                fetchCompletionHandler: FetchCompletionHandler?) {
    log("Handle new Article Push\n  Current App State: \(UIApplication.shared.stateDescription)\n  feed: \(self.defaultFeed.name)")
    log("pn: \(pn) ")
    if specialArticleSystemSetting == false {
      log("do not notify user, deactivated")
      fetchCompletionHandler?(.noData)
      return
    }
    guard let data = payload.articlePushData else {
      fetchCompletionHandler?(.noData)
      return
    }
    LocalNotifications.notifyNewArticle(data: data)
    fetchCompletionHandler?(.newData)
  }
  
  /// Get/Download latestIssue requested by PushNotification
  /// - Parameter fetchCompletionHandler: handler to be called on end
  ///
  /// Not using zipped download due if download breaks all received data is gone
  public func handleNewIssuePush(_ fetchCompletionHandler: FetchCompletionHandler?) {
    ///Challange: on receive push usually a download happen and then a newData is needed (no matter if full download or just overviewDownload)
    ///in case of full download the newData send is simple
    ///But how to implement the partialDownloadForNewData?
    ///When is the last issue downloaded? e.g. last App Issue Download 1.1. today 14.1. missing ~10 Issues
    ///some strange things happen due no download still happen but now i have internet and receive the PN in active Mackground Mode
    ///if we send remoteNotificationFetchCompleete newData too early the System killy all Download Processes and wen miss data
    ///if wen send it too late the automatic .failed is told the system
    ///can we check that there are still downloads?
    ///
    ///**ENSURE INTERNAL USERS DID NOT HANDLE SILENT PN ABO POLL ...App may crash in BG State**
    ///but its still testable if app would crash for the changed code, just by turn on autodownload
    log("Handle new Issue Push\n  Current App State: \(UIApplication.shared.stateDescription)")
    ///Do not access feed here, its maybe uninitialized! self.defaultFeed.name
    BackgroundDownloadService.checkForNewIssue(isPush: true, fetchCompletionHandler)
  }
}

// MARK: - LocalNotifications (User Notifications)
fileprivate extension LocalNotifications {
  static func notify(payload: PushNotification.Payload){
    guard let message = payload.standard?.alert?.body else {
      Log.debug("no standard payload found, not notify localy")
      return
    }
    Self.notify(title: payload.standard?.alert?.title, message:message)
  }
  
  //Helper to trigger local Notification if App is in Background
  static func notifyNewIssue(issue:StoredIssue, feeder:Feeder){
    var attachmentURL:URL?
    if let filepath = feeder.smallMomentImageName(issue: issue) {
      Log.log("Found Moment Image in: \(filepath)")
      attachmentURL =  URL(fileURLWithPath: filepath)
    }
    else {
      Log.debug("Not Found Moment Image for: \(issue.date)")
    }
    
    var subtitle: String?
    var message = "Jetzt lesen!"
    
    if let firstArticle = issue.sections?.first?.articles?.first,
       let aTitle = firstArticle.title,
       let aTeaser = firstArticle.teaser {
      subtitle = "Lesen Sie heute: \(aTitle)"
      message = aTeaser
    }
    Self.notify(title: "Die Ausgabe vom \(issue.date.short) ist verfügbar.",
                subtitle: subtitle,
                message: message,
                badge: UIApplication.shared.applicationIconBadgeNumber + 1,
                attachmentURL: attachmentURL)
    
  }
  
  //Helper to trigger local Notification for new Article if App is in Background
  static func notifyNewArticle(data: PushNotification.Payload.ArticlePushData){
    Self.notify(title: data.articleTitle,
//                subtitle: "TBD",
                message: data.articleBody ?? "-",
                badge: UIApplication.shared.applicationIconBadgeNumber + 1,
                payload: data.payload)
  }
}
