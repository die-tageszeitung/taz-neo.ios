//
//  BackgroundDownloadService+Helper.swift
//  taz.neo
//
//  Created by Ringo Müller on 20.05.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// MARK: - Helper Methods TEMP COLLECTION
extension BackgroundDownloadService {
  
  ///send stop to server
  ///in case of missing downloadId, startDate or issueDate do nothing
  ///Fire and forget, if app killed meanwhile, no retry
  func sendDownloadStopAndTrack(for downloadData: DownloadData,
                                with url: String,
                                feederContext: FeederContext?) {
    
    guard let feederContext = feederContext else {
      log("⚠️WARNING:...No FeederContext available, cannot send stop to server")
      return
    }
    
    let downloadStart =  UsTime(downloadData.startTime)
    let nsec = UsTime.now.timeInterval - downloadStart.timeInterval
    feederContext.gqlFeeder.stopDownload(dlId: downloadData.downloadId, seconds: nsec, returnOnMain: false) { [weak self] err in
      guard let self = self else { return }
      self.log("...send stop to server for dlId: \(downloadData.downloadId) with err: \(err) downloadDuration: \(nsec)s")
      Usage.track(Usage.event.issue.autoDownload,
                  name: downloadData.isoDateKey,
                  dimensions: Usage.event.issue.downloadDim(pdf: self.autoloadPdf,
                                                            audio: self.autoloadAudio))
      Usage.dispatch()
    }
  }
  
  func restartDownloadForIssue(with zipUrl: String) {
    ///WARNING TODO ⚠️ entweder verwerfen oder neustarten merke in defaults restarted...kommt das vor, funktioniert dies...verwerfen == userdefaults eintrag entfernen
    ///db eintrag kann bleiben hat dann halt autodownloading== true, aber dieser Indikator ist nicht eindeutig, da ohne db speichern es auch dazu kommen kann
    log("⚠️⚠️ TODO restart Download for: \(zipUrl)")
    //ist es issue/audio/ressourcen
    ///was war der Fehler
    ///habe ich überhaupt daten (in json oder currentIssues?
  }
}

// MARK: - Custom Error Class for BackgroundDownloadService

struct BackgroundDownloadError: Error {
  let message: String
  
  init(_ parts: String...) {
    self.message = parts.joined(separator: " ")
  }
  
  var localizedDescription: String {
    return message
  }
}

// MARK: - Issue Helper extension

public extension Issue {
  /// Full file path for the JSON data, combining the target directory and filename.
  var jsonFile: File {
    File(dir: dir.path,
         fname: BackgroundDownloadService.jsonDataFilename)
  }
  
  var zipUrl: String? {
    guard let zipName = Defaults.autoloadPdf ? zipNamePdf : zipName else { return nil }
    return baseUrl.appending("/\(zipName)")
  }
  
  /// Marks this issue as finished, reset isAutodownloading flag.
  func setAutodownloadCompleete() {
    self.isComplete = true
    self.isAutodownloading = false
  }
}

// MARK: - GqlFeeder Helper extension

extension GqlFeeder {
  func markStartDownloadAsync(feed: Feed, issue: Issue, isAutomatically: Bool, returnOnMain: Bool) async throws -> (String, UsTime) {
    let pushToken = Defaults.lastKnownPushToken
    let isPush = pushToken != nil
    debug("Sending start of download to server")
    
    return try await withCheckedThrowingContinuation { continuation in
      startDownload(feed: feed, issue: issue, isPush: isPush, pushToken: pushToken, isAutomatically: isAutomatically, returnOnMain: returnOnMain) { res in
        switch res {
          case .success(let value):
            continuation.resume(returning: (value, UsTime.now))
          case .failure(let error):
            continuation.resume(throwing: error) // Fehler wird weitergereicht
        }
      }
    }
  }
}
