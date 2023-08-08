//
//  FeederContext+AppUpdate.swift
//  taz.neo
//
//  Created by Ringo Müller on 08.08.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

// MARK: - Update Checks, Helper
extension FeederContext {
  
  func checkAppUpdate(){
    guard minVersionOK else {
      enforceUpdate()
      return
    }
    if needsReInit() {
      TazAppEnvironment.sharedInstance.resetApp(.cycleChangeWithLogin)
    }
  }
  
  ///Force update called if minVersionOK false after init
  func enforceUpdate(closure: (()->())? = nil) {
    let id = bundleID
    guard let store = try? StoreApp(id) else {
      error("Can't find App with bundle ID '\(id)' in AppStore")
      return
    }
    let minVersion = self.minVersion?.toString() ?? "unbekannt"
    let msg = """
      Es liegt eine neue Version dieser App mit folgenden Änderungen vor:
        
      \(store.releaseNotes)
        
      Sie haben momentan die Version \(currentVersion) installiert. Um aktuelle
      Ausgaben zu laden, ist mindestens die Version \(minVersion)
      erforderlich. Möchten Sie jetzt eine neue Version laden?
    """
    Alert.message(title: "Update erforderlich", message: msg){[weak self] in
      guard let self else { return }
      if self.simulateFailedMinVersion {
        Defaults.singleton["simulateFailedMinVersion"] = "false"
      }
      store.openInAppStore { closure?() }
      #warning("exit(0) not allowed")
      ///either not connect app or update issues == offline from now on or force update Store
      ///@see: https://developer.apple.com/forums/thread/63795
    }
  }
  
  func Xcheck4Update() {
    async { [weak self] in
      guard let self else { return }
      let id = self.bundleID
      let version = self.currentVersion
      guard let store = try? StoreApp(id) else {
        self.error("Can't find App with bundle ID '\(id)' in AppStore")
        return
      }
      self.debug("Version check: \(version) current, \(store.version) store")
      if store.needUpdate() {
        let msg = """
        Sie haben momentan die Version \(self.currentVersion) installiert.
        Es liegt eine neue Version \(store.version) mit folgenden Änderungen vor:
        
        \(store.releaseNotes)
        
        Möchten Sie im AppStore ein Update veranlassen?
        """
        onMain(after: 2.0) {
          Alert.confirm(title: "Update", message: msg) { [weak self] doUpdate in
            guard let self else { return }
            if self.simulateNewVersion {
              Defaults.singleton["simulateNewVersion"] = "false"
            }
            if doUpdate { store.openInAppStore() }
            else { Defaults.newStoreVersionFoundDate = Date()}///delay again for 20? days
          }
        }
      }
    }
  }
}

fileprivate extension StoreApp {
  
  ///check if App Update Popup should be shown
  func needUpdate() -> Bool {
    ///ensure store version is higher then running version
    guard self.version > App.version else { return false }
    
    ///ensure store version is the same like the delayed one otherwise delay the store version
    ///to e.g. current version 0.20.0 delayed 0.20.1 has critical bug 0.20.2 is in phased release
    ///ensure not all 0.20.0 users get 0.20.2, they should stay on 0.20.0 for a while
    guard let delayedVersion = Defaults.singleton["newStoreVersion"],
          delayedVersion == self.version.toString() else {
      Defaults.singleton["newStoreVersion"] = self.version.toString()
      Defaults.newStoreVersionFoundDate = Date()
      return false
    }
    
    ///ensure update popup for **NON AUTOMATIC UPDATE USERS only** comes et first after
    /// x days 20 = 60s*60min*24h*20d* = 3600*24*20  ::: Test 2 Minutes == 60*2*
    guard let versionFoundDate = Defaults.newStoreVersionFoundDate,
          abs(versionFoundDate.timeIntervalSinceNow) > 3600*24*20 else {
      return false
    }
    ///update is needed
    return true
  }
}


fileprivate extension Defaults {
  
  ///Helper to persist newStoreVersionFoundDate
  ///no need to reset on reset App, no need to use somewhere else
  static var newStoreVersionFoundDate : Date? {
    get {
      if let curr = Defaults.singleton["newStoreVersionFoundDate"] {
        return Date.fromString(curr)
      }
      return nil
    }
    set {
      if let date = newValue {
        Defaults.singleton["newStoreVersionFoundDate"] = Date.toString(date)
      }
      else {
        Defaults.singleton["newStoreVersionFoundDate"] = nil
      }
    }
  }
}
