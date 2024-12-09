//
//  UIViewController+Active.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit

extension UIViewController {
  
  var isActiveAndVisible: Bool {

      // Check if part of a UINavigationController
      if let navCtrl = self.navigationController {
          // If inside a UITabBarController, ensure it's the selected tab
          if let tabCtrl = navCtrl.parent as? UITabBarController {
              return tabCtrl.selectedViewController == navCtrl && navCtrl.visibleViewController == self
          }
          // Otherwise, ensure it's the visible view controller in the navigation stack
          return navCtrl.visibleViewController == self
      }

      // If part of a UITabBarController directly (not embedded in a nav controller)
      if let tabCtrl = self.parent as? UITabBarController {
          return tabCtrl.selectedViewController == self
      }

      // For other cases, check if it’s the root or presented directly
      return self.presentingViewController == nil
  }
}
