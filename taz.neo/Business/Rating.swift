//
//  Rating.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.09.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import Foundation
import StoreKit
import NorthLib

/// Helper to start Store Rating
/// first Rating requested after 3 Days
/// if QA Version (higher then Store Version) Rating Requested after 2nd App Start
///            due waitingDays == 1 && ratingRequestedDate == - 3 Days
/// following Ratings Requests every 10 Days
/// following Ratings Requests only if not shown for current minor Version
///
/// **Actions to start Rating**
/// - loggedIn at App Start
/// - at least 10 Seconds in App (in foreground)
/// **AND**
///     - 30 Seconds in Issue and left Issue
///     **OR**
///     - 30 Seconds after finished Audioplayback
class Rating: NSObject, DoesLog{
  private var canRate: Bool
  
  private func canRate(lastRateRequestDate: Date) -> Bool{
    return Date().timeIntervalSince(lastRateRequestDate) >= (60.0*60.0*24.0*Double(waitingDays*(ratingCount+1)))
  }
  
  var waitingDays: Int = 10 {
    didSet {
      guard let date = ratingRequestedDate else { return }
      canRate = canRate(lastRateRequestDate: date)
    }
  }
  
  ///for regular user which rate and frequent updates rating count comes after 10Days 20 30 40...
  ///to not annoy the users
  @Default("ratingCount")
  var ratingCount: Int
  
  @Default("ratingRequestedForVersion")
  var ratingRequestedForVersionDfl: String
  var ratingRequestedForVersion: Version? {
    get {
      guard self.ratingRequestedForVersionDfl.length > 0 else { return nil }
      return Version(self.ratingRequestedForVersionDfl)
    }
    set {
      if let new = newValue {
        self.ratingRequestedDateDfl = "\(new)"
      }
      else {
        self.ratingRequestedDateDfl = ""
      }
    }
  }
    
  @Default("ratingRequestedDate")
  var ratingRequestedDateDfl: String
  var ratingRequestedDate: Date? {
    get {
      guard self.ratingRequestedDateDfl.length > 0 else { return nil }
      return Date.fromString(self.ratingRequestedDateDfl)
    }
    set {
      if let new = newValue {
        self.ratingRequestedDateDfl = Date.toString(new)}
      else {
        self.ratingRequestedDateDfl = ""
      }
    }
  }
  
  
  static let sharedInstance = Rating()
  
  func goingForeground(){
    onMainAfter(5.0) {[weak self] in
      self?.requestReview()
    }
  }
  
  private var valueableActionFinished = false
  
  var issueOpenDate: Date?
  
  static func homeAppeared(){ Self.sharedInstance.homeAppeared() }
  static func issueOpened(){ Self.sharedInstance.issueOpened() }
  
  private func homeAppeared(){
    if let opened = issueOpenDate,
       abs(Date().timeIntervalSince(opened)) > 30 {
      valueableActionFinished = true
      onMainAfter(5.0) {[weak self] in
        self?.requestReview()
      }
    }
    else {
      issueOpenDate = nil
    }
  }
  
  private func issueOpened(){ issueOpenDate = Date() }
  
  func requestReview(){
    if UIApplication.shared.applicationState != .active { return }
    if valueableActionFinished == false { return }
    if canRate == false { return }
    if #available(iOS 14.0, *),
       let windowScene = UIWindow.keyWindow?.windowScene {
      SKStoreReviewController.requestReview(in: windowScene)
    }
    else {
      SKStoreReviewController.requestReview()
    }
    ///Unfortunally we dont know if rate was shown or if rated!
    ratingRequestedForVersion = App.bundleVersion.version
    ratingRequestedDate = Date()
    ratingCount += 1
    canRate = false
  }
  
  override init() {
    canRate = false
    super.init()
    
    if let lastRatedVerion = ratingRequestedForVersion {
      let currentVersion = App.bundleVersion.version
      if currentVersion.major <= lastRatedVerion.major
          && currentVersion.minor <= lastRatedVerion.minor {
        ///already rated for this Version or newer Version
        ratingRequestedDate = Date()///ensure after Update not directly show Popup, wait for waitingDays
        return
      }
    }
    
    guard let ratingRequestedDate = ratingRequestedDate else {
      ///-7 Days: first Rating requested after 3 Days
      ratingRequestedDate = Date().addingTimeInterval(-60*50*24*7)
      return
    }
    
    canRate = canRate(lastRateRequestDate: ratingRequestedDate)
    
    if canRate == false { return }
    
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.goingForeground()
    }
    Notification.receive(Const.NotificationNames.audioPlaybackFinished) { [weak self] _ in
      self?.valueableActionFinished = true
      onMainAfter(30.0) {[weak self] in
        self?.requestReview()
      }
    }
  }
}


fileprivate extension String { var version: Version { return Version(self) }}
