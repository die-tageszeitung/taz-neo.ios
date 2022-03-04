//
//  SearchController.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib


public protocol SearchDelegate {
  func search(_ searchItem: SearchItem, closure: @escaping(Result<SearchItem,Error>)->())
  func open(_ searchHit: GqlSearchHit)
  var presentingController:UIViewController { get }
}


// MARK: - Feeder Search
extension IssueVcWithBottomTiles: SearchDelegate {
  public var presentingController: UIViewController {
    get {
      return self
    }
  }
  
  
  public func search(_ searchItem: SearchItem,
                     closure: @escaping(Result<SearchItem,Error>)->()) {
    guard let feeder = (self as? IssueVC)?.gqlFeeder else { return }
    feeder.search(searchItem: searchItem, closure: closure)
  }
  
  public func open(_ searchHit: GqlSearchHit){
    guard let issueVC = self as? IssueVC else { return }
    
//    issueVC.feederContext.dloader.downloadFiles(url: searchHit.baseUrl, files: searchHit.article.files) {err in
//      print("PayloadDL doneWith Err: \(err)")
//    }
    let path = searchHit.writeToDisk(key: searchHelper?.searchItem.lastResponse?.search.text.sha1)
    
    
    let articleVC = SearchResultArticleVc(feederContext: issueVC.feederContext)
    articleVC.delegate = self.searchHelper
    articleVC.gotoUrl(path)
    searchHelper?.restoredState.wasActive = true
    self.navigationController?.pushViewController(articleVC, animated: true)
//    #warning("Cannot Present while Modal is Presented")
//    ///Solution SearchCtrl must be an extendion to IssueVC
//
//    #warning("more to do's: store local file and open! ")
//    presentingVC?.navigationController?.pushViewController(articleVC, animated: true)
//    //    self.childArticleVC = articleVC
    
  }
}

// MARK: - Feeder Search
extension SearchHelper: ArticleVCdelegate {
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




public class SearchHelper: NSObject, DoesLog {
  
  public var feederContext: FeederContext
  public var dissue: DummyIssue
  
  var searchDelegate: SearchDelegate
  var searchController: UISearchController
  var searchItem:SearchItem = SearchItem(searchString: "")
  var header = SerachResultsTableHeaderView()
  
  
  fileprivate var searchSettingsVC = SearchSettingsVC()
  
  ///Search Bar Height itself is probably 44 But what if Zoom Enabled is Wrapper big enought?
  public static let SearchBarWrapperHeight: CGFloat = 44//
  
  private var searchBarWrapper:UIView
  
  private var searchBarTopConstraint: NSLayoutConstraint?
  
  private var searchBarHidden: Bool = true {
    didSet {
      if searchBarHidden == oldValue { return }
      
      searchBarTopConstraint?.constant
        = searchBarHidden ? Self.SearchBarWrapperHeight : 0
      
      UIView.animate(withDuration: 0.5) {[weak self] in
        guard let self = self else { return }
        self.searchBarWrapper.layoutIfNeeded()
        self.searchController.searchBar.alpha = self.searchBarHidden ? 0.0 : 1.0
      }
    }
  }
  
  init(searchBarWrapper:UIView, searchDelegate: SearchDelegate, feederContext: FeederContext) {
    self.searchDelegate = searchDelegate
    self.searchBarWrapper = searchBarWrapper
    self.feederContext = feederContext
    self.dissue = DummyIssue(feed: feederContext.defaultFeed)
    self.searchController
      = UISearchController(searchResultsController: resultsTableController)
    super.init()
    setup()
  }
  
