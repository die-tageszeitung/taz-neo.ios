//
//  BookmarkCoordinator.swift
//  taz.neo
//
//  Created by Norbert Thies on 24.03.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public class BookmarkCoordinator: IssueInfo, DoesLog {
  public var nc: NavigationController
  public var feederContext: FeederContext
  public lazy var bookmarkFeed = BookmarkFeed.allBookmarks(feeder: feeder) 
  public var issue: Issue { bookmarkFeed.issues![0] }
  
  public var sectionVC: SectionVC?
//  public lazy var sectionVC: SectionVC = { 
//    let svc = SectionVC(feederContext: feederContext)
//    svc.delegate = self
//    return svc
//  }()
  
  public func resetIssueList() {}
  
  public init(nc: NavigationController, feederContext: FeederContext) {
    self.nc = nc
    self.feederContext = feederContext
    Notification.receive("BookmarkChanged") { [weak self] msg in
      // regenerate all bookmark sections
      guard let self = self else { return }
      if let art = msg.sender as? StoredArticle {
        self.bookmarkFeed.loadAllBookmmarks()
        self.bookmarkFeed.genAllHtml()
        if art.hasBookmark { 
          self.sectionVC?.insertArticle(art) 
        }
        else { 
          self.sectionVC?.deleteArticle(art) 
        }
        self.sectionVC?.reload()
      }
    }
  }
  
  public func showBookmarks() {
    if nc.topViewController != sectionVC {
      sectionVC = SectionVC(feederContext: feederContext)
      sectionVC?.delegate = self
      nc.pushViewController(sectionVC!, animated: false)
    }
  }
  
} // BookmarkCoordinator
