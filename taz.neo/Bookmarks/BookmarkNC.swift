//
//  BookmarkNC.swift
//  taz.neo
//
//  Created by Ringo Müller on 12.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

fileprivate class PlaceholderVC: UIViewController{
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view
    = PlaceholderView("Sie haben noch keine Artikel in Ihrer Leseliste.\n\nSpeichern Sie Artikel zum weiterlesen, hören oder erinnern in Ihrer persönlichen Leseliste. Einfach das Sternchen bei den Artikeln aktivieren.",
                      image: UIImage(named: "star"))
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.view.backgroundColor = Const.SetColor.CTBackground.color
  }
}

extension PlaceholderVC: DefaultScreenTracking {
  public var defaultScreen: Usage.DefaultScreen? { .BookmarksEmpty }
}

class BookmarkNC: NavigationController {
  @Default("bookmarksListTeaserEnabled")
  var bookmarksListTeaserEnabled: Bool
  
  private var placeholderVC = PlaceholderVC()
  
  public var feederContext: FeederContext
//  public lazy var bookmarkFeed = BookmarkFeed.allBookmarks(feeder: feeder)
#warning("ITS BAD CHANGE")
  public var issue: Issue { Bookmarks.shared.bookmarkIssue! }
    
  var isShowingAlert = false
  
  public lazy var sectionVC: BookmarkSectionVC = {
    return createSectionVC()
  }()
  
  func createSectionVC(openArticleAtIndex: Int? = nil) -> BookmarkSectionVC{
    genAllHtml()
    let svc = BookmarkSectionVC(feederContext: feederContext,
                               atSection: nil,
                               atArticle: openArticleAtIndex)
    svc.delegate = self
    svc.toolBar.show(show:false, animated: true)
    svc.isStaticHeader = true
    svc.header.titletype = .bigLeft
    svc.header.title = App.isTAZ ? "leseliste" : "Leseliste"
    svc.hidesBottomBarWhenPushed = false
    return svc
  }
  
//  func getModel(){
//    let bi = StoredIssue.bookmarkIssue(in: feederContext.defaultFeed)
//    log("bi art count: \(bi?.allArticles.count ?? 0) hatBMSect: \(bi?.sections?.first?.name ?? "-")")
//    for art in bi?.allArticles ?? [] {
//      log("art in bi title: \(art.title ?? "-") sectionTitle: \(art.sectionTitle ?? "-") path: \(art.path)")
//    }
//    log("done")
//  }
  
  func setup() {
    Notification.receive(Const.NotificationNames.expiredAccountDateChanged) { [weak self] notif in
      guard TazAppEnvironment.hasValidAuth else { return }
      self?.reloadOpened()
    }
    #warning("ToDo after refactor and issue independent bookmarks")
    /*
     there was a (particullary not) reproduceable bug:
     logged out > load demo issue > bookmark demo article > view in bookmark list
     > login in issue-overview
     1. > move to article in bookmarks > showed demo Article OR! full Article (depend on what?) AND showed Login Form
     2. > article in bookmark list was not clickable (list did not refreshed!)
     
     to load all articles fully is maybe too much because currently its needed to load all issues
     later with issue independent bookmark articles we can load all articles
     
     another bug: bookmark css was also after a few restarts not available.
     from testflight alpha > alpha
     not solved by various restarts @see error report by mail
     solved by start debug
     */
    
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { [weak self] notif in
      guard TazAppEnvironment.hasValidAuth else { return }
      self?.reloadOpened()
    }
    
//    Notification.receive("updatedDemoIssue") { [weak self] notif in
//      guard let self = self else { return }
//      self.bookmarkFeed
//      = BookmarkFeed.allBookmarks(feeder: self.feeder)
//      self.sectionVC.delegate = nil
//      self.sectionVC.delegate = self///trigger SectionVC.setup()
//    }
    
//    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
//      // regenerate all bookmark sections
//      guard let emptyRoot = self?.placeholderVC,
//            let self = self else { return }
//      if let art = msg.sender as? StoredArticle {
//        self.bookmarkFeed.loadAllBookmarks()
//        self.bookmarkFeed.genAllHtml()
//        if art.hasBookmark {
//          self.sectionVC.insertArticle(art)
//          self.sectionVC.reload()
//          self.ensureBookmarkListVisibleIfNeeded(animated: false)
//        }
//        else {
//          self.sectionVC.deleteArticle(art)
//          if !self.sectionVC.isVisible { self.sectionVC.reload() }
//          self.sectionVC.updateAudioButton()
//        }
//        if self.bookmarkFeed.count <= 0 {
//          self.viewControllers[0] = emptyRoot
//          self.popToRootViewController(animated: true)
//        }
//      }
//      else {
//        self.bookmarkFeed.genAllHtml()
//        self.sectionVC.reload()
//      }
//    }
    genAllHtml()
  }
  
  
  
