//
//  BookmarkFeed.swift
//  taz.neo
//
//  Created by Norbert Thies on 16.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/**
 
 Diskussion sind die Lesezeichen(Leseliste) ggf. weitere Listen Hörliste, Archiv, ... jetzt Feeds oder im Feed taz/lmd?
 
 Verbindung
 * ist es der gleiche Feed, ist die Verbindung via (regulärer) Issue bzw. Bookmark/Archiv/Hör Issue (nur eine, alles andere via Sections!!) viel einfacher
 * d.h. Cleanup, löschen einer Issue etc.  ist deutlich weniger Komplex (weil nur über eine Ebene, und Löschen von Ausgaben eh bereits vorhanden isT)
 * löschen via Feed ist komplexer, Fehler sind schwerer zu erkennen/debuggen Modellfehler aufwendiger zu beheben
 Pro eigener Feed:
 * was ist auf Serverseite? Wenn wir auf Serverseite die ganz große Interation hätten, dann müssten Nutzerdaten von Ausgabendaten getrennt sein und jeder Nutzer hätte seinen Feed....das werden wir aber so nicht haben, An der Schnittstelle (API, GraphQL) kann eine entsprechende Transformation stattfinden und findet bereits statt => Warum: deutliche Komplexitätsreduzierung
 
 @Norbert falls Wiederspruch:
 * * ich erinnere mich gut an 2-3 Debug Sessions, die wir gemeinsam via zoom gemacht haben, 4ALL: **das Modell ist komplex, wir brauchen ein gemeinsames verständniss davon, Pappnasen erzeugen massive teschnische Schuld und damit Arbeit in der Zukunft: wenn wir nicht aufpassen werden wir uns dann irgendwann eingestehen müssen: eine Weiterentwicklung macht keinen sinn, weil deutlich aufwändiger als Neuentwicklung, mehr als 70% der Arbeitszeit geht für Debuggng, Bugfixing drauf. Das muss nicht sein**
 
 
 HACKS:
 po (shared.bookmarkSection?.articles as? [StoredArticle])?.flatMap{$0.serverId}
 
 Status
 * Bookmark Feed is depreciated
 * lost Section's html after restart
 StoredFileEntry.fileNameExists(inDir:) Info:
   * Warning: File Leseliste.html exists but mtime and/or size are wrong 2024-08-29 08:24:41 +0000 !=? 2024-08-29 08:24:37 +0000 || 377 !=? 14
 ...datei muss generiert und bei appear neu geladen werden!
 tap auf Artikel geht nicht in Artikel
 * löschen Ausgabe
 * neu laden ausgabe?
 * Migration
 * wieso verschwinden artikel aus ihrem eigentlichen issue? ...und wann?
 
 * aktuelle Probleme?
 LADEFEHLER => DONE
 * entfernen aus Leseliste auf Artikelebene klappt nicht
 falscher bookmarks ordner wird noch vom bookmarks feed angelegt
 wenn ein Artikel in Section gebookmarkt ist, erscheint nach neustart der Stern nicht und er lässt sich nicht toggln
 
 kann ein Artikel in mehreren Sections der gleichen Ausgabe sein?
 Was passiert, wenn ein Artikel in einer Ausgabe gelöscht weird, weil die Ausgabe gelöscht wird?
 Wie vermeide ich dass ein Artikel von Ausgabe zu BM Ausgabe hin und her verschoben/Kopiert wird? Beim laden der Ausgabe neu geladen wird?
 Der ArtikelHTML+Bilder sollte an seinem Platz bleiben
 => d.h. Löschen nochmal überarbeiten!
 => reduce to overview sollte passen
 => remove unknown folders & co muss angepasst werden und um diese sachwen erweitert werden
 => delete issue muss angepasst werden
 ...crash war date nil wieso?... war aber beim löschen,
 
 
 nächste Herausforderung finden des Artikels und seiner ressourcen für ArticleVC, ist nicht in issue folder oder nicht in bookmark issue folder!?
 
 
 */

public extension StoredArticle {
  
}

extension PersistentArticle {
  public var hasBookmark2: Bool {
    return true
//    let has = Bookmarks.has(article: self)
//    print("requested has Bookmark for: \(self.title ?? "-") id: \(self.serverId ?? -1) has: \(has)")
//    return has
  }
}

extension StoredArticle {
  public var hasBookmark: Bool {
    get {
      let has = Bookmarks.has(article: self)
      print("requested has Bookmark for: \(self.title ?? "-") id: \(self.serverId ?? -1) has: \(has)")
      return has
    }
    set {
      if Bookmarks.set(article: self, active: newValue) == false { return }///No change, no notification
      Notification.send(Const.NotificationNames.bookmarkChanged, content: sections, sender: self)
    }
  }
}

extension Issue {
  public var isBookmarkIssue: Bool {
    return self is StoredIssue && baseUrl == Bookmarks.bookmarkUrl
  }
  
//  public var dir: Dir? {
//    return nil
//  }
}

