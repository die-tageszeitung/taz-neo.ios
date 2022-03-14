//
//  SearchResultsTVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 29.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib

class SearchResultsTVC:UITableViewController{
  
  var searchItem:SearchItem?
  
  lazy var serachSettingsVC = SearchSettingsVC()
  
  /// a uiview not a common UIToolbar
  lazy var searchBarTools:SearchBarTools = {
    let tool = SearchBarTools()
    tool.onTapping { sender in
      tool.extendedSearchButton.activeColor = .red
      self.serachSettingsVC.modalPresentationStyle = UIModalPresentationStyle.popover
      self.present(self.serachSettingsVC, animated: true, completion: nil)
      let popoverPresentationController = self.serachSettingsVC.popoverPresentationController
      popoverPresentationController?.sourceView = sender.view
    }
    return tool
  }()
  
  public var onBackgroundTap : (()->())?

  static let SearchResultsCellIdentifier = "searchResultsCell"
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    edgesForExtendedLayout = []
    self.tableView.register(SearchResultsCell.self, forCellReuseIdentifier: Self.SearchResultsCellIdentifier)
    self.tableView.backgroundColor = Const.Colors.opacityBackground
//    self.tableView.contentInsetAdjustmentBehavior = .never
    self.navigationController?.navigationBar.isTranslucent = false
    self.tableView.backgroundView?.onTapping {   [weak self] _ in
      guard let self = self else { return }
      self.onBackgroundTap?()
    }
    
    self.tableView.tableHeaderView = searchBarTools
    self.tableView.tableFooterView = UIView(frame: .zero)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    print("Results appeard")
    self.tableView.insetsContentViewsToSafeArea = false
  }
  
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }
}

// MARK: - UITableViewDataSource
extension SearchResultsTVC {
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 0 //searchItem?.allArticles?.count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultsTVC.SearchResultsCellIdentifier,
                                             for: indexPath) as! SearchResultsCell
    cell.titleLabel.text = "Eintrag: \(indexPath.row)"
//    cell.content = self.searchItem?.searchHitList?.valueAt(indexPath.row)
    return cell
  }
}

// MARK: - SearchResultsCell
class SearchResultsCell: UITableViewCell {
  
  var content : GqlSearchHit? {
    didSet{
      if let content = content {
        titleLabel.text = content.article.title
        contentLabel.attributedText = content.snippet?.attributedFromSnippetString
        dateLabel.text = content.date.short
      }
      else {
        titleLabel.text = ""
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
    let label = UILabel("", type: .content)
    label.textAlignment = .left
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  func setup() {
    self.backgroundColor = Const.SetColor.CTBackground.color
    addSubview(cellView)
    cellView.addSubview(titleLabel)
    cellView.addSubview(contentLabel)
    cellView.addSubview(dateLabel)
    self.selectionStyle = .none
    pin(cellView, to: self, dist: Const.ASize.DefaultPadding)
    
    pin(titleLabel.left, to: cellView.left)
    pin(titleLabel.right, to: cellView.right)
    pin(contentLabel.left, to: cellView.left)
    pin(contentLabel.right, to: cellView.right)
    pin(dateLabel.left, to: cellView.left)
    pin(dateLabel.right, to: cellView.right)
    
    pin(titleLabel.top, to: cellView.top)
    pin(contentLabel.top, to: titleLabel.bottom, dist: 3)
    pin(dateLabel.top, to: contentLabel.bottom, dist: 7)
    pin(dateLabel.bottom, to: cellView.bottom)
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
          s.append(NSAttributedString(string: tagged, attributes: [.backgroundColor: UIColor.yellow.withAlphaComponent(0.7), .foregroundColor: UIColor.black]))
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
