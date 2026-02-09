//
//  SceneDelegate.swift
//  taz.neo
//
//  Created by Ringo Müller on 06.02.26.
//  Copyright © 2026 taz. All rights reserved.
//

import UIKit
import NorthLib

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = TazAppEnvironment.sharedInstance.rootViewController
    window.makeKeyAndVisible()
    applyInterfaceStyle()
    self.window = window
    
//    // Push / DeepLink / Shortcut
//    if let notification = connectionOptions.notificationResponse {
//      Log.appStartContext = .handlePushNotification
//      TazAppEnvironment.openedFromNotificationCenter =
//      notification.notification.request.content.userInfo.articlePushData
//    } else {
//      Log.appStartContext = .foregroundUserStarted
//    }
//    ///NEW??
//    if let response = connectionOptions.notificationResponse {
////    NotifiedDelegate.singleton?.notifier.handleOpenFromNotification(
////        center: UNUserNotificationCenter.current(),
////        response: response
////    )
//}
  }
  
  private func applyInterfaceStyle() {
    window?.overrideUserInterfaceStyle
    = Defaults.singleton["colorMode"] == "dark" ? .dark : .light
    /**
     on change may change also:
     func applyInterfaceStyleGlobally() {
         UIApplication.shared.connectedScenes
             .compactMap { $0 as? UIWindowScene }
             .flatMap { $0.windows }
             .forEach {
                 $0.overrideUserInterfaceStyle =
                     Defaults.singleton["colorMode"] == "dark" ? .dark : .light
             }
     }
     */
  }
  
  func scene(
    _ scene: UIScene,
    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
      TazAppEnvironment.openedFromNotificationCenter = userInfo.articlePushData
      completionHandler(.noData)
  }
}