public class Bookmarks: DoesLog {
  ///Motivation: altes bookmark issue war virtuell und nicht in db, soll jetzt in db sein um ausgabenunabhängige lesezeichen zu haben
  ///Problem setze und entferne bookmark hat riesen overhead, sollte vielleicht nicht komplett im Model via Artikel gemacht werden, also hier ...halte dann hier auch das BookmarkIssue und die entsprechende Section vorrätig
  ///später mehrere Sections: Leseliste, archiv, hörliste....

  private static let sharedInstance = Bookmarks()
  static var shared: Bookmarks {
    get {
      if sharedInstance.bookmarkSection == nil {
        ///solves access to bookmarks without inited feeder
        ///if no stored feeder:
        /// - no bookmark can be set OK
        /// - no bookmark can be fetsch from DB list is empty OK
        sharedInstance.setup()
      }
      return sharedInstance
    }
  }
  
  fileprivate static let bookmarkUrl = "bookmark.issue.local"
  
  var bookmarkIssue: StoredIssue?
  var bookmarkSection: StoredSection?
  
  /// returns true if value changed
  /// prepared for multiple bookmark lists
  fileprivate static func set(article: StoredArticle, active: Bool, in list: StoredSection? = nil) -> Bool {
    guard has(article: article, in: list) != active else { return false }//No Change nothing to do
    guard let bookmarkSection = list ?? shared.bookmarkSection else {
      Log.log("Fail to set Bookmark, usually unreachable code")
      return false
    }
    if active {
      article.pr.addToSections(bookmarkSection.pr)
      bookmarkSection.pr.addToArticles(article.pr)
      article.pr.originalMoment?.addToBookmarkedArticles(article.pr)//Required??
//      = article.primaryIssue?.moment.pr.
      addMomentToPublicationDate(for: article)
    }
    else {
      article.pr.removeFromSections(bookmarkSection.pr)
      bookmarkSection.pr.removeFromArticles(article.pr)
      if article.pr.sections?.count == 0 {
        article.delete()
      }
//      article.pr.removeFromIssues(bookmarkIssue.pr)
//      bookmarkIssue.pr.removeFromArticles(article.pr)//??
    }
    return true
  }
  
  fileprivate static func addMomentToPublicationDate(for article: StoredArticle){
    guard let iDate = article.primaryIssue?.date,
          let moment = article.primaryIssue?.moment as? StoredMoment
    else { return }
    
    let pDate = article.primaryIssue?.feed.publicationDates?
      .first{$0.date.issueKey == iDate.issueKey}
    guard let pDate = pDate as? StoredPublicationDate else { return }
    pDate.pr.moment = moment.pr
    article.pr.originalMoment = moment.pr
  }
  
  /// returns true if is in given list
  /// prepared for multiple bookmark lists, uses default list if none given
  fileprivate static func has(article: StoredArticle, in list: StoredSection? = nil) -> Bool {
    return (list ?? shared.bookmarkSection)?
      .articles?.contains{$0.serverId == article.serverId } ?? false
  }
  
  //IS STatic required?
  private func bookmarkIssue(in feed: Feed) -> StoredIssue {
    let request = StoredIssue.fetchRequest
    request.predicate = NSPredicate(format: "(baseUrl = %@)", Self.bookmarkUrl)
    if let si = StoredIssue.get(request: request).first { return si }
    
    let si = StoredIssue.new()
    si.baseUrl = Self.bookmarkUrl
    si.date = Date(timeIntervalSinceReferenceDate: 0)//1.1.2001
    si.moTime = Date()
    si.minResourceVersion = 0
    si.status = .unknown
    si.isWeekend = false
    
    si.isDownloading = false
    si.isComplete = false
    si.feed = feed
    si.moment =  DummyMoment()
    
    addBookmarkSection()
    return si
  }
  
  #warning("ToDo: migrate old bookmarks!")
  private func migrateBookmarks(){
    
  }
  
  //IS STatic required?
  @discardableResult
  private func addBookmarkSection(with name: String = "Leseliste") -> StoredSection? {
    guard let issue = bookmarkIssue else {
      log("Failed to add BookmarkSection with name: \(name), bookmarkIssue is missing.")
      return nil
    }
    copyRessourcesIfNeeded()
    let sect = StoredSection.new()
    sect.name = "Leseliste"
    sect.type = .unknown
//    sect.primaryIssue = issue
    
    let bmFilePath = "\(issue.feed.bookmarksDir.path)/\(sect.name).html"
    File(bmFilePath).string = "initial, empty"
    let tmpFile = StoredFileEntry.new(path: bmFilePath)
    sect.html = tmpFile
    issue.pr.addToSections(sect.pr)
    sect.pr.issue = issue.pr
    migrateBookmarks()

    return sect
  }
  
