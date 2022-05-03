//
//  self.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib

class SearchController: UIViewController {

//  private let resultsTableController = SearchResultsTVC()
  private let resultsTableController = FakeTableTableViewController()
  
  private let defaultSection = BookmarkSection(name: "Suche",
                                       html: TmpFileEntry(name: "SearchTempSection.tmp"))
  
  private var articleVC:SearchResultArticleVc
  private var srIssue:SearchResultIssue
  
  var beginDragOffset:CGFloat?
  
  let header = SearchHeaderView()
  
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
//    if resultsTableController.restoreInitialState() == false {
//      return false
//    }
    return true
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    resultsTableController.tableView.contentInset = UIEdgeInsets(top: 35, left: 0, bottom: 0, right: 0)
    


    if let lastArticle = lastArticleShown,
       let hitList = searchItem.searchHitList,
       let idx = hitList.firstIndex(where: { lastArticle.isEqualTo(otherArticle: $0.article)}) {
      resultsTableController.tableView.scrollToRow(at: IndexPath(row: idx, section:0 ), at: .top, animated: false)
    }
   
    resultsTableController.tableView.scrollIndicatorInsets = UIEdgeInsets(top: 45, left: 0, bottom: 0, right: 0)
  }
  
  public private(set) lazy var serachSettingsVC:SearchSettingsVC = {
    let vc = SearchSettingsVC(style: .grouped)
    vc.setup()
    
    vc.preferredContentSize = CGSize(width: min(self.view.frame.size.width, 500), height: UIWindow.size.height - 280)
    
    vc.finishedClosure = { [weak self] doSearch in
//      self?.checkFilter()
      if doSearch {
//        self?.searchClosure?()
      }
    }
    return vc
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.view.backgroundColor = Const.SetColor.CTBackground.color
    self.view.addSubview(placeholderView)
    placeholderView.center()
    let tbl = FakeTableView()
    self.view.addSubview(tbl)
    pin(tbl, toSafe: self.view)
    tbl.contentInset = UIEdgeInsets(top: 40, left: 0, bottom: 0, right: 0)
    tbl.delegate = self
    self.view.addSubview(header)
    header.topConstraint = pin(header, toSafe: self.view, exclude: .bottom).top
//    resultsTableController.searchClosure = { [weak self] in
//      self?.search()
//    }
//
//    resultsTableController.openSearchHit = { [weak self] hit in
//      self?.openSearchHit(hit)
//    }
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
      #warning("todo set counts in header")
//      fixedHeader.set(text: message,
//                      font: Const.Fonts.contentFont)
//      resultsTableController.searchItem = searchItem
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
    var searchSettings = self.serachSettingsVC.data.settings
    #warning("Todo get text")
//    searchSettings.text = searchController.searchBar.text

    if searchSettings.searchTermTooShort {
#warning("Todo get text")
//      fixedHeader.set(text: "Bitte Suchbegriff eingeben!",
//                                                font: Const.Fonts.boldContentFont,
//                                                color: Const.Colors.ciColor )
      return
    }
    //Ensute settings closed e.g. if search by keyboard
    self.serachSettingsVC.dismiss(animated: true)

    if searchItem.settings != searchSettings {
      searchItem.settings = searchSettings
    }
    
    if searchItem.sessionId == nil {
//      resultsTableController.scrollTop()
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

