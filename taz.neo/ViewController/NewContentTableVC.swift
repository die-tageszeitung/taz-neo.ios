//
//  NewContentTableVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 06.06.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib


/// content table for app view of an issue displayed as flyout ("Flügel")
/// tableHedaer = moment + date
/// section Header = section title + chevron > or ^
/// cell as Article Preview (like in serach or bookmarks
public class NewContentTableVC: UITableViewController {
  
  fileprivate static let CellIdentifier = "NewContentTableVcCell"
  fileprivate static let SectionHeaderIdentifier = "ContentTableHeaderFooterView"
  
  var feeder:Feeder?
  var image:UIImage?
  var issue:Issue?
  var largestTextWidth = 300.0
  var expandedSections: [Int] = []
  
  var widthConstraint:NSLayoutConstraint?
  
  fileprivate var sectionPressedClosure: ((Int)->())?
  fileprivate var imagePressedClosure: (()->())?
  
  
}
  
///lifecycle
extension NewContentTableVC {
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.tableView.register(NewContentTableVcCell.self,
                            forCellReuseIdentifier: Self.CellIdentifier)
    self.tableView.register(ContentTableHeaderFooterView.self,
                            forHeaderFooterViewReuseIdentifier: Self.SectionHeaderIdentifier)
    
    self.tableView.rowHeight = UITableView.automaticDimension
    self.tableView.estimatedRowHeight = 100.0
    if #available(iOS 15.0, *) {
      self.tableView.sectionHeaderTopPadding = 0
    }
  }
  
  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    self.widthConstraint?.constant = size.width
    
//    updateWidth(size.width)
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
//    widthConstraint = self.tableView.pinWidth(self.view.frame.size.width)
//    updateWidth(self.view.frame.size.width)
  }

//  func updateWidth(_ width:CGFloat) {
//    widthConstraint?.constant
//    topGradient.isHidden = UIDevice.current.orientation.isLandscape && Device.isIphone
//  }
}

///actions
extension NewContentTableVC {
  /// Define closure to call when a content label has been pressed
  public func onSectionPress(closure: @escaping (Int)->()) {
    sectionPressedClosure = closure
  }
  
  /// Define closure to call when the image has been tapped
  public func onImagePress(closure: @escaping ()->()) {
    imagePressedClosure = closure
  }
}

///handle expanded/collapsed
extension NewContentTableVC {
  func collapse(section: Int){
    
  }
  
  func expand(section: Int){
    
  }
  
  
  /// expand/colapse section
  /// - Parameter section: section to toggle
  /// - Returns: true if section is **colapsed**
  func toggle(section: Int) -> Bool {
    let cellCount
    = issue?.sections?.valueAt(section)?.articles?.count ?? 0
    
    let changedIdx = (0..<cellCount).map { i in
      return IndexPath(item: i, section: section)
    }
    
    guard changedIdx.count > 0 else { return false }
    
    if let idx = expandedSections.firstIndex(of: section) {
      tableView.performBatchUpdates {
        expandedSections.remove(at: idx)
        tableView.deleteRows(at: changedIdx, with: .automatic)
      }
      return true
    }
    tableView.performBatchUpdates {
      expandedSections.append(section)
      tableView.insertRows(at: changedIdx, with: .automatic)
    }
    return false
  }
  
  func collapseAll(expect: Int? = nil){
    if let expect = expect {
      expandedSections = [expect]
    }
    else {
      expandedSections = []
    }
    tableView.reloadSections(IndexSet(allSectionIndicies),
                             with: .none)
  }
  
  func expandAll(){
    expandedSections = allSectionIndicies
    tableView.reloadSections(IndexSet(expandedSections),
                             with: .automatic)
  }
  
  var allSectionIndicies: [Int] { return Array(0...(issue?.sections?.count ?? 0))}
}

extension NewContentTableVC {
  public override func numberOfSections(in tableView: UITableView) -> Int {
    let imprintCount = issue?.imprint == nil ? 0 : 1
    return (issue?.sections?.count ?? 0) + imprintCount
  }
  
