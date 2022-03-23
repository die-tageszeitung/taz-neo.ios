//
//  SearchResultsTVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib
import CoreGraphics
import UIKit

class SearchResultsTVC:UITableViewController{
  
  var searchClosure: (()->())?
  
  var openSearchHit: ((GqlSearchHit)->())?
  
  var searchItem:SearchItem? {
    didSet {
      searchItem?.noMoreSearchResults ?? true
      ? footer.hideAnimated()
      : footer.showAnimated()
      tableView.reloadData()
    }
  }
  
  lazy var serachSettingsVC:SearchSettingsVC = {
    let vc = SearchSettingsVC()
    vc.view.pinWidth(UIWindow.size.width, priority: .defaultLow)//prevent size animation error
    vc.setup()
    vc.finishedClosure = { [weak self] doSearch in
      if doSearch {
        self?.searchClosure?()
      }
      else {
        //Do both Steps, scroll up and reset
        _ = self?.restoreInitialState()
        _ = self?.restoreInitialState()
      }
      self?.toggleExtendedSearch()
    }
    return vc
  }()
  
  /// a uiview not a common UIToolbar
  lazy var fixedHeader:SearchBarFixedHeader = {
    let view = SearchBarFixedHeader()
    view.extendedSearchButton.onPress { [weak self] _ in
      self?.toggleExtendedSearch()
    }
    return view
  }()
  
  func toggleExtendedSearch(){
    if self.serachSettingsVC.view.superview == nil {//open
      self.fixedHeader.filterActive = true
      self.fixedHeader.textLabel.alpha = 0.0
      self.fixedHeader.set(text: "erweiterte suche", font: Const.Fonts.boldContentFont)
      fixedHeader.wrapper.addSubview(self.serachSettingsVC.view)
      fixedHeader.wrapper.layoutSubviews()
      pin(self.serachSettingsVC.view, to: fixedHeader.wrapper)
      UIView.animate(withDuration: 0.7, delay: 0.0, options: .curveEaseInOut) {
        self.fixedHeader.filterWrapperHeightConstraint?.constant = 1200
        self.fixedHeader.textLabel.alpha = 1.0
        self.fixedHeader.seperator.alpha = 0.0
        self.fixedHeader.wrapper.layoutSubviews()
      } completion: { _ in  }
    }
    else {//close
      UIView.animate(withDuration: 0.7, delay: 0.0, options: .curveEaseInOut) {
        self.fixedHeader.filterWrapperHeightConstraint?.constant = 0
        self.fixedHeader.textLabel.alpha = 0.0
        self.fixedHeader.seperator.alpha = 1.0
        self.fixedHeader.wrapper.layoutSubviews()
      } completion: { _ in
        self.serachSettingsVC.view.removeFromSuperview()
        self.checkFilter()
      }
    }
  }
  
  lazy var footer = LoadingView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
  
  public var onBackgroundTap : (()->())?
  
  func scrollTop(){
    let animated = tableView.contentOffset.y < 8*UIWindow.size.height
    tableView.setContentOffset(CGPoint(x: 1, y: -40), animated: animated)
  }
  
  func restoreInitialState() -> Bool{
    ///first scroll up
    if tableView.contentOffset.y > 20 {
      scrollTop()
      return false
    }
    //then reset everything
    searchItem = nil
    serachSettingsVC.restoreInitialState()
    checkFilter()
    return true
  }
  
  func checkFilter(){
    self.fixedHeader.filterActive = self.serachSettingsVC.data.settings.isChanged
  }

  static let SearchResultsCellIdentifier = "searchResultsCell"
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    edgesForExtendedLayout = []
    self.tableView.register(SearchResultsCell.self, forCellReuseIdentifier: Self.SearchResultsCellIdentifier)
    self.tableView.backgroundColor = Const.Colors.opacityBackground
    self.navigationController?.navigationBar.isTranslucent = false
    self.tableView.backgroundView?.onTapping {   [weak self] _ in
      guard let self = self else { return }
      self.onBackgroundTap?()
    }
    footer.style = .white
    footer.alpha = 0.0
    self.tableView.tableFooterView = footer
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    tableView.superview?.addSubview(fixedHeader)
    tableView.contentInset = UIEdgeInsets(top: 35, left: 0, bottom: 0, right: 0)
    tableView.scrollIndicatorInsets = UIEdgeInsets(top: 35, left: 0, bottom: 0, right: 0)
  }
}

// MARK: - UITableViewDataSource
extension SearchResultsTVC {
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return searchItem?.allArticles?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultsTVC.SearchResultsCellIdentifier,
                                             for: indexPath) as! SearchResultsCell
    cell.content = self.searchItem?.searchHitList?.valueAt(indexPath.row)
    return cell
  }
  
  override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    guard let currentCount = self.searchItem?.searchHitList?.count else { return }
    if indexPath.row == currentCount - 2
        && currentCount > 2
        && searchItem?.noMoreSearchResults == false {
      searchClosure?()
      footer.alpha = 1.0
    }
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if let searchHit = searchItem?.searchHitList?.valueAt(indexPath.row) {
      openSearchHit?(searchHit)
    }
  }
}

