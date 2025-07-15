//
//  BackgroundDownloadService+AppResume.swift
//  taz.neo
//
//  Created by Ringo Müller on 20.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// MARK: - Application Restart Handling
extension BackgroundDownloadService {
  ///fast & lightweight...do not load from json!
  func handleEnterForeground() {
    onThread { [weak self] in
      self?.backgroundSession.resume(archived: false, priority: 1.0)
    }
    #warning("CHECK: maybe update resources and from known cache folder?")
    if tempStorage.hasActiveDownloads {
      log("BDL App entered foreground, execute pending tasks...")
      handlePendingTasks()
    }
  }
}
