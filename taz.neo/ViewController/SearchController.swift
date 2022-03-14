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
  
  var searchItem:SearchItem = SearchItem(searchString: "")
  
  var searchController: UISearchController
  
  lazy var extendedSearchButton: Button<ImageView> = {
    let button = Button<ImageView>()
    button.pinSize(CGSize(width: 32, height: 32))
    button.buttonView.hinset = 0.1
    button.buttonView.name = "filter"
    button.buttonView.imageView.tintColor = .black
    button.onTapping { [weak self] _ in
      self?.filterButtonTapped()
    }
    return button
  }()
  

  
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
    searchController.searchResultsUpdater = self
    searchController.searchBar.delegate = self // Monitor when the search button is tapped.
//    navigationItem.istra
//    resultsTableController.tableView.tableHeaderView = searchBarWraper
  }
  

  
//  var showsSearchResultsController:Bool = false {
//    didSet {
//      if #available(iOS 13.0, *) {
//        searchController.showsSearchResultsController = showsSearchResultsController
//      }
//    }
//  }
  
  
//  var isActive:Bool = false {
//    didSet {
////      searchBarTools.isOpen = false
//      guard let resultsTVC = searchController.searchResultsController as? SearchResultsTVC else { return }
//
//      if isActive == false && searchBarTools.superview != self {
//        resultsTVC.tableView.tableHeaderView = nil
//        self.view.addSubview(searchBarTools)
//        pin(searchBarTools, toSafe: self.view, exclude: .bottom)
//      }
//      else if isActive == true,
//              resultsTVC.tableView.tableHeaderView != searchBarTools {
//        print("set result frame is: \(searchBarTools.frame)")
//
//        resultsTVC.tableView.tableHeaderView = searchBarTools
//      }
//      else if isActive == true{
//        print("set result frame is222: \(searchBarTools.frame)")
//
//        resultsTVC.tableView.tableHeaderView = searchBarTools
//      }
//    }
//  }
  
  required init(feederContext: FeederContext) {
    self.feederContext = feederContext
    searchController = UISearchController(searchResultsController: resultsTableController)
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - extension Filter Actions
extension SearchController {
  func filterButtonTapped() {
    print("Filter tapped todo")
  }
}

extension SearchController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
//    isActive = searchController.isActive
    print("updateSearchResults..sc.isActive: \(searchController.isActive) sc.isFirstResponder: \(searchController.isFirstResponder) ")
  }
}

// MARK: - UISearchControllerDelegate
//extension SearchController: UISearchControllerDelegate {
////  updateSearchResults(for: <#T##UISearchController#>)
//
//
//
//  func updateSearchResults(for searchController: UISearchController) {
//    if let resultsController = searchController.searchResultsController as? SearchResultsTVC {
//      resultsController.tableView.tableHeaderView = searchBarTools
//      print("moved tools to results table header")
//    }
//  }
//}

// MARK: - UISearchBarDelegate
extension SearchController: UISearchBarDelegate {
  
  private func search(){
    self.resultsTableController.searchItem = searchItem
    self.resultsTableController.tableView.reloadData()
//    self.showsSearchResultsController = true
    print("moved tools to results table header")
    
    return
    guard let feeder = feederContext.gqlFeeder else { return }
    feeder.search(searchItem: searchItem) { [weak self] result in
      guard let self = self else { return }
      switch result {
        case .success(let updatedSearchItem):
          self.searchItem = updatedSearchItem
          self.resultsTableController.searchItem = updatedSearchItem
          self.resultsTableController.tableView.reloadData()
//          self.showsSearchResultsController = true
//          self.header.resultCount = updatedSearchItem.resultCount
        case .failure(let err):
          print("an error occoured... \(err)")
      }
    }
  }
  
  public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    guard let searchString = searchController.searchBar.text, searchString.length > 2 else {
      Toast.show("Suchbegriff zu kurz!", .alert)
      
//      searchBarTools.errorTextLabel.text = "Suchbegriff zu kurz!"
      return
    }
//    searchBarTools.errorTextLabel.text = nil
    
    searchItem.searchString = searchString

    search()
    
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


