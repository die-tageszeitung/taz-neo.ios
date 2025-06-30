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
    if hasDownloadedRessources {
      //  FeederContext+ResourcesUpdate.swift
      ///private func loadResources(res: Resources, fromCacheDir: String? = nil) {
      ///**missing Resources!!**
    }
    
    if tempStorage.hasActiveDownloads {
      log("App entered foreground, execute pending tasks...")
      handlePendingTasks()
    }
  }
}
