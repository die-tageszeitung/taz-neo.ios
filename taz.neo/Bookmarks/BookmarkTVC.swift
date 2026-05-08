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
  
  @Default("autoSyncBookmarks")
  var autoSyncBookmarks: Bool
  
  @Default("requestedSyncBookmarks")
  var requestedSyncBookmarks: Bool
  
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
  private var _articleVC: ArticleVC? {
    didSet { if oldValue != nil {
//      oldValue?.releaseOnDisappear()
    }}
  }
  private var articleVC: ArticleVC? {
    if _articleVC == nil,
       let issueInfo = Bookmarks.shared.issueInfo {
      _articleVC =  ArticleVC(feederContext: issueInfo.feederContext)
      _articleVC?.delegate = issueInfo
    }
    return _articleVC
  }
  
  lazy var header:SettingsHeaderView = {
    let v = SettingsHeaderView()
    v.titletype = .bigLeft
    v.title = App.isLMD ? "Leseliste" :"leseliste"
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
  
  private lazy var placeholderView: BookmarksEmptyStateView = {
    let view = BookmarksEmptyStateView("Sie haben keine Artikel in Ihrer Leseliste.\n\nSpeichern Sie Artikel zum weiterlesen, hören oder erinnern in Ihrer persönlichen Leseliste. Einfach das Sternchen bei den Artikeln aktivieren.",
                                              image: UIImage(named: "star"))
    view.syncLabel.text = "Leseliste jetzt synchronisieren."
    
    Task {
      var hasRemoteBookmarks = false
      do { hasRemoteBookmarks = try await BookmarksSyncBusiness.hasRemoteBookmarks()
      } catch { print("Error due Sync:", error) }
      await MainActor.run {[weak self] in view.syncLabel.isHidden = !hasRemoteBookmarks }
    }

    view.syncLabel.onTapping {[weak self] _ in
      view.spinner.isHidden = false
      view.syncLabel.hideAnimated()
      view.spinner.startAnimating()
      self?.syncBookmarksIfNeeded(syncReason: .manual, finishNoChangeMessage: "Keine Lesezeichen zum Synchronisieren gefunden.")
    }
    return view
  }()
  
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
  
  func requestDeleteAllBookmarks(){
    Alert.confirm(message: "Alle Lesezeichen löschen?", okText: "Löschen", isDestructive: true) {[weak self] choice in
      guard choice == true else { return }
      Bookmarks.shared.removeAllBookmarks()
      self?.updateData()
      self?.bookmarksTable.reloadData()
      guard self?.autoSyncBookmarks == true else { return }
      self?.syncBookmarksIfNeeded(syncReason: .manual)
    }
  }
  
  enum SyncReason {
    case manual
    case bookmarksAppeared
    case goingBackgroundForeground
  }
  
  var showRequiredLoginForSyncAlert:Bool = false
  
  private func syncBookmarksIfNeeded(syncReason:SyncReason, finishNoChangeMessage:String? = nil){
    if TazAppEnvironment.isAuthenticated == false {
      if showRequiredLoginForSyncAlert { return }
      showRequiredLoginForSyncAlert = true
      Alert.actionSheet(message: "Sie müssen angemeldet sein, um diese Funktion zu nutzen!",
                        actions: [UIAlertAction.init( title: "Anmelden",
                                                     style: .default ){_ in
        TazAppEnvironment.sharedInstance.feederContext?.authenticate()
      }],  completion: {[weak self] in
        self?.showRequiredLoginForSyncAlert = false
      })
      return
    }
    
    if syncReason != .manual && autoSyncBookmarks == false { return }
    
    let lastSync = BookmarksSyncBusiness.lastBookmarkSyncDate ?? .distantPast
    
    if syncReason == .bookmarksAppeared {
      ///user maybe wants auto-synced bookmarks quite early but not with every tap on bookmarks
      guard Date() > lastSync.addingTimeInterval(5 * 60) else { return }
    }
    else if syncReason == .goingBackgroundForeground {
      ///twice in a hour auto sync is enought here
      guard Date() > lastSync.addingTimeInterval(30 * 60) else { return }
    }
    ///on manual sync, sync everytime
    
    headerSyncButton.isHidden = false
    headerSyncButton.startRotating()
    var hasChanges: Bool = false
    
    Task {
      do {
        hasChanges =
        try await BookmarksSyncBusiness.sync(localBookmarks: Bookmarks.shared.bookmarkedArticles)
        
      } catch {
        print("Error due Sync:", error)
      }
      await MainActor.run {[weak self] in
        self?.syncBookmarksFinished(hasChanges, finishNoChangeMessage: finishNoChangeMessage)
      }
    }
  }
  
  private func syncBookmarksFinished(_ hasChanges: Bool, finishNoChangeMessage:String? = nil){
    if hasChanges {
      Bookmarks.shared.reloadBookmarksFromDatabase()
      updateData()
      bookmarksTable.reloadData()
      articleVC?.setup()///re-init delegate!
      updateAudioButton()
    }
    else if let msg = finishNoChangeMessage {
      Toast.show(msg)
    }
    if placeholderView.spinner.isAnimating {
      placeholderView.spinner.stopAnimating()
      placeholderView.spinner.hideAnimated()
    }
    onMainAfter(1.0) {[weak self] in
      self?.headerSyncButton.stopRotating()
      self?.headerSyncButton.isHidden = true
    }
  }
  
  private var remoteAudioContent: [Article] {
    var dlContent: [Article] = []
    for art in Bookmarks.shared.bookmarkedArticles {
      guard let fileEntry = art.audioItem?.file else { continue }
      let localFilePath = art.dir.path + "/" + fileEntry.name
      let file = File(localFilePath)
      if file.exists == false {  dlContent.append(art) }
    }
    return dlContent
  }
  
  private func downloadAllAudio(){
    let dlContent = remoteAudioContent
    guard dlContent.count > 0 else {
      Toast.show("Alle Audioinhalte der Leseliste wurden bereits heruntergeladen.")
      return
    }
    debug("can download \(dlContent.count) items")
    Bookmarks.downloadAllAudio(dlContent: dlContent)
  }
  
  private lazy var headerMoreButton: UIButton = {
    let btn = UIButton()
    btn.setImage(UIImage(named: "ellipsis-circle"), for: .normal)
    btn.pinSize(CGSize(width: 27, height: 27))
    btn.tintColor = Const.Colors.appIconGrey
    if #available(iOS 14.0, *) {
      btn.addTarget(self, action: #selector(updateMenuBeforeOpen), for: .touchDown)
      btn.showsMenuAsPrimaryAction = true
      btn.menu = moreButtonMenu
    }
    return btn
  }()
  
  @available(iOS 14.0, *)
  @objc private func updateMenuBeforeOpen() {
      headerMoreButton.menu = moreButtonMenu
  }
  
  private var moreButtonMenu: UIMenu? {
    get {
      guard #available(iOS 14.0, *) else {
        return nil
      }
      
      let deleteAllAction = UIAction(
        title: "Alle Lesezeichen löschen",
        image: UIImage(systemName: "trash"), attributes: [.destructive]) {[weak self] _ in
          self?.requestDeleteAllBookmarks()
        }
      let autoSyncAction = UIAction(
        title: "Leseliste automatisch synchronisieren"/*,
                                                       image: UIImage(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")*/) {[weak self] _ in
                                                         self?.autoSyncBookmarks.toggle()
                                                         guard self?.autoSyncBookmarks == true else { return }
                                                         self?.syncBookmarksIfNeeded(syncReason: .manual)
                                                       }
      autoSyncAction.state = autoSyncBookmarks ? .on : .off
      let syncAction = UIAction(
        title: "Leseliste jetzt synchronisieren",
        image: UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90")) {[weak self] _ in
          self?.syncBookmarksIfNeeded(syncReason: .manual)
        }
      let lastSyncInfo = UIAction(
        title: "Letzte Synchronisierung:\n\(BookmarksSyncBusiness.lastBookmarkSyncAgoString)"){_ in }
      lastSyncInfo.attributes = [.disabled]
      
      let downloadAllAudioAction = UIAction(
        title: "Alle Audioinhalte der Leseliste herunterladen",
        image: UIImage(named: "download")) {[weak self] _ in
          self?.downloadAllAudio()
        }
      
      var otherActions: [UIAction] = []
      
      if remoteAudioContent.count > 0 {
        otherActions.append(downloadAllAudioAction)
      }
      
      if Bookmarks.shared.bookmarkedArticles.count > 0 {
        otherActions.append(deleteAllAction)
      }
      
      let syncMenu: UIMenu
      = UIMenu(title: "Synchronisierung",
               options: .displayInline,
               children: [autoSyncAction, syncAction, lastSyncInfo])
      var menuActions: [UIMenu] = [syncMenu]
      
      if otherActions.count > 0 {
        let defaultMenu = UIMenu(title: "Allgemein", options: .displayInline, children: otherActions)
        menuActions.insert(defaultMenu, at: 0) }
      
      return UIMenu(title: "", children: menuActions)
    }
  } 
  
  private lazy var headerSyncButton: UIButton = {
    let btn = UIButton()
    btn.setImage(UIImage(name: "arrow.trianglehead.2.clockwise.rotate.90"), for: .normal)
    btn.pinSize(CGSize(width: 27, height: 27))
    btn.tintColor = Const.Colors.appIconGrey
    btn.isHidden = true
    return btn
  }()
  
  var headerPlayButtonContextMenu: ContextMenu?
  
  public var menu: MenuActions? {
    return Bookmarks.shared.bookmarkIssue?._contextMenu(group: 0)
  }
  
  // MARK: - Lifecycle
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    placeholderView.syncLabel.isHidden = false
    
    if requestedSyncBookmarks && autoSyncBookmarks {
      syncBookmarksIfNeeded(syncReason: .bookmarksAppeared)
    }
    ///just ask the user once if auto sync should be done
    if requestedSyncBookmarks == true { return }
    
    let autoSyncAction =  UIAlertAction.init( title: "Automatisch Synchronisieren",
                                          style: .default) {  [weak self] _ in
      self?.autoSyncBookmarks = true
      self?.syncBookmarksIfNeeded(syncReason: .manual)
    }
    
    let cancelAction =  UIAlertAction.init( title: "Nicht Synchronisieren",
                                            style: .cancel)

    Alert.message(message: "Möchten Sie Ihre Leseliste mit anderen Geräten, mit denen Sie die taz lesen synchronisieren?",
                      actions: [autoSyncAction, cancelAction], presentationController: self)
    requestedSyncBookmarks = true
  }
    
    
  
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
    self.header.addSubview(headerMoreButton)
    self.header.addSubview(headerSyncButton)
    pin(headerPlayButton.right, to: self.header.right, dist: -10)
    pin(headerMoreButton.right, to: headerPlayButton.left, dist: -10)
    pin(headerSyncButton.right, to: headerMoreButton.left, dist: -10)
    pin(headerPlayButton.centerY, to: header.titleLabel.centerY)
    pin(headerMoreButton.centerY, to: header.titleLabel.centerY)
    pin(headerSyncButton.centerY, to: header.titleLabel.centerY)
    headerPlayButton.activeColor = Const.SetColor.taz2(.text).color
    headerPlayButtonContextMenu = ContextMenu(view: headerPlayButton.buttonView)
    headerPlayButtonContextMenu?.itemPrivider = self
    
    Notification.receive(Const.NotificationNames.audioPlaybackStateChanged) { [weak self] _ in
      self?.updateAudioButton()
    }
    
    Notification.receive(UIApplication.willResignActiveNotification) { [weak self] _ in
      self?.syncBookmarksIfNeeded(syncReason: .goingBackgroundForeground)
    }
    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.syncBookmarksIfNeeded(syncReason: .goingBackgroundForeground)
    }
    
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      if let art = msg.sender as? StoredArticle {
        self?.handleBookmarkChanged(for: art)
      } else {
        self?.updateData()
        self?.bookmarksTable.reloadData()///ugly to reload all rows
      }
    }
    guard #available(iOS 14.0, *) else { headerMoreButton.isHidden = true; return}
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
    guard articleVC != nil else { return }
    ArticleExportDialogue.show(article: article,
                               image: article.cellIconImage,
                               sourceView: sourceView)
  }
  
  func open(article: Article){
    if article.isReducedArticle
        && TazAppEnvironment.sharedInstance.feederContext?.isConnected == true
        && TazAppEnvironment.hasValidAuth {
      if article.serverId != nil {
        loadAndOpen(article: article)
        return
      }
      log("article has no serverId, cannot load article...open it")
      Toast.show("<b>Hinweis:</b> Dieser Eintrag scheint beschädigt zu sein.<br>Bitte löschen Sie ihn und fügen Sie ihn bei Bedarf erneut hinzu.")
    }
    guard let avc = articleVC else { return }
    let idx = avc.articles.firstIndex { $0.serverId == article.serverId } ?? 0
    avc.gotoIndex(index: idx)
    
    self.navigationController?.pushViewController(avc, animated: true)
  }
  
  ///handler for tap in List on demo Article
  private func loadAndOpen(article: Article){
    let serverId = article.serverId ///remember bevore reload article
    Notification.receiveOnce(Const.NotificationNames.bookmarksLoaded) { [weak self] _ in
      ///ensure Tabledata is refreshed earlier
      onMainAfter(0.2) {[weak self] in
        guard let avc = self?.articleVC else { return }
        let idx = avc.articles.firstIndex { $0.serverId == serverId } ?? 0
        avc.gotoIndex(index: idx)
        self?.navigationController?.pushViewController(avc, animated: true)
      }
    }
    let snap = UIWindow.activeKeyWindow?.snapshotView(afterScreenUpdates: false)
    WaitingAppOverlay.show(alpha: 1.0,
                           backbround: snap,
                           showSpinner: true,
                           titleMessage: "Aktualisiere Daten",
                           bottomMessage: "Bitte haben Sie einen Moment Geduld!",
                           dismissNotification: Const.NotificationNames.bookmarksLoaded)
    reloadOpened()
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
    let dict = Dictionary(grouping: Bookmarks.shared.bookmarkedArticles.bookmarkOrder(), by: { article in (article.issueDate ?? Date(timeIntervalSince1970: 0)).isoDate() })
    
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
    guard let indexPath = indexPath(for: article) else {
      ///added bookmark!
      updateData()
      bookmarksTable.reloadData()
      return
    }
    if article.hasBookmark == false {
      self.removeBookmarkArticleCell(at: indexPath, article: article)
    }
  }
  
  
  func updateAudioButton(){
    self.headerPlayButton.buttonView.name
    = (ArticlePlayer.singleton.currentPlayingContent as? Article)?.hasBookmark == true
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
  
  var shouldReload: Bool {
    guard (groupedArticles.values.flatMap { $0 })
      .filter({ $0.isReducedArticle }).count > 0 else { return false }
    guard TazAppEnvironment.hasValidAuth else { return false }
    return true
  }
  
  public func reloadOpened(){
    ///check if demo articles in table then reload
    guard shouldReload else {
      Notification.send(Const.NotificationNames.bookmarksLoaded, sender: nil)
      return
    }
    var reloadArtIndex: Int?
    
    if let artVc = self.navigationController?.viewControllers.last as? ArticleVC {
      artVc.navigationController?.popToRootViewController(animated: false)
      reloadArtIndex = artVc.index
    }
    
    _articleVC = nil///ensure re-init; set articles, content and updateWebwiews() did not worked
    
    Notification.receiveOnce(Const.NotificationNames.bookmarksLoaded) { [weak self] _ in
      ///Reload Overview Table
      self?.updateData()
      self?.bookmarksTable.reloadData()
      
      guard let reloadArtIndex = reloadArtIndex else {
        /// no article reopen needed; e.g. loadAndOpen(article: Article) sets and pushes correct articleVc himself
        return
      }
      guard let avc = self?.articleVC else { return }
      ///handle exchange event comes in while on articleVC, not in list
      avc.gotoIndex(index: reloadArtIndex)
      self?.navigationController?.pushViewController(avc, animated: true)
    }
    Bookmarks.shared.loadFullArticlesIfNeeded()
  }
}


extension UIView {
  func startRotating(duration: CFTimeInterval = 2) {
    // Verhindert doppelte Animationen
    if self.layer.animation(forKey: "rotationAnimation") != nil {
      return
    }
    
    let rotation = CABasicAnimation(keyPath: "transform.rotation")
    rotation.fromValue = 0
    rotation.toValue = CGFloat.pi * 2
    rotation.duration = duration
    rotation.repeatCount = Float.infinity
    rotation.isRemovedOnCompletion = false
    
    self.layer.add(rotation, forKey: "rotationAnimation")
  }
  
  func stopRotating() {
    self.layer.removeAnimation(forKey: "rotationAnimation")
  }
}
