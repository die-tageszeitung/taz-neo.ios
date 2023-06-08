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
  var image:UIImage? {
    didSet {
            (self.tableView.tableHeaderView as? NewContentTableVcHeader)?.image = image
    }
  }
  var issue:Issue? {
    didSet {
      if issue?.date == oldValue?.date { return }
      (self.tableView.tableHeaderView as? NewContentTableVcHeader)?.issue = issue
      tableView.reloadData()
    }
  }
  var largestTextWidth = 300.0
  var expandedSections: [Int] = []
  
  var widthConstraint:NSLayoutConstraint?
  
  fileprivate var sectionPressedClosure: ((Int)->())?
  fileprivate var articlePressedClosure: ((Article)->())?
  fileprivate var imagePressedClosure: (()->())?
  
  lazy var topView: UIView = {
    let v = UIView()
    return v
  }()
  
  public override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    setupTopView()
  }
  
  func setupTopView(){
    if topView.superview == nil {
      self.view.addSubview(topView)
      pin(topView, toSafe: self.view, exclude: .bottom).top?.constant = -30
      topView.pinHeight(40.0)
      topView.backgroundColor = Const.SetColor.CTBackground.color
      self.tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
    }
    self.view.bringSubviewToFront(topView)
  }
}
  
///lifecycle
extension NewContentTableVC {
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.tableView.register(NewContentTableVcCell.self,
                            forCellReuseIdentifier: Self.CellIdentifier)
    self.tableView.register(ContentTableHeaderFooterView.self,
                            forHeaderFooterViewReuseIdentifier: Self.SectionHeaderIdentifier)
    self.tableView.backgroundColor = Const.SetColor.CTBackground.color
    self.tableView.rowHeight = UITableView.automaticDimension
    self.tableView.estimatedRowHeight = 100.0
    if #available(iOS 15.0, *) {
      self.tableView.sectionHeaderTopPadding = 0
    }
    setupHeader()
  }
  
  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    self.widthConstraint?.constant = size.width
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    #warning("toDo extend background, prevent overflow cells")
//    if let tvsv = self.tableView.superview {
//      //10...to align to taz Logo top
//      pin(self.tableView, toSafe: tvsv).top.constant = 10.0
//    }
//    self.tableView.contentInset = UIEdgeInsets(top: 70, left: 0, bottom: 0, right: 0)
    super.viewDidAppear(animated)
  }
}

///actions
extension NewContentTableVC {
  /// Define closure to call when a content label has been pressed
  public func onSectionPress(closure: @escaping (Int)->()) {
    sectionPressedClosure = closure
  }
  
  public func onArticlePress(closure: @escaping (Article)->()) {
    articlePressedClosure = closure
  }
  
  /// Define closure to call when the image has been tapped
  public func onImagePress(closure: @escaping ()->()) {
    imagePressedClosure = closure
  }
}

///handle expanded/collapsed
extension NewContentTableVC {
  
  func setupHeader(){
    let header = NewContentTableVcHeader(frame: CGRect(x: 0,
                                                       y: 0,
                                                       width: UIScreen.shortSide,
                                                       height: 250))
    header.bottomLabel.onTapping {[weak self] _ in
      if header.bottomLabel.text == header.closeText {
        header.bottomLabel.text = header.openText
        self?.collapseAll()
      }else {
        header.bottomLabel.text = header.closeText
        self?.expandAll()
      }
    }
    header.pinHeight(250.0)
    self.tableView.tableHeaderView = header
  }
  
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
    articlePressedClosure?(art)
    log("you tapped: \(art.title)")
  }
  
  public override func tableView(_ tableView: UITableView,
                                 cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell
    = tableView.dequeueReusableCell(withIdentifier: Self.CellIdentifier,
                                    for: indexPath) as? NewContentTableVcCell
    ?? NewContentTableVcCell()
    cell.article = issue?.sections?.valueAt(indexPath.section)?.articles?.valueAt(indexPath.row)
    cell.customImageView.image = cell.article?.images?.first?.image(dir: issue?.dir)?.invertedIfNeeded
    return cell
  }
}


