//
//  FeederContext.swift
//
//  Created by Norbert Thies on 17.06.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/**
 A FeederContext manages one Feeder, its GraphQL interface to the backing
 server and its persistent data.
 
 Depending on the state of Feeder access the following Notifications are 
 sent (the receiver gets the sending object as argument):
   - feederReachable
     network connectivity changed, feeder is reachable
   - feederUneachable
     network connectivity changed, feeder is not reachable
   - feederReady
     Feeder data is available (if not reachable then data is from DB)
 */
open class FeederContext: DoesLog {
  /// Name (title) of Feeder
  public var name: String
  /// URL of Feeder (as String)
  public var url: String
  /// The GraphQL Feeder (from server)
  public var gqlFeeder: GqlFeeder?
  /// The stored Feeder (from DB)
  public var storedFeeder: StoredFeeder!
  /// The Downloader to use 
  public var dloader: Downloader?
  /// netAvailability is used to check for network access to the Feeder
  public var netAvailability: NetAvailability
  @DefaultBool(key: "useMobile")
  public var useMobile: Bool
  /// isConnected returns true if the Feeder is available
  public var isConnected: Bool { 
    var isCon: Bool
    if netAvailability.isAvailable {
      if netAvailability.isMobile {
        isCon = useMobile
      } 
      else { isCon = true }
    }
    else { isCon = false }
    return isCon
  }
  /// Has the Feeder been initialized yet
  public var isReady = false
  
  /// notify sends a Notification to all objects listening to the passed
  /// String 'name'. The receiver closure gets the sending FeederContext
  /// as argument.
  private func notify(_ name: String) {
    Notification.send(name, object: self)
  }
  
  /// Present an alert indicating there is no connection to the Feeder
  public func noConnection(to: String? = nil, isExit: Bool = false,
                           closure: (()->())?) {
    self.gqlFeeder = nil
    var sname: String? = nil
    if storedFeeder != nil { sname = storedFeeder.title }
    if let name = to ?? sname {
      let title = isExit ? "Fehler" : "Warnung"
      var msg = """
        Ich kann den \(name)-Server nicht erreichen, möglicherweise
        besteht keine Verbindung zum Internet. Oder Sie haben der App
        die Verwendung mobiler Daten nicht gestattet.
        """
      if isExit {
        msg += """
          Bitte versuchen Sie es zu einem späteren Zeitpunkt
          noch einmal.
          """
      }
      else {
        msg += """
          Sie können allerdings bereits heruntergeladene Ausgaben auch
          ohne Internet-Zugriff lesen.
          """        
      }
      Alert.message(title: title, message: msg, closure: closure)
    }
  }
  
  /// Feeder is now reachable
  private func feederReachable(feeder: Feeder) {
    self.debug("Feeder now reachable")
    self.dloader = Downloader(feeder: feeder as! GqlFeeder)
    notify("feederReachable")    
  }
  
  /// Feeder is not reachable
  private func feederUnreachable() {
    self.debug("Feeder now unreachable")
    self.dloader = nil
    self.gqlFeeder = nil
    notify("feederUneachable")
  }
  
  /// Network status has changed 
  private func checkNetwork() {
    if isConnected {
      self.gqlFeeder = GqlFeeder(title: name, url: url) { [weak self] res in
        guard let self = self else { return }
        if let feeder = res.value() { self.feederReachable(feeder: feeder) }
        else { self.feederUnreachable() }
      }
    }
    else { self.feederUnreachable() }
  }
  
  /// Feeder is initialized, set up other objects
  private func feederReady() {
    if isConnected { self.dloader = Downloader(feeder: gqlFeeder!) }
    self.netAvailability.onChange { [weak self] _ in self?.checkNetwork() }
    self.isReady = true
    notify("feederReady")            
  }
  
  /// React to the feeder being online or not
  private func feederStatus(isOnline: Bool) {
    if isOnline {
      self.storedFeeder = StoredFeeder.persist(object: self.gqlFeeder!)
      feederReady()
    }
    else {
      let feeders = StoredFeeder.get(name: name)
      if feeders.count == 1 {
        self.storedFeeder = feeders[0]
        self.noConnection(to: name, isExit: false) {
          self.feederReady()            
        }
      }
      else {
        self.noConnection(to: name, isExit: true) { exit(0) }
      }
    }
  }
  
  /// init sends a "feederReady" Notification when the feeder context has
  /// been set up
  public init?(name: String, url: String) {
    guard let host = URL(string: url)?.host else { return nil }
    self.name = name
    self.url = url
    self.netAvailability = NetAvailability(host: host)
    if isConnected {
      self.gqlFeeder = GqlFeeder(title: name, url: url) { [weak self] res in
        self?.feederStatus(isOnline: res.value() != nil)
      }
    }
    else { feederStatus(isOnline: false) }
  }
  
  /// Downloads resources if necessary
  func updateResources(toVersion: Int = -1, closure: @escaping (Error?)->()) {
    let latestResources = StoredResources.latest()
    let version = (toVersion < 0) ? storedFeeder.resourceVersion : toVersion
    if let latest = latestResources, latest.resourceVersion >= version,
       !latest.isDownloading && latest.isComplete { 
      closure(nil)
      return
    }
    // update from server needed
    gqlFeeder!.resources { [weak self] result in
      guard let res = result.value() else { closure(result.error()); return }
      guard let self = self else { return }
      let resources = StoredResources.persist(res: res, 
        localDir: self.storedFeeder.resourcesDir.path)
      resources.isDownloading = true
      // dloader.downloadPayload(...)
      if let latest = latestResources, 
        latest.resourceVersion < version
      { latest.delete() }
    }
  }

} // FeederContext
