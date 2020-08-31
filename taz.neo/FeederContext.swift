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
 sent:
   - feederReachable(FeederContext)
     network connectivity changed, feeder is reachable
   - feederUneachable(FeederContext)
     network connectivity changed, feeder is not reachable
   - feederReady(FeederContext)
     Feeder data is available (if not reachable then data is from DB)
   - issueOverview(Result<Issue,Error>)
     Issue Overview has been received (and stored in DB) 
   - issue(Result<Issue,Error>), sender: Issue
     Issue with complete structural data and downloaded files is available
   - resourcesReady(FeederContext)
     Resources are loaded and ready
   - resourcesProgress((bytesLoaded, totalBytes))
     Resource loading progress indicator
 */
open class FeederContext: DoesLog {
  /// Name (title) of Feeder
  public var name: String
  /// URL of Feeder (as String)
  public var url: String
  /// Authenticator object
  public var authenticator: Authenticator?
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
  
  /// Are we authenticated with the server?
  public var isAuthenticated: Bool { gqlFeeder != nil && gqlFeeder!.isAuthenticated }
  
  /// notify sends a Notification to all objects listening to the passed
  /// String 'name'. The receiver closure gets the sending FeederContext
  /// as 'sender' argument.
  private func notify(_ name: String, content: Any? = nil) {
    Notification.send(name, content: content, sender: self)
  }
  
  /// This notify sends a Result<Type,Error>
  private func notify<Type>(_ name: String, result: Result<Type,Error>) {
    Notification.send(name, result: result, sender: self)
  }
  
