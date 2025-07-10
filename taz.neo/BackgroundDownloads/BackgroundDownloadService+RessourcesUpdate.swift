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
  
  func updateRessourcesIfNeeded(issueMinResourceVersion: Int,
                                       localResources: Resources?,
                                       feederContext: FeederContext,
                                      isBackground: Bool) async -> (BackgroundSession, [String])? {
    
    guard let storedFeed = feederContext.defaultFeed else { return nil }
    let localResourceFiles = localResources?.resourceFiles ?? []
    guard let lastLocalResourceVersion = localResources?.resourceVersion else {
      log("❌ WARNING: No Local Ressource given")
      return nil
    }
    
    guard issueMinResourceVersion > lastLocalResourceVersion else {
      log("No Ressource update required")
      return nil
    }
    
    guard remoteRessourcesBaseUrl.length > 6 else {
      log("❌ WARNING: Need to update resources but missing remoteResourceBaseUrl!")
      return nil
    }
    
    if isBackground == false {
      log("Update resources in foreground")
      feederContext.updateResources()
      return nil
    }
    
    log("Update resources in background ")
    updatedRessourcesLocalPath = localResourceUrl(for: storedFeed.feeder, feed: storedFeed).path
    
    guard updatedRessourcesLocalPath.length > 6 else {
      log("no ressources Download Required due to missing localPath: \(updatedRessourcesLocalPath)")
      return nil
    }
    
    let jsonFile = updatedRessourcesLocalJsonFile
    if jsonFile?.exists == false { jsonFile?.string = "" }///create path structure before bg download finish!
    
    guard let response = await feederContext.gqlFeeder.resources() else {
      log("ERROR: No data fetched")
      return nil
    }
    
    let res = response.0 ///the ressources
    let resJsonData = response.1 ///the ressources as JSON Data
    
    let remoteResourceFiles: [FileEntry] = res.resourceFiles
    
    self.updatedResourcesFiles = remoteResourceFiles.filter { remoteFile in
      // lookup for matching fileentry with same name
      guard let localFile = localResourceFiles.first(where: { $0.name == remoteFile.name }) else {
        return true ///no local fileentry => new file
      }
      return remoteFile.sha256 != localFile.sha256
    }
    log("updatedResourcesFiles contains \(updatedResourcesFiles.count) files")
    
    guard updatedResourcesFiles.isEmpty == false else {
      log("ERROR: No updated Files to download, skip Ressources Update")
      return nil
    }
    
    guard let data = resJsonData else {
      log("ERROR: No data fetched for saving to: \(jsonFile?.path ?? "-")")
      return nil
    }
    jsonFile?.data = data
    log("persist \(data.count) bytes of data to filesystem for later use in: \(jsonFile?.path ?? "-")")
    log("need to download \(updatedResourcesFiles.count) updated resource files")
    
      
    #warning("Check if restart make sense here; its not essential required")
    ///MAYBE TODO RESTART but required refactoring of BackgroundSession to find different resources urls;
    ///did not match BackgroundDownloadService logic for ressources download on new fetch&issuedownload a new resources download ist probably initiated
    ///...easy way just download them...
    //    if BackgroundSession.search(url: updatedRessourcesUrl) {
    //      ///already downloading, maybe a restart to trigger is required
    //      do { try restartAll() }
    //      catch { log("restartAll failed: \(error)") }
    //      return
    //    }
      
    do {
      let filenames = updatedResourcesFiles.map { $0.name }
      let resourcesDownload =
      try BackgroundSession(remoteRessourcesBaseUrl, asBackgroundSession: isBackground) { [weak self] url, err in
       self?.log("resourcesDownload finished for: \(url)")
       self?.dlCallback(downloadUrl: url, err: err)
     }
      resourcesDownload.allowMobile = !autoloadOnlyInWLAN
      resourcesDownload.waitForAvailability = true
      
      ///reset after download enqueued;
      ///its not ensured that download finishes callback has access to the array;
      ///maybe the app is restarted
      updatedResourcesFiles = []
      return (resourcesDownload, filenames)
    }
    catch { log("❌ downloadRessources failed: \(error)")  }
    return nil
  }
  
  /// Handles the completion of a resource download by checking if the downloaded
  /// resource file exists and then initiating asynchronous processing of the data.
  /// If valid data is present, it will decode the resource information and load it
  /// on the main thread. Temporary files and state are cleaned up afterward.
  func handleRessourcesDownloadFinished(for url: String) {
    
    var downloadingResourcesFiles = UserDefaults.standard.downloadingResourcesFiles
    
    guard downloadingResourcesFiles.isEmpty == false else {
      log("ERROR: No resources are currently being downloaded.")
      return
    }
    
    let fileName = url.lastPathComponent
   
    
    if let index = downloadingResourcesFiles.firstIndex(of: fileName) {
      downloadingResourcesFiles.remove(at: index)
      log("Check if downloadedFile: \(fileName) is in downloadingResourcesFiles")
    } else {
      log("ERROR: File \(fileName) not found in downloadingResourcesFiles")
      return
    }
    
    if downloadingResourcesFiles.isEmpty == false {
      UserDefaults.standard.downloadingResourcesFiles = downloadingResourcesFiles
      log("Resources still downloading: \(downloadingResourcesFiles.count) files remaining")
      return
    }
    UserDefaults.standard.downloadingResourcesFiles = []
    log("...RessourcesDownloadFinished")

    func cleanup() {
      if updatedRessourcesLocalPath.length > 5 {
        Dir(dir: updatedRessourcesLocalPath, fname: "").remove()
        log("Deleted updatedRessourcesLocalPath: \(updatedRessourcesLocalPath)")
      }
      remoteRessourcesBaseUrl = ""
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
}

// MARK: - UserDefaults Extension to save download resource files in an array (Thread-safe)
fileprivate extension UserDefaults {
  private static let backgroundDownloadResourcesFilesKey = "backgroundDownloadResourcesFilesKey"
  
  private static let userDefaultsQueue = DispatchQueue(label: "de.taz.userdefaults.background.dl.ressources.array.queue")
  
  var downloadingResourcesFiles: [String] {
    get {
      return Self.userDefaultsQueue.sync {
        return array(forKey: Self.backgroundDownloadResourcesFilesKey) as? [String] ?? []
      }
    }
    set {
      Self.userDefaultsQueue.sync {
        set(newValue, forKey: Self.backgroundDownloadResourcesFilesKey)
      }
    }
  }
}


fileprivate extension GqlFeeder {
  
  func resources() async -> (Resources, Data?)? {
    await withCheckedContinuation { continuation in
      resources {[weak self] result, data in
        switch result {
          case .success(let resources):
            continuation.resume(returning: (resources, data))
          case .failure(let error):
            self?.log("Error fetching resources: \(error)")
            continuation.resume(returning: nil)
        }
      }
    }
  }
}
