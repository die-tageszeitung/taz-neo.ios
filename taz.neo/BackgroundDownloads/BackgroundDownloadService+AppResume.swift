//
//  BackgroundDownloadService+AppResume.swift
//  taz.neo
//
//  Created by Ringo Müller on 20.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation

/// MARK: - Application Restart Handling
extension BackgroundDownloadService {
  
  func handleEnterForeground() {
    if tempStorage.hasActiveDownloads {
      log("App entered foreground, execute pending tasks...")
      handlePendingTasks()
    }
    ///What about canceld/stopped downloads?
    ///..handled somewhere else
    ///check if active not started downloads start immediately!
    ///this is: restartPendingDownloads! ...
    #warning("restartPendingDownloads is maybe required?")
  }
}
