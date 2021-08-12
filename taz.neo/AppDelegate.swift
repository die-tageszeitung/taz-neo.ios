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
  
  @Default("defaultFeeder")
  var defaultFeeder: String
  
  func handleShortcuts(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
      var needDelete = false
      switch shortcutItem.type {
        case "Logging":
          wantLogging = true
        case "taz":
          if defaultFeeder != "taz" { needDelete = true}
          defaultFeeder = "taz"
        case "TestFeeder":
          if defaultFeeder != "taz-test" { needDelete = true}
          defaultFeeder = "taz-test"
        case "TestServer":
          if defaultFeeder != "taz-test-server" { needDelete = true}
          defaultFeeder = "taz-test-server"
        default:
          break
      }
      if needDelete {
        MainNC.singleton.deleteAll()
      }
    }
  }
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    updateDefaultsIfNeeded()
    self.window = UIWindow(frame: UIScreen.main.bounds)
    handleShortcuts(launchOptions)
    self.window?.rootViewController = MainNC()
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
    if #available(iOS 13.0, *) {
      UIApplication.shared.keyWindow?.overrideUserInterfaceStyle
        = Defaults.singleton["colorMode"] == "dark" ? .dark : .light
    } 
    return true
  }
  
  func updateDefaultsIfNeeded(){
    let dfl = Defaults.singleton
    dfl["offerTrialSubscription"]=nil
    dfl.setDefaults(values: ConfigDefaults)
  }
  
  /// Define App Icon menue
  public func applicationWillResignActive(_ application: UIApplication) {
//    let proto = UIApplicationShortcutItem(type: "Logging",
//                localizedTitle: "Protokoll einschalten")
    ///Shortcut Items only for Alpha Versions
    if App.isAlpha == false { return }
    let testChannel = UIApplicationShortcutItem(type: "TestFeeder",
                                                localizedTitle: "Testkanal")
    let liveServer = UIApplicationShortcutItem(type: "taz",
                                                localizedTitle: "Taz Live Server")
    let testServer = UIApplicationShortcutItem(type: "TestServer",
                                                localizedTitle: "Test Server")
    application.shortcutItems = [liveServer, testChannel, testServer]
  }

  func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    if shortcutItem.type == "Logging" { wantLogging = true }
  }
  
  // Store background download completion handler
  func application(_ application: UIApplication,
                   handleEventsForBackgroundURLSession identifier: String,
                   completionHandler: @escaping () -> Void) {
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
  }


}

