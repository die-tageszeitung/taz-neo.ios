//
//  BackgroundDownloadManager.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.02.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib


// Model für die JSON Response
struct FeedResponse: Decodable {
  let data: FeedRequestContainer
  
  struct FeedRequestContainer: Decodable {
    let feedRequest: GqlFeeder.FeedRequest
  }
  
  var issueTargetDir: Dir? {
    guard let issueFolderName = data.feedRequest.feeds.first?.issues?.first?.date.ISO8601,
          let feedName = data.feedRequest.feeds.first?.name else { return nil }
    let dir = Dir(dir: Dir.appSupportPath, fname: "\(feedName)/\(feedName)/\(issueFolderName)")
    if !dir.exists { dir.create()  }
    return dir
  }
}


class BackgroundDownloadManager: NSObject, URLSessionDownloadDelegate, DoesLog {
  
  var currentFeeder : (name: String, url: String, feed: String)
  = Defaults.currentFeeder
  
  static let shared = BackgroundDownloadManager()
  
  var latestIssueResponse: FeedResponse?
  
  private var backgroundSession: URLSession!
  private var fetchCompletionHandler: FetchCompletionHandler?

  private let authKey: String = SimpleAuthenticator.getUserData().token ?? ""
  
  private override init() {
    super.init()
    
    // Hintergrund-Session-Konfiguration
    let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "com.taz.downloadSession")
    backgroundConfig.isDiscretionary = true  // iOS darf die Download-Ressourcen verwalten
    backgroundConfig.sessionSendsLaunchEvents = true  // Startet die App bei einer Push Notification
    
