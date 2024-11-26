//
//  BookmarkTVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 19.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

//@inlinable public mutating func sort(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows
// extension Array<StoredArticle> {

extension Array where Element == StoredArticle {
  func bmSorted() -> Self {
    self.sorted(by: {
      if $0.issueDate?.issueKey != $1.issueDate?.issueKey {
        return $0.issueDate?.ISO8601 ?? "0" > $1.issueDate?.ISO8601 ?? "1"
      }
      
      let section0MinOrder
      = $0.nonBookmarkSections.map { Int($0.pr.order) }.min() ?? Int.max
      let section1MinOrder
      = $1.nonBookmarkSections.map { Int($0.pr.order) }.min() ?? Int.max
      
      if section0MinOrder != section1MinOrder {
        return section0MinOrder < section1MinOrder
      }
  
      return $0.pr.order < $1.pr.order
    })
  }
  }
class BookmarkTVC: UIViewController, ContextMenuItemPrivider {
  
  private lazy var bookmarksTable:UITableView = {
    let tv = UITableView(frame: .zero, style: .plain)
    tv.register(BookmarksCell.self,
                            forCellReuseIdentifier: BookmarksCell.ReuseIdentifier)
    tv.register(BookmarkTableHeaderCell.self,
                forCellReuseIdentifier: BookmarkTableHeaderCell.ReuseIdentifier)
    tv.register(BookmarkTableFooterView.self,
                            forHeaderFooterViewReuseIdentifier: BookmarkTableFooterView.ReuseIdentifier)
    tv.separatorStyle = .none
    tv.estimatedRowHeight = 100.0
    tv.separatorInset = .zero
    if #available(iOS 15.0, *) {
      tv.sectionHeaderTopPadding = 0
    }
    tv.dataSource = self
    tv.delegate = self
    
//    tv.contentInset = UIEdgeInsets(top: Const.Dist2.m25, left: 0, bottom: 0, right: 0)
    tv.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    tv.bounces = true
    let longTap = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTap(sender:)))
    tv.addGestureRecognizer(longTap)
    
    tv.isHidden = true
    return tv
  }()
  
  
  public var menu: MenuActions? {
    return Bookmarks.shared.bookmarkIssue?._contextMenu(group: 0)
  }
  
  var headerPlayButtonContextMenu: ContextMenu?
  
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
  
  //groupedArticles.values.flatMap { $0 }
  private var groupedArticles: [String: [Article]] = [:] {
    didSet {
      let empty = groupedArticles.values.flatMap { $0 }.count == 0
      placeholderView.isHidden = !empty
      header.isHidden = empty
      bookmarksTable.isHidden = empty
    }
  }
  private var sortedSectionKeys: [String] = []
  
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
  @Default("bookmarksListTeaserEnabled")
  var bookmarksListTeaserEnabled: Bool
  // extension PlaceholderVC: DefaultScreenTracking {
//  public var defaultScreen: Usage.DefaultScreen? { .BookmarksEmpty }
  
  let placeholderView = PlaceholderView("Sie haben noch keine Artikel in Ihrer Leseliste.\n\nSpeichern Sie Artikel zum weiterlesen, hören oder erinnern in Ihrer persönlichen Leseliste. Einfach das Sternchen bei den Artikeln aktivieren.",
                            image: UIImage(named: "star"))
  
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
  
  func updateAudioButton(){
    self.headerPlayButton.buttonView.name
    = ArticlePlayer.singleton.isPlaying
    && (ArticlePlayer.singleton.currentContent as? Article)?.hasBookmark == true
    ? "audio-active"
    : "audio"
    self.headerPlayButton.buttonView.isHidden = Bookmarks.shared.bookmarkIssue?.hasAudio != true
  }

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
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateData()
    bookmarksTable.reloadData()///ugly to reload all rows
    applyStyles()
    updateAudioButton()
  }
}

extension BookmarkTVC {

