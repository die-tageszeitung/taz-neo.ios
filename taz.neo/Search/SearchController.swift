//
//  self.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib

class SearchController: UIViewController {
  // MARK: *** Properties ***
  var feederContext: FeederContext
  
  private let defaultSection
  = BookmarkSection(name: "Suche",
                    html: TmpFileEntry(name: "SearchTempSection.tmp"))
  
  private var srIssue:SearchResultIssue
  private var lastArticleShown: Article?
  
  private var articleVC:SearchResultArticleVc
  
  var searchItem:SearchItem = SearchItem() {
    didSet {
      updateArticleVcIfNeeded()
      var textColor:UIColor?
      var message: String?
      let rCount = searchItem.resultCount
      if let currentCount = rCount.currentCount, let totalCount = rCount.total {
        message = "\(totalCount)/\(currentCount) Treffer"
      }
      else if let count = rCount.currentCount {
        message = "\(count) Treffer"
      }
      else if let count = rCount.total {
        message = "\(count) Treffer"
      }
      else if resultsTable.isHidden == false {
        message = "Keine Treffer"
        textColor = .red
      }
      header.updateHeaderStatusWith(text: message, color: textColor)
      resultsTable.searchItem = searchItem
    }
  }
  
  // MARK: *** UIComponents ***
  private lazy var resultsTable:SearchResultsTableView = {
    let v = SearchResultsTableView()
    v.searchClosure = { [weak self] in
      self?.search()
    }
    v.openSearchHit = { [weak self] hit in
      self?.openSearchHit(hit)
    }
    v.handleScrolling = { [weak self] (offset,end) in
      self?.header.setHeader(scrollOffset: offset, animateEnd: end)
    }
    v.isHidden = true
    return v
  }()
  
  lazy var header:SearchHeaderView = {
    let header = SearchHeaderView()
    
    header.cancelButton.addTarget(self,
                   action: #selector(self.handleCancelButton),
                   for: .touchUpInside)
    
    header.extendedSearchButton.onTapping { [weak self] _ in
      self?.header.setHeader(showMaxi: true)
      self?.searchSettingsView.toggle()
      self?.checkFilter()
    }
    header.searchClosure = { [weak self] in
      self?.search()
    }
    return header
  }()
  
  lazy var searchSettingsView:SearchSettingsView = {
    let v = SearchSettingsView(frame: .zero, style: .grouped)
    v.backgroundView = UIView()
    v.backgroundView?.onTapping {[weak self] _ in
      v.toggle(toVisible: false)
      self?.checkFilter()
    }
    v.searchButton.addTarget(self,
                             action: #selector(self.handleSearchButton),
                             for: .touchUpInside)
    v.propertyChanged = { [weak self] in
      self?.checkFilter()
      self?.header.checkCancelButton()
    }
    return v
  }()
  
  lazy var placeholderView: UIView = {
    let v = UILabel()
    v.text = "Suche nach Autor*innen, Artikeln, Rubriken oder Themen"
    v.textAlignment = .center
    v.numberOfLines = 0
    v.boldContentFont()
    v.textColor = .lightGray
    #warning("Wrong on ipad change traits todo implement!")
    v.pinWidth(UIWindow.shortSide - 2*Const.Size.DefaultPadding)
    return v
  }()
    
  // MARK: *** Lifecycle ***
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let lastArticle = lastArticleShown,
       let hitList = searchItem.searchHitList,
       let idx = hitList.firstIndex(where: { lastArticle.isEqualTo(otherArticle: $0.article)}) {
      resultsTable.scrollToRow(at: IndexPath(row: idx, section:0 ), at: .top, animated: false)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = Const.SetColor.CTBackground.color
    self.view.addSubview(placeholderView)
    self.view.addSubview(resultsTable)
    self.view.addSubview(searchSettingsView)
    self.view.addSubview(header)
    
    placeholderView.center()
    pin(resultsTable, toSafe: self.view, exclude: .top)
    pin(resultsTable.top, to: header.bottom)
    header.topConstraint = pin(header, to: self.view, exclude: .bottom).top
    pin(searchSettingsView.left, to: self.view.left)
    pin(searchSettingsView.right, to: self.view.right)
    searchSettingsView.topConstraint
    = pin(searchSettingsView.top, to: header.bottom, dist: -UIWindow.size.height)
    searchSettingsView.bottomConstraint
    = pin(searchSettingsView.bottom, to: self.view.bottom, dist: -UIWindow.size.height)
    
    feederContext.updateResources()
  }
  