    // Erstelle die Hintergrund-URLSession mit einem Delegate
    self.backgroundSession = URLSession(configuration: backgroundConfig, delegate: self, delegateQueue: nil)
    /**
     USAGE:
     let downloadTask = backgroundSession.downloadTask(with: request)
     downloadTask.resume()
     
     */
  }
  
  // Methode zum Verarbeiten der Push Notification
  func processPushNotification(pn: PushNotification, payload: PushNotification.Payload, fetchCompletionHandler: @escaping FetchCompletionHandler) {
    self.fetchCompletionHandler = fetchCompletionHandler
    self.currentFeeder = Defaults.currentFeeder///update if required
    
    // Ruft die JSON-Daten ab, um den Feed zu analysieren
    fetchLatestIssueData { [weak self] result,data  in
      switch result {
        case .success(let feedResponse):
          if let data = data, let path = feedResponse.issueTargetDir?.path {
            let file = File(dir: path, fname: "issueData.json")
            file.data = data
          }
          self?.latestIssueResponse = feedResponse
          self?.downloadZip(from: feedResponse)
        case .failure:
          fetchCompletionHandler(.failed)
      }
    }
  }
  
  // Ruft das JSON vom Server ab
  private func fetchLatestIssueData(_ completion: @escaping (Result<FeedResponse, Error>, Data?) -> Void) {
    guard let baseURL = URL(string: Defaults.currentFeeder.url) else {
      log("no baseUrl found")
      return
    }
    var request = URLRequest(url: baseURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(authKey, forHTTPHeaderField: "X-tazAppAuthKey")
    
    let body: [String: Any] = [
      "query": """
            {
            \(GqlFeeder.FeedRequest.request(feedName: self.currentFeeder.feed,
            date: nil,
            key: nil,
            count: 1,
            isOverview: false))
            }
            """
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
    #warning("ATTENTION MAYBE VERRY IMPORTANT! USING SHARES SESS")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(error), nil)
        return
      }
      
      guard let data = data else {
        completion(.failure(NSError(domain: "BackgroundDownloadManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])), nil)
        return
      }
      
      let res = self.requestResult(data: data, type: FeedResponse.self)
      completion(res, data)
    }
    task.resume()
  }
  
  private func requestResult<T>(data: Data?, type: T.Type)
  -> Result<T,Error> where T: Decodable {
    var result: Result<T,Error>
    if let d = data {
      self.debug("Received: \"\(String(decoding: d, as: UTF8.self)[0..<2000])\"")
      if let gerr = GraphQlError.from(data: d) {
        self.fatal("GraphQL-Server encountered error:\n\(gerr)")
        result = .failure(gerr)
      }
      else {
        do {
          let dec = JSONDecoder()
          let response = try dec.decode(T.self, from: d)
          result = .success(response)
        }
        catch let DecodingError.dataCorrupted(context) {
          log("DecodingError#1: Decode failed dataCorrupted context: \(context)")
          result = .failure(self.fatal("JSON decoding error"))
        } catch let DecodingError.keyNotFound(key, context) {
          log("DecodingError#2: Key \(key) not found: \(context.debugDescription)")
          log("DecodingError#2: codingPath: \(context.codingPath)")
          result = .failure(self.fatal("JSON decoding error"))
        } catch let DecodingError.valueNotFound(value, context) {
          log("DecodingError#3: Value \(value) not found: \(context.debugDescription)")
          log("DecodingError#3: codingPath: \(context.codingPath)")
          result = .failure(self.fatal("JSON decoding error"))
        } catch let DecodingError.typeMismatch(type, context)  {
          log("DecodingError#4: Type \(type) mismatch: \(context.debugDescription)")
          log("DecodingError#4: codingPath: \(context.codingPath)")
          result = .failure(self.fatal("JSON decoding error"))
        } catch {
          log("DecodingError#5: error: \(error)")
          result = .failure(self.fatal("JSON decoding error"))
        }
      }
    }
    else { result = .failure(self.fatal("No data from GraphQL server")) }
    return result
  }
  
  // Startet den Download der ZIP-Datei
  private func downloadZip(from feedResponse: FeedResponse) {
    guard let feed = feedResponse.data.feedRequest.feeds.first,
          let gqlIssue = feed.gqlIssues?.first else {
      fetchCompletionHandler?(.failed)
      return
    }
    //URL: https://testdl.taz.de/appGraphQl/content.taz.39413.zip?????
    let zipUrlString = gqlIssue.baseUrl
    guard let zipUrl = URL(string: zipUrlString),
          let zipName = gqlIssue.zipName else {
      fetchCompletionHandler?(.failed)
      return
    }

    let sourceURL = zipUrl.appendingPathComponent(zipName)
    
    var request = URLRequest(url: sourceURL)
    request.setValue(authKey, forHTTPHeaderField: "X-tazAppAuthKey")
    
    let downloadTask = backgroundSession.downloadTask(with: request)
    downloadTask.resume()
  }
  
  // Delegate-Methode, die aufgerufen wird, wenn der Download abgeschlossen ist
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let zipName = downloadTask.originalRequest?.url?.lastPathComponent else {
      fetchCompletionHandler?(.failed)
      return
    }
    log("File: \(zipName)")
    log("Downloaded \(downloadTask.originalRequest?.url?.absoluteString ?? "")")
    let destinationDir = Dir.backgroundDownloads
    if !destinationDir.exists { destinationDir.create()  }
    
    let destinationURL = destinationDir.url.appendingPathComponent(zipName)
    log("Dest Url: \(destinationURL.path)")

    let dowloadedTempFile = File(location)
    dowloadedTempFile.move(to: destinationURL.path, isOverwrite: true)
    log("Download abgeschlossen, Datei gespeichert unter: \(destinationURL.path)")
    unzipAndMoveToTargetDir(zipSource: destinationURL)
  }
  
  func unzipAndMoveToTargetDir(zipSource: URL){
    guard let destinationDir = latestIssueResponse?.issueTargetDir else {
      log("failed, no current issue response")
      fetchCompletionHandler?(.failed)
      return
    }
    
    
    do {
      let zfile = ZipFile(path: zipSource.path)
      try zfile.unpack(toDir: destinationDir.path)
      fetchCompletionHandler?(.newData)
    } catch {
      log("Fehler beim Entpacken der Datei: \(error.localizedDescription)")
      fetchCompletionHandler?(.failed)
    }
    
  }
  
  func unzipTest(){

  }
  
  
  // Delegate-Methode, die den Fortschritt des Downloads überwacht
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset offset: Int64, expectedTotalBytes: Int64) {
    let progress = Float(offset) / Float(expectedTotalBytes)
    log("Download fortgesetzt, Fortschritt: \(progress * 100)%")
  }
  
  // Delegate-Methode, die aufgerufen wird, wenn der Download aufgrund eines Fehlers abgebrochen wird
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error as NSError?, error.code == NSURLErrorCancelled {
      // Falls der Download abgebrochen wurde, speichere die `resumeData`
      if let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
        // Speichern der `resumeData` für späteres Fortsetzen
        UserDefaults.standard.set(resumeData, forKey: "downloadResumeData")
      }
    }
  }
  
  // Methode, um einen abgebrochenen Download fortzusetzen
  func resumeDownload() {
    if let resumeData = UserDefaults.standard.data(forKey: "downloadResumeData") {
      let downloadTask = backgroundSession.downloadTask(withResumeData: resumeData)
      downloadTask.resume()
    }
  }
}


