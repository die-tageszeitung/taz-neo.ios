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
  
  func searchFor(searchString: String){
    header.searchTextField.text = searchString
    self.searchItem.reset()
    self.search(false)
  }
  
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
  
  var blockedState = false
  
  private var currentState: searchState = .initial {
    didSet {
      checkStateChange()
    }
  }
  
  func checkStateChange(){
    if blockedState == true {
      onMainAfter{[weak self] in self?.checkStateChange() }
      return
    }
    blockedState = true
    
    switch currentState {
      case .initial:
        placeholderView.label.text = Localized("search_placeholder_initial")
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
        placeholderView.label.text = Localized("search_placeholder_empty_result")
        centralActivityIndicator.isHidden = true
        placeholderView.showAnimated()
        resultsTable.hideAnimated()
    }
    //Animations should be finished
    onMainAfter(0.6){[weak self] in self?.blockedState = false }
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
      self?.deactivateCoachmark(Coachmarks.Search.filter)
      self?.checkFilter()
    }
    header.searchTextField.delegate = self
    return header
  }()
  
  lazy var searchSettingsView:SearchSettingsView = {
    let v = SearchSettingsView(frame: .zero,
                               style: .grouped,
                               minimumSearchDate: feederContext.defaultFeed.firstSearchableIssue ?? Date(timeIntervalSinceReferenceDate: 0))
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
    v.helpButton.onTapping {[weak self] _ in
      guard let url = Bundle.main.url(forResource: "searchHelp",
                                      withExtension: "html",
                                      subdirectory: "files"),
            case let file = File(url),
            file.exists  else {
        self?.log("search Help not found")
        return
      }
      let introVC = TazIntroVC()
      introVC.htmlIntro = url.absoluteString
      introVC.topOffset = 40
      let intro = file
      introVC.webView.webView.load(url: intro.url)
      introVC.webView.webView.scrollView.contentInsetAdjustmentBehavior = .never
      introVC.webView.webView.scrollView.isScrollEnabled = true
      
      introVC.webView.onX { _ in
        introVC.dismiss(animated: true, completion: nil)
      }
      self?.modalPresentationStyle = .fullScreen
      introVC.modalPresentationStyle = .fullScreen
      introVC.webView.webView.scrollDelegate.atEndOfContent {_ in }
      self?.present(introVC, animated: true) {
        //Overwrite Default in: IntroVC viewDidLoad
        introVC.webView.buttonLabel.text = nil
      }
    }
    v.textFieldDelegate = self
    return v
  }()
  
  lazy var placeholderView = PlaceholderView(Localized("search_placeholder_initial"),
                                             image: UIImage(named: "search-magnifier"))

  
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
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    showCoachmarkIfNeeded()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.view.backgroundColor = Const.SetColor.HBackground.color
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(placeholderView)
    self.view.addSubview(centralActivityIndicator)
    self.view.addSubview(resultsTable)
    self.view.addSubview(searchSettingsView)
    self.view.addSubview(header)
    centralActivityIndicator.centerAxis()
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
    
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(keyboardWillShow),
        name: UIResponder.keyboardWillShowNotification,
        object: nil
    )
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(keyboardWillHide),
        name: UIResponder.keyboardWillHideNotification,
        object: nil
    )
    
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

extension SearchController: ReloadAfterAuthChanged {
  public func reloadOpened(){
    self.articleVC.dismiss(animated: true)
    self.searchItem.reset()
    self.search(true)
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
    if let idx = searchItem.allArticles?.firstIndex(where: {$0.html?.name == searchHit.article.html?.name}) {
      self.articleVC.index = idx
    }
    
    if self.articleVC.parentViewController == nil {
      self.navigationController?.pushViewController(self.articleVC, animated: true)
    }
  }

  private func search(_ sendDismissNotofication:Bool = false) {
    var searchSettings = self.searchSettingsView.data.settings
    header.searchTextField.text = header.searchTextField.text?.trimed ?? ""
    searchSettings.text = header.searchTextField.text
    if searchSettings.searchTermTooShort {
      header.setStatusLabel(text: "Bitte Suchbegriff eingeben!",
                                    color: .red)
      if sendDismissNotofication { Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)}
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
      if sendDismissNotofication { Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)}
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
    Usage.track(Usage.event.search.filterSearch)
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

// MARK: - Handle Keyboard hides SearchSettingsTable
extension SearchController{

  @objc func keyboardWillShow(_ notification: Notification) {
      if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
          let keyboardRectangle = keyboardFrame.cgRectValue
          let keyboardHeight = keyboardRectangle.height
        searchSettingsView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
      }
  }
  
  @objc func keyboardWillHide(_ notification: Notification) {
    searchSettingsView.contentInset = .zero
  }
}

// MARK: - UITextFieldDelegate -
extension SearchController : UITextFieldDelegate {
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    Usage.track(Usage.event.search.keyboardSearch)
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
        guard let fileName = art.html?.fileName else { continue }
        d[fileName] = s
      }
      return d
    }
    return [:]
  }
  
  public func displaySection(index: Int) {
    debug("TODO:: displaySection \(index)")
  }
  
  public func linkPressed(from: URL?, to: URL?) {
    guard let to = to else { return }
    self.debug("Calling application for: \(to.absoluteString)")
    if UIApplication.shared.canOpenURL(to) {
      UIApplication.shared.open(to, options: [:], completionHandler: nil)
    }
    else {
      error("No application or no permission for: \(to.absoluteString)")
    }
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
  public func writeToDisk() -> String? {
    guard let filename = self.article.html?.fileName else { return nil }
    let f = TmpFileEntry(name: filename)
    f.content = self.articleHtml
    return f.path
  }
  
  var localPath: String? {
    guard let fileName = article.html?.fileName else { return nil }
    let f = File(dir: Dir.searchResultsPath, fname: fileName)
    if !f.exists { return nil }
    return Dir.searchResultsPath + "/" + fileName
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

extension SearchController: CoachmarkVC {
  
   public var viewName: String { Coachmarks.Search.typeName }
  
  public func targetView(for item: CoachmarkItem) -> UIView? {
    guard let item = item as? Coachmarks.Search else { return nil }
    switch item {
      case .filter:
        return header.extendedSearchButton
    }
  }
}