  func ensureBookmarkListVisibleIfNeeded(animated: Bool = true){
//    if bookmarkFeed?.count ?? 0 > 0 && self.viewControllers.first != sectionVC  {
    if self.viewControllers.first != sectionVC  {
      setViewControllers([sectionVC], animated: animated)
    }
  }
   
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    ensureBookmarkListVisibleIfNeeded()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  init(feederContext: FeederContext) {
    self.feederContext = feederContext
    super.init(rootViewController: placeholderVC)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension BookmarkNC: IssueInfo {
  public func resetIssueList() {}
}


extension BookmarkNC: ReloadAfterAuthChanged {
  public func reloadOpened(){
    #warning("TODO: discuss with nthies...")
    /// UseCase: app reseted, unauth, bookmark demo Article
    /// view demo article in bookmark list, scroll down login
    /// "Aktualisiere Daten" did not disappear due the StoredFeeder of the FeederContext still unauth,
    /// but the gql feeder is authenticated => hack test this one not the stored feeder, untill Fixing
    /// OLD CODE:  guard self.feeder.isAuthenticated else { return }
    guard TazAppEnvironment.hasValidAuth else { return }
    
    let lastIndex: Int? = (self.viewControllers.last as? ArticleVC)?.index
    var issuesToDownload:[StoredIssue] = []
//    for art in bookmarkFeed.issues?.first?.allArticles ?? [] {
//      if let sissue = art.primaryIssue as? StoredIssue,
//         sissue.status == .reduced,
//         issuesToDownload.contains(sissue) == false {
//        issuesToDownload.append(sissue)
//      }
//    }
        
    func downloadNextIfNeeded(){
      if let nextIssue = issuesToDownload.first {
        self.feederContext.getCompleteIssue(issue: nextIssue,
                                             isPages: false,
                                             isAutomatically: false)
      } else if let idx = lastIndex {
        reopenArticleAtIndex(idx: idx)
      } else {
//        self.bookmarkFeed
//        = BookmarkFeed.allBookmarks(feeder: self.feeder)
//        self.sectionVC.reload()
        Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
      }
    }
    
    Notification.receive("issue"){ notif in
      ///ensure the issue download comes from here!
      guard let issue = notif.object as? Issue else { return }
      guard let issueIdx = issuesToDownload.firstIndex(where: {$0.date == issue.date})
      else { return /* Issue Download from somewhere else */ }
      issuesToDownload.remove(at: issueIdx)
      downloadNextIfNeeded()
    }
    downloadNextIfNeeded()
  }
  
  private func reopenArticleAtIndex(idx: Int?){
//    self.bookmarkFeed
//    = BookmarkFeed.allBookmarks(feeder: self.feeder)
//    self.sectionVC.releaseOnDisappear()
//    self.sectionVC
//    = createSectionVC(openArticleAtIndex: idx)
//    self.viewControllers[0] = self.sectionVC
//    self.popToRootViewController(animated: true)
//    Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
  }
  
  public func reloadIfNeeded(article: Article?){
    guard let article = article,
          let reloadIssue = article.primaryIssue as? StoredIssue else { return }

    if article.html?.exists(inDir: article.dir.path) == false {
      loadReload(reloadIssue: reloadIssue)
    }
    else if reloadIssue.isReduced && TazAppEnvironment.hasValidAuth {
      loadReload(reloadIssue: reloadIssue)
    }
  }
  
  private func loadReload(reloadIssue: StoredIssue){
    let lastIndex: Int? = (self.viewControllers.last as? ArticleVC)?.index
    let snap = UIWindow.keyWindow?.snapshotView(afterScreenUpdates: false)
    WaitingAppOverlay.show(alpha: 1.0,
                           backbround: snap,
                           showSpinner: true,
                           titleMessage: "Aktualisiere Daten",
                           bottomMessage: "Bitte haben Sie einen Moment Geduld!",
                           dismissNotification: Const.NotificationNames.removeLoginRefreshDataOverlay)
    Notification.receive("issue"){[weak self] notif in
      ///ensure the issue download comes from here!
      guard let issue = notif.object as? Issue else { return }
      guard reloadIssue.date.issueKey == issue.date.issueKey else { return }
      self?.reopenArticleAtIndex(idx: lastIndex)
    }
    reloadOpened()
    onMainAfter {[weak self] in
      self?.popToRootViewController(animated: false)//there is a overlay
    }
  }
}


//generate section html helper
extension BookmarkNC {
  // HTML header
  static var htmlHeader = """
  <!DOCTYPE html>
  <html lang="de">
  <head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0"/>
    <link rel="stylesheet" href="resources/bookmarks-ios.css"/>
    <script src="resources/tazApi.js"></script>
    <script src="resources/bookmarks-ios.js"></script>
    <title>Bookmarks</title>
  </head>
  """
  
  // A dotted line using SVG
  //static var htmlDottedLine = "<div class='dottedline'></div>"
  static var htmlDottedLine = "<hr class='dotted'/>"
  
  func dottedLine(inSection: Bool) -> String {
    return (App.isTAZ ? !inSection : inSection) ?
      BookmarkFeed.htmlDottedLine : "";
  }
  
  /// Get all authors as String with HTML markup
  public func getAuthors(art: Article) -> String {
    var ret = ""
    if let authors = art.authors, authors.count > 0 {
      let n = authors.count - 1
      for i in 0...n {
        if let name = authors[i].name {
          ret += name
          if i != n { ret += ", " }
        }
      }
      ret = "<address>\(ret.authorsFormated)</address>&ensp;"
    }
    if let duration = art.readingDuration {
      ret += "<time>\(duration) min.</time>"
    }
    return """
        <div class="author">
          \(ret)
        </div>\n
    """
  }
  
  /// Get image of first picture (if available) with markup
  public func getImage(art: Article) -> String {
    if let imgs = art.images, imgs.count > 0 {
      let fn = imgs[0].name
      return "<img class=\"photo\" src=\"\(art.dir.path)/\(fn)\">"
    }
    else { return "" }
  }
  
  /// Get the inner HTML of an article
  public func getInnerHtml(art: StoredArticle) -> String {
    let title = art.title ?? art.html?.name ?? ""
    let shareIcon
    = art.onlineLink == nil
    ? ""
    : """
        <img class="share" src="resources/Share.svg">
      """
    let teaser = bookmarksListTeaserEnabled
    ? "<p>\((art.teaser ?? "").xmlEscaped())</p>"
    : ""
    let html = """
      \(dottedLine(inSection: false))
      <a href="\(art.path)">
        \(getImage(art: art))
        <h2>\(title.xmlEscaped())</h2>
        \(teaser)
      </a>
      <div class = "foot">
        \(getAuthors(art: art))
        <div class="icons">
          \(shareIcon)
          <img class="bookmark" src="resources/StarFilled.svg">
        </div>
      </div>
    """
    return html
  }
  
  /// Generate HTML for given HTML Section
  public func genHtmlSection(date: Date, arts: [Article]) -> String {
    if let articles = arts as? [StoredArticle],
       articles.count > 0,
       let issue = articles[0].primaryIssue {
      let momentPath = feeder.smallMomentImageName(issue: issue)
      let dateText = App.isLMD ?
        "Ausgabe " + issue.date.gMonthYear(tz: GqlFeeder.tz, isNumeric: true) :
        issue.validityDateText(timeZone: GqlFeeder.tz, leadingText: "wochentaz, ")
      var html = """
      <section id="\(date.timeIntervalSince1970)">
        <header class="issue">
          <img class="moment" src="\(momentPath ?? "")">
          <h1>\(dateText)</h1>
        </header>\n
        \(dottedLine(inSection: true))
      """
      var order = 1;
      for art in articles {
        let issues = art.issues
        if issues.count > 0 {
          html += """
            <article id="\(File.progname(art.html?.name ?? ""))" style="order:\(order)">
            \(getInnerHtml(art: art))
            </article>\n
          """
        }
        order += 1
      }
      html += "</section>\n"
      return html
    }
    return ""
  }

  public func genHtmlSections(section: StoredSection) -> String {
    var groupedArticles: [Date:[Article]] = [:]
    
    for art in section.articles ?? [] {
      let sdate = art.issueDate
      var artsAtDate: [Article] = groupedArticles[sdate] ?? []
      artsAtDate.append(art)
      groupedArticles[sdate] = artsAtDate
    }
    var html = ""
    for date in Array(groupedArticles.keys).sorted(by: { d1, d2 in d1 > d2 }) {
      guard let arts = groupedArticles[date] else { continue }
      html += genHtmlSection(date: date, arts: arts)
    }
    return html
  }
  
  /// Generate HTML for given Section
  public func genHtml(section: StoredSection) {
    var html = """
      \(BookmarkFeed.htmlHeader)
      <body>\n
      """
    html += genHtmlSections(section: section)
    html += "</body>\n</html>\n"
//    let tmpFile = section.html as! BookmarkFileEntry
    guard let path = (section.html as? StoredFileEntry)?.path,
          File(path).exists else { return }
    File(path).string = html
//    
//    guard let feed = Bookmarks.shared.bookmarkIssue?.feed else { return }
//    let feed2 = section.primaryIssue?.feed
//    let bmFile = BookmarkFileEntry(feed: feed,
//                      name: "\(section.name).html")
//    bmFile.content = html
//    section.html.content = html
  }

  /// Generate HTML for all Sections
  public func genAllHtml() {
    guard let section = Bookmarks.shared.bookmarkSection else { return }
    self.genHtml(section: section)
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