class ZipDownloader2: NSObject, URLSessionDownloadDelegate, DoesLog {
  
  private var backgroundSession: URLSession!
  
  private override init() {
    super.init()
    
    // Hintergrund-Session-Konfiguration
    let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "de.taz.downloadSession")
    backgroundConfig.isDiscretionary = true  // iOS darf die Download-Ressourcen verwalten
    backgroundConfig.sessionSendsLaunchEvents = true  // Startet die App bei einer Push Notification
    
    // Erstelle die Hintergrund-URLSession mit einem Delegate
    self.backgroundSession = URLSession(configuration: backgroundConfig, delegate: self, delegateQueue: nil)
  }
  
  // Startet den Download der ZIP-Datei
  private func downloadZip(sourceURL:URL, authKey: String) {
    var request = URLRequest(url: sourceURL)
    request.setValue(authKey, forHTTPHeaderField: "X-tazAppAuthKey")
    let downloadTask = backgroundSession.downloadTask(with: request)
    downloadTask.resume()
  }
  
  // Delegate-Methode, die aufgerufen wird, wenn der Download abgeschlossen ist
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let zipName = downloadTask.originalRequest?.url?.lastPathComponent else {
//      fetchCompletionHandler?(.failed)
      return
    }
    log("File: \(zipName)")
    log("Downloaded \(downloadTask.originalRequest?.url?.absoluteString ?? "")")
    let destinationDir = Dir.backgroundDownloads
    if !destinationDir.exists { destinationDir.create()  }
    
    let destinationURL = destinationDir.url.appendingPathComponent(zipName)
    log("Dest Url: \(destinationURL.path)")

    let dowloadedTempFile = File(location)
    dowloadedTempFile.move(to: destinationURL.path, isOverwrite: true)
    log("Download abgeschlossen, Datei gespeichert unter: \(destinationURL.path)")
//    unzipAndMoveToTargetDir(zipSource: destinationURL)
  }
  
  
  // Delegate-Methode, die den Fortschritt des Downloads überwacht
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset offset: Int64, expectedTotalBytes: Int64) {
    let progress = Float(offset) / Float(expectedTotalBytes)
    log("Download fortgesetzt, Fortschritt: \(progress * 100)%")
  }
  
  // Delegate-Methode, die aufgerufen wird, wenn der Download aufgrund eines Fehlers abgebrochen wird
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error as NSError?, error.code == NSURLErrorCancelled {
      // Falls der Download abgebrochen wurde, speichere die `resumeData`
      if let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
        // Speichern der `resumeData` für späteres Fortsetzen
        UserDefaults.standard.set(resumeData, forKey: "downloadResumeData")
      }
    }
  }
  
  // Methode, um einen abgebrochenen Download fortzusetzen
  func resumeDownload() {
    if let resumeData = UserDefaults.standard.data(forKey: "downloadResumeData") {
      let downloadTask = backgroundSession.downloadTask(withResumeData: resumeData)
      downloadTask.resume()
    }
  }
}

#warning("JUST A COLLECTION OF STUFF")
///on App Start the json must be persisted to the db
class BGDowerloadPersist {
  func checkAppState() {
    let state = UIApplication.shared.applicationState
    switch state {
      case .active:
        print("📱 App läuft im VORDERGRUND")
      case .background:
        print("🌙 App läuft im HINTERGRUND")
      case .inactive:
        print("⚠️ App ist INAKTIV (Übergang zwischen States)")
      @unknown default:
        print("❓ Unbekannter App-Status")
    }
  }
}





