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
  ///fast & lightweight...do not load from json!
  func handleEnterForeground() {
    #warning("maybe update resources and from known cache folder?")
    if tempStorage.hasActiveDownloads {
      log("App entered foreground, execute pending tasks...")
      handlePendingTasks()
    }
  }
}