  public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if expandedSections.contains(section) == false { return 0 }
    return issue?.sections?.valueAt(section)?.articles?.count ?? 0
  }
  
  public override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 38.5
  }
  
  public override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: Self.SectionHeaderIdentifier)
            as? ContentTableHeaderFooterView else { return nil}
    
    if let ressort = issue?.sections?.valueAt(section) {
      header.label.text = ressort.title
      header.chevron.isHidden = ressort.type == .advertisement
      header.collapsed = true
      header.dottedLine.isHidden = ressort.type == .advertisement
    } else if section == issue?.sections?.count ?? 0 {
      header.label.text = issue?.imprint?.title ?? "Impressum"
      header.chevron.isHidden = true
      header.dottedLine.isHidden = true
    } else {
      log("a section with no title and not imprint")
      header.label.text = nil
      header.chevron.isHidden = true
      header.dottedLine.isHidden = true
    }

    header.tag = section
    
    header.onTapping { [weak self] _ in
      self?.sectionPressedClosure?(header.tag)
      self?.log("You tapped header with tdx: \(header.tag)")
      header.active = true
      header.collapsed = false
      self?.collapseAll(expect: header.tag)
    }
    
    header.chevron.onTapping { [weak self] _ in
      self?.log("You tapped header with tdx: \(header.tag)")
      header.collapsed = self?.toggle(section: header.tag) ?? true
    }
    
    
    return header
  }
  
  public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let art = issue?.sections?.valueAt(indexPath.section)?.articles?.valueAt(indexPath.row) else {
      log("Article you tapped not found for section: \(indexPath.section), row: \(indexPath.row)")
      return
    }
    log("you tapped: \(art.title)")
  }
  
  public override func tableView(_ tableView: UITableView,
                                 cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell
    = tableView.dequeueReusableCell(withIdentifier: Self.CellIdentifier,
                                    for: indexPath) as? NewContentTableVcCell
    ?? NewContentTableVcCell()
    cell.article = issue?.sections?.valueAt(indexPath.section)?.articles?.valueAt(indexPath.row)
    cell.customImageView.image = cell.article?.images?.first?.image(dir: issue?.dir)
    return cell
  }
}


fileprivate class NewContentTableVcHeader: UIView {
  
}

