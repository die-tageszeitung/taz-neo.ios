//
//  TazAppEnvironmen+UniversalLinks.swift
//  taz.neo
//
//  Created by Ringo Müller on 19.10.26.
//  Copyright © 2026 taz. All rights reserved.
//

import NorthLib
import Foundation

extension TazAppEnvironment {
  
  func receiveUniversalLink(_ url: URL) {
    guard let destination = AppLinkParser.parse(url) else {
      log("TazAppEnvironment.receiveUniversalLink: cannot parse valid universallink with: \(url)")
      return
    }

    if TazAppEnvironment.sharedInstance.feederContext?.masterFeed != nil {
      log("TazAppEnvironment.receiveUniversalLink parsed universallink with: \(url)")
      navigate(to: destination)
      return
    }
    log("TazAppEnvironment.receiveUniversalLink parsed universallink with: \(url), waiting for feederReady")
    Notification.receiveOnce("feederReady") { _ in
      onMainAfter { [weak self] in self?.navigate(to: destination)}
    }
  }
  
  private func navigate(to destination: AppLinkDestination) {
    switch destination {
      case .home:
        log("TazAppEnvironment.receiveUniversalLink.navigate: to home")
        let data = PushNotification.Payload.ArticlePushData(nil, nil, nil ,nil, [:])
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
        ///maybe switch tab and pop to rrot
      case let .issue(date):
        log("TazAppEnvironment.receiveUniversalLink.navigate: to issue with date: \(date)")
        let data = PushNotification.Payload.ArticlePushData(nil, nil, nil ,date, [:])
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
      case let .section(date, _):
      log("TazAppEnvironment.receiveUniversalLink.navigate: to issue with date: \(date?.short ?? "-")")
        let data = PushNotification.Payload.ArticlePushData(nil, nil, nil ,date, [:])
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
      case let .article(msid, date, _):
        log("TazAppEnvironment.receiveUniversalLink.navigate: to art: \(msid) in issue with date: \(date?.short ?? "-")")
        let data = PushNotification.Payload.ArticlePushData(msid, nil, nil ,date, [:])
        Notification.send(Const.NotificationNames.gotoArticleInIssue, content: data, sender: self)
    }
  }
}

enum AppLinkDestination {
  case home
  case issue(date: Date)
  case section(date: Date?, id: Int64?)
  case article(
    id: Int64,
    date: Date?,
    sectionID: Int64?
  )
}

enum AppLinkParser {
  
  static func parse(_ url: URL) -> AppLinkDestination? {
    ///All Domains or just given domains?
    guard url.scheme?.lowercased() == "https",
          url.host?.lowercased() == "epaper.taz.de",
          let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
          )
    else { return nil }
    
    let path = components.path
    let parts = path
      .split(separator: "/")
      .map(String.init)
    
    let query = Dictionary(
      components.queryItems?.map {
        ($0.name, $0.value ?? "")
      } ?? [],
      uniquingKeysWith: { first, _ in first }
    )
    
    // ID's and date from path or query
    let queryDate:Date?
    let querySection:Int64?
    let queryArticleMsid:Int64?
    if let val = query["date"] { queryDate = date(from: val) } else { queryDate = nil }
    if let val = query["section"] { querySection = Int64(val) } else { querySection = nil }
    if let val = query["art"] { queryArticleMsid = Int64(val) } else { queryArticleMsid = nil }
    
    // 1. article link: /article/400171
    if parts.count == 2, parts[0] == "article" {
      let val =  parts[1]
      if !val.isEmpty, val.allSatisfy(\.isNumber), let artMsid:Int64 = Int64(val) {
        return article(artMsid, date: queryDate, section: querySection)
      }
      else { Log.log("AppLinkParser.parse: Parse failed: invalid article"); return nil }
    }
    
    // 2. article-ID from query, e.g. /?art=400171
    if let articleMsid = queryArticleMsid {
      return article(
        articleMsid,
        date: queryDate,
        section: querySection
      )
    }
    
    // 3. date and optional path parts
    let date: Date? = date(from: parts.first) ?? queryDate
   
    // 4. title-section.
    if parts.count == 1, parts[0] == "section" {
      return .section(date: queryDate, id: nil)
    }
    
    // 5. title-page
    if parts.count == 1, parts[0] == "page" {
      guard let date else { Log.log("AppLinkParser.parse: Parse failed: invalid page"); return nil }
      ///maybe missing: open issue in page mode
      return .issue(date: date)
    }
    
    // 6. query-variation /issue?date=...
    if parts.first == "issue" {
      guard let date else{ Log.log("AppLinkParser.parse: Parse failed: invalid issue date"); return nil }
      return .issue(date: date)
    }
    
    // 7. query-variation sect/art: /2026-09-23/section/338491[/400171]
    if let date, parts.count >= 2, parts[1] == "section" {
      if parts.count >= 3, let sectId = Int64(parts[2]) {
        return .section(date: date, id: sectId)
      }
      return .section(date: date, id: nil)
    }
    
    // 8. query-variation with section id
    if let sectionID = querySection {
      return .section(date: date, id: sectionID)
    }
    
    // 9. query page: /2026-09-23/page
    if let date, parts.count == 2, parts[1] == "page" {
      ///maybe missing: open issue in page mode
      return .issue(date: date)
    }
    
    // 10. query /2026-09-23/section without section id
    if let date, parts.count == 2, parts[1] == "section" {
      return .section(date: date, id: nil)
    }
    
    // 11. pure date link open section or page, depends on current pdf mode
    if let date, parts.count == 1 {
      return .issue(date: date)
    }
    
    // 12. domain without params or path, just open app
    if path == "/" && query.isEmpty {
      return .home
    }
    
    // unknown or invalid url
    Log.log("AppLinkParser.parse: Parse failed: unknown pattern")
    return nil
  }
  
  private static func article(
    _ id: Int64,
    date: Date?,
    section: Int64?
  ) -> AppLinkDestination? {
    return .article(
      id: id,
      date: date,
      sectionID: section
    )
  }
  
  private static func date(from dateString: String?) -> Date? {
    guard let dateString else { return nil }
    let pattern = #"^\d{4}-\d{2}-\d{2}$"#
    
    guard dateString.range(
      of: pattern,
      options: .regularExpression
    ) != nil else {
      Log.log("AppLinkParser.date: unexpected date in: \(dateString)")
      return nil
    }
    
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    
    guard let date = formatter.date(from: dateString) else {
      Log.log("AppLinkParser.date: unexpected date format: \(dateString)")
      return nil
    }
    guard formatter.string(from: date) == dateString else {
      Log.log("AppLinkParser.date: unexpected date: \(dateString)")
      return nil
    }
    return date
  }
}