fileprivate class NewContentTableVcHeader: UIView {
  
  let closeText = "alle ressorts schliessen"
  let openText = "alle ressorts öffnen"
  
  var issue: Issue? {
    didSet {
      topLabel.text
      = "\(issue?.validityDateText(timeZone: GqlFeeder.tz) ?? "")"
        .replacingOccurrences(of: ", ", with: ",\n")
    }
  }
  
  var image: UIImage? {
    didSet {
      imageView.image = image
      updateImage()
    }
  }
  
  var imageView = UIImageView()
  var topLabel = UILabel()
  var bottomLabel = UILabel()
  
  var imageAspectConstraint: NSLayoutConstraint?
  
  override func didMoveToSuperview() {
    if imageView.superview == nil { setup() }
    super.didMoveToSuperview()
  }
  
  func updateImage(){
    guard let image = image else { return }
    let ratio = image.size.width / image.size.height
    if imageAspectConstraint == nil {
      imageAspectConstraint = imageView.pinAspect(ratio: ratio)
    }
    else {
      imageAspectConstraint?.constant = ratio
    }
  }
  
  func setup(){
    self.addSubview(imageView)
    self.addSubview(topLabel)
    self.addSubview(bottomLabel)
    
    imageView.shadow()
    imageView.layer.shadowColor = Const.SetColor.CTArticle.color.cgColor
    imageView.contentMode = .scaleAspectFit
    
    topLabel.contentFont()
    bottomLabel.contentFont()
    
    bottomLabel.text = openText
    topLabel.numberOfLines = 0
    
    pin(imageView, to: self, dist: Const.Size.DefaultPadding, exclude: .right)
    pin(topLabel.left, to: imageView.right, dist: 10)
    pin(topLabel.right, to: self.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    pin(topLabel.top, to: imageView.top)
    pin(bottomLabel.left, to: imageView.right, dist: 10)
    pin(bottomLabel.bottom, to: imageView.bottom)
    pin(bottomLabel.right, to: self.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
  }
}

fileprivate  class NewContentTableVcCell: UITableViewCell {
  
  var articleIdentifier: String?
  
  let starFill = UIImage(named: "star-fill")?.withTintColor(Const.Colors.iconButtonInactive,
                                               renderingMode: .alwaysOriginal)
  let star = UIImage(named: "star")?.withTintColor(Const.Colors.iconButtonInactive,
                                               renderingMode: .alwaysOriginal)
  
  var article: Article? {
    didSet {
      articleIdentifier = article?.html?.name
      let attributedString
      = NSMutableAttributedString(string: article?.authors() ?? "")
      let range = NSRange(location: 0, length: attributedString.length)
      
      let boldFont = Const.Fonts.titleFont(size: 13.5)
      attributedString.addAttribute(.font, value: boldFont, range: range)
      attributedString.addAttribute(.backgroundColor, value: UIColor.clear, range: range)
      

      if let rd = article?.readingDuration {
        let timeString
        = NSMutableAttributedString(string: " \(rd)min")
        let trange = NSRange(location: 0, length: timeString.length)
        let thinFont = Const.Fonts.contentFont(size: 12.0)
        timeString.addAttribute(.font, value: thinFont, range: trange)
        timeString.addAttribute(.foregroundColor, value: Const.Colors.iconButtonInactive, range: trange)
        timeString.addAttribute(.backgroundColor, value: UIColor.clear, range: trange)
        attributedString.append(timeString)
      }
      bottomLabel.attributedText = attributedString
      
      titleLabel.text = article?.title
      customTextLabel.text = article?.teaser
      
      bookmarkButton.image = article?.hasBookmark ?? false ? starFill : star
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
    
    let rightSpacer = UIView.verticalSpacer
    
    v.addSubview(titleLabel)
    v.addSubview(customTextLabel)
    v.addSubview(bottomLabel)
    v.addSubview(customImageView)
    v.addSubview(rightSpacer)
    v.addSubview(bookmarkButton)
    
    titleLabel.numberOfLines = 2
    customTextLabel.numberOfLines = 3
    bottomLabel.numberOfLines = 0
    
    titleLabel.boldContentFont()
    customTextLabel.contentFont()
    bottomLabel.boldContentFont(size: 13.5)
    
    let imgWidth = 60.0
    customImageView.pinSize(CGSize(width: imgWidth, height: imgWidth))
    customImageView.contentMode = .scaleAspectFill
    customImageView.clipsToBounds = true
    
    pin(titleLabel.top, to: v.top, priority: .required)
    pin(titleLabel.left, to: v.left)
    pin(titleLabel.right, to: v.right, dist: -(imgWidth + 10))
    
    pin(customTextLabel.top, to: titleLabel.bottom, dist: 4.0)
    pin(customTextLabel.left, to: v.left)
    pin(customTextLabel.right, to: v.right, dist: -(imgWidth + 10))
    customTextLabel.setContentHuggingPriority(.defaultLow, for: .vertical)//the spacer!
    
    pin(rightSpacer.right, to: v.right)
    pin(bottomLabel.top, to: customTextLabel.bottom, dist: 8.0)
    pin(bottomLabel.left, to: v.left)
    pin(bottomLabel.right, to: v.right, dist: -(imgWidth + 10))
    pin(bottomLabel.bottom, to: v.bottom)
    
    pin(customImageView.top, to: v.top)
    pin(customImageView.right, to: v.right)
    
    bookmarkButton.pinSize(CGSize(width: 26, height: 26))
    pin(rightSpacer.top, to: customImageView.bottom)
    pin(bookmarkButton.top, to: rightSpacer.bottom, dist: 10)
    pin(bookmarkButton.right, to: v.right)
    pin(bookmarkButton.bottom, to: v.bottom)
    
    bookmarkButton.onTapping {[weak self] _ in
      self?.article?.hasBookmark.toggle()
    }
    
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
    pin(content, to: contentView, dist: Const.Size.DefaultPadding)
    
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      guard let art = msg.sender as? StoredArticle,
            art.html?.name == self?.articleIdentifier else { return }
      self?.bookmarkButton.image = art.hasBookmark ? self?.starFill : self?.star
    }
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
    self.addBorderView(Const.Colors.iconButtonInactive,
                       edge: .top,
                       insets: Const.Insets.Default)
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


extension UIImage {
  
  var invertedIfNeeded: UIImage {
    if self.size.width > 200 || self.size.height > 200 { return self }
    if !Defaults.darkMode { return self }
    return inverted
  }
  
  var inverted: UIImage {
    guard let cgImage = cgImage else { return self }
    let ciSourceImage = CIImage(cgImage: cgImage)
    let ciFilter = CIFilter(name: "CIColorInvert")
    ciFilter?.setValue(ciSourceImage, forKey: kCIInputImageKey)
    guard let ciResultImage
            = ciFilter?.value(forKey: kCIOutputImageKey) as? CIImage
    else{ return self }
    return UIImage(ciImage: ciResultImage)
  }
}

extension UIView {
  static var verticalSpacer: UIView {
    let v = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    v.setContentHuggingPriority(.defaultLow, for: .vertical)
    return v
  }
}
