//
//  self.swift
//  taz.neo
//
//  Created by Ringo Müller on 27.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

class SearchController: UIViewController {
  // MARK: *** Properties ***
  var feederContext: FeederContext
  
  private var defaultSection: SearchSection
  private var searchResultIssue: SearchResultIssue
  private var lastArticleShown: Article?
  
  private var articleVC:SearchResultArticleVc
  
  var searchItem:SearchItem {
    didSet {
      updateArticleVcIfNeeded()
      var textColor:UIColor?
      var message: String?
      var newState: searchState = .result
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
      else {
        message = "Keine Treffer"
        textColor = .red
        newState = .emptyResult
      }
      header.setStatusLabel(text: message, color: textColor)
      resultsTable.searchItem = searchItem
      self.currentState = newState
    }
  }
  
  enum searchState: String {case initial, firstSearch, result, emptyResult}
  
  private var currentState: searchState = .initial {
    didSet {
      switch currentState {
        case .initial:
          resultsTable.hideAnimated()
          placeholderView.showAnimated()
        case .firstSearch:
          resultsTable.hideAnimated()
          resultsTable.scrollTop()
          placeholderView.hideAnimated()
          centralActivityIndicator.isHidden = false
          centralActivityIndicator.startAnimating()
        case .result:
          centralActivityIndicator.isHidden = false
          centralActivityIndicator.stopAnimating()
          resultsTable.isHidden = false
        case .emptyResult:
          centralActivityIndicator.isHidden = true
          placeholderView.showAnimated()
          resultsTable.hideAnimated()
      }
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
    header.searchTextField.delegate = self
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
    v.textFieldDelegate = self
    return v
  }()
  
  lazy var placeholderView = PlaceholderView("Suche nach Autor*innen, Artikeln, Rubriken oder Themen", image: UIImage(named: "search-magnifier"))
  
  lazy var centralActivityIndicator = UIActivityIndicatorView()
    
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
    self.view.addSubview(centralActivityIndicator)
    self.view.addSubview(resultsTable)
    self.view.addSubview(searchSettingsView)
    self.view.addSubview(header)
    centralActivityIndicator.center()
    pin(placeholderView, toSafe: self.view)
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
    self.currentState = .initial
    
    Notification.receive("authenticationSucceeded") { [weak self]_ in
      self?.articleVC.dismiss(animated: true)
      self?.searchItem.reset()
      self?.search()
    }
  }
  
  required init(feederContext: FeederContext) {
    self.feederContext = feederContext
    searchResultIssue = SearchResultIssue.shared
    defaultSection = SearchSection(name: "Suche",
                                   issue: searchResultIssue,
                                   html: TmpFileEntry(name: "SearchTempSection.tmp"))
    searchResultIssue.sections = [defaultSection]
    searchItem
    = SearchItem(articlePrimaryIssue:searchResultIssue)
    articleVC = SearchResultArticleVc(feederContext: self.feederContext)
    articleVC.baseDir = Dir.searchResultsPath
    
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
  func updateArticleVcIfNeeded(){
    self.articleVC.feederContext = self.feederContext
    self.articleVC.baseDir = Dir.appSupportPath
    guard let allArticles = searchItem.allArticles else { return }
    defaultSection.articles = allArticles
    articleVC.maxResults = self.searchItem.resultCount.currentCount ?? 0
    searchResultIssue.search = self.searchItem
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
//        setHeader(artIndex: idx)??
        self.navigationController?.pushViewController(self.articleVC, animated: true)
      }
    }
  }

  private func search() {
    var searchSettings = self.searchSettingsView.data.settings
    searchSettings.text = header.searchTextField.text
    if searchSettings.searchTermTooShort {
      header.setStatusLabel(text: "Bitte Suchbegriff eingeben!",
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
      currentState = .firstSearch
      header.setStatusLabel(text: nil, color: nil)
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
          self.header
            .setStatusLabel(text: "Fehler, bitte erneut versuchen!",
                                    color: .red)
          self.log("an error occoured... \(err)")
      }
    }
  }
  
  func checkFilter(){
      self.header.filterActive
      = self.searchSettingsView.data.settings.isChanged
  }
  
  @discardableResult
  @objc func handleCancelButton() -> Bool{
    if searchSettingsView.isOpen {
      searchSettingsView.toggle(toVisible: false)
      return false
    }
    else if resultsTable.isVisible && header.searchTextField.isFirstResponder {
      header.searchTextField.resignFirstResponder()
      return false
    }
    searchItem.reset()
    header.searchTextField.resignFirstResponder()
    header.searchTextField.text = nil
    searchSettingsView.restoreInitialState()
    searchSettingsView.toggle(toVisible: false)
    self.checkFilter()
    header.checkCancelButton()
    header.setHeader(showMaxi: true)
    header.setStatusLabel(text: nil, color: nil)
    self.currentState = .initial
    return true
  }
  
  @objc func handleSearchButton(){
    searchSettingsView.toggle(toVisible: false)
    checkFilter()
    search()
  }
  
  func restoreInitialState() -> Bool{
    if resultsTable.restoreInitialState() == false {
      header.setHeader(showMaxi: true)
      return false
    }
    return handleCancelButton()
  }
}

// MARK: - UITextFieldDelegate -
extension SearchController : UITextFieldDelegate {
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    search()
    checkFilter()
    return true
  }
  
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    onMainAfter { [weak self] in self?.header.checkCancelButton() }
    return true
  }
}

// MARK: - ArticleVCdelegate -
extension SearchController: ArticleVCdelegate {
  public var issue: Issue {
    return searchResultIssue
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
    if let s = searchResultIssue.sections, let artArray = searchItem.allArticles {
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

