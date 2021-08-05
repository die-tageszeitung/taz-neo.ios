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
  var feeder: String = "taz"
  
  func handleShortcuts(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
      switch shortcutItem.type {
        case "Logging":
          wantLogging = true
        case "TestFeeder":
          feeder = "taz-test"
        default:
          break
      }
    }
  }
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    updateDefaultsIfNeeded()
    self.window = UIWindow(frame: UIScreen.main.bounds)
    handleShortcuts(launchOptions)
    self.window?.rootViewController = MainNC()
//    self.window?.rootViewController =  TmpTestController()
//    self.window?.rootViewController = SearchSettingsVC()
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
    if #available(iOS 13.0, *) {
      UIApplication.shared.keyWindow?.overrideUserInterfaceStyle
        = Defaults.singleton["colorMode"] == "dark" ? .dark : .light
    } 
    return true
  }
  
  func updateDefaultsIfNeeded(){
    Defaults.singleton["offerTrialSubscription"]=nil
  }
  
  /// Define App Icon menue
  public func applicationWillResignActive(_ application: UIApplication) {
//    let proto = UIApplicationShortcutItem(type: "Logging",
//                localizedTitle: "Protokoll einschalten")
    let testChannel = UIApplicationShortcutItem(type: "TestFeeder",
                                                localizedTitle: "Testkanal")
    application.shortcutItems = [testChannel]
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

