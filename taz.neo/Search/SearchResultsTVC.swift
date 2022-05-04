//
//  SearchResultsTableView.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib
import CoreGraphics
import UIKit

class SearchResultsTableView:UITableView{
  
  var beginDragOffset:CGFloat?
  
  var searchClosure: (()->())?
  
  var openSearchHit: ((GqlSearchHit)->())?
  
  var searchItem:SearchItem? {
    didSet {
      searchItem?.noMoreSearchResults ?? true
      ? footer.hideAnimated()
      : footer.showAnimated()
      self.reloadData()
    }
  }
  
  lazy var footer = LoadingView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
  
  public var onBackgroundTap : (()->())?
  
  func scrollTop(){
    let animated = contentOffset.y < 8*UIWindow.size.height
    setContentOffset(CGPoint(x: 1, y: -40), animated: animated)
  }
  
  func restoreInitialState() -> Bool{
    ///first scroll up
    if contentOffset.y > 20 {
      scrollTop()
      return false
    }
    //then reset everything
    searchItem = nil
//    serachSettingsVC.restoreInitialState()
    checkFilter()
    return true
  }
  
  func checkFilter(){
//    self.fixedHeader.filterActive = self.serachSettingsVC.data.settings.isChanged
  }

  static let SearchResultsCellIdentifier = "searchResultsCell"
  
  func setup(){
    self.register(SearchResultsCell.self, forCellReuseIdentifier: Self.SearchResultsCellIdentifier)
    self.backgroundColor = Const.Colors.opacityBackground
    footer.style = .white
    footer.alpha = 0.0
    self.tableFooterView = footer
    
    self.dataSource = self
    self.delegate = self
  }
  
  // MARK: *** Lifecycle ***
  override init(frame: CGRect, style: UITableView.Style) {
    super.init(frame: frame, style: style)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  var handleScrolling: ((_ withOffset:CGFloat, _ isEnd: Bool)->())?
}

// MARK: - UITableViewDataSource -
extension SearchResultsTableView: UITableViewDelegate {
  
  func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    guard let currentCount = self.searchItem?.searchHitList?.count else { return }
    if indexPath.row == currentCount - 2
        && currentCount > 2
        && searchItem?.noMoreSearchResults == false {
      searchClosure?()
      footer.alpha = 1.0
    }
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if let searchHit = searchItem?.searchHitList?.valueAt(indexPath.row) {
      openSearchHit?(searchHit)
    }
  }
  
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    beginDragOffset = scrollView.contentOffset.y
  }
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    guard let beginDragOffset = beginDragOffset else { return }
    handleScrolling?(beginDragOffset - scrollView.contentOffset.y, true)
    self.beginDragOffset = nil
  }
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard let beginDragOffset = beginDragOffset else { return }
    handleScrolling?(beginDragOffset - scrollView.contentOffset.y, false)
  }
  
  
}
// MARK: - UITableViewDataSource -
extension SearchResultsTableView: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return searchItem?.allArticles?.count ?? 0
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: Self.SearchResultsCellIdentifier,
                                             for: indexPath) as! SearchResultsCell
    cell.content = self.searchItem?.searchHitList?.valueAt(indexPath.row)
    return cell
  }

}

// MARK: - SearchResultsCell
class SearchResultsCell: UITableViewCell {
  
  var content : GqlSearchHit? {
    didSet{
      if let content = content {
        titleLabel.text = content.article.title
        authorLabel.text = content.article.authors()
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
    let label = UILabel("", type: .content)
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
    
    pin(titleLabel.top, to: cellView.top, dist: 15)
    pin(authorLabel.top, to: titleLabel.bottom, dist: 8)
    pin(contentLabel.top, to: authorLabel.bottom, dist: 8)
    pin(dateLabel.top, to: contentLabel.bottom, dist: 8)
    pin(dateLabel.bottom, to: cellView.bottom, dist: -12)
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
          let tagged
          = tagged.starts(with: openTag)
          ? String(tagged.dropFirst(openTag.count))
          : tagged
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


