//
//  TazAppEnvironmen+UniversalLinks.swift
//  taz.neo
//
//  Created by Ringo Müller on 19.10.26.
//  Copyright © 2026 taz. All rights reserved.
//

import NorthLib
import Foundation
import LinkPresentation

struct UniversalLinkOpenIssueData {
    let originalUrl: URL
    let issueDate: Date
    let articleCID: Int64?
    let pageID: String?
    let sectionCID: Int64?

  var hasTargetInIssue: Bool {
    return articleCID != nil || sectionCID != nil || pageID != nil
  }
  
  init(issueDate: Date, articleCID: Int64? = nil, pageID: String? = nil, sectionCID: Int64? = nil, originalUrl: URL) {
        self.issueDate = issueDate
        self.articleCID = articleCID
        self.pageID = pageID
        self.sectionCID = sectionCID
        self.originalUrl = originalUrl
    }
}

extension TazAppEnvironment {
  
  func requestOpenLinkInBrowser(for url: URL, contentNotFound: Bool) {
    guard invalidUniversalLinkOpenPopup == false else { return }
    invalidUniversalLinkOpenPopup = true
    let openInBrowser =  UIAlertAction.init( title: "Im Browser öffnen",
                                             style: .default) {[weak self] _ in
      UIApplication.shared.open(url)
      self?.invalidUniversalLinkOpenPopup = false
    }
    let cancelAction =  UIAlertAction.init( title: "Abbrechen",
                                            style: .cancel){[weak self] _ in
      self?.invalidUniversalLinkOpenPopup = false
    }
    
    let actions = [openInBrowser, cancelAction]
    let message = contentNotFound
    ? "Der Link kann in der App leider nicht geöffnet werden.\nMöglicherweise ist der Link ungültig oder der angeforderte Inhalt nicht mehr verfügbar.\nMöchten Sie den Link stattdessen im Browser öffnen?"
    : "Der Link kann in der App leider nicht geöffnet werden.\nMöchten Sie den Link stattdessen im Browser öffnen?"
    Alert.message(message: message, actions: actions)
  }
  
  func receiveUniversalLink(_ url: URL) {
    guard let destination = AppLinkParser.parse(url) else {
      log("TazAppEnvironment.receiveUniversalLink: cannot parse universal link: \(url)")
      requestOpenLinkInBrowser(for: url, contentNotFound: false)
      return
    }
    
    if TazAppEnvironment.sharedInstance.feederContext?.masterFeed != nil {
      log("TazAppEnvironment.receiveUniversalLink parsed universal link: \(url)")
      navigate(to: destination, originalUrl: url)
      return
    }
    
    log("TazAppEnvironment.receiveUniversalLink parsed universal link: \(url), waiting for feederReady")
    
    Notification.receiveOnce("feederReady") { [weak self] _ in
      onMainAfter {
        self?.navigate(to: destination, originalUrl: url)
      }
    }
  }
  
  private func navigate(to destination: AppLinkDestination, originalUrl: URL) {
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
        let data = UniversalLinkOpenIssueData(issueDate: date, originalUrl: originalUrl)
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
      case let .section(date, sectionCID):
        log("UniversalLink.navigate issue: \(date.short) section \(sectionCID ?? -1)")
        let data = UniversalLinkOpenIssueData(issueDate: date, sectionCID: sectionCID, originalUrl: originalUrl)
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
      case let .article(date, artCID):
        log("UniversalLink.navigate issue: \(date.short) art \(artCID ?? -1)")
        let data = UniversalLinkOpenIssueData(issueDate: date, articleCID: artCID, originalUrl: originalUrl)
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
      case let .page(date, pageID):
        log("UniversalLink.navigate issue: \(date.short) page \(pageID ?? "-")")
        let data = UniversalLinkOpenIssueData(issueDate: date, pageID: pageID, originalUrl: originalUrl)
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
    if parts == ["search"] { return .search }

    // 2. Bookmarks tab
    // /bookmarks
    if parts == ["bookmarks"] { return .bookmarks }

    // 3. Home, optionally with issue date
    // /home
    // /home/2026-11-02
    if parts.first == "home" { return .home(date: date(from: parts.valueAt(1))) }

    // 4. Issue
    // /issue/2026-11-02
    // /issue/2026-11-02/section.339235
    // /issue/2026-11-02/art04008786
    guard parts.count == 2 || parts.count == 3,
          parts[0] == "issue",
          let date = date(from: parts[1])
    else {
      return fail("invalid issue path")
    }

    // No additional parameter: cover/page1 / title section
    guard parts.count == 3 else {
      return .issue(date: date)
    }

    let identifier = parts[2]

    // Section
    if let sectionCID = numericSuffix(of: identifier, prefix: "section.") {
      return .section(date: date, sectionCID: sectionCID)
    }

    // Article
    if let articleCID = numericSuffix(of: identifier, prefix: "art") {
      return .article(date: date, articleCID: articleCID)
    }

    return fail("unknown issue identifier")
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
