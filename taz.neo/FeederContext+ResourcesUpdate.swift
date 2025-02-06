//
//  FeederContext+ResourcesUpdate.swift
//  taz.neo
//
//  Created by Ringo Müller on 07.08.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import UIKit

extension FeederContext {
  /// Downloads resources if necessary
  public func updateResources(toVersion: Int = -1) {
    guard !isUpdatingResources else { return }
    guard let storedFeeder = storedFeeder else {
      log("storedFeeder not initialized yet!")
      return
    }
    isUpdatingResources = true
    let version = (toVersion < 0) ? storedFeeder.resourceVersion : toVersion
    if StoredResources.latest() == nil { loadBundledResources(/*setVersion: 1*/) }
    if let latest = StoredResources.latest() {
      if latest.resourceVersion >= version, latest.isComplete {
        isUpdatingResources = false
        debug("No need to read resources version \(latest.resourceVersion)")
        notify("resourcesReady");
        return
      }
    }
    if !isConnected {
      //Skip Offline Start Deathlock //TODO TEST either notify("resourcesReady"); or:
      isUpdatingResources = false
      return
    }
    // update from server needed
    gqlFeeder.resources { [weak self] result in
      guard let self = self, let res = result.value() else { return }
      self.loadResources(res: res)
    }
  }
  
  /// Load resources from server with optional cache directory
  private func loadResources(res: Resources, fromCacheDir: String? = nil) {
    let previous = StoredResources.latest()
    let resources = StoredResources.persist(object: res)
    self.dloader.createDirs()
    var onProgress: ((Int64,Int64)->())? = { (bytesLoaded,totalBytes) in
      self.notify("resourcesProgress", content: (bytesLoaded,totalBytes))
    }
    if fromCacheDir != nil { onProgress = nil }
    resources.isDownloading = true
    self.dloader.downloadPayload(payload: resources.payload as! StoredPayload,
                                 fromCacheDir: fromCacheDir,
                                 onProgress: onProgress) { err in
      resources.isDownloading = false
      if err == nil {
        let source: String = fromCacheDir ?? "server"
        self.debug("Resources version \(resources.resourceVersion) loaded from \(source)")
        self.notify("resourcesReady")
        /// Delete unneeded old resources
        if let prev = previous, prev.resourceVersion < resources.resourceVersion {
          prev.delete()
        }
        ArticleDB.save()
      }
      self.isUpdatingResources = false
    }
  }
  
  private func loadBundledResources(setVersion: Int? = nil) {
    if case let bundledResources = BundledResources(),
            let result = bundledResources.resourcesPayload.value(),
            let res = result["resources"],
            bundledResources.bundledFiles.count > 0 {
      if let v = setVersion { res.resourceVersion = v }
      let success = persistBundledResources(bundledResources: bundledResources,
                                             resData: res)
      if success == true {
        ArticleDB.save()
        log("Bundled Resources version \(res.resourceVersion) successfully loaded")
      }
    }
  }
  
  
  /// persist helper function for updateResources
  /// - Parameters:
  ///   - bundledResources: the resources (with files) to persist
  ///   - resData: the GqlResources data object to persist
  /// - Returns: true if succeed
  private func persistBundledResources(bundledResources: BundledResources,
                                        resData : GqlResources) -> Bool {
    //Use Bundled Resources!
    resData.setPayload(feeder: self.gqlFeeder)
    let resources = StoredResources.persist(object: resData)
    self.dloader.createDirs()
    resources.isDownloading = true
    var success = true
    
    if bundledResources.bundledFiles.count != resData.files.count {
      log("WARNING: Something is Wrong maybe need to download additional Files!")
      success = false
    }
    
    var bundledResourceFiles : [File] = []
    
    for fileUrl in bundledResources.bundledFiles {
      let file = File(fileUrl)
      if file.exists {
        bundledResourceFiles.append(file)
      }
    }
    
    let globalFiles = resources.payload.files.filter {
      $0.storageType != .global
    }
    
    for globalFile in globalFiles {
      let bundledFiles = bundledResourceFiles.filter{ $0.basename == globalFile.name }
      if bundledFiles.count > 1 { log("Warning found multiple matching Files!")}
      guard let bundledFile = bundledFiles.first else {
        log("Warning not found matching File!")
        success = false
        continue
      }
      
      /// File Creation Dates did not Match! bundledFile.mTime != globalFile.moTime
      if bundledFile.exists,
         bundledFile.size == globalFile.size {
        let targetPath = self.gqlFeeder.resourcesDir.path + "/" + globalFile.name
        bundledFile.copy(to: targetPath)
        let destFile = File(targetPath)
        if destFile.exists { destFile.mTime = globalFile.moTime }
        debug("File \(bundledFile.basename) moved... exist in resdir? : \(globalFile.existsIgnoringTime(inDir: self.gqlFeeder.resourcesDir.path))")
      } else {
        log("* Warning: File \(bundledFile.basename) may not exist (\(bundledFile.exists)), mtime, size is wrong  \(bundledFile.size) !=? \(globalFile.size)")
        success = false
      }
    }
    resources.isDownloading = false
    if success == false {
      log("* Warning: There was an error due persisting Bundled Ressources ....delete them.")
      resources.delete()
    }
    return success
  }
}
