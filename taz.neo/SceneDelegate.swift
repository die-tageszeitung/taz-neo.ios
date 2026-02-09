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
    
    // handle Push if any
    if let notification = connectionOptions.notificationResponse {
      Log.appStartContext = .handlePushNotification
      TazAppEnvironment.openedFromNotificationCenter =
      notification.notification.request.content.userInfo.articlePushData
    } else {
      Log.appStartContext = .foregroundUserStarted
    }
    
    // handle Shortcut if any
    if let shortcutItem = connectionOptions.shortcutItem {
        TazAppEnvironment.sharedInstance.handleShortcutItem(shortcutItem)
    }
  }
  
  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
      TazAppEnvironment.sharedInstance.handleShortcutItem(shortcutItem)
      completionHandler(true)
  }
  
  private func applyInterfaceStyle() {
    window?.overrideUserInterfaceStyle
    = Defaults.singleton["colorMode"] == "dark" ? .dark : .light
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
