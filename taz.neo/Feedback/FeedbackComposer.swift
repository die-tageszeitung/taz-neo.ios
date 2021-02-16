//
//  FeedbackComposer.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 25.09.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib
/**
 TODOS
 - Check if still working in Article & more!!
 - Overlay, seams to work testet in Simulator in ArticleCV && deinit for Overlay Called
 - not for ZoomedImageView? =>  its ContentImageVC => also not => Ticket created #12863
 - ZoomedImageView
 - WORKAROUND DONE fix screenshot fullscreen border, not using overlay, not using zoomed ImageView
 - FEEDBACK REQUIRED make the buttons similar 
 */

public enum FeedbackType { case error, feedback, fatalError }

open class FeedbackComposer : DoesLog{
  
  public static func requestFeedback(logData: Data? = nil,
                                     gqlFeeder: GqlFeeder,
                                     finishClosure: @escaping ((Bool) -> ())) {
    let screenshot = UIWindow.screenshot
    let deviceData = DeviceData()
    
    let feedbackAction = UIAlertAction(title: "Feedback geben", style: .default) { _ in
      FeedbackComposer.send(type: FeedbackType.feedback,
                            gqlFeeder: gqlFeeder,
                            finishClosure: finishClosure)
    }
    
    let errorReportAction = UIAlertAction(title: "Fehler melden", style: .destructive) { _ in
      FeedbackComposer.send(type: FeedbackType.error,
                            deviceData: deviceData,
                            screenshot: screenshot,
                            logData: logData,
                            gqlFeeder: gqlFeeder,
                            finishClosure: finishClosure)
    }
    let cancelAction = UIAlertAction(title: "Abbrechen", style: .cancel) { _ in finishClosure(false) }
    
    Alert.message(title: "Rückmeldung", message: "Möchten Sie einen Fehler melden oder uns Feedback geben?", actions: [feedbackAction, errorReportAction, cancelAction])
  }
  
  public static func send(type: FeedbackType,
                          deviceData: DeviceData? = nil,
                          screenshot: UIImage? = nil,
                          logData: Data? = nil,
                          gqlFeeder: GqlFeeder,
                          finishClosure: @escaping ((Bool) -> ())) {
    
    guard let currentVc = UIViewController.top() else {
      print("Error, no Controller to Present")
      return;
    }
    
    var feedbackBottomSheet : FullscreenBottomSheet?
    
    let feedbackViewController
      = FeedbackViewController(
        type: type,
        screenshot: screenshot,
        deviceData: deviceData,
        logData: logData,
        gqlFeeder: gqlFeeder){
          feedbackBottomSheet?.slide(toOpen: false, animated: true)
          
    }
                                                       
    feedbackBottomSheet = FullscreenBottomSheet(slider: feedbackViewController,
                                              into: currentVc)
    feedbackBottomSheet?.sliderView.backgroundColor = Const.SetColor.CTBackground.color
    feedbackBottomSheet?.coverageRatio = 1.0
    
    feedbackBottomSheet?.onUserSlideToClose = ({
      guard let feedbackBottomSheet = feedbackBottomSheet else { return }
      feedbackBottomSheet.slide(toOpen: true, animated: true)
      Alert.confirm(message: Localized("feedback_cancel_title"),
                    isDestructive: true) { (close) in
                      if close {
                        feedbackBottomSheet.slide(toOpen: false, animated: true, forceClose: true)
                      }
      }
    })
    
    feedbackBottomSheet?.onClose(closure: { (slider) in
      finishClosure(feedbackViewController.sendSuccess)
      feedbackBottomSheet = nil//Important the memory leak!
    })
    feedbackBottomSheet?.open()
  }
}



