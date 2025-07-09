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
                                       lastLocalResourceVersion: Int,
                                       fetchedResourceUrl: String?,
                                       feederContext: FeederContext,
                                       isBackground: Bool) {
    
    guard let storedFeed = feederContext.defaultFeed else { return }
    
    guard issueMinResourceVersion > lastLocalResourceVersion else {
      log("No Ressource update required")
      return
    }
    
    guard let fetchedResourceUrl = fetchedResourceUrl,
          fetchedResourceUrl.length > 6 else {
      log("❌ WARNING: Need to update resources but missing zipURL!")
      return
    }
    
    if isBackground == false {
      log("Update resources in foreground")
      feederContext.updateResources()
      return
    }

    log("Update resources in background")
    
    updatedRessourcesUrl = fetchedResourceUrl
    updatedRessourcesLocalPath = localResourceUrl(for: storedFeed.feeder, feed: storedFeed).path
    let jsonFile = updatedRessourcesLocalJsonFile
    if jsonFile?.exists == false { jsonFile?.string = "" }///create path structure before bg download finish!
    
    //fetch latest ressources Data (not files)
    feederContext.gqlFeeder.resources {[weak self] resources, data in
      switch resources {
        case .success(_):
          let jsonFile = self?.updatedRessourcesLocalJsonFile
          guard let data = data else {
            self?.log("ERROR: No data fetched for saving to: \(jsonFile?.path ?? "-")")
            return
          }
          jsonFile?.data = data
          self?.log("persist \(data.count) bytes of data to filesystem for later use in: \(jsonFile?.path ?? "-")")
        case .failure(let err):
          self?.log("ERROR: No data fetched")
      }
    }
  }
  
  /// Handles the completion of a resource download by checking if the downloaded
  /// resource file exists and then initiating asynchronous processing of the data.
  /// If valid data is present, it will decode the resource information and load it
  /// on the main thread. Temporary files and state are cleaned up afterward.
  func handleRessourcesDownloadFinished(for url: String) {
    log("...RessourcesDownloadFinished")

    func cleanup() {
      if updatedRessourcesLocalPath.length > 5 {
        Dir(dir: updatedRessourcesLocalPath, fname: "").remove()
        log("Deleted updatedRessourcesLocalPath: \(updatedRessourcesLocalPath)")
      }
      updatedRessourcesUrl = ""
      updatedRessourcesLocalPath = ""
    }

    guard let file = updatedRessourcesLocalJsonFile, file.exists else {
      log("ERROR: Missing Ressources Data File")
      cleanup()
      return
    }

    guard let feederContext = feederContext else {
      log("ERROR: Missing feederContext")
      cleanup()
      return
    }

    log("Start Update Ressources")
    feederContext.gqlFeeder.resources(fromData: file.data, returnOnMain: false) { [weak self] res, _ in
      guard let self = self else { return }
      self.log(">> Update Ressources callback")

      switch res {
        case .success(let resources):
          DispatchQueue.main.async(qos: .utility) { [weak self] in
            guard let self = self else { return }
            feederContext.loadResources(res: resources, fromCacheDir: self.updatedRessourcesLocalPath) {
              self.log("Loaded resources succeed!")
              cleanup()
            }
          }
        case .failure(let err):
          self.log("Failed to load resources with error: \(err)")
          cleanup()
      }
    }
  }
  
  ///URL/PATH
  private func localResourceUrl(for feeder: Feeder, feed: Feed) -> Dir {
    feeder.issueDir(feed: feed.name, issue: Self.updatedRessourcesDir)
  }
  
  var updatedRessourcesLocalJsonFile: File? {
    guard updatedRessourcesLocalPath.length > 6 else {
      log( "updatedRessourcesLocalPath is empty/invalid" )
      return nil
    }
    
    let dir = Dir(updatedRessourcesLocalPath)
    if dir.exists == false {
      dir.create()
    }
    return File(dir: updatedRessourcesLocalPath,
                fname: "fetchedResources.json")
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
      ///cachePolicy is: requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
      ///should be no Problem for updated zip
    }
    catch { log("❌ downloadRessources failed: \(error)")  }
  }
}
