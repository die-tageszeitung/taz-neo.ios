//
//  self.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib

class SearchController: UIViewController {

  private let resultsTableController = SearchResultsTVC()
  private let defaultSection = BookmarkSection(name: "Suche",
                                       html: TmpFileEntry(name: "SearchTempSection.tmp"))
  
  private var articleVC:SearchResultArticleVc
  private var srIssue:SearchResultIssue
  private var searchController: UISearchController
  
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
    if resultsTableController.restoreInitialState() == false {
      return false
    }
    searchController.isActive = false
    searchController.dismiss(animated: false)
    return true
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    searchController.searchBar.alpha = 1.0
    self.navigationController?.setNavigationBarHidden(false, animated: false)
    resultsTableController.tableView.contentInset = UIEdgeInsets(top: 35, left: 0, bottom: 0, right: 0)
    resultsTableController.tableView.scrollIndicatorInsets = UIEdgeInsets(top: 45, left: 0, bottom: 0, right: 0)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Place the search bar in the navigation bar.
    navigationItem.title = nil
    
    self.definesPresentationContext = true
    self.navigationItem.titleView = searchController.searchBar
    // Don't hide the navigation bar because the search bar is in it.
    searchController.hidesNavigationBarDuringPresentation = false


    self.view.backgroundColor = Const.SetColor.CTBackground.color
    searchController.searchBar.tintColor = .black
    searchController.searchBar.placeholder = "taz Archiv durchsuchen"
    searchController.searchBar.backgroundColor = Const.SetColor.CTBackground.color
    searchController.searchBar.backgroundImage = UIImage()//removes seperator
    if #available(iOS 13.0, *) {
      searchController.searchBar.searchTextField.defaultStyle(placeholder: "taz Archiv durchsuchen")
    }
    self.view.addSubview(placeholderView)
    placeholderView.center()
    
    if #available(iOS 13.0, *) {
      searchController.automaticallyShowsSearchResultsController = false
      searchController.showsSearchResultsController = true
    }
    searchController.searchBar.delegate = self // Monitor when the search button pressed
    
    resultsTableController.searchClosure = { [weak self] in
      self?.search()
    }
    
    
    resultsTableController.openSearchHit = { [weak self] hit in
      self?.openSearchHit(hit)
    }
    feederContext.updateResources()
  }
  
  required init(feederContext: FeederContext) {
    self.feederContext = feederContext
    searchController = UISearchController(searchResultsController: resultsTableController)
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
      
      resultsTableController
        .fixedHeader.set(text: message,
                            font: Const.Fonts.contentFont)
      resultsTableController.searchItem = searchItem
    }
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
    var searchSettings = self.resultsTableController.serachSettingsVC.data.settings
    searchSettings.text = searchController.searchBar.text
     
    if searchSettings.searchTermTooShort {
      resultsTableController.fixedHeader.set(text: "Bitte Suchbegriff eingeben!",
                                                font: Const.Fonts.boldContentFont,
                                                color: Const.Colors.ciColor )
      return
    }
    //Ensute settings closed e.g. if search by keyboard
    self.resultsTableController.serachSettingsVC.dismiss(animated: true)
    
    if searchItem.settings != searchSettings {
      searchItem.settings = searchSettings
    }
    
    if searchItem.sessionId == nil {
      resultsTableController.scrollTop()
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
    get {
      debug("TODO:: article requested")
      return nil
    }
    set {
      debug("TODO:: article set \(newValue?.title)")
    }
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

