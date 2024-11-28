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
  
  static func downloadAllAudio(dlContent: [Article]){
    guard let fc = Self.shared.feederContext else { return }
    for art in dlContent {
      guard let baseUrl = art.baseURL,
            let audioItem = art.audioItem?.file else { continue }
      fc.dloader.downloadSearchHitFiles(files: [audioItem],
                                        baseUrl: baseUrl,
                                        targetDir: art.dir) { err in
        if let err = err {
          Self.shared.log("dl err \(err) for: \(audioItem.fileName)")
        }
      }
    }
  }
  
  ///get moment image even if article is not in related issue
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

// MARK: - Various Helper
extension Array where Element == StoredArticle {
  func bmSorted() -> Self {
    self.sorted(by: {
      if $0.issueDate?.issueKey != $1.issueDate?.issueKey {
        return $0.issueDate?.ISO8601 ?? "0" > $1.issueDate?.ISO8601 ?? "1"
      }
      
      let section0MinOrder
      = $0.nonBookmarkSections.map { Int($0.pr.order) }.min() ?? Int.max
      let section1MinOrder
      = $1.nonBookmarkSections.map { Int($0.pr.order) }.min() ?? Int.max
      
      if section0MinOrder != section1MinOrder {
        return section0MinOrder < section1MinOrder
      }
      
      return $0.pr.order < $1.pr.order
    })
  }
}

extension UIViewController {
  
  var isActiveAndVisible: Bool {

      // Check if part of a UINavigationController
      if let navCtrl = self.navigationController {
          // If inside a UITabBarController, ensure it's the selected tab
          if let tabCtrl = navCtrl.parent as? UITabBarController {
              return tabCtrl.selectedViewController == navCtrl && navCtrl.visibleViewController == self
          }
          // Otherwise, ensure it's the visible view controller in the navigation stack
          return navCtrl.visibleViewController == self
      }

      // If part of a UITabBarController directly (not embedded in a nav controller)
      if let tabCtrl = self.parent as? UITabBarController {
          return tabCtrl.selectedViewController == self
      }

      // For other cases, check if it’s the root or presented directly
      return self.presentingViewController == nil
  }
}
