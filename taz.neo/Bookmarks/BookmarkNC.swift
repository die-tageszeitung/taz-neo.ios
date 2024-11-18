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
  
  var isShowingAlert = false
  
  private var _sectionVC: BookmarkSectionVC?
  var sectionVC: BookmarkSectionVC? {
    return _sectionVC ?? {
      let svc = createSectionVC()
      _sectionVC = svc
      return svc
    }()
  }
  
  func createSectionVC(openArticleAtIndex: Int? = nil) -> BookmarkSectionVC?{
    guard let issueInfo = Bookmarks.shared.issueInfo else { return nil }
    
    let svc = BookmarkSectionVC(feederContext: issueInfo.feederContext,
                                atSection: nil,
                                atArticle: openArticleAtIndex)
    svc.delegate = issueInfo
    svc.toolBar.show(show:false, animated: true)
    svc.isStaticHeader = true
    svc.header.titletype = .bigLeft
    svc.header.title = App.isTAZ ? "leseliste" : "Leseliste"
    svc.hidesBottomBarWhenPushed = false
    return svc
  }
  
  func setup() {
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      self?.handleBookmarksChange(notification: msg)
    }
    genAllHtml()///initial call
    exchangeRootControllerIfNeeded()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
}

extension BookmarkNC {
  fileprivate func handleBookmarksChange(notification: Notification) {
    // Regenerate all bookmark sections
    genAllHtml()
    
    if let article = notification.sender as? StoredArticle {
      handleArticleBookmarkChange(article)
    } else {
      ///handle Settings: bookmarksListTeaserEnabled change
      sectionVC?.reload()
    }
  }
  
  private func handleArticleBookmarkChange(_ article: StoredArticle) {
    if article.hasBookmark {
      sectionVC?.insertArticle(article)
      sectionVC?.reload()
    } else {
      sectionVC?.deleteArticle(article)
    }
    sectionVC?.updateAudioButton()
    exchangeRootControllerIfNeeded()
  }
  
  func exchangeRootControllerIfNeeded(){
    if Bookmarks.shared.bookmarkSection?.articles?.isEmpty == true {
      if viewControllers.first != placeholderVC {
        setViewControllers([placeholderVC], animated: self.isVisible)
      }
      if viewControllers.count > 1 {
        popToRootViewController(animated: self.isVisible)
      }
      return
    }
    ///there are bookmarks
    guard let sectVc = sectionVC else { return }
    
    if viewControllers.first == sectVc { return }
    setViewControllers([sectVc], animated: self.isVisible)
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
    <link rel="stylesheet" href="resources/bookmarks-\(App.isLMD ? "lmd" : "taz")-ios.css"/>
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
    BookmarkNC.htmlDottedLine : "";
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
#warning("Primary Issue unavailable after delete!")
    ///Herausforderung: Wie bekomme ich das Moment Image persistiert? Aber ich möchte die ganze Ausgabe löschen?
    ///ich muss das Moment IMage irgendwo ander hinschieben/kopieren?
    ///Übergeordnete Frage: will ich vielleicht Lese/Vorlese Listen haben, darin dann die Artikel vielleicht noch gruppiert?
    ///**NEIN**, weil ich keine Code duplication für den Download von zusätzlichen Ressourcen haben möchte
    ///**UND NEIN** weil ich die komplexitätssteigerung durch Abstraktion dessen scheue
    ///zu sehen an den Beispielen TBD wo einfach bestimmte Objekte reingeworfen werden und dann aber 1.000 Sonderbehandlungen gemacht werden müssen
    ///bzw. endlode Bugfixing Sessions anstehen
    ///....KISS vermeide Komplexitätssteigerung ist die Intention der aktuellen Umsetzung
    if let articles = arts as? [StoredArticle],
       articles.count > 0,
       let publicationDate =  articles.first?.originalMoment?.publicationDate,
       let lowres = articles.first?.originalMoment?.lowres,
       let path = articles.first?.originalIssueDir()?.path {
      let momentPath = "\(path)/\(lowres.name)"
      let dateText = publicationDate.validityDateText(leadingText: "wochentaz, ")
      var html = """
      <section id="\(date.timeIntervalSince1970)">
        <header class="issue">
          <img class="moment" src="\(momentPath)">
          <h1>\(dateText)</h1>
        </header>\n
        \(dottedLine(inSection: true))
      """
      var order = 1;
      for art in articles {
        html += """
            <article id="\(File.progname(art.html?.name ?? ""))" style="order:\(order)">
            \(getInnerHtml(art: art))
            </article>\n
          """
        order += 1
      }
      html += "</section>\n"
      return html
    }
    return ""
  }
  
  public func genHtmlSections(section: StoredSection) -> String {
    var groupedArticles: [Date:[Article]] = [:]
    
    for case let art as StoredArticle in section.articles ?? [] {
      guard let sdate = art.pr.originalMoment?.publicationDate?.date else { continue }
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
      \(BookmarkNC.htmlHeader)
      <body>\n
      """
    html += genHtmlSections(section: section)
    html += "</body>\n</html>\n"
    guard let path = (section.html as? StoredFileEntry)?.path,
          File(path).exists else { return }
    File(path).string = html
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
