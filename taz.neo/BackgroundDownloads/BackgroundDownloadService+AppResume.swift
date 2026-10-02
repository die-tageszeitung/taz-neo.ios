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
    if tempStorage.hasActiveDownloads {
      #warning("check if recieve feeder ready required!")
      //otherwise ...
      log("BDL App entered foreground, execute pending tasks...")
      if let feed = TazAppEnvironment.sharedInstance.feederContext?.masterFeed1 {
        handlePendingTasks(in: feed)
      }
      
    }
  }
}
