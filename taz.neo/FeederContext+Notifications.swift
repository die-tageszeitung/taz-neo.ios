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
        #warning("may comes in double if real PN!")
        if UIApplication.shared.applicationState == .active {
          LocalNotifications.notify(payload: payload)
        }
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
    
    if App.isAvailable(.AUTODOWNLOAD) == false {
      log("Currently not handle new Issue Push\n  Current App State: \(UIApplication.shared.stateDescription)\n  feed: \(self.defaultFeed.name)")
      fetchCompletionHandler?(.noData)
      return
    }
    log("Handle new Issue Push\n  Current App State: \(UIApplication.shared.stateDescription)\n  feed: \(self.defaultFeed.name)")
    
    guard let storedFeeder = storedFeeder,
          let sFeed = StoredFeed.get(name: self.defaultFeed.name, inFeeder: storedFeeder).first else {
      self.error("Expected to have a stored feed, but did not found one.")
      fetchCompletionHandler?(.noData)
      return
    }
    #warning("TODO: ADD APPLICATION BACKGROUND FETCH RÖDLER")
    Notification.receiveOnce("resourcesReady") { [weak self] err in
      guard let self = self else { return }
      self.gqlFeeder.issues(feed: sFeed,
                            count: 1,
                            isOverview: false,
                            isPages: self.autoloadPdf) { res in
        if let issues = res.value() {//Fetch result got an 'latest' Issue
          guard issues.count == 1 else {
            self.error("Expected to find 1 issue found: \(issues.count)")
            fetchCompletionHandler?(.failed)
            return
          }
          guard let issue = issues.first else { return }
          
          let si = StoredIssue.get(date: issue.date, inFeed: sFeed)
          #warning("did not overwrite existing issue")
          ///in 03/2023 due an server/editorial error the next day issue was published round 3:00 pm, was revoked but server logs said 5-10 People got this issue **HOW TO HANDLE THIS IN FUTURE?**
          ///
          ///
          self.log("got issue from \(issue.date.short) from server with status: \(issue.status) got issue in db with status: \(si.first?.status.localizedDescription ?? "- no Issue in DB -") dbIssue isComplete: \(si.first?.isComplete ?? false)")
          
          
          /* Possible states for both
                case regular = "regular"          /// authenticated Issue access
                case demo    = "demo"             /// demo Issue
                case locked  = "locked"           /// no access
                case reduced = "reduced(public)"  /// available for everybody/incomplete articles
                case unknown = "unknown"          /// decoded from unknown string
          */
          
          var persist = false
          
          ///ensure no full issue (demo/regular) is overwritten with reduced
          if issue.status == .regular {
            self.log("persist server version due its a regular one")//probably overwrite old local one
            persist = true
          }///update with the new one
          else if (si.first?.status == .regular || si.first?.status == .demo) == false {
            self.log("there is no full issue locally so overwrite it with the new one from server")
            persist = true
          }
          
          #warning("got issue from 30.3.2023 from server with status: regular got issue in db with status: regular dbIssue isComplete: false")
          ///Discussion: overwrite regular overview with regular full is ok!
          
          if persist {
            StoredIssue.persist(object: issue)
            ArticleDB.save()
          }
          
          guard let sissue = StoredIssue.issuesInFeed(feed: sFeed,
                                                      count: 1,
                                                      fromDate: issue.date).first else {
            self.error("Expected to find downloaded issue (\(issue.date.short) in db.")
            fetchCompletionHandler?(.failed)
            return
          }
          
          if self.autoloadOnlyInWLAN, self.netAvailability.isMobile {
            self.log("Prevent compleete Download in celluar for: \(sissue.date.short), just load overview")
            LocalNotifications.notifyNewIssue(issue: sissue, feeder: self.gqlFeeder)
            fetchCompletionHandler?(.newData)
            return
          }
          self.log("Download Compleete Issue: \(sissue.date.short)")
          
          self.dloader.createIssueDir(issue: issue)
          Notification.receive("issue"){ notif in
            ///ensure the issue download comes from here!
            guard let downloaded = notif.object as? Issue else { return }
            guard downloaded.date.short == issue.date.short else { return }
            LocalNotifications.notifyNewIssue(issue: sissue, feeder: self.gqlFeeder)
            #warning("KILL SWITCH due 2nd call on receive issue!")
            fetchCompletionHandler?(.newData)//2nd Time Call!
          }
          
          if self.autoloadNewIssues {
            self.downloadCompleteIssue(issue: sissue, isAutomatically: true)
          }
          else {
            fetchCompletionHandler?(.newData)//2nd Time Call!
          }
        }
        else if let err = res.error() as? FeederError {
          self.error("There was an error: \(err)")
          let res: Result<Issue,Error> = .failure(err)
          self.notify("issueOverview", result: res)
          fetchCompletionHandler?(.failed)
        }
        else {
          self.error("Did not found a issue")
          let res: Result<Issue,Error> = .failure(Log.error("Did not found a issue"))
          self.notify("issueOverview", result: res)
          fetchCompletionHandler?(.noData)
        }
      }
    }
    updateResources()
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
