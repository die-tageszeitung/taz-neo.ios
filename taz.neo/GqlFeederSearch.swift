//
//  GqlFeederSearch.swift
//  taz.neo
//
//  Created by Ringo Müller on 26.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib
import Foundation

public struct SearchSettings: Equatable {
  public var title:String?
  public var author:String?
  public var text:String?
  
  public var filter:GqlSearchFilter = .all
  public var range = SearchRange()
  
//  public var searchLocation:GqlSearchLocation = .everywhere
  public var sorting:GqlSearchSorting = .relevance
  public var from:Date?
  public var to:Date?
  
  public var searchTermTooShort:Bool {
    return text?.isEmpty == true
    && author?.isEmpty == true
    && title?.isEmpty  == true
  }
  
  public var isChanged: Bool {
    get {
      return author?.isEmpty == false
        || title?.isEmpty == false
        || sorting != .relevance
        || filter != .all
        || range.currentOption != .all
    }
  }
  
  static public func ==(lhs: SearchSettings, rhs: SearchSettings) -> Bool {
    return lhs.author == rhs.author
    && lhs.text == rhs.text
    && lhs.title == rhs.title
    && lhs.sorting == rhs.sorting
    && lhs.filter == rhs.filter
    && lhs.range.currentOption == rhs.range.currentOption
    && lhs.from == rhs.from
    && lhs.to == rhs.to
  }
}

public enum GqlSearchFilter: String {
  case all = "all"
  case taz = "taz"
  case LMd = "LMd"
  case Kontext = "Kontext"
  case weekend = "weekend"
  
  public var labelText: String {
    get{
      switch self {
        case .all: return "Überall"
        case .taz: return "taz"
        case .LMd: return "Le Monde diplomatique"
        case .Kontext: return "Kontext"
        case .weekend: return "Wochenendausgaben"
      }
    }
  }

  static let allItems : [GqlSearchFilter] = [.all, .taz, .LMd, .Kontext, .weekend]
}

public enum SearchRangeOption: String {
  case all = "Alles"
  case lastDay = "Letzter Tag"
  case lastWeek = "Letzte Woche"
  case lastMonth = "Letzter Monat"
  case lastYear = "Letztes Jahr"
  case custom = "Zeitraum festlegen"
  
  static let allItems : [SearchRangeOption] = {
  #if LMD
      return [.all, .lastMonth, .lastYear, .custom]
  #else
      return [.all, .lastDay, .lastWeek, .lastMonth, .lastYear, .custom]
  #endif
    }()
  
  var textWithDate: String {
    get {
      if self == .all { return "\(self.rawValue)" }
      return "\(self.rawValue) (\(self.minimumDate?.shorter ?? "") - \(self.maximuDate?.shorter ?? ""))"
    }}
    
  var minimumDate: Date? {
    get {
      let cal = Calendar.current
      switch self {
        case .all:
          return Date(timeIntervalSinceReferenceDate: 0)
        case .lastDay:
          return cal.startOfDay(for: Date(timeIntervalSinceNow: -60*60*24))
        case .lastWeek:
          return cal.startOfDay(for: Date(timeIntervalSinceNow: -7*60*60*24))
        case .lastMonth:
          return Calendar.current.date(byAdding: DateComponents(month: -1),
                                       to: Date())
        case .lastYear:
          return cal.date(
            from: DateComponents(year: cal.component(.year, from: Date()) - 1))
        default:
          return nil
      }
    }
  }
  var maximuDate: Date? { Date().endOfDay }
}

public struct SearchRange {
  var from: Date?
  var to: Date?
  var currentOption: SearchRangeOption = .all
}

/// Sorting of search Result
public enum GqlSearchSorting: String, CodableEnum {
  /// relevance (default)
  case relevance = "relevance"
  /// newest first
  case actuality = "actuality"
  /// oldest first
  case appearance = "appearance"
  
  static let allItems : [GqlSearchSorting] = [.relevance, .actuality, .appearance]
  
  public var labelText: String {
    get{
      switch self {
        case .relevance: return "Relevanz"
        case .appearance: return "Älteste zuerst"
        case .actuality: return "Neueste zuerst"
      }
    }
  }
  