  //IS STatic required?
  private func copyRessourcesIfNeeded(){
    guard let issue = bookmarkIssue else {
      log("Failed to copy, bookmarkIssue is missing.")
      return
    }
    let bmDir = issue.feed.bookmarksDir
    if bmDir.exists { return }

    bmDir.create()
    let rlink = File(dir: bmDir.path, fname: "resources")
    let glink = File(dir: bmDir.path, fname: "global")
    if !rlink.isLink { rlink.link(to: issue.feed.feeder.resourcesDir.path) }
    if !glink.isLink { glink.link(to: issue.feed.feeder.globalDir.path) }
    
    ///copy both taz and lmd bookmark css, and just use different ones! Switch would be easier
    ///@see old init BookmarkFeed for prev version
    var resources = ["bookmarks-ios.js", "Star.svg", "StarFilled.svg",
                     "Share.svg", "dot-night.svg", "dot-day.svg", "bookmarks-taz-ios.css", "bookmarks-lmd-ios.css"]
    for f in resources {
      if let path = Bundle.main.path(forResource: f, ofType: nil) {
        let base = File.basename(path)
        let src = File(path)
        let dest = "\(bmDir.path)/resources/\(base)"
        src.copyResource(to: dest)
      }
    }
  }
  
  func setup(){
    guard let feed
    = TazAppEnvironment.sharedInstance.feederContext?.defaultFeed else {
      return
    }
    let bmIssue: StoredIssue = bookmarkIssue(in: feed)
    self.bookmarkIssue = bmIssue
    #warning("What if multiple sections and deletion ist there? , handle this!")
    self.bookmarkSection
    = bookmarkIssue?.sections?.first as? StoredSection //handle this here!
    ?? addBookmarkSection()
  }
}

/// An Issue of Sections of bookmarked Articles
public class VirtualIssue: Issue {
  public var isDownloading: Bool { get { false } set {} }
  public var isComplete: Bool { get { false } set {} }
  public var feed: Feed
  public var date: Date
  public var validityDate: Date?
  public var moTime: Date
  public var isWeekend: Bool { false }
  public var moment: Moment { DummyMoment() }
  public var key: String? { nil }
  public var baseUrl: String { "" }
  public var status: IssueStatus { .unknown }
  public var minResourceVersion: Int { 0 }
  public var zipName: String? { nil }
  public var zipNamePdf: String? { nil }
  public var imprint: Article? { nil }
  public var sections: [Section]?
  public var pages: [Page]? { nil }
  public var lastSection: Int? { get { nil } set {} }
  public var lastArticle: Int? { get { nil } set {} }
  public var lastPage: Int? { get { nil } set {} }
  public var payload: Payload { DummyPayload() }
  public var dir: Dir { feed.dir }
  
  init(feed: Feed) {
    self.feed = feed
    self.date = Date()
    self.moTime = self.date
  }
}

/// A Section of bookmarked Articles
public class BookmarkSection: Section {
  public var audioItem: Audio?
  public var name: String
  public var extendedTitle: String? { name }
  public var type: SectionType { .articles }
  public var articles: [Article]?
  public var groupedArticles: [Date:[Article]]?
  public var issueDates: [Date]?
  public var navButton: ImageEntry? { nil }
  public var html: FileEntry?
  public var images: [ImageEntry]? { nil }
  public var authors: [Author]? { nil }
  public var primaryIssue: Issue?
  
  public init(name: String, issue: Issue, html: FileEntry) {
    self.name = name
    self.primaryIssue = issue
    self.html = html
  }
}

public class DummyPayload: Payload {
  public var localDir: String { "" }
  public var remoteBaseUrl: String { "" }
  public var remoteZipName: String? { nil }
  public var files: [FileEntry] { [] }
  public var issue: Issue? { nil }
  public var resources: Resources? { nil }
}

public class DummyMoment: Moment {
  public var images: [ImageEntry] { [] }
  public var creditedImages: [ImageEntry] { [] }
  public var animation: [FileEntry] { [] }
}

/// Small File extension to copy resource files
extension File {
  /**
   copies a file to a destination given by its pathname.

   self is only copied if it is either newer than the destination file
   (in this case it is an update of a new app version) or the destination
   file is newer than the source file (in this case it has been copied before
   but the mtime has not been set to that of the source file).
   After copying the destination file's mtime is set to that of the source
   file.
   */
  public func copyResource(to: String) {
    let dest = File(to)
    if dest.mtime != self.mtime {
      self.copy(to: to)
      dest.mtime = self.mtime
    }
  }
  
  public func copyResourceWithStatusReturn(to: String) -> Int {
    var status = -123
    let dest = File(to)
    if dest.mtime != self.mtime {
      status = self.copy(to: to)
      dest.mtime = self.mtime
    }
    return status
  }
}

fileprivate extension String {
  var authorsFormated: String {
    #if LMD
    return self.length > 0 ? self.xmlEscaped().prepend("von ") : ""
    #else
    return self.xmlEscaped()
    #endif
  }
}