  private var isActiveAndVisible: Bool {

      // Check if part of a UINavigationController
      if let navCtrl = self.navigationController {
          // If inside a UITabBarController, ensure it's the selected tab
          if let tabCtrl = navCtrl.parent as? UITabBarController {
              return tabCtrl.selectedViewController == navCtrl && navCtrl.visibleViewController == self
          }
          // Otherwise, ensure it's the visible view controller in the navigation stack
          return navCtrl.visibleViewController == self
      }

      // If part of a UITabBarController directly (not embedded in a nav controller)
      if let tabCtrl = self.parent as? UITabBarController {
          return tabCtrl.selectedViewController == self
      }

      // For other cases, check if it’s the root or presented directly
      return self.presentingViewController == nil
  }
  
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
}

extension BookmarkTVC: UITableViewDataSource,  UITableViewDelegate {
  
  @objc private func handleLongTap(sender: UILongPressGestureRecognizer) {
    if sender.state == .began {
      let touchPoint = sender.location(in: bookmarksTable)
      guard let indexPath = bookmarksTable.indexPathForRow(at: touchPoint) else { return }
      print("long tap at cell: \(indexPath)")
    }
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.row > 0 { return UITableView.automaticDimension }
    return indexPath.section == 0 ? 57.0 + Const.Dist2.m20 : 57.0
  }
  
  
  func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let cell = tableView.cellForRow(at: indexPath) as? BookmarksCell,
          let article = cell.article
    else { return nil }
    let openIssueAction = UIContextualAction(style: .normal, title: "Ausgabe\nanzeigen", handler: {[weak self] (_, _, completionHandler) in
      Notification.send(Const.NotificationNames.gotoIssue, content: article.issueDate, sender: self)
      completionHandler(true)
    }
          )
    // Show Current Cloud Upload Status
    openIssueAction.backgroundColor = .systemGreen
    openIssueAction.image = UIImage(systemName: "arrowshape.turn.up.right")//?.imageWith(size: CGSize(width: 20, height: 25), tintColor: .white)
    let swipeConfiguration = UISwipeActionsConfiguration(actions: [openIssueAction])
    return swipeConfiguration
  }
  func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard let cell = tableView.cellForRow(at: indexPath) as? BookmarksCell,
          let article = cell.article
    else { return nil }
      let deleteAction = UIContextualAction(style: .destructive, title: "löschen", handler: {(_, _, completionHandler) in
        self.removeBookmarkArticleCell(at: indexPath, article: article)
        Bookmarks.set(article: article, bookmarked: false)
        completionHandler(true)
    }
          )
    // Show Current Cloud Upload Status
    deleteAction.image = UIImage(systemName: "trash")//?.imageWith(size: CGSize(width: 20, height: 25), tintColor: .white)
    let swipeConfiguration = UISwipeActionsConfiguration(actions: [deleteAction])
    return swipeConfiguration
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
  
  
  func numberOfSections(in tableView: UITableView) -> Int {
    groupedArticles.keys.count
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      let sectionKey = sortedSectionKeys[section]
      return (groupedArticles[sectionKey]?.count ?? -1) + 1
  }
  
  func article(for indexPath: IndexPath) -> Article? {
    let sectionKey = sortedSectionKeys[indexPath.section]
    guard let articlesForSection = groupedArticles[sectionKey] else { return nil }
    if indexPath.row - 1  > articlesForSection.count { return nil }
    return articlesForSection[indexPath.row - 1]
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.row == 0 {
      // Header-Zelle
      guard let headerCell = tableView.dequeueReusableCell(withIdentifier: BookmarkTableHeaderCell.ReuseIdentifier, for: indexPath) as? BookmarkTableHeaderCell,
              let feed = Bookmarks.shared.bookmarkIssue?.feed as? StoredFeed else { return BookmarkTableHeaderCell() }
      
      let article = article(for: IndexPath(item: 1, section: indexPath.section))
      headerCell.dateLabel.text = article?.issueDate?.validityDateText(timeZone: GqlFeeder.tz, feed: feed)
      headerCell.image = lowresMomentImage(for: article)
      return headerCell
    }

    guard let cell
            = tableView.dequeueReusableCell(withIdentifier: BookmarksCell.ReuseIdentifier,
                                            for: indexPath) as? BookmarksCell,
          let article = article(for: indexPath) else { return BookmarksCell() }
    cell.article = article
    
    cell.onShare { [weak self] (art, sourceView) in
      self?.shareArticle(article: art, sourceView: sourceView)
    }
    
    
    if let issue = article.primaryIssue {
      cell.image = cell.article?.images?.first?.image(dir: issue.dir)?.invertedIfNeeded
    }
    else if let issueDate = article.issueDate,
            let dir = Bookmarks.shared.commonIssueDir(for: issueDate) {
      cell.image = cell.article?.images?.first?.image(dir: dir)?.invertedIfNeeded
    }
    
    let sectionKey = sortedSectionKeys[indexPath.section]
    cell.dottedLine.isHidden = groupedArticles[sectionKey]?.count == indexPath.row
    return cell
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
  
  // MARK: - UITableViewDelegate (optional, für Benutzerinteraktion)
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if let cell = tableView.cellForRow(at: indexPath) as? BookmarkTableHeaderCell,
       let article = article(for: IndexPath(item: 1, section: indexPath.section)) {
      Notification.send(Const.NotificationNames.gotoIssue, content: article.issueDate, sender: self)
    }
    
    guard let cell = tableView.cellForRow(at: indexPath) as? BookmarksCell,
          let article = cell.article,
          let avc = articleVC else { return }
    avc.index = avc.articles.firstIndex { $0.serverId == article.serverId } ?? 0
    self.navigationController?.pushViewController(avc, animated: true)
  }
  
  func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return 0.7
  }
  
  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    if section == sortedSectionKeys.count - 1 { return nil }
    return tableView.dequeueReusableHeaderFooterView(withIdentifier: BookmarkTableFooterView.ReuseIdentifier)
  }

  
  ///get moment image even if article is not in related issue
  private func lowresMomentImage(for article:Article?) -> UIImage? {
    guard let article = article,
          let issueDate = article.issueDate,
          let feed = Bookmarks.shared.bookmarkIssue?.feed as? StoredFeed,
          let issue = StoredIssue.get(date: issueDate, inFeed: feed).first,
          let image = issue.moment.lowres
    else { return nil }
   return UIImage(contentsOfFile: "\(issue.dir.path)/\(image.name)")
  }
    
}


