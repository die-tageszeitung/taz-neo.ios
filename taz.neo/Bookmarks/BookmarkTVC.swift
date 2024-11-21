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

fileprivate extension Array where Element == StoredArticle {
  func sorted() -> Self {
    self.sorted(by: {
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
class BookmarkTVC: UIViewController {
  
  private lazy var bookmarksTable:UITableView = {
    let tv = UITableView(frame: .zero, style: .plain)
    tv.register(BookmarksCell.self,
                            forCellReuseIdentifier: BookmarksCell.ReuseIdentifier)
    tv.register(BookmarkTableHeaderView.self,
                            forHeaderFooterViewReuseIdentifier: BookmarkTableHeaderView.ReuseIdentifier)
    tv.register(BookmarkTableFooterView.self,
                            forHeaderFooterViewReuseIdentifier: BookmarkTableFooterView.ReuseIdentifier)
    tv.rowHeight = UITableView.automaticDimension
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
  
  override func viewDidLoad() {
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
   
    
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      if let art = msg.sender as? StoredArticle {
        self?.handleBookmarkChanged(for: art)
      }
    }
  }
  
  private func indexPath(for article: Article) -> IndexPath? {
    guard let serverId = article.serverId else { return nil }
    for (sectionKey, articles) in groupedArticles {
      if let aIdx = articles.firstIndex(where: { $0.serverId == serverId }) {
        if let sIdx = sortedSectionKeys.firstIndex(where: {$0 == sectionKey }) {
          return IndexPath(row: aIdx, section: sIdx)
          
        }
        return nil
      }
    }
    return nil
  }
  
  func handleBookmarkChanged(for article: StoredArticle){
    Bookmarks.shared.issueInfo?.updateData()
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
    self.removeBookmarkArticleCell(at: indexPath)
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateData()
    bookmarksTable.reloadData()///ugly to reload all rows
    applyStyles()
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
    let dict = Dictionary(grouping: Bookmarks.shared.bookmarkedArticles, by: { article in (article.issueDate ?? Date(timeIntervalSince1970: 0)).isoDate() })
    
    var out: [String: [StoredArticle]] = [:]
    
    for (sectionKey, articles) in dict {
      //Cannot use mutating member on immutable value: 'articles' is a 'let' constant
      out[sectionKey] = articles.sorted()
      
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
        self.removeBookmarkArticleCell(at: indexPath)
        Bookmarks.set(article: article, bookmarked: false)
        completionHandler(true)
    }
          )
    // Show Current Cloud Upload Status
    deleteAction.image = UIImage(systemName: "trash")//?.imageWith(size: CGSize(width: 20, height: 25), tintColor: .white)
    let swipeConfiguration = UISwipeActionsConfiguration(actions: [deleteAction])
    return swipeConfiguration
  }
  
  func removeBookmarkArticleCell(at indexPath: IndexPath){
    let sectionKey = sortedSectionKeys[indexPath.section]
    guard var articlesInSection = groupedArticles[sectionKey] else { return }
    
    // Entferne den Artikel aus der Datenquelle
    articlesInSection.remove(at: indexPath.row)
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
      return groupedArticles[sectionKey]?.count ?? 0
  }
  
  func article(for indexPath: IndexPath) -> Article? {
    let sectionKey = sortedSectionKeys[indexPath.section]
    guard let articlesForSection = groupedArticles[sectionKey] else { return nil }
    return articlesForSection[indexPath.row]
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell
            = tableView.dequeueReusableCell(withIdentifier: BookmarksCell.ReuseIdentifier,
                                            for: indexPath) as? NewContentTableVcCell,
          let article = article(for: indexPath) else { return BookmarksCell() }
    cell.article = article
    if let issue = article.primaryIssue {
      cell.image = cell.article?.images?.first?.image(dir: issue.dir)?.invertedIfNeeded
    }
    let sectionKey = sortedSectionKeys[indexPath.section]
    cell.dottedLine.isHidden = groupedArticles[sectionKey]?.count == indexPath.row + 1
    return cell
  }
  
  // MARK: - UITableViewDelegate (optional, für Benutzerinteraktion)
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let cell = tableView.cellForRow(at: indexPath) as? BookmarksCell,
          let article = cell.article,
          let avc = articleVC else { return }
    #warning("TODODODODOD")
//    let index = articles.firstIndex{ $0.serverId == article.serverId }
    avc.index = 0
    self.navigationController?.pushViewController(avc, animated: true)
  }
  
  func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return 1.0
  }
  
  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    if section == sortedSectionKeys.count - 1 { return nil }
    return tableView.dequeueReusableHeaderFooterView(withIdentifier: BookmarkTableFooterView.ReuseIdentifier)
  }
  
  func tableView1(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    let v = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.longSide, height: 1))
      v.backgroundColor = .black
    #warning("not handlet darkmode change")
    return v
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    if section == 0 { return 55.0 + Const.Dist2.m25}
    return 55.0
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
    
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: BookmarkTableHeaderView.ReuseIdentifier)
            as? BookmarkTableHeaderView,
          let feed = Bookmarks.shared.bookmarkIssue?.feed as? StoredFeed
    else { return nil}
    let article = article(for: IndexPath(row: 0, section: section))
    header.dateLabel.text = article?.issueDate?.validityDateText(timeZone: GqlFeeder.tz, feed: feed)
    header.image = lowresMomentImage(for: article)