  // MARK: - Setup SearchHelper
  private func setup(){
    ///Initially Hide SearchBar
    searchController.searchBar.alpha = 0.0
    
    searchBarWrapper.addSubview(searchController.searchBar)
    

    
    searchController.delegate = self
    searchController.searchBar.delegate = self // Monitor when the search button is tapped.
    
    ///Set Delegates for SearchResult Controller
    resultsTableController.tableView.delegate = self
    resultsTableController.tableView.dataSource = self
    
    //self.searchResultsUpdater = self ///LiveTyping Results Update not needed
    
    searchController.hidesNavigationBarDuringPresentation = false ///show statusBar also!
    searchController.obscuresBackgroundDuringPresentation = false
    

    
    ///SearchBar Styling
    searchController.searchBar.barStyle = .black
    if #available(iOS 13.0, *) {
      if let searchIcon
          = searchController.searchBar.searchTextField.leftView as? UIImageView {
        searchIcon.tintColor = .gray
      }
      searchController.searchBar.searchTextField.textColor = .white
      searchController.searchBar.searchTextField.backgroundColor = UIColor(white: 0.1, alpha: 0.7)
    } else {
      UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes
        = [
          NSAttributedString.Key.foregroundColor: UIColor.white
          //,
          //          NSAttributedString.Key.backgroundColor: UIColor.darkGray //only text bg color not the whole textfield
        ]
    }
    searchController.searchBar.isTranslucent = true
    searchController.searchBar.barTintColor = .clear
    searchController.searchBar.tintColor = .white
    searchController.searchBar.autocapitalizationType = .none
    
    ///Search Bar Config
    searchController.searchBar.showsCancelButton = true //Important after color Set!
    
    ///Modal Search Settings VC Config
    self.searchSettingsVC.finishedClosure = { [weak self] apply in
      guard let self = self else { return }
      if apply{
        self.searchItem.settings =  self.searchSettingsVC.currentConfig
        self.searchBarSearchButtonClicked(self.searchController.searchBar)
      }
      
      self.header.filterActive = self.searchSettingsVC.currentConfig.isDefault
      
    }
    self.header.filterActive = self.searchSettingsVC.currentConfig.isDefault
    
    ///Integrated Results TCV Config
    self.resultsTableController.onBackgroundTap = {
      self.searchController.dismiss(animated: true, completion: nil)
      self.toggleSearchBar(toHidden: true)
    }
    
    ///Filter Header
    self.header.filterButton.addTarget(self,
                                  action: #selector(handleFilterButtonPress),
                                  for: .touchUpInside)
  }
  
  
  @objc func handleFilterButtonPress(){
    self.searchDelegate.presentingController.present(self.searchSettingsVC, animated: true)
  }
  
  public func toggleSearchBar(toHidden: Bool? = nil) {
    if let to = toHidden {
      self.searchBarHidden = to
    }
    else {
      self.searchBarHidden = !self.searchBarHidden
    }
  }
  
  public func restoreState() {
    // Restore the searchController's active state.
    if restoredState.wasActive {
      self.searchController.isActive = restoredState.wasActive
      restoredState.wasActive = false
      
      if restoredState.wasFirstResponder {
        self.searchController.searchBar.becomeFirstResponder()
        restoredState.wasFirstResponder = false
      }
    }
  }
  
  public struct SearchControllerRestorableState {
    var wasActive = false
    var wasFirstResponder = false
  }
  /// Restoration state for UISearchController
  public var restoredState = SearchControllerRestorableState()
  fileprivate let resultsTableController = SearchResultsTVC()
}

// MARK: - UITableViewDelegate
// Handle Result Tap here!
extension SearchHelper: UITableViewDelegate {
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let searchHit = searchItem.searchHitList?.valueAt(indexPath.row) else {
      debug("No Search Hit found at \(indexPath.row)")
      return
    }
    let tmp = TmpFileEntry(name: "test")
    let bs = BookmarkSection(name: "Suche: \(searchItem.searchString)", html: tmp)
    bs.articles = searchItem.allArticles
    dissue.search = self.searchItem
    dissue.sections = [bs]
    searchDelegate.open(searchHit)
    self.searchController.searchResultsController?.view.isHidden = true
  }
  
  public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    guard let currentCount = searchItem.searchHitList?.count else { return }
    if indexPath.row == currentCount - 2 {
      search()
    }
  }
  
  public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    return section == 0 ? header : nil
  }
  
  public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return section == 0 ? 34 : 0
  }
  
}

extension SearchHelper: UITableViewDataSource {
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.searchItem.searchHitList?.count ?? 0
  }
  
  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultsTVC.SearchResultsCellIdentifier,
                                             for: indexPath) as! SearchResultsCell
    cell.content = self.searchItem.searchHitList?.valueAt(indexPath.row)
    return cell
  }
}


