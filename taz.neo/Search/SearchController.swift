//
//  self.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib

class SearchController: UIViewController {


  private lazy var resultsTable:SearchResultsTableView = {
    let v = SearchResultsTableView()
    v.searchClosure = { [weak self] in
      self?.search()
    }
    return v
  }()
  
  private let defaultSection = BookmarkSection(name: "Suche",
                                       html: TmpFileEntry(name: "SearchTempSection.tmp"))
  
  private var articleVC:SearchResultArticleVc
  private var srIssue:SearchResultIssue
  
  var beginDragOffset:CGFloat?
  
  lazy var header:SearchHeaderView = {
    let header = SearchHeaderView()
    
    header.cancelButton.addTarget(self,
                   action: #selector(self.handleCancelButton),
                   for: .touchUpInside)
    
    header.extendedSearchButton.onTapping { [weak self] _ in
      self?.header.setHeader(showMaxi: true)
      self?.header.hideResult()
      self?.serachSettingsView.toggle()
      self?.checkFilter()
    }
    
    header.searchClosure = { [weak self] in
      self?.search()
    }
    
    return header
  }()
  
  lazy var serachSettingsView:SearchSettingsView = {
    let v = SearchSettingsView(frame: .zero, style: .grouped)
    v.backgroundView = UIView()
    
    //    vc.finishedClosure = { [weak self] doSearch in
    ////      self?.checkFilter()
    //      if doSearch {
    ////        self?.searchClosure?()
    //      }
    //    }
    
    v.backgroundView?.onTapping {[weak self] _ in
      v.toggle(toVisible: false)
      self?.checkFilter()
    }
    
    v.searchButton.addTarget(self,
                             action: #selector(self.handleSearchButton),
                             for: .touchUpInside)
    
    return v
  }()
  
  private var lastArticleShown: Article?
  
  var feederContext: FeederContext
  
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
  
  func restoreInitialState() -> Bool{
    if resultsTable.restoreInitialState() == false {
      return false
    }
    return true
  }
  
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
    placeholderView.center()
    self.view.addSubview(resultsTable)
    pin(resultsTable, toSafe: self.view)
    resultsTable.contentInset = UIEdgeInsets(top: 40, left: 0, bottom: 0, right: 0)
    #warning("DELEGATE")
//    resultsTable.delegate = self
    self.view.addSubview(serachSettingsView)
    self.view.addSubview(header)
    
    header.topConstraint = pin(header, to: self.view, exclude: .bottom).top

//
//    resultsTableController.openSearchHit = { [weak self] hit in
//      self?.openSearchHit(hit)
//    }
    
    pin(serachSettingsView.left, to: self.view.left)
    pin(serachSettingsView.right, to: self.view.right)
    serachSettingsView.topConstraint = pin(serachSettingsView.top, to: header.bottom, dist: -UIWindow.size.height)
    serachSettingsView.bottomConstraint = pin(serachSettingsView.bottom, to: self.view.bottom, dist: -UIWindow.size.height)
    
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
  
  var searchItem:SearchItem = SearchItem() {
    didSet {
      updateArticleVcIfNeeded()
      
      var message = "Keine Treffer"
      let rCount = searchItem.resultCount
      if let currentCount = rCount.currentCount, let totalCount = rCount.total {
        message = "\(totalCount)/\(currentCount)"
      }
      else if let count = rCount.currentCount {
        message = "\(count) Treffer"
      }
      else if let count = rCount.total {
        message = "\(count) Treffer"
      }
      header.showResult(text: message)
      resultsTable.searchItem = searchItem
    }
  }
}

extension SearchController: UITableViewDelegate {

  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    beginDragOffset = scrollView.contentOffset.y
  }
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    guard let beginDragOffset = beginDragOffset else { return }
    header.setHeader(scrollOffset: beginDragOffset - scrollView.contentOffset.y, animateEnd: true)
    self.beginDragOffset = nil
  }
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard let beginDragOffset = beginDragOffset else { return }
//    #warning("implement mini header animation")
//    log("scrolling offset: \(scrollView.contentOffset.y) beginDragOffset: \(beginDragOffset)")
    header.setHeader(scrollOffset: beginDragOffset-scrollView.contentOffset.y)
  }
}
  

// MARK: - UISearchBarDelegate
extension SearchController: UISearchBarDelegate {
  
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
    var searchSettings = self.serachSettingsView.data.settings
    searchSettings.text = header.searchTextField.text
    if searchSettings.searchTermTooShort {
      header.showResult(text: "Bitte Suchbegriff eingeben!")
      return
    }
    
    header.searchTextField.resignFirstResponder()
    serachSettingsView.toggle(toVisible: false)

    if searchItem.settings != searchSettings {
      searchItem.settings = searchSettings
    }
    
    if searchItem.sessionId == nil {
      resultsTable.scrollTop()
    }
    
    guard let feeder = feederContext.gqlFeeder else { return }
    feeder.search(searchItem: searchItem) { [weak self] result in
      guard let self = self else { return }
      switch result {
        case .success(let updatedSearchItem):
          for searchHit in updatedSearchItem.lastResponse?.search.searchHitList ?? [] {
            searchHit.writeToDisk()
          }
          self.searchItem = updatedSearchItem
        case .failure(let err):
          print("an error occoured... \(err)")
      }
    }
  }
  
  public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    search()
  }
}

extension SearchController {
  
  func checkFilter(){
    onMainAfter {[weak self] in
      self?.header.filterActive
      = self?.serachSettingsView.data.settings.isChanged ?? false
    }
  }
  
  @objc func handleCancelButton(){
    header.searchTextField.resignFirstResponder()
    header.searchTextField.text = nil
    header.hideCancel()
    serachSettingsView.restoreInitialState()
    serachSettingsView.toggle(toVisible: false)

    #warning("Clear old results")
  }
  
  @objc func handleSearchButton(){
    serachSettingsView.toggle(toVisible: false)
    search()
  }
}

extension GqlSearchHit {
  var localPath: String? {
    let f = File(dir: Dir.searchResultsPath, fname: article.html.fileName)
    if !f.exists { return nil }
    return Dir.searchResultsPath + "/" + article.html.fileName
  }
}

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

// MARK: - extension String
extension String {
  var sha1:String { self.data(using: .utf8)?.sha1 ?? self }
  var sha256:String { self.data(using: .utf8)?.sha256 ?? self }
  var md5:String { self.data(using: .utf8)?.md5 ?? self }
}

// MARK: - GqlSearchHit
extension GqlSearchHit {
  @discardableResult
  public func writeToDisk() -> String {
    let filename = self.article.html.fileName
    let f = TmpFileEntry(name: filename)
    f.content = self.articleHtml
    return f.path
  }
}

