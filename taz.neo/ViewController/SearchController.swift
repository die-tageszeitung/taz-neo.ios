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
  
  var searchController: UISearchController
  
  fileprivate let resultsTableController = SearchResultsTVC()
  
  var searchBarWraper = UIView()
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    searchController.searchBar.alpha = 1.0
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.view.addSubview(searchBarWraper)
    pin(searchBarWraper, toSafe: self.view, dist: 0, exclude: .bottom)
    searchBarWraper.pinHeight(80)
    searchBarWraper.backgroundColor = .orange
    self.view.backgroundColor = .yellow
    searchBarWraper.addSubview(searchController.searchBar)
    searchController.searchBar.placeholder = "taz Archiv durchsuchen"
  }
  
  
  required init(feederContext: FeederContext) {
    self.feederContext = feederContext
    searchController = UISearchController(searchResultsController: resultsTableController)
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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