// MARK: - SearchResultsCell
class SearchResultsCell: UITableViewCell {
  
  var content : GqlSearchHit? {
    didSet{
      if let content = content {
        titleLabel.text = content.article.title
        authorLabel.text = content.article.authors() ?? "- - -"
        contentLabel.attributedText = content.snippet?.attributedFromSnippetString
        dateLabel.text = content.date.short + " " + (content.sectionTitle ?? "")
      }
      else {
        titleLabel.text = ""
        authorLabel.text = ""
        contentLabel.text = ""
        dateLabel.text = ""
      }
    }
  }
  
  lazy var cellView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.clear
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()
  

  lazy var titleLabel: UILabel = {
    let label = UILabel("", type: .bold)
    label.textAlignment = .left
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  lazy var dateLabel: UILabel = {
    let label = UILabel("", type: .small)
    label.textAlignment = .left
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  lazy var contentLabel: UILabel = {
    let label = UILabel("", type: .contentText)
    label.textAlignment = .left
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  lazy var authorLabel: UILabel = {
    let label = UILabel("", type: .content)
    label.textAlignment = .left
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  func setup() {
    self.backgroundColor = Const.SetColor.CTBackground.color
    addSubview(cellView)
    cellView.addSubview(titleLabel)
    cellView.addSubview(authorLabel)
    cellView.addSubview(contentLabel)
    cellView.addSubview(dateLabel)
    self.selectionStyle = .none
    pin(cellView, to: self, dist: Const.ASize.DefaultPadding)
    
    pin(titleLabel.left, to: cellView.left)
    pin(titleLabel.right, to: cellView.right)
    pin(authorLabel.left, to: cellView.left)
    pin(authorLabel.right, to: cellView.right)
    pin(contentLabel.left, to: cellView.left)
    pin(contentLabel.right, to: cellView.right)
    pin(dateLabel.left, to: cellView.left)
    pin(dateLabel.right, to: cellView.right)
    
    pin(titleLabel.top, to: cellView.top, dist: 2)
    pin(authorLabel.top, to: titleLabel.bottom, dist: 3)
    pin(contentLabel.top, to: authorLabel.bottom, dist: 3)
    pin(dateLabel.top, to: contentLabel.bottom, dist: 7)
    pin(dateLabel.bottom, to: cellView.bottom, dist: 2)
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
}

// MARK: - String Ext. attributedFromSnippetString
extension String {
  var attributedFromSnippetString:NSAttributedString? {
    get {
      let s = NSMutableAttributedString()
      let openTag =  "<span class=\"snippet\">"
      let closeTag =  "</span>"
      
      let scanner = Scanner(string: self)
      var highlighted:Bool = false
      while !scanner.isAtEnd {
        if highlighted, let tagged = scanner.scanTill(string: closeTag) {
          s.append(NSAttributedString(string: tagged, attributes: [.backgroundColor: Const.Colors.fountTextHighlight, .foregroundColor: UIColor.black]))
          s.append(NSAttributedString(string: " "))
        }
        else if let text = scanner.scanTill(string: openTag){
          s.append(NSAttributedString(string: text))
        }
        highlighted = !highlighted
      }
      return s.length > 0 ? s : nil
    }
  }
}

// MARK: - Scanner
extension Scanner {
  public func scanTill(string: String) -> String? {
    var value: NSString?
    guard scanUpTo(string, into: &value) else { return nil }
    scanString(string, into: nil)///Moved the current start scan location for next item
    return value as String?
  }
}


// MARK: - SearchResultArticleVc
class SearchResultArticleVc : ArticleVC {
  var navigationBarHiddenRestoration:Bool?
  var maxResults:Int = 0
  var searchClosure: (()->())?
  
  override func setHeader(artIndex: Int) {
    super.setHeader(artIndex: artIndex)
    header.pageNumber = "\(artIndex+1)/\(maxResults)"
    if artIndex >= articles.count - 1 {
      searchClosure?()
    }
  }
  
  var searchContents: [Article] = [] {
    didSet {
      super.articles = searchContents
      super.contents = searchContents
      let path = feeder.issueDir(issue: issue).path
      let curls: [ContentUrl] = contents.map { cnt in
        ContentUrl(path: path, issue: issue, content: cnt) { [weak self] curl in
          guard let this = self else { return }
          this.dloader.downloadIssueData(issue: this.issue, files: curl.content.files) { err in
            if err == nil { curl.isAvailable = true }
          }
        }
      }
      displayUrls(urls: curls)
    }
  }
  
  override func setupSlider() {}
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationBarHiddenRestoration = self.navigationController?.isNavigationBarHidden
    self.navigationController?.isNavigationBarHidden = true
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if let val = navigationBarHiddenRestoration {
      self.navigationController?.isNavigationBarHidden = val
    }
  }
}