  /// Present an alert indicating there is no connection to the Feeder
  public func noConnection(to: String? = nil, isExit: Bool = false,
                           closure: (()->())? = nil) {
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
        self?.authenticator = SimpleAuthenticator(feeder: (self?.gqlFeeder)!)
        self?.feederStatus(isOnline: res.value() != nil)
      }
    }
    else { feederStatus(isOnline: false) }
  }
  
  /// Downloads resources if necessary
  public func updateResources(toVersion: Int = -1) {
    let version = (toVersion < 0) ? storedFeeder.resourceVersion : toVersion
    let latestResources = StoredResources.latest()
    if let latest = latestResources {
      if latest.isDownloading { return } 
      if (latest.resourceVersion >= version && latest.isComplete) || !isConnected { 
        notify("resourcesReady"); return
      }
    }
    // update from server needed
    guard let dloader = self.dloader, isConnected else { 
      noConnection()
      return
    }
    gqlFeeder!.resources { [weak self] result in
      guard let self = self, let res = result.value() else { return }
      let previous = latestResources
      let resources = StoredResources.persist(res: res, 
                        localDir: self.storedFeeder.resourcesDir.path)
      resources.isDownloading = true
      dloader.downloadPayload(payload: resources.payload, 
        onProgress: { (bytesLoaded,totalBytes) in
          self.notify("resourcesProgress", content: (bytesLoaded,totalBytes))
        }) { err in
        resources.isDownloading = false
        if err == nil {
          self.notify("resourcesReady")
          /// Delete unneeded old resources
          if let prev = previous, prev.resourceVersion < version { prev.delete() }
        }
      }
    }
  }
  
  /// Feeder has flagged an error
  func handleFeederError(_ err: FeederError, closure: @escaping ()->()) {
    var text = ""
    switch err {
    case .invalidAccount: text = "Ihre Kundendaten sind nicht korrekt."
    case .expiredAccount: text = "Ihr Abo ist abgelaufen."
    case .changedAccount: text = "Ihre Kundendaten haben sich geändert."
    case .unexpectedResponse: 
      Alert.message(title: "Fehler", 
                    message: "Es gab ein Problem bei der Kommunikation mit dem Server") {
        exit(0)               
      }
    }
    SimpleAuthenticator.deleteUserData()
    Alert.message(title: "Fehler", message: text) {
      self.authenticator?.authenticate(isFullScreen: true) { err in closure() }
    }
  }
  
  /// Download overview moment images and store references in DB
  private func getOvwMoments(issues: [StoredIssue]) {
    var iss = issues
    if let issue = iss.pop() {
      var res: Result<Issue,Error> = .success(issue)
      if !issue.isOvwComplete {
        dloader!.downloadStoredMoment(issue: issue) { err in
          if err == nil { issue.isOvwComplete = true }
          else { res = .failure(err!) }
          self.notify("issueOverview", result: res)
        }
      }
      else { self.notify("issueOverview", result: res) }
      self.getOvwMoments(issues: iss)
    }
    else { ArticleDB.save() }
  }

  /**
   Get Overview Issues from Feed
   
   If we are online, 'count' Issue overviews are requested from the server.
   Otherwise 'count' Issues from the DB are returned. The returned Issues are always 
   StoredIssues.
   */
  public func getOvwIssues(feed: Feed, count: Int, fromDate: Date? = nil) {
    let sfs = StoredFeed.get(name: feed.name, inFeeder: storedFeeder)
    guard sfs.count > 0 else { return }
    let sfeed = sfs[0]  
    Notification.receiveOnce("resourcesReady") { [weak self] err in
      guard let self = self else { return }
      if self.isConnected {
        self.gqlFeeder!.issues(feed: sfeed, date: fromDate, count: count, 
                               isOverview: true) { res in
          if let issues = res.value() {
            for issue in issues {
              let si = StoredIssue.get(date: issue.date, inFeed: sfeed)
              if si.count < 1 {
                StoredIssue.persist(object: issue, inFeed: sfeed)
              }
            }
            ArticleDB.save()
            let sissues = StoredIssue.issuesInFeed(feed: sfeed, count: count, 
                                                   fromDate: fromDate)
            self.getOvwMoments(issues: sissues)
          }
          else {
            if let err = res.error() as? FeederError {
              self.handleFeederError(err) { 
                self.getOvwIssues(feed: feed, count: count, fromDate: fromDate)
              }
            }
            else { 
              let res: Result<Issue,Error> = .failure(res.error()!)
              self.notify("issueOverview", result: res)
            }
            return
          }
        }
      }
      else {
        let sissues = StoredIssue.issuesInFeed(feed: sfeed, count: count, 
                                               fromDate: fromDate)
        self.getOvwMoments(issues: sissues)
      }
    }
    updateResources()
  }

  /**
   Get a complete Issue
   
   This method retrieves a complete Issue (ie downloaded Issue with complete structural
   data) from the database. If necessary all files are downloaded from the server.
   */
  public func getCompleteIssue(issue: StoredIssue) {
    if issue.isDownloading {
      Notification.receiveOnce("issue", from: issue) { notif in
        self.getCompleteIssue(issue: issue)
      }
    }
    if issue.isComplete {
      if issue.isReduced && isAuthenticated {
        issue.isComplete = false
      }
      else {
        Notification.send("issue", result: .success(issue), sender: issue)
        return
      }
    }
    if self.isConnected {
      gqlFeeder!.issues(feed: issue.feed, date: issue.date, count: 1) { res in
        if let issues = res.value(), issues.count == 1 {
          let dissue = issues[0]
          issue.update(object: dissue, inFeed: issue.feed as! StoredFeed)
          ArticleDB.save()
          self.downloadIssue(issue: issue)
        }
      }
    }
    else { noConnection() }
  }
  
  /// Download Issue files and resources if necessary
  private func downloadIssue(issue: StoredIssue) {
    Notification.receiveOnce("resourcesReady") { [weak self] err in
      guard let self = self else { return }
      if self.isConnected {
        issue.isDownloading = true
        self.dloader!.downloadPayload(payload: issue.payload!, 
          onProgress: { (bytesLoaded,totalBytes) in
            Notification.send("issueProgress", content: (bytesLoaded,totalBytes),
                              sender: issue)
          }) { err in
          issue.isDownloading = false
          var res: Result<StoredIssue,Error>
          if err == nil { 
            res = .success(issue) 
            issue.isComplete = true
            ArticleDB.save()
          }
          else { res = .failure(err!) }
          Notification.send("issue", result: res, sender: issue)
        }
      }
      else {
        self.noConnection() 
      }
    }
    updateResources(toVersion: issue.minResourceVersion)
  }

} // FeederContext
