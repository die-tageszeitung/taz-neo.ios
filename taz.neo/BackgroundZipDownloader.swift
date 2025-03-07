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
