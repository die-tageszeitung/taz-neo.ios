//
//  self.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib

class SearchController: UIViewController {

  var feederContext: FeederContext
  
  var bs: BookmarkSection?
  
  var dissue:DummyIssue
  
  var searchItem:SearchItem = SearchItem() {
    didSet {
      resultsTableController.searchItem = searchItem
    }
  }
  
  var searchController: UISearchController
  
  fileprivate let resultsTableController = SearchResultsTVC(style: .plain)
  
  lazy var placeholder: UIView = {
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
    self.view.addSubview(placeholder)
    placeholder.center()
    
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
    dissue = DummyIssue(feed: feederContext.defaultFeed)
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - UISearchBarDelegate
extension SearchController: UISearchBarDelegate {
  private func search() {
    var searchSettings = self.resultsTableController.serachSettingsVC.data.settings
    searchSettings.text = searchController.searchBar.text
     
    if searchSettings.searchTermTooShort {
      resultsTableController.searchBarTools.set(text: "Suchbegriff zu kurz!",
                                                font: Const.Fonts.boldContentFont,
                                                color: Const.Colors.ciColor )
      return
    }

    searchItem.settings = searchSettings
    guard let feeder = feederContext.gqlFeeder else { return }
    feeder.search(searchItem: searchItem) { [weak self] result in
      guard let self = self else { return }
      switch result {
        case .success(let updatedSearchItem):
          self.searchItem = updatedSearchItem
          self.updateArticleVcIfNeeded()
          var message = "Keine Treffer"
          let rCount = updatedSearchItem.resultCount
          if let currentCount = rCount.currentCount, let totalCount = rCount.total {
            message = "\(totalCount)/\(currentCount)"
          }
          else if let count = rCount.currentCount {
            message = "\(count) Treffer"
          }
          else if let count = rCount.total {
            message = "\(count) Treffer"
          }
          self.resultsTableController
            .searchBarTools.set(text: message,
                                font: Const.Fonts.contentFont)
        case .failure(let err):
          print("an error occoured... \(err)")
      }
    }
  }
  
  public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    search()
  }
  
  func updateArticleVcIfNeeded(){
    guard let articleVC = self.navigationController?.viewControllers.last as? SearchResultArticleVc else { return }
    guard let bs = bs else { return }
    guard let searchHit = searchItem.lastResponse?.search.searchHitList?.first else { return }
    guard let allArticles = searchItem.allArticles else { return }
    bs.articles = allArticles
    articleVC.maxResults = self.searchItem.resultCount.currentCount ?? 0
    dissue.search = self.searchItem
    dissue.sections = [bs]
    articleVC.searchContents = allArticles
    feederContext.dloader.downloadSearchResultFiles(url: searchHit.baseUrl, files: searchHit.article.files) { [weak self] err in
      guard let self = self else { return }
      _ = searchHit.writeToDisk(key: self.searchItem.lastResponse?.search.searchText.sha1)
      if let err = err {
        self.log("Download error, try to display Article: \(err)")
      }
      articleVC.reload()
    }
  }
  
  private func openSearchHit(_ searchHit: GqlSearchHit){
    let tmp = TmpFileEntry(name: "test")
    bs = BookmarkSection(name: "Suche:", html: tmp)
    guard let bs = bs else { return }
    bs.articles = searchItem.allArticles
    dissue.search = self.searchItem
    dissue.sections = [bs]
    
    feederContext.dloader.downloadSearchResultFiles(url: searchHit.baseUrl, files: searchHit.article.files) {[weak self] err in
      guard let self = self else { return }
      let path = searchHit.writeToDisk(key: self.searchItem.lastResponse?.search.searchText.sha1)
      #warning("missing deleted empty delegate functions")
      let articleVC = SearchResultArticleVc(feederContext: self.feederContext)
      articleVC.delegate = self
      articleVC.maxResults = self.searchItem.resultCount.currentCount ?? 0
      articleVC.searchClosure = { [weak self] in
        self?.search()
      }
      articleVC.baseDir = Dir.appSupportPath
      articleVC.gotoUrl(path)
      if err == nil { articleVC.reload() }
      self.navigationController?.pushViewController(articleVC, animated: true)
    }
  }
}

extension SearchController: ArticleVCdelegate {
  public var issue: Issue {
    return self.dissue
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
      
    }
  }
  
  public var article2section: [String : [Section]] {
    debug("TODO:: article2section requested")
    if let s = dissue.sections, let artArray = searchItem.allArticles {
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
  public func writeToDisk(key:String?) -> String {
    print("Base Url to write file: \(self.baseUrl)")
#warning("unique key if similar seraches produce similar results for highlighting")
    //    e.g.: Hochwaser Oder // VS // Hochwasser Elbe
    /// contain either <span class="snippet">Hochwasser Oder</span>
    /// or <span class="snippet">Hochwasser Elbe</span>
    /// if same article found!
    let key = key ?? "na"
#warning("ignore unique key currently")
    
    //    let filename = key + "-" + self.article.html.fileName
    let filename = self.article.html.fileName
    let f = TmpFileEntry(name: filename)
    f.content = self.articleHtml
    return f.path
  }
}


