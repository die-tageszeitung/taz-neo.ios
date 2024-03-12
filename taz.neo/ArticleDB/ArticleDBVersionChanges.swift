//
//  ArticleDBVersionChanges.swift
//  taz.neo
//
//  Created by Norbert Thies on 13.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import CoreData
import NorthLib

/// This ArcticleDB extension provides methods to merge different database 
/// model versions in addition to Core Data's automatic lightweight migration.
public extension ArticleDB {
  
  private func initializeDB() {
    // currently nothing to do
  }
  
  private func merge1to2() {
    for feeder in StoredFeeder.all() {
      for feed in StoredFeed.feedsOfFeeder(feeder: feeder) {
        for issue in StoredIssue.issuesInFeed(feed: feed) {
          // Add Issue to imprint.issues
          if let art = issue.imprint as? StoredArticle {
            art.pr.addToIssues(issue.pr)
            art.pr.issueImprint = issue.pr
          }
          // Add Issue to Article.issues
          for section in StoredSection.sectionsInIssue(issue: issue) {
            for art in StoredArticle.articlesInSection(section: section) {
              art.pr.addToIssues(issue.pr)
              art.pr.issueImprint = issue.pr
            }
          }
        }
      }
    }
  }
  private func merge2to3() {
    for feeder in StoredFeeder.all() {
      for feed in StoredFeed.feedsOfFeeder(feeder: feeder) {
        for issue in StoredIssue.issuesInFeed(feed: feed) {
          issue.needUpdateAudio = true
        }
      } 
    }
  }
  
  /// Merge different model versions (after auto migration)
  func mergeVersions() {
    if oldModelVersion == 0 { initializeDB() }
    if oldModelVersion < 2 && newModelVersion >= 2 { merge1to2() }
    if oldModelVersion < 3 && newModelVersion >= 3 { merge2to3() }
    ///For future migrations ... In case of audio => audioEntry do manual sheme migration THIS IS NOT HERE
  }
  
}
