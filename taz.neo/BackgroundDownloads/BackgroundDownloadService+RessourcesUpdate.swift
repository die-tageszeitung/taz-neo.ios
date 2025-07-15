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
  
  static let updatedResourcesDir: String = "updatedResources"
  
  func prepareResourcesUpdateIfNeeded(issueMinResourceVersion: Int,
                                      localResources: Resources?,
                                      feederContext: FeederContext,
                                      isBackground: Bool) async {
    guard let storedFeed = feederContext.defaultFeed else { return }
    let localResourceFiles = localResources?.resourceFiles ?? []
    guard let lastLocalResourceVersion = localResources?.resourceVersion else {
      log("❌ WARNING: No Local Ressource given")
      return
    }
    
    guard issueMinResourceVersion > lastLocalResourceVersion else {
      log("No Ressource update required")
      return
    }
    
    guard remoteResourcesBaseUrl.length > 6 else {
      log("❌ WARNING: Need to update resources but missing remoteResourceBaseUrl!")
      return
    }
    
    if isBackground == false {
      log("Update resources in foreground")
      feederContext.updateResources()
      return
    }
    
    log("Update resources in background ")
    let localResourcesDir = localResourceUrl(for: storedFeed.feeder, feed: storedFeed)
    if !localResourcesDir.exists { localResourcesDir.create() }
    updatedResourcesLocalPath = localResourcesDir.path
    
    guard updatedResourcesLocalPath.length > 6 else {
      log("no resources Download Required due to missing localPath: \(updatedResourcesLocalPath)")
      return
    }
    
    let jsonFile = updatedResourcesLocalJsonFile
    if jsonFile?.exists == false { jsonFile?.string = "" }///create path structure before bg download finish!
    
    guard let response = await feederContext.gqlFeeder.resources() else {
      log("ERROR: No data fetched")
      return
    }
    
    let res = response.0 ///the resources
    let resJsonData = response.1 ///the resources as JSON Data
    
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
      log("ERROR: No updated Files to download, skip Resources Update")
      return
    }
    
    guard let data = resJsonData else {
      log("ERROR: No data fetched for saving to: \(jsonFile?.path ?? "-")")
      return
    }
    jsonFile?.data = data
    log("persist \(data.count) bytes of data to filesystem for later use in: \(jsonFile?.path ?? "-")")
    log("need to download \(updatedResourcesFiles.count) updated resource files")
  }
  
  /// Handles the completion of a resource download by checking if the downloaded
  /// resource file exists and then initiating asynchronous processing of the data.
  /// If valid data is present, it will decode the resource information and load it
  /// on the main thread. Temporary files and state are cleaned up afterward.
  func handleResourcesDownloadFinished(for url: String) {
    
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
    log("...ResourcesDownloadFinished")

    func cleanup() {
      if updatedResourcesLocalPath.length > 5 {
        Dir(dir: updatedResourcesLocalPath, fname: "").remove()
        log("Deleted updatedResourcesLocalPath: \(updatedResourcesLocalPath)")
      }
      remoteResourcesBaseUrl = ""
      updatedResourcesLocalPath = ""
    }

    guard let file = updatedResourcesLocalJsonFile, file.exists else {
      log("ERROR: Missing Resources Data File")
      cleanup()
      return
    }

    guard let feederContext = feederContext else {
      log("ERROR: Missing feederContext")
      cleanup()
      return
    }

    log("Start Update Resources")
    feederContext.gqlFeeder.resources(fromData: file.data, returnOnMain: false) { [weak self] res, _ in
      guard let self = self else { return }
      self.log(">> Update Resources callback")

      switch res {
        case .success(let resources):
          DispatchQueue.main.async(qos: .utility) { [weak self] in
            guard let self = self else { return }
            feederContext.loadResources(res: resources, fromCacheDir: self.updatedResourcesLocalPath) {
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
    feeder.issueDir(feed: feed.name, issue: Self.updatedResourcesDir)
  }
  
  var updatedResourcesLocalJsonFile: File? {
    guard updatedResourcesLocalPath.length > 6 else {
      log( "updatedResourcesLocalPath is empty/invalid" )
      return nil
    }
    
    let dir = Dir(updatedResourcesLocalPath)
    if dir.exists == false {
      dir.create()
    }
    return File(dir: updatedResourcesLocalPath,
                fname: "fetchedResources.json")
  }
}

// MARK: - UserDefaults Extension to save download resource files in an array (Thread-safe)
extension UserDefaults {
  private static let backgroundDownloadResourcesFilesKey = "backgroundDownloadResourcesFilesKey"
  
  private static let userDefaultsQueue = DispatchQueue(label: "de.taz.userdefaults.background.dl.resources.array.queue")
  
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
  
  /// Fügt mehrere Einträge hinzu, ohne Duplikate zu erzeugen
  func addDownloadingResourceFiles(_ filenames: [String]) {
    Self.userDefaultsQueue.sync {
      let current = array(forKey: Self.backgroundDownloadResourcesFilesKey) as? [String] ?? []
      let updated = Array(Set(current).union(filenames))
      set(updated, forKey: Self.backgroundDownloadResourcesFilesKey)
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
