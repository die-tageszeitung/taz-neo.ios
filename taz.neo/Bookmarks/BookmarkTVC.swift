//
//  BookmarkTVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 19.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

class BookmarkTVC: UIViewController, ContextMenuItemPrivider {
  
  // MARK: - Properties: Data
  ///Titles/keys for row 0, used as section header
  var sortedSectionKeys: [String] = []
  
  var groupedArticles: [String: [Article]] = [:] {
    didSet {
      let empty = groupedArticles.values.flatMap { $0 }.count == 0
      placeholderView.isHidden = !empty
      header.isHidden = empty
      bookmarksTable.isHidden = empty
    }
  }
  
  // MARK: - Properties: UI Components
  
  private lazy var articleVC: ArticleVC? = {
    guard let issueInfo = Bookmarks.shared.issueInfo else { return nil }
    let avc =  ArticleVC(feederContext: issueInfo.feederContext)
    avc.delegate = issueInfo
    return avc
  }()
  
  lazy var header:SettingsHeaderView = {
    let v = SettingsHeaderView()
    v.titletype = .bigLeft
    v.title = "leseliste"
    return v
  }()
  
  private lazy var bookmarksTable:UITableView = {
    let tv = UITableView(frame: .zero, style: .plain)
    tv.register(BookmarksCell.self,
                forCellReuseIdentifier: BookmarksCell.ReuseIdentifier)
    tv.register(BookmarkTableHeaderCell.self,
                forCellReuseIdentifier: BookmarkTableHeaderCell.ReuseIdentifier)
    tv.register(TableSectionSeperatorFooterView.self,
                forHeaderFooterViewReuseIdentifier: TableSectionSeperatorFooterView.ReuseIdentifier)
    tv.separatorStyle = .none
    tv.estimatedRowHeight = 100.0
    tv.separatorInset = .zero
    if #available(iOS 15.0, *) {
      tv.sectionHeaderTopPadding = 0
    }
    tv.dataSource = self
    tv.delegate = self
    
    tv.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    tv.bounces = true
    ///for future implementation
    //    let longTap = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTap(sender:)))
    //    tv.addGestureRecognizer(longTap)
    
    tv.isHidden = true
    return tv
  }()
  
  let placeholderView = PlaceholderView("Sie haben noch keine Artikel in Ihrer Leseliste.\n\nSpeichern Sie Artikel zum weiterlesen, hören oder erinnern in Ihrer persönlichen Leseliste. Einfach das Sternchen bei den Artikeln aktivieren.",
                                        image: UIImage(named: "star"))
  
  private lazy var headerPlayButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onTapping { [weak self] _ in
      guard let sissue = Bookmarks.shared.bookmarkIssue else { return }
      ArticlePlayer.singleton.play(issue: sissue,
                                   startFromArticle: nil,
                                   enqueueType: .replaceCurrent)
    }
    btn.pinSize(CGSize(width: 36, height: 36))
    btn.hinset = 0.1//20%
    btn.color = Const.Colors.appIconGrey
    return btn
  }()
  
  var headerPlayButtonContextMenu: ContextMenu?
  
  public var menu: MenuActions? {
    let ctxMenu = Bookmarks.shared.bookmarkIssue?._contextMenu(group: 0)
    var dlContent: [Article] = []
    for art in Bookmarks.shared.bookmarkedArticles {
      guard let fileEntry = art.audioItem?.file else { continue }
      let localFilePath = art.dir.path + "/" + fileEntry.name
      let file = File(localFilePath)
      if file.exists == false {  dlContent.append(art) }
    }
    
    if dlContent.count == 0 { return ctxMenu }
    debug("can download \(dlContent.count) items")
    ctxMenu?.addMenuItem(title: "Alle Audioinhalte der Leseliste herunterladen",
                         icon: "download",
                         group: 0,
                         closure: { _ in
      Bookmarks.downloadAllAudio(dlContent: dlContent)
    })
    return ctxMenu
  }
  
  // MARK: - Lifecycle
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(placeholderView)
    pin(placeholderView, toSafe: self.view)
    
    self.view.addSubview(header)
    pin(header, to: self.view, exclude: .bottom)
    
    self.view.addSubview(bookmarksTable)
    pin(bookmarksTable, to: self.view, exclude: .top)
    bookmarksTable.isHidden = false
    
    ///It
    pin(bookmarksTable.top, to: header.bottom, dist: -2)
    
    self.header.addSubview(headerPlayButton)
    pin(headerPlayButton.right, to: self.header.right, dist: -10)
    pin(headerPlayButton.centerY, to: header.titleLabel.centerY)
    headerPlayButton.activeColor = Const.SetColor.taz2(.text).color
    headerPlayButtonContextMenu = ContextMenu(view: headerPlayButton.buttonView)
    headerPlayButtonContextMenu?.itemPrivider = self
    
    Notification.receive(Const.NotificationNames.audioPlaybackStateChanged) { [weak self] _ in
      self?.updateAudioButton()
    }
    
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      if let art = msg.sender as? StoredArticle {
        self?.handleBookmarkChanged(for: art)
      }
    }
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateData()
    bookmarksTable.reloadData()///ugly to reload all rows
    applyStyles()
    updateAudioButton()
  }
}



// MARK: - BookmarkTVC: Actions
extension BookmarkTVC {
  
