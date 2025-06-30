//
//  BackgroundDownloadService.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import Foundation
import NorthLib

// MARK: - Persistance Helper Extensions
extension BackgroundDownloadService {
  
  static let updatedRessourcesDir: String = "updatedRessources"
  
  func prepareIfResoucesUpdateRequired(issueMinResourceVersion: Int,
                                       fetchedResourceUrl: String?,
                                       storedFeed: StoredFeed) {
    #warning("uncomment the following lines for Release!")
//    guard issueMinResourceVersion > storedFeed.feeder.resourceVersion else {
//      log("No Ressource update required")
//      return
//    }
    
    guard let fetchedResourceUrl = fetchedResourceUrl,
          fetchedResourceUrl.length > 6 else {
      log("❌ WARNING: Need to upddate resources but missing zipURL!")
      return
    }
    
    updatedRessourcesUrl = fetchedResourceUrl
    updatedRessourcesLocalPath = localResourceUrl(for: storedFeed.feeder, feed: storedFeed).path
  }
  
  ///URL/PATH
  private func localResourceUrl(for feeder: Feeder, feed: Feed) -> Dir {
    feeder.issueDir(feed: feed.name, issue: Self.updatedRessourcesDir)
  }
  
  var hasDownloadedRessources: Bool {
    updatedRessourcesUrl.length == 0 && updatedRessourcesLocalPath.length > 6
  }
  
  func downloadRessourcesIfNeeded(isBackground:Bool) {
    guard updatedRessourcesUrl.length > 6,
    updatedRessourcesLocalPath.length > 6 else {
      log("no ressources Download Required due to missing url: \(updatedRessourcesUrl) or localPath: \(updatedRessourcesLocalPath)")
      return
    }
    
    if BackgroundSession.search(url: updatedRessourcesUrl) {
      ///already downloading, maybe a restart to trigger is required
      do { try restartAll() }
      catch { log("restartAll failed: \(error)") }
      return
    }
    
    do {
      let resourcesDownload
      = try BackgroundSession(updatedRessourcesUrl, asBackgroundSession: isBackground) { [weak self] url, err in
        self?.log("resourcesDownload finished for: \(url)")
        self?.dlCallback(downloadUrl: url, err: err)
      }
      resourcesDownload.allowMobile = !autoloadOnlyInWLAN
      resourcesDownload.waitForAvailability = true
      resourcesDownload.downloadZip(toDir: updatedRessourcesLocalPath)
    }
    catch { log("❌ downloadRessources failed: \(error)")  }
  }
}