  required init(feederContext: FeederContext) {
    self.feederContext = feederContext
    srIssue = SearchResultIssue(feed: feederContext.defaultFeed)
    srIssue.sections = [defaultSection]
    articleVC = SearchResultArticleVc(feederContext: self.feederContext)
    
    super.init(nibName: nil, bundle: nil)
    
    self.articleVC.searchClosure = { [weak self] in
      self?.search()
    }
    articleVC.delegate = self
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Helper Functions -
extension SearchController {
  func restoreInitialState() -> Bool{
    if resultsTable.restoreInitialState() == false {
      return false
    }
    return true
  }
  
  func updateArticleVcIfNeeded(){
    self.articleVC.feederContext = self.feederContext
    self.articleVC.baseDir = Dir.appSupportPath
    guard let allArticles = searchItem.allArticles else { return }
    defaultSection.articles = allArticles
    articleVC.maxResults = self.searchItem.resultCount.currentCount ?? 0
    srIssue.search = self.searchItem
    articleVC.searchContents = allArticles
    articleVC.reload()
  }
  
  private func openSearchHit(_ searchHit: GqlSearchHit){
    feederContext.dloader.downloadSearchResultFiles(url: searchHit.baseUrl, files: searchHit.article.files) {[weak self] err in
      guard let self = self else { return }
      if let err = err {
        self.log("Download error, try to display Article: \(err)")
      }
      self.updateArticleVcIfNeeded()
      if let path = searchHit.localPath {
        self.articleVC.gotoUrl(path)//otherwise idx 0 will be loaded, header not set probably
      }
      self.articleVC.reload()
      if self.articleVC.parentViewController == nil {
//        this.setHeader(artIndex: idx)
        self.navigationController?.pushViewController(self.articleVC, animated: true)
      }
    }
  }

  private func search() {
    var searchSettings = self.searchSettingsView.data.settings
    searchSettings.text = header.searchTextField.text
    if searchSettings.searchTermTooShort {
      header.updateHeaderStatusWith(text: "Bitte Suchbegriff eingeben!",
                                    color: .red)
      return
    }
    
    header.searchTextField.resignFirstResponder()
    searchSettingsView.toggle(toVisible: false)
    header.miniHeaderLabel.text = searchSettings.miniHeaderText

    if searchItem.settings != searchSettings {
      searchItem.settings = searchSettings
    }
    
    if searchItem.sessionId == nil {
      resultsTable.isHidden = true
      resultsTable.scrollTop()
    }
    
    guard let feeder = feederContext.gqlFeeder else { return }
    #warning("show spinner")
    feeder.search(searchItem: searchItem) { [weak self] result in
      guard let self = self else { return }
    #warning("hide spinner")
      self.resultsTable.isHidden = false
      switch result {
        case .success(let updatedSearchItem):
          for searchHit in updatedSearchItem.lastResponse?.search.searchHitList ?? [] {
            searchHit.writeToDisk()
          }
          self.searchItem = updatedSearchItem
        case .failure(let err):
          self.header
            .updateHeaderStatusWith(text: "Fehler, bitte erneut versuchen!",
                                    color: .red)
          self.log("an error occoured... \(err)")
      }
    }
  }
  
  func checkFilter(){
      self.header.filterActive
      = self.searchSettingsView.data.settings.isChanged
  }
  
  @objc func handleCancelButton(){
    if searchSettingsView.isOpen {
      searchSettingsView.toggle(toVisible: false)
      return
    }
    else if resultsTable.isVisible && header.searchTextField.isFirstResponder {
      header.searchTextField.resignFirstResponder()
      return
    }
    header.searchTextField.resignFirstResponder()
    header.searchTextField.text = nil
    searchSettingsView.restoreInitialState()
    searchSettingsView.toggle(toVisible: false)
    self.checkFilter()
    resultsTable.isHidden = true
    header.checkCancelButton()
    searchItem = SearchItem()
  }
  
  @objc func handleSearchButton(){
    searchSettingsView.toggle(toVisible: false)
    checkFilter()
    search()
  }
}

// MARK: - ArticleVCdelegate -
extension SearchController: ArticleVCdelegate {
  public var issue: Issue {
    return self.srIssue
  }
  
  public var section: Section? {
    debug("TODO:: section requested")
    return nil
  }
  
  public var sections: [Section] {
    debug("TODO:: sections array requested")
    return []
  }
  
  public var article: Article? {
    get { return lastArticleShown }
    set { lastArticleShown = newValue }
  }
  
  public var article2section: [String : [Section]] {
    debug("TODO:: article2section requested")
    if let s = srIssue.sections, let artArray = searchItem.allArticles {
      var d : [String : [Section]]  = [:]
      for art in artArray {
        d[art.html.fileName] = s
      }
      return d
    }
    return [:]
  }
  
  public func displaySection(index: Int) {
    debug("TODO:: displaySection \(index)")
  }
  
  public func linkPressed(from: URL?, to: URL?) {
    debug("TODO:: linkPressed \(from?.absoluteString) to: \(to?.absoluteString)")
  }
  
  public func closeIssue() {
    debug("TODO:: closeIssue")
//    self.navigationController?.popViewController(animated: false)
  }

  
  public func resetIssueList() {
      debug("TODO:: resetIssueList")
  }
}

// MARK: - other extensions -
// MARK: *** String ***
extension String {
  var sha1:String { self.data(using: .utf8)?.sha1 ?? self }
  var sha256:String { self.data(using: .utf8)?.sha256 ?? self }
  var md5:String { self.data(using: .utf8)?.md5 ?? self }
}

// MARK: *** GqlSearchHit ***
extension GqlSearchHit {
  @discardableResult
  public func writeToDisk() -> String {
    let filename = self.article.html.fileName
    let f = TmpFileEntry(name: filename)
    f.content = self.articleHtml
    return f.path
  }
  
  var localPath: String? {
    let f = File(dir: Dir.searchResultsPath, fname: article.html.fileName)
    if !f.exists { return nil }
    return Dir.searchResultsPath + "/" + article.html.fileName
  }
}

// MARK: *** SearchSettings ***
fileprivate extension SearchSettings {
  var miniHeaderText:String? {
    var s:[String] = []
    if let t = text, !t.isEmpty { s.append("Text: \(t)") }
    if let t = title, !t.isEmpty { s.append("Titel: \(t)") }
    if let t = author, !t.isEmpty { s.append("Autor*innen: \(t)") }
    if s.isEmpty { return nil}
    return "Suche nach \(s.joined(separator: ", "))"
  }
}

