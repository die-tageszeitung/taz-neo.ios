//
//  AppDelegate.swift
//
//  Created by Norbert Thies on 22.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

@UIApplicationMain
class AppDelegate: NotifiedDelegate {

  var window: UIWindow?
  var wantLogging = false
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    self.window = UIWindow(frame: UIScreen.main.bounds)
    self.window?.rootViewController = MainNC()
//    self.window?.rootViewController = NavController()
//    self.window?.rootViewController = ContentVC()
//    self.window?.rootViewController = UITests()
//    self.window?.rootViewController = DLController()
//    self.window?.rootViewController = CarouselVC()
    self.window?.makeKeyAndVisible()
    if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
      if shortcutItem.type == "Logging" { wantLogging = true }
    }
    return true
  }
  
  /// Enable Logging button on home screen
  public func applicationWillResignActive(_ application: UIApplication) {
    let proto = UIApplicationShortcutItem(type: "Logging", 
                localizedTitle: "Protokoll einschalten")
    application.shortcutItems = [proto]
  }

  func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    if shortcutItem.type == "Logging" { wantLogging = true }
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }


}

