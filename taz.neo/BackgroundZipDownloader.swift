//
//  BackgroundZipDownloader.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.02.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib


class BackgroundZipDownloader: NSObject, URLSessionDownloadDelegate, DoesLog {
  private var continuation: CheckedContinuation<URL, Error>?
  private var targetURL: URL?
  
  lazy var backgroundSession: URLSession = {
    //    let config = URLSessionConfiguration.background(withIdentifier: "de.taz.background.downloadSession")
    let config = URLSessionConfiguration.default
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()
  
  func downloadZip(sourceURL: URL, authKey: String, targetDir: Dir) async throws -> URL {
    if targetDir.exists == false { targetDir.create() }
    targetURL = targetDir.url.appendingPathComponent(sourceURL.lastPathComponent)
    
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      
      var request = URLRequest(url: sourceURL)
      request.setValue(authKey, forHTTPHeaderField: "X-tazAppAuthKey")
      
      let downloadTask = backgroundSession.downloadTask(with: request)
      downloadTask.resume()
    }
  }
  
  // URLSessionDownloadDelegate-Methode, wenn der Download abgeschlossen ist
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    
    if FileManager.default.fileExists(atPath: location.path) == false {
      continuation?.resume(throwing: BackgroundDownloadError("Target file not found: ", location.path))
      log("Target file not found: \(location.path)")
      continuation = nil
      return
    }
    
    guard let targetURL = targetURL else {
      continuation?.resume(throwing: BackgroundDownloadError("Target URL not set"))
      continuation = nil
      return
    }
    let dowloadedTempFile = File(location)
    dowloadedTempFile.move(to: targetURL.path, isOverwrite: true)
    continuation?.resume(returning: targetURL)
    continuation = nil
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    debug("error: \(error?.localizedDescription ?? "no error")")
    if let error = error {
      continuation?.resume(throwing: error)
    }
    continuation = nil
  }
}


import Foundation

protocol IssueDownloaderDelegate: AnyObject {
  func didFinishAllDownloads(error: Error?)
}

class IssueDownloader: NSObject, URLSessionDownloadDelegate {
  
  private var session: URLSession!
  private var downloadQueue: [URL] = []
  private var currentTask: URLSessionDownloadTask?
  weak var delegate: IssueDownloaderDelegate?
  private var targetDir: Dir?
  private var error:Error?
  private var authKey: String
  
  init(authKey: String, isBackground: Bool) {
    self.authKey = authKey
    super.init()
    let config
    = isBackground
    ?  URLSessionConfiguration.background(withIdentifier: "de.taz.background.downloadSession")
    : URLSessionConfiguration.default
    session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }
  
  func download(files: [URL], toDir: Dir) {
    guard !files.isEmpty else { return }
    targetDir = toDir
    downloadQueue = files
    startNextDownload()
  }
  
  private func startNextDownload() {
    if error != nil  || downloadQueue.isEmpty {
      self.delegate?.didFinishAllDownloads(error: error)
      return
    }
    let nextFile = downloadQueue.removeFirst()
    
    var request = URLRequest(url: nextFile)
    request.setValue(authKey, forHTTPHeaderField: "X-tazAppAuthKey")
    
    currentTask = session.downloadTask(with: request)
    currentTask?.resume()
  }
    
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    let file = File(location)

    if (downloadTask.originalRequest?.url?.lastPathComponent.hasSuffix(".zip")) == true,
        let targetDir = targetDir {
      let zfile = ZipFile(path: location.path)
      do {
        try zfile.unpack(toDir: targetDir.path)
      } catch {
        self.error = error
      }
    }
    else if file.exists, let targetDir = targetDir {
      file.move(to: targetDir.path, isOverwrite: true)
    }
    startNextDownload()
  }
}