  @objc private func handleLongTap(sender: UILongPressGestureRecognizer) {
    if sender.state == .began {
      let touchPoint = sender.location(in: bookmarksTable)
      guard let indexPath = bookmarksTable.indexPathForRow(at: touchPoint) else { return }
      print("long tap at cell: \(indexPath)")
    }
  }
  
  func shareArticle(article: Article, sourceView: UIView){
    guard let articleVC = articleVC else { return }
    var artImage: UIImage?
    if let issue = article.primaryIssue {
      artImage = article.images?.first?.image(dir: issue.dir)?.invertedIfNeeded
    }
    
    ArticleExportDialogue.show(article: article,
                               delegate: articleVC,
                               image: artImage,
                               sourceView: sourceView)
  }
  
  func open(article: Article){
    guard let avc = articleVC else { return }
    avc.index = avc.articles.firstIndex { $0.serverId == article.serverId } ?? 0
    self.navigationController?.pushViewController(avc, animated: true)
  }
  
}

// MARK: - BookmarkTVC: Helper
extension BookmarkTVC {
  
  private func indexPath(for article: Article) -> IndexPath? {
    guard let serverId = article.serverId else { return nil }
    for (sectionKey, articles) in groupedArticles {
      if let aIdx = articles.firstIndex(where: { $0.serverId == serverId }) {
        if let sIdx = sortedSectionKeys.firstIndex(where: {$0 == sectionKey }) {
          return IndexPath(row: aIdx + 1, section: sIdx)///+1 to fix section header is row 0
          
        }
        return nil
      }
    }
    return nil
  }
  
  ///updates datasource initially and after change
  func updateData() {
    // group after date
    let dict = Dictionary(grouping: Bookmarks.shared.bookmarkedArticles.bmSorted(), by: { article in (article.issueDate ?? Date(timeIntervalSince1970: 0)).isoDate() })
    
    var out: [String: [StoredArticle]] = [:]
    
    for (sectionKey, articles) in dict {
      //Cannot use mutating member on immutable value: 'articles' is a 'let' constant
      out[sectionKey] = articles
      
    }
    
    groupedArticles = out
    
    // Sections sortieren (nach Datum absteigend)
    sortedSectionKeys = groupedArticles.keys.sorted().reversed()
  }
  
  func handleBookmarkChanged(for article: StoredArticle){
    ///do not set compleete array new, this did not add/remove articles if in artVC e.g. when unbookmark and revert e.g.:
    /// articleVC?.articles = (Bookmarks.shared.bookmarkIssue?.allArticles as? [StoredArticle])?.bmSorted() ?? []
    if article.hasBookmark {
      articleVC?.insert(article: article)
    }
    else {
      articleVC?.delete(article: article)
    }
    
    if articleVC?.articles.count == 0 {
      articleVC?.navigationController?.popViewController(animated: true)
    }
    
    if isActiveAndVisible == false { return }
    guard let indexPath = indexPath(for: article) else {
      ///added bookmark!
      updateData()
      bookmarksTable.reloadData()
      return
    }
    self.removeBookmarkArticleCell(at: indexPath, article: article)
  }
  
  
  func updateAudioButton(){
    self.headerPlayButton.buttonView.name
    = ArticlePlayer.singleton.isPlaying
    && (ArticlePlayer.singleton.currentContent as? Article)?.hasBookmark == true
    ? "audio-active"
    : "audio"
    self.headerPlayButton.buttonView.isHidden = Bookmarks.shared.bookmarkIssue?.hasAudio != true
  }
  
  func removeBookmarkArticleCell(at indexPath: IndexPath, article: Article){
    let sectionKey = sortedSectionKeys[indexPath.section]
    guard var articlesInSection = groupedArticles[sectionKey] else { return }
    
    // Entferne den Artikel aus der Datenquelle
    articlesInSection.removeAll { $0.serverId == article.serverId }
    self.groupedArticles[sectionKey] = articlesInSection
    
    // Wenn die Section leer ist, entferne die Section
    if articlesInSection.isEmpty {
      self.groupedArticles.removeValue(forKey: sectionKey)
      self.sortedSectionKeys = self.sortedSectionKeys.filter { $0 != sectionKey }
    }
    
    // Tabelle aktualisieren
    bookmarksTable.performBatchUpdates {
      if articlesInSection.isEmpty {
        // Wenn die gesamte Section gelöscht wurde
        bookmarksTable.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
      } else {
        // Wenn nur eine Zeile gelöscht wurde
        bookmarksTable.deleteRows(at: [indexPath], with: .fade)
      }
    }
  }
}

// MARK: - BookmarkTVC: Protocol Implementations / Delegate

// MARK: - ScreenTracking
extension BookmarkTVC: ScreenTracking {
  public var screenUrl:URL? { URL(path: "bookmarks/list") }
  public var screenTitle:String? { "Bookmarks List" }
}

extension BookmarkTVC: DefaultScreenTracking {
  public var defaultScreen: Usage.DefaultScreen? {
    placeholderView.isHidden ? .BookmarksList : .BookmarksEmpty
  }
}

// MARK: - UIStyleChangeDelegate
extension BookmarkTVC: UIStyleChangeDelegate {
  public func applyStyles() {
    self.view.backgroundColor = Const.SetColor.HBackground.color
  }
}

// MARK: - ReloadAfterAuthChanged
extension BookmarkTVC: ReloadAfterAuthChanged {
  public func reloadOpened(){
    Bookmarks.shared.loadFullArticlesIfNeeded()
  }
}
