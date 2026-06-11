//
//  BackgroundTaskRegistrar.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.06.26.
//  Copyright © 2026 taz. All rights reserved.
//
import NorthLib
import BackgroundTasks

final class BackgroundTaskRegistrar {

  static let shared = BackgroundTaskRegistrar()

  private var registered = false

  func registerTasks() {
    guard !registered else { return }
    registered = true
    BGTaskScheduler.shared.register(forTaskWithIdentifier: App.backgroundTaskRefreshId,
                                    using: nil) { task in
      BackgroundDownloadService.shared.handleIssueCheckTask(task: task)
    }
  }
}