//    header.topBorderHidden = section == 0
    
        
    header.onTapping { [weak self] gr in
//      guard let _header = gr.view as? ContentTableHeaderFooterView else { return }
//      self?.sectionPressedClosure?(_header.tag)
//      _header.active = true
//      _header.collapsed = false
//      self?.collapseAll(expect: _header.tag)
//      Usage.track(isImprint ? Usage.event.drawer.action_tap.Imprint : Usage.event.drawer.action_tap.Section)
    }
    
    return header
  }
  
  
  /*
  public override  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: Self.SectionHeaderIdentifier)
            as? ContentTableHeaderFooterView else { return nil}
    
    if let ressort = issue?.sections?.valueAt(section) {
      header.label.text = ressort.name
      let unexpandable = ressort.type == .advertisement || ressort.type == .podcast
      header.chevron.isHidden = unexpandable
      header.dottedLine.isHidden = unexpandable
    } else if section == issue?.sections?.count ?? 0 {
      header.label.text = issue?.imprint?.title ?? "Impressum"
      header.chevron.isHidden = true
      header.dottedLine.isHidden = true
    } else {
      header.label.text = nil
      header.chevron.isHidden = true
      header.dottedLine.isHidden = true
    }
    
    header.collapsed = !expandedSections.contains(section)

    header.tag = section
    header.topSeperator?.isHidden = section == 0
    
    let isImprint = section == issue?.sections?.count ?? 0
    
    header.onTapping { [weak self] gr in
      guard let _header = gr.view as? ContentTableHeaderFooterView else { return }
      self?.sectionPressedClosure?(_header.tag)
      _header.active = true
      _header.collapsed = false
      self?.collapseAll(expect: _header.tag)
      Usage.track(isImprint ? Usage.event.drawer.action_tap.Imprint : Usage.event.drawer.action_tap.Section)
    }
    
    header.chevronTapArea.onTapping {  [weak self] gr in
      ///fixes memory leak
      ///ugly but working first superview is _UITableViewHeaderFooterContentView due chevronTapArea is added to contentView
      ///on refactor my just pass closure/handler
      guard let _header = gr.view?.superview?.superview as? ContentTableHeaderFooterView else { return }
      _header.collapsed = self?.toggle(section: _header.tag) ?? true
      Usage.track(Usage.event.drawer.action_toggle.Section)
    }
    header.active = section == sectIndex
    return header
  }*/
  /*
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let art = issue?.sections?.valueAt(indexPath.section)?.articles?.valueAt(indexPath.row) else {
      log("Article you tapped not found for section: \(indexPath.section), row: \(indexPath.row)")
      return
    }
    Usage.track(Usage.event.drawer.action_tap.Article)
    articlePressedClosure?(art)
  }
  
  public func tableView(_ tableView: UITableView,
                                 cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell
    = tableView.dequeueReusableCell(withIdentifier: Self.CellIdentifier,
                                    for: indexPath) as? NewContentTableVcCell
    ?? NewContentTableVcCell()
    cell.article = issue?.sections?.valueAt(indexPath.section)?.articles?.valueAt(indexPath.row)
    cell.image = cell.article?.images?.first?.image(dir: issue?.dir)?.invertedIfNeeded
    cell.active = indexPath == activeItem
    return cell
  }*/
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
 
fileprivate class BookmarkTableHeaderView: UITableViewHeaderFooterView, UIStyleChangeDelegate{
  
  static let ReuseIdentifier = "BookmarkTableHeaderViewIdentifier"
  
  var dateLabel: UILabel = UILabel()
  let dottedLine = DottedLineView()
  private let imageView = UIImageView()
  var image: UIImage? {
    didSet {
      imageView.image = image
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
    self.contentView.addSubview(imageView)
    pin(dottedLine.left, to: self.contentView.left, dist: Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    pin(dottedLine.right, to: self.contentView.right, dist: -Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    pin(dottedLine.bottom, to: self.contentView.bottom)
    imageView.pinSize(CGSize(width: 25, height: 34))
    imageView.contentMode = .scaleAspectFit
    
    pin(dateLabel.left, to: self.contentView.left, dist: Const.Size.DefaultPadding, priority: .defaultLow)
    pin(dateLabel.right, to: self.contentView.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    
    pin(imageView.left, to: self.contentView.left, dist: Const.Size.DefaultPadding)
    pin(imageView.bottom, to: self.contentView.bottom, dist: -Const.Size.DefaultPadding)
    pin(dateLabel.centerY, to: imageView.centerY)
    textLeftImageConstraint = pin(dateLabel.left, to: imageView.right, dist: Const.Dist2.s10)
    textLeftImageConstraint?.isActive = false
    
    self.contentView.layoutMargins.top = 0.0
    self.contentView.layoutMargins.left = Const.Size.DefaultPadding
    self.contentView.layoutMargins.right = Const.Size.DefaultPadding
    
    registerForStyleUpdates()
    dateLabel.boldContentFont()
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

class BookmarksCell: NewContentTableVcCell {
  override func updateStyles(){
    super.updateStyles()
    self.contentView.backgroundColor = Const.SetColor.ios(.systemBackground).color
  }
  
  override func setup() {
    super.setup()
    pin(dottedLine.bottom, to: self.contentView.bottom)
  }
  
}
