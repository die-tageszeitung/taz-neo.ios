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
  
  lazy var searchBarWraper: UIView = {
    let v = UIView()
    let bottomBorder = UIView()
    bottomBorder.pinHeight(0.5)
    bottomBorder.backgroundColor = .black
    v.addSubview(bottomBorder)
    pin(bottomBorder, to: v,insets: Const.Insets.Default, exclude: .top)
    v.addSubview(extendedSearchButton)
    pin(extendedSearchButton.bottom, to: v.bottom, dist: 0)
    pin(extendedSearchButton.right, to: v.right, dist: -Const.Size.SmallPadding)
    v.pinHeight(85)
    return v
  }()
  
  lazy var placeholder: UIView = {
    let v = UILabel()
    v.text = "Keine aktuelle Suche\nSuchbegriff eingeben und \"Suchen\" drücken."
    v.textAlignment = .center
    v.numberOfLines = 0
    v.contentFont(size: 28)
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
    
    self.view.addSubview(searchBarWraper)
    pin(searchBarWraper, toSafe: self.view, dist: 0, exclude: .bottom)

    searchBarWraper.backgroundColor = Const.SetColor.CTBackground.color
    self.view.backgroundColor = Const.SetColor.CTBackground.color
    searchBarWraper.addSubview(searchController.searchBar)
    searchController.searchBar.placeholder = "taz Archiv durchsuchen"
    searchController.searchBar.backgroundColor = Const.SetColor.CTBackground.color
    searchController.searchBar.backgroundImage = UIImage()//removes seperator
    if #available(iOS 13.0, *) {
      searchController.searchBar.searchTextField.layer.cornerRadius = 18
      searchController.searchBar.searchTextField.layer.masksToBounds = true
    }
    self.view.addSubview(placeholder)
    placeholder.center()
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

// MARK: - extension Filter Actions
extension SearchController {
  func filterButtonTapped() {
    print("Filter tapped todo")
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


