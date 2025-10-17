//
//  Bookmarks+Helper.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

// MARK: - Bookmarks Helper
extension Bookmarks {
  func commonIssueDir(for issueDate: Date) -> Dir? {
    guard let feeder = feederContext?.storedFeeder,
    let feed = bookmarkIssue?.feed else { return nil }
    return feeder.issueDir(feed: feed.name, issue: feeder.date2a(issueDate))
  }
  
  func commonIssueDir(fromSearchArticle searchArticle: SearchArticle) -> Dir? {
    guard let issueDate = searchArticle.originalIssueDate else { return nil }
    return commonIssueDir(for: issueDate)
  }
 
}

// MARK: - Bookmarks Static Helper
extension Bookmarks {
  /// Downloads all audio files for a list of articles.
  static func downloadAllAudio(dlContent: [Article]) {
    guard let context = shared.feederContext else { return }
    var filesCount = dlContent.count
    var errorCount = 0
    Toast.show("Lade Audiodateien für \(filesCount) Artikel herunter...")
    for article in dlContent {
      guard let baseUrl = article.baseURL,
            let audioFile = article.audioItem?.file else { continue }
      
      context.dloader.downloadSearchHitFiles(
        files: [audioFile],
        baseUrl: baseUrl,
        targetDir: article.dir
      ) { error in
        if let error = error {
          shared.log("Error downloading \(audioFile.fileName): \(error)")
          errorCount += 1
        }
        filesCount -= 1
        if filesCount == 0 {
          let msg = errorCount == 0
          ? "Audio-Download abgeschlossen."
          : "\(errorCount) Audiodatei\(errorCount == 1 ? "":"en") konnte\(errorCount == 1 ? "":"n") nicht heruntergeladen werden."
          Toast.show(msg)
        }
      }
    }
  }
  
  /// Retrieves a low-resolution moment image for the article, if available.
  /// even if article is not in related issue
  static func lowresMomentImage(for article:Article?) -> UIImage? {
    guard let article = article,
          let issueDate = article.issueDate,
          let feed = Self.shared.bookmarkIssue?.feed as? StoredFeed,
          let issue = StoredIssue.get(date: issueDate, inFeed: feed).first,
          let image = issue.moment.lowres
    else { return nil }
   return UIImage(contentsOfFile: "\(issue.dir.path)/\(image.name)")
  }
}