  public var detailDescription: String {
    get{
      switch self {
        case .relevance: return "Relevanteste Ergebnisse werden als erstes angezeigt"
        case .appearance: return "Älteste Veröffentlichungen werden zuerst angezeigt. Das heißt z.B. für die Suche nach Corona, dass die Ergebnisse aus Dezember 2019 oben stehen. Noch mehr Text um einen Umbruch zu simulieren."
        case .actuality: return "Neueste Beiträge werden zuerst angezeigt"
      }
    }
  }
}

public typealias resultCount = (total:Int?, currentCount:Int?)

public class GqlSearchResponse: GQLObject {
  public var total: Int
  public var totalFound: Int
  var authInfo: GqlAuthInfo
  public var searchText: String {
    get {
      return "\(title ?? "noTitle")-\(author ?? "noAuthor")-\(text ?? "noText")"
    }
  }
  public var text: String?
  public var title: String?
  public var author: String?
  public var sessionId: String?
  public var searchHitList: [GqlSearchHit]?
  public func toString() -> String {
    var sid = ""
    if let s = sessionId { sid = "sessionId: \(s)," }
    return "GqlSearchItem{ total:\(total), title: \(title ?? "-"), author: \(author ?? "-"), text: \(text ?? "-") \(sid)searchHitList: \(String(describing: searchHitList))}"
  }
  static var fields = "total, totalFound, text, sessionId, searchHitList { \(GqlSearchHit.fields) }"
}


public class GqlSearchResponseWrapper: GQLObject {
  public var search: GqlSearchResponse
  public func toString() -> String {
    "GqlSearchData{ total:\(search)}"
  }
  static var fields = "search"
}

public class SearchItem: DoesLog {
  
  var articlePrimaryIssue: SearchResultIssue
  public fileprivate(set) var searching: Bool = false
  
  fileprivate static let itemsPerFetch:Int = 20///like API default
  
  public private(set) var noMoreSearchResults = true
  public var sessionId: String?

  public var settings: SearchSettings = SearchSettings() {
    didSet {
      if oldValue != settings {
        reset()
      }
    }
  }
  
  public var resultCount: resultCount {
    get{
      if let total = lastResponse?.search.totalFound,
         let currentCount = searchHitList?.count {
        return (currentCount, total)
      }
      return (nil, nil)
    }
  }
  
  
  public var lastResponse: GqlSearchResponseWrapper? {
    didSet {
      if searchHitList == nil {
        searchHitList = lastResponse?.search.searchHitList
      } else if let last = lastResponse?.search.searchHitList {
        searchHitList?.append(contentsOf: last)
      }
      else {
        self.log("No Data Added!")
      }
      saveArticles(hits: lastResponse?.search.searchHitList)
      noMoreSearchResults 
      = (lastResponse?.search.searchHitList?.count ?? 0) == 0
      || (lastResponse?.search.searchHitList?.count ?? 0) == lastResponse?.search.total
      sessionId = lastResponse?.search.sessionId
    }
  }
  
  
  /// Save Search Hit to its Article HTML File, to use highlightes Search Terms
  /// - Parameter hits: current array of search hits
  func saveArticles(hits:[GqlSearchHit]?){
    guard let hits = hits, hits.count > 0 else { return }
    onThread {
      for hit in hits {
        if let html = hit.articleHtml {
          File(Dir.searchResultsPath.appending("/\(hit.article.articleHtml.name)")).string = html
        }
      }
    }
  }
  
  var allArticles: [SearchArticle]? {
    get {
      guard let hits = self.searchHitList else { return nil }
      return hits.map{
        let art = $0.article
        ///Set Search Hit Base URL to Article because this is missing currently,
        /// used to download server contents from related issue
        art.originalIssueBaseURL = $0.baseUrl
        return art
      }
    }
  }
  
  
  public var searchHitList: [GqlSearchHit]?
  public var offset: Int {
    get{
      guard let list = searchHitList else {
        return 0
      }
      return list.count
    }
  }
  
  func reset(){
    sessionId = nil
    searchHitList = nil
    noMoreSearchResults = false
  }
  
