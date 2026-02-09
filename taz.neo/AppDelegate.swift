//
//  AppDelegate.swift
//
//  Created by Norbert Thies on 22.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib
import Darwin

@UIApplicationMain
class AppDelegate: NotifiedDelegate {

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    TazAppEnvironment.updateDefaultsIfNeeded()
    TazAppEnvironment.saveLastLog()
    TazAppEnvironment.setupDefaultStyles()
//    _ = TazAppEnvironment.sharedInstance //configure Logging
//    log("starting with #launchOptions: \(launchOptions?.count ?? 0)")///still not in File Logger
    ///handle application started from NotificationCenter, if app not running
    /////will be overwritten, on TazAppEnvironment setup, stores data
    onOpenApplicationFromNotification {center, response, handler in
      TazAppEnvironment.openedFromNotificationCenter
      = response.notification.request.content.userInfo.articlePushData
    }
    
    /// FileLogger is available now! - not available anymore due
    /// TazAppEnvironment.sharedInstance not inited
//    if let keys = launchOptions?.keys.map({ $0.rawValue }) {
//      log("started with \(keys.count) launchOptions: \(keys)")
//    }else {
//      log("started with \(launchOptions?.count ?? 0) launchOptions")
//    }
    
    if launchOptions?[.remoteNotification] != nil {
      Log.appStartContext = .handlePushNotification
    } else if launchOptions?.count ?? 0 == 0 {
      Log.appStartContext = .foregroundUserStarted
    }else {
      Log.appStartContext = .unknown
    }
    return true
  }

  // Store background download completion handler
  func application(_ application: UIApplication,
                   handleEventsForBackgroundURLSession identifier: String,
                   completionHandler: @escaping () -> Void) {
    log("application handleEventsForBackgroundURLSession identifier: \(identifier)")
    tzset() // <— reload timezone info
    log("application handleEventsForBackgroundURLSession identifier: \(identifier) ...after fixed TimeZone ")
    BackgroundSession.resumeBackgroundURLSession(name: identifier,
                                                 completionHandler: completionHandler,
                                                 callback: BackgroundDownloadService.dlCallback)
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    log("enter background: \(application.stateDescription)")
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }
  
  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // application.shortcutItems = [] //not working!
    ///NOT CALLED @see:https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623111-applicationwillterminate
     //log("applicationWillTerminate ")
  }
}