// MARK: - UISearchControllerDelegate
extension SearchHelper: UISearchControllerDelegate { }

// MARK: - UISearchBarDelegate
extension SearchHelper: UISearchBarDelegate {
  
  private func search(){
    searchDelegate.search(searchItem) {   [weak self] result in
      guard let self = self else { return }
      switch result {
        case .success(let updatedSearchItem):
          self.searchItem = updatedSearchItem
          self.resultsTableController.tableView.reloadData()
          self.resultsTableController.view.isHidden = false
          self.header.resultCount = updatedSearchItem.resultCount
        case .failure(let err):
          print("an error occoured... \(err)")
      }
    }

  }
  
  public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    guard let searchString = searchController.searchBar.text, searchString.length > 2 else {
      Toast.show("Suchbegriff zu kurz!", .alert)
      return
    }
    
    searchItem.searchString = searchString

    search()
    
  }
  
  public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
    self.toggleSearchBar()
  }
}

public class SerachResultsTableHeaderView: UIView {
  
  var filterActive:Bool = false {
    didSet{
      filterButton.buttonView.alpha = filterActive ? 1.0 : 0.5
    }
  }
  
  var resultCount: (Int?, Int?) {
    set{
      if let from = newValue.0 , let to = newValue.1 {
        label.text = "\(from)/\(to) Treffer"
      }
      else {
        label.text = "- Treffer"
      }
    }
    get {
      return (0,0)
    }
  }
  
  private lazy var label: UILabel = UILabel("",
                                            type: .small,
                                            color: Const.SetColor.CTArticle,
                                            align: .center)
  
  public lazy var filterButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.buttonView.name = "slider_h3"
    btn.pinWidth(55)
    btn.inset = 0.3
    btn.buttonView.color = Const.SetColor.ios(.tintColor).color
    return btn
  }()
  
  private func setup() {
    self.backgroundColor = .black
    addSubview(label)
    addSubview(filterButton)
    
    addBorder(.white.withAlphaComponent(0.7), 0.5, only: .bottom)
    
    label.centerY()
    pin(filterButton.top, to: self.top)
    pin(filterButton.bottom, to: self.bottom)
    
    pin(label.left, to: self.left, dist: Const.ASize.DefaultPadding)
    pin(label.right, to: filterButton.left, dist: Const.ASize.DefaultPadding)
    pin(filterButton.right, to: self.right)
  }
  
  public override init(frame: CGRect) {
    let f = frame == .zero ? CGRect(x: 0, y: 0, width: UIWindow.size.width, height: 34) : frame
    super.init(frame: f)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}



// MARK: - SearchResultArticleVc
class SearchResultArticleVc : ArticleVC {
  override func setupSlider() {}

}

public class TmpTestController:UIViewController{
  
  var main: TazAppEnvironment?
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .cyan
   
    
    let btn = UIButton()
    btn.setTitle("XXX", for: .normal)
    btn.addTarget(self,
                  action: #selector(handleButton),
                  for: .touchUpInside)
    
    self.view.addSubview(btn)
    btn.center()
    main = TazAppEnvironment.sharedInstance
//    main?.pushViewController(UIViewController(), animated: false)
    main?.setupFeeder()
  }
  
  @objc func handleButton(){
    guard let sr = GqlFeeder.test() else {
      print("faild to parse demo data!")
      return
    }
    guard let hit = sr.searchHitList?.first else {
      print("faild to get a hit!")
      return
    }
    
    guard let f = main?.feederContext else {
      print("No Feeder")
      return
    }
    print("Got Feeder \(f.feedName)")
    hit.writeToDisk(key: sr.text.sha1)
    
//    let payload = SearchPayload()
//    payload.files = hit.article.files
    #warning("not testable dloader is nil ")
//    po f.isConnected     true
//    po f.isReady false
    
    
    f.dloader.downloadFiles(url: hit.baseUrl, files: hit.article.files) {err in
      print("PayloadDL doneWith Err: \(err)")
    }
  }
}

extension String {
  var sha1:String { self.data(using: .utf8)?.sha1 ?? self }
  var sha256:String { self.data(using: .utf8)?.sha256 ?? self }
  var md5:String { self.data(using: .utf8)?.md5 ?? self }
}

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
