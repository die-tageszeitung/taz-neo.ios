//
//  AppOverlay.swift
//  NorthLib
//
//  Created by Ringo Müller-Gromes on 21.01.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// WaitingAppOverlay with static call and dismiss by notification
public class WaitingAppOverlay {
  
  /// add overlay to app's window
  /// - Parameters:
  ///   - alpha: alpha of black gackground layer
  ///   - showSpinner: show spinner or not
  /// - Returns: true|false, true if added false if not
  public static func show(alpha:CGFloat = 0.8, showSpinner:Bool = true, titleMessage:String? = nil, bottomMessage:String?=nil, dismissNotification:String) {
    let appDelegate = UIApplication.shared.delegate
    let window = appDelegate?.window
    if window == nil { return }
    
    ///show layer
    onMain {
      let layer = UIView(frame: UIScreen.main.bounds)
      
      if showSpinner {
        let spinner = UIActivityIndicatorView(style: .white)
        layer.addSubview(spinner)
        spinner.center()
        spinner.startAnimating()
      }
      
      if let title = titleMessage {
        let label = UILabel(title).titleFont().white().center()
        layer.addSubview(label)
        pin(label.bottom, to: layer.centerY, dist: -30)
        pin(label.left, to: layer.left, dist: 10)
        pin(label.right, to: layer.right, dist: -10)
      }
      
      if let text = bottomMessage {
        let label = UILabel(text).contentFont().white().center()
        layer.addSubview(label)
        pin(label.top, to: layer.centerY, dist: 30)
        pin(label.left, to: layer.left, dist: 10)
        pin(label.right, to: layer.right, dist: -10)
      }
      
      layer.backgroundColor = UIColor(white: 0, alpha: alpha)
      layer.alpha = 0.0
      window!?.addSubview(layer)
      UIView.animate(withDuration: 0.7,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
                      layer.alpha = 1.0
                     }, completion: { (_) in
                      if layer.isTopmost == false {
                        window!?.bringSubviewToFront(layer)
                      }
                     })
      
      Notification.receiveOnce(dismissNotification) { _ in
        onMain {
          UIView.animate(withDuration: 0.7,
                         delay: 0,
                         options: UIView.AnimationOptions.curveEaseInOut,
                         animations: {
                          layer.alpha = 0.0
                         }, completion: { (_) in
                          layer.removeFromSuperview()
                         })
        }
      }
    }
  }
}
