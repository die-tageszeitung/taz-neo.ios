//
//  AppOverlay.swift
//  NorthLib
//
//  Created by Ringo Müller-Gromes on 21.01.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public typealias AppOverlayStep1 = (image: UIImage?,
                                    totalDuration: Double?,
                                    actionDelay: Double?,
                                    action:(()->())?)


/// Step for App overlay animation sequence
public struct AppOverlayStep {
  var image:UIImage?
  var totalDuration: Double
  var actionDelay: Double
  var action:(()->())?
  
  public init(_ image:UIImage?,
              totalDuration: Double = 2.0,
              actionDelay: Double = 0.7,
              action: (()->())? = nil) {
    self.image = image
    self.totalDuration = totalDuration
    self.actionDelay = actionDelay
    self.action = action
  }
}

/// creates overlay for app e.g. to prevent user interaction due update cycles
public class AppOverlay {
  /// creates overlay with given steps
  /// - Parameters:
  ///   - steps: steps to show
  ///   - initialDelay: initial delay to start first step
  ///   - finishedCallback: block to call after all steps finished
  public static func show(steps:[AppOverlayStep], initialDelay: Double = 0.0, finishedCallback:(()->())? = nil) {
    if initialDelay > 0.0 {
      onThreadAfter(initialDelay) {
        AppOverlay.show(steps: steps, finishedCallback: finishedCallback)
      }
      return
    }
    onMain {
      let appDelegate = UIApplication.shared.delegate
      let window = appDelegate?.window
      var steps = steps
      
      if window == nil, steps.count == 0 {
        finishedCallback?()
        return
      }
      
      guard let step = steps.pop() else {
        finishedCallback?()
        return
      }
      
      let iv = UIImageView(frame: UIScreen.main.bounds)
      iv.image = step.image
      iv.backgroundColor = UIColor(white: 0, alpha: 0.5)
      iv.contentMode = .scaleAspectFit
      iv.alpha = 0.0
      
      onMainAfter(step.actionDelay) {
        step.action?()
      }
      window!?.addSubview(iv)
      UIView.animate(withDuration: 0.5,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
                      iv.alpha = 1.0
                     }, completion: { (_) in
                      UIView.animate(withDuration: 0.5,
                                     delay: step.totalDuration - 1.0 ,
                                     options: UIView.AnimationOptions.curveEaseInOut,
                                     animations: {
                                      iv.alpha = 0.0
                                     }, completion: { (_) in
                                      iv.removeFromSuperview()
                                      AppOverlay.show(steps: steps, initialDelay: 0.2, finishedCallback: finishedCallback)
                                     })
                     })
    }
  }
  
  
  /// creates app overlay with given image
  /// - Parameters:
  ///   - image: image to show
  ///   - holdDelay: time to show image
  ///   - initialDelay: delay to start
  ///   - finishedCallback: block to call after finished
  public static func show(_ image:UIImage?, _ holdDelay: CGFloat = 2.0, _ initialDelay: CGFloat = 0.0, _ finishedCallback:(()->())? = nil) {
    
    guard let image = image else {
      finishedCallback?()
      return;
    }
    
    DispatchQueue.main.async {
      let appDelegate = UIApplication.shared.delegate
      let window = appDelegate?.window
      
      if window == nil {
        finishedCallback?()
        return
      }
      
      let iv = UIImageView(frame: UIScreen.main.bounds)
      iv.image = image
      iv.backgroundColor = UIColor(white: 0, alpha: 0.3)
      iv.contentMode = .scaleAspectFit
      iv.alpha = 0.0
      window!?.addSubview(iv)
      
      UIView.animate(withDuration: 0.7,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
                      iv.alpha = 1.0
                     }, completion: { (_) in
                      UIView.animate(withDuration: 0.7,
                                     delay: TimeInterval(holdDelay),
                                     options: UIView.AnimationOptions.curveEaseInOut,
                                     animations: {
                                      iv.alpha = 0.0
                                     }, completion: { (_) in
                                      iv.removeFromSuperview()
                                      finishedCallback?()
                                     })
                     })
    }
    
    let close = showWaiting()
    close?()
  }
  
  
  /// show waiting spinner (UIActivityIndicatorView) centered with semi transparent layer over app
  /// - Returns: block to remove blocking layer
  public static func showWaiting() -> (()->())? {
    let appDelegate = UIApplication.shared.delegate
    let window = appDelegate?.window
    if window == nil { return nil }
    print(">>> window.subviews count1: \(window!?.subviews.count ?? 0)")
    var layer:UIView? = UIView(frame: UIScreen.main.bounds)
    
    ///show layer
    onMain {
      let spinner = UIActivityIndicatorView(style: .white)
      guard let layer = layer else { return }
      layer.addSubview(spinner)
      spinner.center()
      spinner.startAnimating()
      layer.backgroundColor = UIColor(white: 0, alpha: 0.7)
      layer.alpha = 0.0
      print(">>> window.subviews count2: \(window!?.subviews.count ?? 0)")
      window!?.addSubview(layer)
      print(">>> window.subviews count3: \(window!?.subviews.count ?? 0)")
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
    }
    
    ///block to remove layer
    return {
      onMain {
        layer?.removeFromSuperview()
        layer = nil
      }
    }
  }
}


/// WaitingAppOverlay Version with static call and dismiss by notification
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


///  WaitingAppOverlay Version with static call and dismiss by function call on returned object 
public class WaitingAppOverlay2 {
  
  var layer:UIView?
  
  /// add overlay to app's window
  /// - Parameters:
  ///   - alpha: alpha of black gackground layer
  ///   - showSpinner: show spinner or not
  /// - Returns: true|false, true if added false if not
  public static func show(alpha:CGFloat = 0.8, showSpinner:Bool = true, titleMessage:String? = nil, bottomMessage:String?=nil) -> WaitingAppOverlay2? {
  
    let appDelegate = UIApplication.shared.delegate
    let window = appDelegate?.window
    if window == nil { return nil}
    let instance = WaitingAppOverlay2()
    
    ///show layer
    onMain {
      let layer = UIView(frame: UIScreen.main.bounds)
      instance.layer = layer
      
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
    }
    return instance
  }
  
  deinit {
    print("##> deinnit WaitingAppOverlay2")
  }
  
  func dismiss(){
    onMain { [weak self] in
      self?.layer?.removeFromSuperview()
    }
  }
}