  var request: String {
    get {
      var fromDateArg = ""
      if settings.range.currentOption != .all, let date = settings.from {
        fromDateArg = ", pubDateFrom: \"\(date.isoDate(tz: GqlFeeder.tz))\""
      }
      
      var toDateArg = ""
      if settings.range.currentOption != .all, let date = settings.to {
        toDateArg = ", pubDateUntil: \"\(date.isoDate(tz: GqlFeeder.tz))\""
      }
      
      var sessionArg = ""
      if let sId = sessionId {
        sessionArg = ", sessionId: \"\(sId)\""
      }
      
      var searchString = ""
      if let txt = settings.text, !txt.isEmpty {
        searchString += "text: \(txt.quote()),"
      }
      if let txt = settings.author, !txt.isEmpty {
        searchString += "author: \(txt.quote()),"
      }
      if let txt = settings.title, !txt.isEmpty {
        searchString += "title: \(txt.quote()),"
      }
      
      
      return """
     search(
        \(searchString)
        offset: \(offset),
        filter: \(settings.filter),
        rowCnt: \(Self.itemsPerFetch),
        sorting: \(settings.sorting),
        \(TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder.deviceInfoString ?? "") 
      \(sessionArg)
      \(fromDateArg)
       \(toDateArg)
    ){authInfo {\(GqlAuthInfo.fields)} total, totalFound, text, sessionId searchHitList{\(GqlSearchHit.fields)}}
    """
    }
  }
  
  init(articlePrimaryIssue: SearchResultIssue){
    self.articlePrimaryIssue = articlePrimaryIssue
  }
}



/// One Issue of a Feed
public class GqlSearchHit: GQLObject {
  /// found Article
  var article: SearchArticle
  /// text for result list
  var snippet: String?
  /// teaser for result list
  var teaser: String?
  /// text with highlighted search result
  var articleHtml: String?
  /// base URL for Article
  var baseUrl: String
  /// sectionTitle for Article
  var sectionTitle: String?

  public var sDate: String
  
  public var date: Date { return UsTime(iso: sDate, tz: GqlFeeder.tz).date }
  
  enum CodingKeys: String, CodingKey {
    case article
    case snippet
    case teaser
    case articleHtml
    case sDate
    case baseUrl
    case sectionTitle
    case sessionId
  }
    
  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    article = try container.decode(SearchArticle.self, forKey: .article)
    snippet = try container.decodeIfPresent(String.self, forKey: .snippet)
    teaser = try container.decodeIfPresent(String.self, forKey: .teaser)
    articleHtml = try container.decodeIfPresent(String.self, forKey: .articleHtml)
    sDate = try container.decode(String.self, forKey: .sDate)
    baseUrl = try container.decode(String.self, forKey: .baseUrl)
    sectionTitle = try container.decodeIfPresent(String.self, forKey: .sectionTitle)
  }
  
  
  public func toString() -> String {
    return """
      article:\(article),
      snippet:\(snippet ?? "-"),
      teaser:\(teaser ?? "-"),
      sectionTitle:\(sectionTitle ?? "-"),
      articleHtml:\(articleHtml ?? "-"),
      sDate:\(sDate)",
      baseUrl:\(baseUrl)
    """
  }
  
  static var fields = """
    sDate: date
    snippet
    teaser
    sectionTitle
    articleHtml
    baseUrl
    article{ \(GqlArticle.fields) }
  """
}

// sDate: date,

extension GqlFeeder {
  
  public func search(searchItem: SearchItem,
                     closure: @escaping(Result<SearchItem,Error>)->()) {
    if searchItem.searching {
      closure(.failure(self.error("Still searching in Progress")))
      return
    }
    searchItem.searching = true
    guard let gqlSession = self.gqlSession else {
      closure(.failure(fatal("Not connected"))); return
    }
    let wasAuthenticated: Bool = authToken != nil
    let request = searchItem.request
    let started = Date()
    gqlSession.query(graphql: request,
                     type: GqlSearchResponseWrapper.self) {   [weak self] res in
      guard let self = self else { return }
      print("Request Duration: \(Date().timeIntervalSince(started))s for: \(request)")
      searchItem.searching = false
      switch res {
        case .success(let searchResponseWrapper):
          self.checkResponse(authInfo: searchResponseWrapper.search.authInfo,
                             wasAuthenticated: wasAuthenticated)
          searchItem.lastResponse = searchResponseWrapper
          closure(.success(searchItem))
        case .failure(let err):
          closure(.failure(err))
      }
    }
  }
}
