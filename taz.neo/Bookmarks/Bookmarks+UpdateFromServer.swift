//
//  Bookmarks+UpdateFromServer.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

extension Bookmarks {
  func loadFullArticlesIfNeeded(){
    guard TazAppEnvironment.hasValidAuth else {
      log("no valid auth, skip loading")
      return
    }
    
    /// workflow: load article data, update "demo" article entity (including: onlineLink, Authors, files (content+images)...
    /// download files
    let reducedArticles = bookmarkedArticles.filter { $0.isReducedArticle }
    
    if reducedArticles.count == 0 { return }
    
    Bookmarks.shared.feederContext?.gqlFeeder.loadArticles(reducedArticles, finished:{[weak self] res in
      guard let self = self else { return }
      if let err = res.error() as? FeederError {
        self.handleDownloadError(error: err)
      } else if let err = res.error() as? URLError {
        self.debug("failed to load \(err)")///offline
      } else if let err = res.error(){
        self.debug("failed to load \(err)")///unknown
      }
      if let arts = res.value() {
        self.update(bookmarkedArticles: reducedArticles, with: arts)
      }
    })
  }
  
  private func update(bookmarkedArticles: [StoredArticle], with articles: [GqlSingleArticle]) {
    debug("try to update \(bookmarkedArticles.count)")
    // Iterate through the list of GqlSingleArticles
    for articleWrapper in articles {
      // Extract the serverId from the current GqlSingleArticle
      guard let gqlServerId = articleWrapper.gqlArticle.serverId else {
        continue // Skip if the serverId is nil
      }
      
      // Find the matching StoredArticle based on the serverId
      guard let storedArticle
              = bookmarkedArticles.first(where: { $0.serverId == gqlServerId }) else {
        continue
      }
      // Call the update method to sync the StoredArticle with the GqlSingleArticle
      storedArticle.update(from: articleWrapper.gqlArticle)
      storedArticle.baseURL = articleWrapper.baseUrl
      
      ///2 options: either write file OR download file(s)
      guard let issueDate = storedArticle.issueDate,
            let targetDir = commonIssueDir(for: issueDate) else { continue }
      
      let subdir = String(targetDir.path.dropFirst(Database.appDir.count + 1))
      for case let f as StoredFileEntry in storedArticle.files {
        f.subdir = subdir
      }
      
      /// Warning: do not use storedArticle.baseURL! It is still the old, due getter uses: article.pr.baseURL
      feederContext?.dloader.downloadSearchHitFiles(files: storedArticle.files,
                                                    baseUrl: articleWrapper.baseUrl,
                                                    targetDir: targetDir,
                                                    closure: { err in
        if let err = err { self.log("download of article files for: \(String(describing: storedArticle.title)) finished with err: \(err)") }
      })
    }
    ArticleDB.save()
  }
}