extension BookmarkTVC: ScreenTracking {
  public var screenUrl:URL? { URL(path: "bookmarks/list") }
  public var screenTitle:String? { "Bookmarks List" }
}

extension BookmarkTVC: UIStyleChangeDelegate {
  public func applyStyles() {
    self.view.backgroundColor = Const.SetColor.HBackground.color
  }
}

///just a black/white line
fileprivate class BookmarkTableFooterView: UITableViewHeaderFooterView, UIStyleChangeDelegate{
  static let ReuseIdentifier = "BookmarkTableFooterViewIdentifier"
  var line: UIView = UIView()
  
  func applyStyles() {
    line.backgroundColor = Const.SetColor.HText.color
  }
  
  func setup() {
    line.backgroundColor = Const.SetColor.ios(.systemBackground).color
    //    topBorder = self.addBorderView(.black, edge: .top, insets: UIEdgeInsets(top: 0, left: Const.Size.DefaultPadding, bottom: 0, right: -Const.Size.DefaultPadding))
    self.contentView.addSubview(line)
    
    pin(line.left, to: self.contentView.left, dist: Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    pin(line.right, to: self.contentView.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    line.centerY()
    line.pinHeight(1.0)
    
    self.contentView.layoutMargins.left = Const.Size.DefaultPadding
    self.contentView.layoutMargins.right = Const.Size.DefaultPadding
    
    registerForStyleUpdates()
  }
  
  override init(reuseIdentifier: String?) {
    super.init(reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}
 
fileprivate class BookmarkTableHeaderCell: UITableViewCell, UIStyleChangeDelegate{
  
  static let ReuseIdentifier = "BookmarkTableHeaderViewIdentifier"
  
  var dateLabel: UILabel = UILabel()
  let dottedLine = DottedLineView()
  private let imgView = UIImageView()
  var image: UIImage? {
    didSet {
      imgView.image = image
      textLeftImageConstraint?.isActive = image != nil
    }
  }
  
  var active: Bool = false {
    didSet {
      dateLabel.textColor
      = active
      ? Const.SetColor.CIColor.color
      : Const.SetColor.ios(.label).color
      if active == false && oldValue == true {
        contentView.layoutSubviews()
      }
    }
  }
  
  func applyStyles() {
    contentView.backgroundColor = Const.SetColor.ios(.systemBackground).color
    dottedLine.fillColor = Const.SetColor.HText.color
    dottedLine.strokeColor = Const.SetColor.HText.color
  }
  var textLeftImageConstraint: NSLayoutConstraint?
  func setup(){
    dottedLine.offset = 1.7
    dottedLine.pinHeight(Const.Size.DottedLineHeight*0.7)
    self.contentView.addSubview(dottedLine)
    self.contentView.addSubview(dateLabel)
    self.contentView.addSubview(imgView)
    pin(dottedLine.left, to: self.contentView.left, dist: Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    pin(dottedLine.right, to: self.contentView.right, dist: -Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    pin(dottedLine.bottom, to: self.contentView.bottom)
    imgView.pinSize(CGSize(width: 28, height: 37))
    imgView.contentMode = .scaleAspectFit
    
    pin(dateLabel.left, to: self.contentView.left, dist: Const.Size.DefaultPadding, priority: .defaultLow)
    pin(dateLabel.right, to: self.contentView.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    
    pin(imgView.left, to: self.contentView.left, dist: Const.Size.DefaultPadding)
    pin(imgView.bottom, to: self.contentView.bottom, dist: -Const.Size.DefaultPadding + 5)
    pin(dateLabel.centerY, to: imgView.centerY)
    textLeftImageConstraint = pin(dateLabel.left, to: imgView.right, dist: Const.Dist2.s10)
    textLeftImageConstraint?.isActive = false
    
    self.contentView.layoutMargins.top = 0.0
    self.contentView.layoutMargins.left = Const.Size.DefaultPadding
    self.contentView.layoutMargins.right = Const.Size.DefaultPadding
    
    registerForStyleUpdates()
    dateLabel.boldContentFont()
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}

class BookmarksCell: NewContentTableVcCell {
  
  func onShare(closure:  ((Article, UIView)->())?) { _shareClosure = closure }
  private var _shareClosure: ((
    Article , UIView)->())?
  
  let shareButton = UIImageView(image: UIImage(named: "share"))
    
  override func updateStyles(){
    super.updateStyles()
    self.contentView.backgroundColor = Const.SetColor.ios(.systemBackground).color
  }
  
  override func setup() {
    super.setup()
    pin(dottedLine.bottom, to: self.contentView.bottom)
    shareButton.tintColor = Const.Colors.appIconGrey
    content.addSubview(shareButton)
    shareButton.pinSize(CGSize(width: 26, height: 26))
    pin(shareButton.right, to: bookmarkButton.left, dist: -10)
    pin(shareButton.centerY, to: bookmarkButton.centerY)
    
    shareButton.onTapping {[weak self] _ in
      onMainAfter(0.1){[weak self] in ///prevent additional  cell tap due async call
        if let article = self?.article, let self = self {
          self._shareClosure?(article, self.shareButton)
        }
      }
    }
  }
  
}