fileprivate  class NewContentTableVcCell: UITableViewCell {
  
  var article: Article? {
    didSet {
      var attributedString
      = NSMutableAttributedString(string: article?.authors() ?? "")
      let range = NSRange(location: 0, length: attributedString.length)
      
      let boldFont = Const.Fonts.titleFont(size: Const.Size.SmallerFontSize)
      attributedString.addAttribute(.font, value: boldFont, range: range)
      attributedString.addAttribute(.foregroundColor, value: Const.SetColor.CTDate.color, range: range)
      attributedString.addAttribute(.backgroundColor, value: UIColor.clear, range: range)
      

      if let rd = article?.readingDuration {
        var timeString
        = NSMutableAttributedString(string: " \(rd)min")
        let trange = NSRange(location: 0, length: timeString.length)
        let thinFont = Const.Fonts.contentFont(size: Const.Size.SmallerFontSize)
        timeString.addAttribute(.font, value: thinFont, range: trange)
        timeString.addAttribute(.foregroundColor, value: Const.SetColor.CTDate.color, range: trange)
        timeString.addAttribute(.backgroundColor, value: UIColor.clear, range: trange)
        attributedString.append(timeString)
      }
      bottomLabel.attributedText = attributedString
      
      titleLabel.text = article?.title
      customTextLabel.text = article?.teaser
      
      bookmarkButton.image = UIImage(named: "star")
    }
  }
  
  let customImageView = UIImageView()
  let bookmarkButton = UIImageView()
  let titleLabel = UILabel()
  let customTextLabel = UILabel()
  let bottomLabel = UILabel()
  let dottedLine = DottedLineView()
  
  
  public override func prepareForReuse() {
    customImageView.image = nil
    article = nil
  }
  
  lazy var content: UIView = {
    let v = UIView()
    v.addSubview(titleLabel)
    v.addSubview(customTextLabel)
    v.addSubview(bottomLabel)
    v.addSubview(customImageView)
    v.addSubview(bookmarkButton)
    
    titleLabel.numberOfLines = 2
    customTextLabel.numberOfLines = 3
    bottomLabel.numberOfLines = 0
    
    titleLabel.boldContentFont()
    customTextLabel.contentFont()
    bottomLabel.boldContentFont(size: Const.Size.SmallerFontSize)
    
    let imgWidth = 60.0
    customImageView.pinSize(CGSize(width: imgWidth, height: imgWidth))
    customImageView.contentMode = .scaleAspectFill
    customImageView.clipsToBounds = true
    
    pin(titleLabel.top, to: v.top)
    pin(titleLabel.left, to: v.left)
    pin(titleLabel.right, to: v.right, dist: -(imgWidth + 10))
    
    pin(customTextLabel.top, to: titleLabel.bottom, dist: 4.0)
    pin(customTextLabel.left, to: v.left)
    pin(customTextLabel.right, to: v.right, dist: -(imgWidth + 10))
    
    pin(bottomLabel.top, to: customTextLabel.bottom, dist: 8.0)
    pin(bottomLabel.left, to: v.left)
    pin(bottomLabel.right, to: v.right, dist: -(imgWidth + 10))
    pin(bottomLabel.bottom, to: v.bottom)
    
    pin(customImageView.top, to: v.top)
    pin(customImageView.right, to: v.right)
    
    bookmarkButton.pinSize(CGSize(width: 30, height: 30))
    pin(bookmarkButton.top, to: customImageView.bottom, dist: 10, priority: .fittingSizeLevel)
    pin(bookmarkButton.right, to: v.right)
    pin(bookmarkButton.bottom, to: v.bottom)
 
    return v
  }()
  
  func setup(){
    self.contentView.addSubview(content)
    self.contentView.addSubview(dottedLine)
    dottedLine.pinHeight(Const.Size.DottedLineHeight)
    dottedLine.fillColor = Const.SetColor.HText.color
    dottedLine.strokeColor = Const.SetColor.HText.color
    pin(dottedLine.left, to: self.contentView.left, dist: Const.ASize.DefaultPadding)
    pin(dottedLine.right, to: self.contentView.right, dist: -Const.ASize.DefaultPadding)
    pin(dottedLine.top, to: self.contentView.top)
    
    content.addBorder(.red)
    titleLabel.addBorder(.blue)
    customTextLabel.addBorder(.purple)
    bottomLabel.addBorder(.cyan)
    contentView.addBorder(.green)
    customImageView.addBorder(.yellow)
    
    pin(content, to: contentView, dist: Const.Size.DefaultPadding)
  }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

fileprivate class ContentTableHeaderFooterView: TazHeaderFooterView{
  
  let dottedLine = DottedLineView()
  
  var active: Bool = false {
    didSet {
      label.textColor
      = active
      ? Const.SetColor.CIColor.color
      : Const.SetColor.ios(.label).color
    }
  }
  
  override func setup(){
    super.setup()
    self.addBorder(Const.SetColor.HText.color, only: .top)
    dottedLine.isHorizontal = false
    self.contentView.addSubview(dottedLine)
    pin(dottedLine.top, to: self.contentView.top, dist: 3.0, priority: .fittingSizeLevel)
    pin(dottedLine.bottom, to: self.contentView.bottom, dist: -3.0, priority: .fittingSizeLevel)
    pin(dottedLine.right, to: self.chevron.left, dist: -5.0)
    dottedLine.pinWidth(Const.Size.DottedLineHeight/2)
    dottedLine.fillColor = Const.SetColor.HText.color
    dottedLine.strokeColor = Const.SetColor.HText.color
  }
}
