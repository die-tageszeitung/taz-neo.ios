//
//  BackgroundDownloadService+LocalNotifications.swift
//  taz.neo
//
//  Created by Ringo Müller on 16.07.25.
//  Copyright © 2025 taz. All rights reserved.
//

import Foundation
import NorthLib

extension BackgroundDownloadService {
  
  private static let bdlnId: String = "taz.bgdl.notification.newissue"
  
  func notify(issueDate: Date, finished: Bool){
    guard autoloadNotifications else { return }
    /// Only notify download start if the user is a test user
    guard finished || SimpleAuthenticator.getUserData().id == "145489" else { return }
    let message
    = finished
    ? "Die Ausgabe vom \(issueDate.short) wurde heruntergeladen."
    : "Die Ausgabe vom \(issueDate.short) wird heruntergeladen."
    LocalNotifications.notify(message: message, notificationIdentifier: Self.bdlnId)
  }
}
