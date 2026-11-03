//
//  TazAppEnvironmen+UniversalLinks.swift
//  taz.neo
//
//  Created by Ringo Müller on 19.10.26.
//  Copyright © 2026 taz. All rights reserved.
//

import NorthLib
import Foundation

struct UniversalLinkOpenIssueData {
    let issueDate: Date
    let articleCID: Int64?
    let pageID: String?
    let sectionCID: Int64?

    init(issueDate: Date, articleCID: Int64? = nil, pageID: String? = nil, sectionCID: Int64? = nil) {
        self.issueDate = issueDate
        self.articleCID = articleCID
        self.pageID = pageID
        self.sectionCID = sectionCID
    }
}

extension TazAppEnvironment {
  
  func receiveUniversalLink(_ url: URL) {
    guard let destination = AppLinkParser.parse(url) else {
      log("TazAppEnvironment.receiveUniversalLink: cannot parse universal link: \(url)")
      return
    }
    
    if TazAppEnvironment.sharedInstance.feederContext?.masterFeed != nil {
      log("TazAppEnvironment.receiveUniversalLink parsed universal link: \(url)")
      navigate(to: destination)
      return
    }
    
    log("TazAppEnvironment.receiveUniversalLink parsed universal link: \(url), waiting for feederReady")
    
    Notification.receiveOnce("feederReady") { [weak self] _ in
      onMainAfter {
        self?.navigate(to: destination)
      }
    }
  }
  
  private func navigate(to destination: AppLinkDestination) {
    
    switch destination {
      case let .home(date):
        log("UniversalLink.navigate: home, date: \(date?.short ?? "-")")
        Notification.send(Const.NotificationNames.gotoIssue, content: date, sender: self)
      case let .issue(date):
        guard let date = date else {
          Notification.send(Const.NotificationNames.gotoIssue, content: nil, sender: self)
          return
        }
        log("UniversalLink.navigate: issue, date: \(date.short)")
        let data = UniversalLinkOpenIssueData(issueDate: date)
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
      case let .section(date, sectionCID):
        log("UniversalLink.navigate issue: \(date.short) section \(sectionCID ?? -1)")
        let data = UniversalLinkOpenIssueData(issueDate: date, sectionCID: sectionCID)
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
        
      case let .article(date, artCID):
        log("UniversalLink.navigate issue: \(date.short) art \(artCID ?? -1)")
        let data = UniversalLinkOpenIssueData(issueDate: date, articleCID: artCID)
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
        
      case let .page(date, pageID):
        log("UniversalLink.navigate issue: \(date.short) page \(pageID ?? "-")")
        let data = UniversalLinkOpenIssueData(issueDate: date, pageID: pageID)
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
      case .search:
        log("UniversalLink.navigate: search")
        Notification.send(Const.NotificationNames.gotoTabByIndex, content: 2)
      case .bookmarks:
        log("UniversalLink.navigate: bookmarks")
        Notification.send(Const.NotificationNames.gotoTabByIndex, content: 1)
    }
  }
}


enum AppLinkDestination {
  case home(date: Date?)                   // Without date: current issue
  case search
  case bookmarks
  case issue(date: Date?)                   // Without date: current issue
  case section(date: Date, sectionCID: Int64?)  // Without sectId: title section / first section
  case article(date: Date, articleCID: Int64?)  // Without artId: first article
  case page(date: Date, pageID: String?)   // Without pageId: first page
}


enum AppLinkParser {
  
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    return formatter
  }()
  
  static func parse(_ url: URL) -> AppLinkDestination? {
    
    guard url.scheme?.lowercased() == "https",
          url.host?.lowercased() == "epaper.taz.de"
    else {
      return fail("invalid scheme or host")
    }
    
    let parts = url.path
      .split(separator: "/")
      .map(String.init)
    
    // 1. Search tab
    // /search
    if parts == ["search"] {
      return .search
    }
    
    // 2. Bookmarks tab
    // /bookmarks
    if parts == ["bookmarks"] {
      return .bookmarks
    }
    
    // 3. Home, maybe with issue date
    // /home/2024-11-02
    if parts[0] == "home" {
      return .home(date: date(from: parts.valueAt(1)))
    }
    
    // All remaining links require a date as first component
    guard let dateString = parts.first,
          let date = date(from: dateString)
    else {
      return fail("invalid date or unknown pattern")
    }
    
    // 4. Issue
    // /2024-11-02
    if parts.count == 1 { return .issue(date: date) }
    
    // 5. Section
    // /2024-11-02/section.339235
    if parts.count == 2,
       let sectionCID = numericSuffix(of: parts[1], prefix: "section.") {
      return .section(date: date, sectionCID: sectionCID)
    }
    
    // 6. Page with server ID
    // /2024-11-02/page/s00941365
    if parts.count == 3, parts[1] == "page" {
      let pageID = parts[2]
      
      guard pageID.count > 1,
            pageID.first == "s",
            pageID.dropFirst().allSatisfy(\.isNumber)
      else {
        return .page(date: date, pageID: nil)
      }
      
      return .page(date: date, pageID: pageID)
    }
    
    // 7. Article
    // /2024-11-02/art04008786
    // This is the article ID, NOT the MediaSyncID/MSID.
    if parts.count == 2,
       let articleCID = numericSuffix(of: parts[1], prefix: "art") {
      return .article(date: date, articleCID: articleCID)
    }
    
    return fail("unknown path pattern")
  }
  
  
  // MARK: - Helpers
  
  private static func numericSuffix(
    of value: String,
    prefix: String
  ) -> Int64? {
    
    guard value.hasPrefix(prefix) else { return nil }
    
    let suffix = value.dropFirst(prefix.count)
    
    guard !suffix.isEmpty,
          suffix.allSatisfy(\.isNumber)
    else {
      return nil
    }
    
    return Int64(suffix)
  }
  
  private static func date(from dateString: String?) -> Date? {
    
    guard let dateString else { return nil }
    
    let pattern = #"^\d{4}-\d{2}-\d{2}$"#
    
    guard dateString.range(
      of: pattern,
      options: .regularExpression
    ) != nil else {
      return failDate(dateString, reason: "unexpected format")
    }
    
    guard let date = dateFormatter.date(from: dateString) else {
      return failDate(dateString, reason: "invalid date")
    }
    
    // Reject dates that DateFormatter might normalize.
    guard dateFormatter.string(from: date) == dateString else {
      return failDate(dateString, reason: "date mismatch")
    }
    
    return date
  }
  
  
  private static func failDate(
    _ value: String,
    reason: String
  ) -> Date? {
    Log.log("AppLinkParser.date: \(reason): \(value)")
    return nil
  }
  
  
  private static func fail(_ reason: String) -> AppLinkDestination? {
    Log.log("AppLinkParser.parse: Parse failed: \(reason)")
    return nil
  }
}
