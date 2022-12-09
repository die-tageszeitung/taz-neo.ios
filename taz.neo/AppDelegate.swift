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
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    TazAppEnvironment.updateDefaultsIfNeeded()
    TazAppEnvironment.saveLastLog()
    TazAppEnvironment.setupDefaultStyles()
    self.window = UIWindow(frame: UIScreen.main.bounds)
    self.window?.rootViewController = TazAppEnvironment.sharedInstance.rootViewController
//    self.window?.rootViewController =  TmpTestController()
//    let res = SearchResultsTVC()
//    res.searchResponse = GqlFeeder.test()
//    self.window?.rootViewController = res
    
//    self.window?.rootViewController = TestController()
//    self.window?.rootViewController = NavController()
//    self.window?.rootViewController = ContentVC()
//    self.window?.rootViewController = UITests()
//    self.window?.rootViewController = CarouselVC()
//    self.window?.rootViewController = WebViewTests()
//    self.window?.rootViewController = SliderTest()
//    self.window?.rootViewController = ColorTests()
//    self.window?.rootViewController = OverlayTest()
//    self.window?.rootViewController = TazPdfPagesViewController()
//    self.window?.rootViewController = KeychainTest()
    
    self.window?.makeKeyAndVisible()
    UIWindow.keyWindow?.overrideUserInterfaceStyle
    = Defaults.singleton["colorMode"] == "dark" ? .dark : .light
    return true
  }

  /// Update App Icon Menu
  public func applicationWillResignActive(_ application: UIApplication) {
    application.shortcutItems = Shortcuts.currentItems()
  }

  func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    TazAppEnvironment.sharedInstance.handleShortcutItem(shortcutItem)
  }
  
  // Store background download completion handler
  func application(_ application: UIApplication,
                   handleEventsForBackgroundURLSession identifier: String,
                   completionHandler: @escaping () -> Void) {
    log("store bg Download compleetion")
    HttpSession.bgCompletionHandlers[identifier] = completionHandler
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
    // application.shortcutItems = [] //not working!
    ///NOT CALLED @see:https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623111-applicationwillterminate
     //log("applicationWillTerminate ")
  }
}
