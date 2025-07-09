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
  
  /// Checks whether updated resources need to be processed.
  /// If so, performs the update asynchronously and invokes the callback when finished.
  /// If the update takes longer than 2 seconds, a timeout callback is triggered.
  ///
  /// - Parameter completion: Called after resource update handling (if any).
  func updateRessourcesIfNeeded(completion: @escaping () -> Void){
    guard updatedRessourcesUrl.isEmpty
            && updatedRessourcesLocalPath.length > 6 else {
      //TODO:  Background Download log>debug
      log("No need to update Ressources due \(updatedRessourcesUrl.isEmpty ? "" : "not downloaded yet") \(updatedRessourcesLocalPath.length <= 6 ? "no Update available" : "")")
      completion()
      return
    }
    
    guard let file = updatedRessourcesLocalJsonFile, file.exists else {
      log("ERROR: Missing Ressources Data File")
      ///updatedRessourcesLocalPath was not empty, but the file did not exist. maybe deleted?
      completion()
      return
    }
    
    guard Thread.isMainThread else {
      /// Do not terminate the app here.
      /// Updating resources is rarely needed, and terminating the app doesn't help verify if it's functioning correctly.
      /// Alternatively, using `ensureMain` would wrap this in another closure,
      /// which could introduce a race condition due to delayed execution on the main thread.
      log("❌❌ ERROR: only available in Main Thread!")
      completion()
      return
    }
    
    guard let feederContext = feederContext else {
      log("ERROR: Missing feederContext")
      completion()
      return
    }
    
    // callOnce Wrapper for completion
    var didCallCompletion = false
    func callOnce(_ msg: String) {
      guard !didCallCompletion else { return }
      didCallCompletion = true
      if updatedRessourcesLocalPath.length > 5 {
        Dir(dir: updatedRessourcesLocalPath, fname: "").remove()
        log("deleteed updatedRessourcesLocalPath: \(updatedRessourcesLocalPath)")
      }
      updatedRessourcesLocalPath = ""
      log("... done \(msg)")
      DispatchQueue.main.async {
        completion()
      }
    }
    
    let timeout = DispatchWorkItem {[weak self] in
      self?.log("⚠️ Timeout: Resource update took too long, continuing anyway.")
      callOnce("Canceled - Timeout")
    }
    log("Start Update Ressources")
    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)
    feederContext.gqlFeeder.resources(fromData: file.data) {[weak self] res, _ in
      self?.log(">> Update Ressources callback")
      switch res {
        case .success(let resources):
          feederContext.loadResources(res: resources, fromCacheDir: self?.updatedRessourcesLocalPath) {
            self?.log("Loaded resources succeed!")
            timeout.cancel()
            callOnce("success")
          }
        case .failure(let err):
          self?.log("Failed to load resources with error: \(err)")
          timeout.cancel()
          callOnce("failed")
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