extension XGqlFeeder {
  
   /// Download complete Payload of Issue
   func downloadCompleteIssue(issue: StoredIssue, isAutomatically: Bool) async {
   do {
   let (dlId, tstart) = try await markStartDownload(feed: issue.feed, issue: issue, isAutomatically: isAutomatically)
   issue.isDownloading = true
   
   try await dloader.downloadPayload(payload: issue.payload as! StoredPayload) { bytesLoaded, totalBytes in
   Notification.send("issueProgress", content: (bytesLoaded, totalBytes), sender: issue)
   }
   
   issue.isDownloading = false
   issue.isComplete = true
   ArticleDB.save()
   didDownload(issue)
   Notification.send("issueProgress", content: (Int64(1), Int64(1)), sender: issue)
   await markStopDownload(dlId: dlId, tstart: tstart)
   Notification.send("issue", result: .success(issue), sender: issue)
   } catch {
   issue.isDownloading = false
   await markStopDownload(dlId: nil, tstart: UsTime.now)
   //            Notification.send("issue", result: .failure(error), sender: issue)
   }
   }
   
   public func getCompleteIssue(issue: StoredIssue, isPages: Bool = false, isAutomatically: Bool, force: Bool = false, withAudio: Bool = false) async {
   if issue.isBookmarkIssue || issue.safeDate == nil { return }
   //        self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated) issueDate: \(issue.date.short)")
   
   if issue.isDownloading {
   await Notification.await(for: "issue", from: issue)
   await getCompleteIssue(issue: issue, isPages: isPages, isAutomatically: isAutomatically, force: force, withAudio: withAudio)
   return
   }
   
   if !force && !needsUpdate(issue: issue, toShowPdf: isPages || autoloadPdf) {
   Notification.send("issue", result: .success(issue), sender: issue)
   return
   }
   
   
   do {
   let issues = try await gqlFeeder.issues(feed: issue.feed, date: issue.date, key: issue.key, count: 1, isPages: isPages, withAudio: withAudio)
   guard let dissue = issues.first else { throw DownloadError(message: "Unexpected Behaviour", handled: false) }
   issue.update(from: dissue)
   issue.isAudioComplete = withAudio
   await Notification.wait(for: "resourcesReady")
   Notification.send("issueStructure", result: .success(issue), sender: issue)
   await downloadIssue(issue: issue, isComplete: true, isAutomatically: isAutomatically)
   } catch {
   Notification.send("issueStructure", result: .failure(error), sender: issue)
   }
   }
   
   func markStartDownload(feed: Feed, issue: Issue, isAutomatically: Bool) async throws -> (String?, UsTime) {
   debug("Sending start of download to server")
   let dlId = try await gqlFeeder.startDownload(feed: feed, issue: issue, isPush: isAutomatically, pushToken: Defaults.lastKnownPushToken, isAutomatically: isAutomatically)
   return (dlId, UsTime.now)
   }
   
   
   func markStopDownload(dlId: String?, tstart: UsTime) async {
   guard let dlId else { return }
   let nsec = UsTime.now.timeInterval - tstart.timeInterval
   debug("Sending stop of download to server")
   await gqlFeeder.stopDownload(dlId: dlId, seconds: nsec)
   cleanupOldIssues()
   }
   
   func didDownload(_ issue: Issue) {
   guard issue.date == defaultFeed.lastIssue, let momentPublicationDate = issue.moment.files.first?.moTime else { return }
   NotificationBusiness.sharedInstance.showPopupIfNeeded(newIssueAvailableSince: -momentPublicationDate.timeIntervalSinceNow)
   }
   
   private func downloadIssue(issue: StoredIssue, isComplete: Bool = false, isAutomatically: Bool) async {
   self.debug("isConnected: \(isConnected) isAuth: \(isAuthenticated) isComplete: \(isComplete) issueDate: \(issue.date.short)")
   await Notification.wait(for: "resourcesReady")
   dloader.createIssueDir(issue: issue)
   
   if isConnected {
   if isComplete { await downloadCompleteIssue(issue: issue, isAutomatically: isAutomatically) }
   else { await downloadPartialIssue(issue: issue) }
   } else {
   OfflineAlert.show(type: .issueDownload)
   }
   }
}
