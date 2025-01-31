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
  
  /* CASES
   Startup, connected => required new version
   Startup, offline, use app, online => required new Version, so its ok not to block the app in case of online start
   minVersionOK is not persisted (should not be in this implementation!), so delayed check is default
   */
  func checkAppUpdate(){
    if self.simulateFailedMinVersion {
      onMainAfter(5.0) {
        self.minVersion = Version("142.0.0")
        self.minVersionOK = false
      }
      return
    }
    
    checkMinVersion()
    
    guard minVersionOK else {
      enforceUpdate()
      return
    }
    if needsReInit() {
      TazAppEnvironment.sharedInstance.resetApp(.cycleChangeWithLogin)
    }
    check4Update()
  }
  
  //ToDo: Ensure this is just done once not on every net status Change
  public func checkMinVersion(){
    GqlAppInfo.query(feeder: self.gqlFeeder) { [weak self] res in
      guard let self else { return }
      //Test: let fakeMv = GqlAppInfo() // fakeMv.minVersion = "1.4.0"
      let fakeMv = GqlAppInfo()
      fakeMv.minVersion = "1.4.0"
      if let mv = fakeMv ?? res.value() {
        if let mvs = mv.minVersion {
          let minVersion = Version(mvs)
          self.log("Version check current: \(App.version), server-min:\(mvs)")
          if App.version < minVersion {
            self.minVersion = minVersion
            self.minVersionOK = false
          }
          else {
            self.minVersion = nil
            self.minVersionOK = true
          }
          return
        }
        else { self.log("Server doesn't return minVersion") }
      }
      else { self.error("Can't get minimal App version from server") }
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
    if updateAlert?.message == msg
        && updateAlert?.view.isVisible == true { return }
    
    updateAlert = Alert.message(title: "Update erforderlich", message: msg){[weak self] in
      guard let self else { return }
      if self.simulateFailedMinVersion {
        Defaults.singleton["simulateFailedMinVersion"] = "false"
      }
      store.openInAppStore { closure?() }
      updateAlert = nil
      /*Discussion former solution 2 Buttons Store & Abbrechen
       Abbrechen exit the App, but this is forbidden!
       @see https://developer.apple.com/forums/thread/63795
      
       refactored: only one button in alert: Store Button
       */
    }
  }
  
  func check4Update() {
    log("Überprüfe, ob neuere Store Version vorliegt")
    async { [weak self] in
      guard let self else { return }
      let id = self.bundleID
      if id == "de.taz.taz.neo" { return }
      if id == "de.taz.taz.beta" { return }
      let version = self.currentVersion
      guard let store = try? StoreApp(id) else {
        self.error("Can't find App with bundle ID '\(id)' in AppStore")
        return
      }
      self.log("Version check current: \(version), store:\(store.version)")
      
      if store.version < version {
        ///set Rating Waiting Days to 1 for RC Testing
        Rating.sharedInstance.waitingDays = 1
        self.lastAppPreviewVersion = version.toString()
      }
      
      if store.needUpdate(simulate: self.simulateNewVersion) {
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
  func needUpdate(simulate: Bool = false) -> Bool {
    ///ensure store version is higher then running version
    guard simulate || self.version > App.version else { return false }
    
    ///ensure store version is the same like the delayed one otherwise delay the store version
    ///to e.g. current version 0.20.0 delayed 0.20.1 has critical bug 0.20.2 is in phased release
    ///ensure not all 0.20.0 users get 0.20.2, they should stay on 0.20.0 for a while
    guard let delayedVersion = Defaults.singleton["newStoreVersion"],
          delayedVersion == self.version.toString() else {
      Defaults.singleton["newStoreVersion"] = self.version.toString()
      Defaults.newStoreVersionFoundDate = Date()
      return false
    }
    let delay:Double = simulate ? 60 : 3600*24*20 //60s or 20 days?
    
    ///ensure update popup for **NON AUTOMATIC UPDATE USERS only** comes et first after
    /// x days 20 = 60s*60min*24h*20d* = 3600*24*20  ::: Test 2 Minutes == 60*2*
    guard let versionFoundDate = Defaults.newStoreVersionFoundDate,
          abs(versionFoundDate.timeIntervalSinceNow) > delay else {
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
