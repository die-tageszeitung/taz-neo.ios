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
    updateDefaultsIfNeeded()
    self.window = UIWindow(frame: UIScreen.main.bounds)
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
  
  /// Update App Icon Menu
  public func applicationWillResignActive(_ application: UIApplication) {
    application.shortcutItems = Shortcuts.currentItems(wantsLogging: wantLogging)
  }

  func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    self.handleShortcutItem(shortcutItem)
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
    // application.shortcutItems = [] //not working!
    ///NOT CALLED @see:https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623111-applicationwillterminate
    // log("applicationWillTerminate ")
  }
}

fileprivate extension AppDelegate {
  
  func handleServerSwitch(to shortcutServer: Shortcuts) {
    if Defaults.currentServer == shortcutServer { return }//already selected!
    
    let killHandler: (Any?) -> Void = {_ in
      switch shortcutServer {
        case Shortcuts.liveServer:
          Defaults.currentServer = .liveServer
          MainNC.singleton.deleteAll()
        case Shortcuts.testServer:
          Defaults.currentServer = .testServer
          MainNC.singleton.deleteAll()
        default:
          break;
      }
    }
    
    let killAction = UIAlertAction(title: "Ja Server wechseln",
                                   style: .destructive,
                                   handler: killHandler )
    let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel)
    
    Alert.message(title: "Achtung Serverwechsel!", message: "Möchten Sie den Server vom \(Defaults.serverSwitchText) wechseln?\nAchtung!\nDie App muss neu gestartet werden.\n\n Alle Daten werden gelöscht!", actions: [killAction,  cancelAction])
  }
  
  func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
    switch shortcutItem.type {
      case Shortcuts.logging.type:
        wantLogging = !wantLogging
      case Shortcuts.liveServer.type:
        handleServerSwitch(to: Shortcuts.liveServer)
      case Shortcuts.testServer.type:
        handleServerSwitch(to: Shortcuts.testServer)
      default:
        Toast.show("Aktion nicht verfügbar!")
        break;
    }
  }
}


/// Helper to add App Shortcuts to App-Icon
/// Warning View Logger did not work untill MainNC -> setupLogging ...   viewLogger is disabled!
/// @see: Log.append(logger: consoleLogger, /*viewLogger,*/ fileLogger)
fileprivate enum Shortcuts{
  
  static func currentItems(wantsLogging:Bool) -> [UIApplicationShortcutItem]{
      if App.isAlpha == false && Defaults.currentServer == .liveServer {
        return []
//        return [Shortcuts.logging.shortcutItem()]
      }
      var itms:[UIApplicationShortcutItem] = [
//        Shortcuts.feedback.shortcutItem(.mail),
//        Shortcuts.logging.shortcutItem(wantsLogging ? .confirmation : nil)
      ]
      if Defaults.currentServer == .liveServer {
        itms.append(Shortcuts.liveServer.shortcutItem(.confirmation, subtitle: "aktiv"))
        itms.append(Shortcuts.testServer.shortcutItem())
      }
      else {
        itms.append(Shortcuts.liveServer.shortcutItem())
        itms.append(Shortcuts.testServer.shortcutItem(.confirmation, subtitle: "aktiv"))
      }
      return itms
  }
  
  case liveServer, testServer, feedback, logging
  
  var type:String{
    switch self {
      case .liveServer: return "shortcutItemLiveServer"
      case .testServer: return "shortcutItemTestServer"
      case .feedback: return "shortcutItemFeedback"
      case .logging: return "shortcutItemLogging"
    }
  }
  
  var title:String{
    switch self {
      case .liveServer: return "Live Server"
      case .testServer: return "Test Server"
      case .feedback: return "Feedback"
      case .logging: return "Protokoll einschalten"
    }
  }
    

  func shortcutItem(_ iconType:UIApplicationShortcutIcon.IconType? = nil, subtitle: String? = nil) -> UIApplicationShortcutItem {
    return UIApplicationShortcutItem(type: self.type,
                                     localizedTitle: self.title,
                                     localizedSubtitle: subtitle,
                                     icon: iconType == nil ? nil : UIApplicationShortcutIcon(type: iconType!) )
  }
}



extension Defaults{
  fileprivate static func isServerSwitch(for shortcutItem: UIApplicationShortcutItem) -> Bool{
    if shortcutItem.type == Shortcuts.liveServer.type && currentServer != .liveServer { return true }
    if shortcutItem.type == Shortcuts.testServer.type && currentServer != .testServer { return true }
    return false
  }
  
  fileprivate static var currentServer : Shortcuts {
    get {
      if let curr = Defaults.singleton["currentServer"], curr == Shortcuts.testServer.type {
        return .testServer
      }
      return .liveServer
    }
    set {
      ///only update if changed
      if Defaults.singleton["currentServer"] != newValue.type {
        Defaults.singleton["currentServer"] = newValue.type
      }
    }
  }
  
  static var currentFeeder : (name: String, url: String, feed: String) {
    get {
      if let curr = Defaults.singleton["currentServer"], curr == Shortcuts.testServer.type {
        return (name: "taz-testserver", url: "https://testdl.taz.de/appGraphQl", feed: "taz")
      }
      return (name: "taz", url: "https://dl.taz.de/appGraphQl", feed: "taz")
    }
  }
  
  
  fileprivate static var serverSwitchText : String {
    get {
      if currentServer == .testServer {
        return "Test Server zum Live Server"
      }
      return "Live Server zum Test Server"
    }
  }
}
