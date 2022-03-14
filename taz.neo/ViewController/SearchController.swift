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
  
  var dissue:DummyIssue
  
  var searchItem:SearchItem = SearchItem(searchString: "") {
    didSet {
      resultsTableController.searchItem = searchItem
      self.resultsTableController.tableView.reloadData()
    }
  }
  
  var searchController: UISearchController
  
  fileprivate let resultsTableController = SearchResultsTVC()
  
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
  
  func reset(){
    searchController.isActive = false
    searchController.dismiss(animated: false)
    searchItem = SearchItem(searchString: "")
    resultsTableController.serachSettingsVC.reset()
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
      searchController.searchBar.searchTextField.layer.cornerRadius = 18
      searchController.searchBar.searchTextField.layer.masksToBounds = true
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
  private func search(){
    guard let searchString = searchController.searchBar.text, searchString.length > 2 else {
      Toast.show("Suchbegriff zu kurz!", .alert)
      
//      searchBarTools.errorTextLabel.text = "Suchbegriff zu kurz!"
      return
    }
//    searchBarTools.errorTextLabel.text = nil
    
    searchItem.searchString = searchString

    searchItem.settings = self.resultsTableController.serachSettingsVC.currentConfig
    guard let feeder = feederContext.gqlFeeder else { return }
    feeder.search(searchItem: searchItem) { [weak self] result in
      guard let self = self else { return }
      switch result {
        case .success(let updatedSearchItem):
          self.searchItem = updatedSearchItem
//          self.showsSearchResultsController = true
//          self.header.resultCount = updatedSearchItem.resultCount
        case .failure(let err):
          print("an error occoured... \(err)")
      }
    }
  }
  
  public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    search()
  }
  
  private func openSearchHit(_ searchHit: GqlSearchHit){
    let tmp = TmpFileEntry(name: "test")
    let bs = BookmarkSection(name: "Suche: \(searchItem.searchString)", html: tmp)
    bs.articles = searchItem.allArticles
    dissue.search = self.searchItem
    dissue.sections = [bs]
    
//    searchDelegate.open(searchHit)
    
    feederContext.dloader.downloadFiles(url: searchHit.baseUrl, files: searchHit.article.files) {err in
  //      print("PayloadDL doneWith Err: \(err)")
  //    }
      let path = searchHit.writeToDisk(key: self.searchItem.lastResponse?.search.text.sha1)

      let articleVC = SearchResultArticleVc(feederContext: self.feederContext)
      #warning("missing deleted empty delegate functions")
      articleVC.delegate = self
      articleVC.gotoUrl(path)

      self.navigationController?.pushViewController(articleVC, animated: true)
  //    #warning("Cannot Present while Modal is Presented")
  //    ///Solution SearchCtrl must be an extendion to IssueVC
  //
  //    #warning("more to do's: store local file and open! ")
  //    presentingVC?.navigationController?.pushViewController(articleVC, animated: true)
  //    //    self.childArticleVC = articleVC

    }
    
    
    
    
    
    
    
    
    
    
    
    
    
//    self.self.searchResultsController?.view.isHidden = true
  }
}


//extension SearchController: IssueInfo {
//  var issue: Issue {
//    return dissue
//  }
//  
//  func resetIssueList() {
//    print("todo...")
//  }
//  
//  
//}

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
    print(self.baseUrl)
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


