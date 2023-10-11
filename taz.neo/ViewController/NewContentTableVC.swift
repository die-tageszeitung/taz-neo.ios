//
//  NewContentTableVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 06.06.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

///handle expanded/collapsed animated

///handle expanded/collapsed
extension NewContentTableVC {
  func expand(section: Int){
    if expandedSections.contains(section) { return }
    let cellCount
    = issue?.sections?.valueAt(section)?.articles?.count ?? 0
    let changedIdx = (0..<cellCount).map { i in
      return IndexPath(item: i, section: section)
    }
    guard changedIdx.count > 0 else { return }
    ///Only handle UI Changes if still loaded and ready for reload & changes
    let tv = self.tableView.superview != nil ? tableView : nil
    tv?.beginUpdates()
    self.expandedSections.append(section)
    tv?.insertRows(at: changedIdx, with: .bottom)
    tv?.endUpdates()
  }
  
  /// expand/colapse section
  /// - Parameter section: section to toggle
  /// - Returns: true if section is **colapsed**
  func toggle(section: Int) -> Bool {
    ///Only handle UI Changes if still loaded and ready for reload & changes
    let tv = self.tableView.superview != nil ? tableView : nil
    tv?.superview?.doLayout()
    let cellCount = issue?.sections?.valueAt(section)?.articles?.count ?? 0
    
    let changedIdx = (0..<cellCount).map { i in
      return IndexPath(item: i, section: section)
    }
    
    guard changedIdx.count > 0 else { return false }
    let visibleRect = CGRect(origin: tv?.contentOffset ?? .zero, size: .zero)
//    print("visibleRect: \(visibleRect)")
    tv?.beginUpdates()
    
    if let idx = expandedSections.firstIndex(of: section) {
      expandedSections.remove(at: idx)
      tv?.deleteRows(at: changedIdx, with: .top)
      tv?.endUpdates()
//      tv?.scrollToRow(at: IndexPath(row: NSNotFound, section: section), at: .top, animated: true)
//      [NSIndexPath indexPathForRow:NSNotFound inSection:section]
      tv?.scrollRectToVisible(visibleRect, animated: true)
//      onMain { tv?.scrollRectToVisible(visibleRect, animated: true) }
      return true
    }
    expandedSections.append(section)
    tv?.insertRows(at: changedIdx, with: .bottom)
    tv?.endUpdates()
//    tv?.scrollRectToVisible(visibleRect, animated: true)
//    onMain { tv?.scrollRectToVisible(visibleRect, animated: true) }

    tv?.scrollToRow(at: IndexPath(row: 0, section: section), at: .top, animated: true)
    return false
  }
  
  func collapseAll(expect: Int? = nil){
    ///Only handle UI Changes if still loaded and ready for reload & changes
    let tv = self.tableView.superview != nil ? tableView : nil
    tv?.beginUpdates()
    if let expect = expect {
      expandedSections = [expect]
    }
    else {
      expandedSections = []
    }
    tv?.reloadSections(IndexSet(allSectionIndicies),
                                      with: .top)
    tv?.endUpdates()
  }
  
  func expandAll(){
    ///Only handle UI Changes if still loaded and ready for reload & changes
    let tv = self.tableView.superview != nil ? tableView : nil
    tv?.beginUpdates()
    expandedSections = allSectionIndicies
    tv?.reloadSections(IndexSet(expandedSections),
                             with: .bottom)
    tv?.endUpdates()
  }
  
  var allSectionIndicies: [Int] { return Array(0...(issue?.sections?.count ?? 0))}
}


/// content table for app view of an issue displayed as flyout ("Flügel")
/// tableHedaer = moment + date
/// section Header = section title + chevron > or ^
/// cell as Article Preview (like in serach or bookmarks
public class NewContentTableVC: UIViewController {
  
  fileprivate static let CellIdentifier = "NewContentTableVcCell"
  fileprivate static let SectionHeaderIdentifier = "ContentTableHeaderFooterView"
  fileprivate static let SectionFooterIdentifier = "ContentTableFooterSeperatorView"
  
  private var tableView = UITableView(frame: .zero, style: .plain)
  ///for SectionVc the highlighted SectionHeader
  private var sectIndex: Int?
  ///for ArticleVC the highlighted Cell
  var activeItem:IndexPath? {
    didSet {
      guard let activeItem = activeItem else { return }
        expandedSections = [activeItem.section]
    }
  }
  
  func setActive(row: Int?, section: Int?){
    if let row = row, let sect = section {
      activeItem = IndexPath(row: row, section: sect)
    }
    else if let sect = section {
      sectIndex = section
      collapseAll(expect: sect)
      activeItem = nil
    }
    else {
      sectIndex = nil
      activeItem = nil
      collapseAll()
    }
  }
  
  var feeder:Feeder?
  var image:UIImage? { didSet { header.image = image }}
  var issue:Issue? {
    didSet {
      if issue?.date == oldValue?.date { return }
      header.issue = issue
      if tableView.superview != nil { tableView.reloadData() }
    }
  }
  
  var expandedSections: [Int] = [] {
    didSet {
      header.collapsed = expandedSections.count != (issue?.sections?.count ?? 999) + 1
    }
  }
  
  var widthConstraint:NSLayoutConstraint?
  
  fileprivate var sectionPressedClosure: ((Int)->())?
  fileprivate var articlePressedClosure: ((Article)->())?
  fileprivate var imagePressedClosure: (()->())?
  
  fileprivate lazy var header: NewContentTableVcHeader = {
    let h = NewContentTableVcHeader(frame: CGRect(x: 0,
                                                  y: 0,
                                                  width: Const.Size.ContentSliderMaxWidth,
                                                  height: 240))
    h.collapseIcon.onTapping {[weak self] _ in
      guard let self = self else { return }
      if self.header.collapsed {
        self.expandAll()
        self.header.collapsed = false
      }
      else {
        self.collapseAll()
        self.header.collapsed = true
      }
      Usage.track(Usage.event.drawer.action_toggle.AllSections)
    }
    h.listenLabel.onTapping {[weak self] _ in
      guard let issue = self?.issue else { return }
      ArticlePlayer.singleton.play(issue: issue,
                 startFromArticle: nil,
                 enqueueType: .replaceCurrent)
      self?.header.listenIconActive = true
      Usage.track(Usage.event.drawer.action_tap.PlayIssue)
    }
    h.imageView.onTapping {[weak self] _ in
      Usage.track(Usage.event.drawer.action_tap.Moment)
      self?.imagePressedClosure?()
    }
    h.pinHeight(240)
      
    h.listenIconActive =
    ArticlePlayer.singleton.currentContent?.primaryIssue?.date.issueKey
    == self.issue?.date.issueKey
    return h
  }()
  
  public override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
  }
}
  
extension NewContentTableVC: UIStyleChangeDelegate{
  public func applyStyles() {
    self.tableView.backgroundColor = Const.SetColor.HBackground.color
    if tableView.superview != nil { self.tableView.reloadData() }
  }
}

///lifecycle
extension NewContentTableVC {
  public override func viewDidLoad() {
    super.viewDidLoad()

    tableView.dataSource = self
    tableView.delegate = self
    self.tableView.register(NewContentTableVcCell.self,
                            forCellReuseIdentifier: Self.CellIdentifier)
    self.tableView.register(ContentTableHeaderFooterView.self,
                            forHeaderFooterViewReuseIdentifier: Self.SectionHeaderIdentifier)
    self.tableView.register(ContentTableFooterView.self,
                            forHeaderFooterViewReuseIdentifier: Self.SectionFooterIdentifier)
    self.tableView.rowHeight = UITableView.automaticDimension
    self.tableView.separatorStyle = .none
    self.tableView.estimatedRowHeight = 100.0
    
    if #available(iOS 15.0, *) {
      self.tableView.sectionHeaderTopPadding = 0
    }
    registerForStyleUpdates()
    
    self.view.addSubview(header)
    self.view.addSubview(tableView)
    
    pin(header, to: self.view, exclude: .bottom)
    pin(tableView, to: self.view, exclude: .top)
    pin(tableView.top, to: header.bottom)
    
    Notification.receive(Const.NotificationNames.audioPlaybackStateChanged) { [weak self] _ in
      self?.header.listenIconActive =
      ArticlePlayer.singleton.currentContent?.primaryIssue?.date.issueKey
      == self?.issue?.date.issueKey
    }
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    tableView.reloadData()
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard self.issue?.sections?.count ?? 0 > 0 else {
      Notification.receiveOnce("issue", from: issue) { [weak self] notif in
        self?.tableView.reloadData()
      }      
      return
    }
    if let activeItem = activeItem,
       expandedSections.contains(activeItem.section) {
      tableView.scrollToRow(at: activeItem, at: .top, animated: false)
    }
    else if let activeItem = activeItem {
      tableView.scrollToRow(at: IndexPath(row: NSNotFound, section: activeItem.section), at: .top, animated: false)
    }
    else if let sectIndex = sectIndex, tableView(self.tableView, numberOfRowsInSection: sectIndex) > 0 {
      tableView.scrollToRow(at: IndexPath(row: 0, section: sectIndex), at: .top, animated: false)
    }
    else if let sectIndex = sectIndex {
      ///Fix Layout Bug: issue > regular section open menu swipe > anzeige open menu ==> menu wrongly layouted, nothing helped
      /// similar: https://stackoverflow.com/questions/14995573/dequeued-uitableviewcell-has-incorrect-layout-until-scroll-using-autolayout
      onMainAfter { [weak self] in
        //self?.tableView.scrollRectToVisible(CGRect(x: 10, y: 100, width: 10, height: 10), animated: true)//did not work
        self?.tableView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
        self?.tableView.scrollToRow(at: IndexPath(row: NSNotFound, section: sectIndex), at: .top, animated: false)
      }
    }
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

extension NewContentTableVC: UITableViewDataSource,  UITableViewDelegate{
  public func numberOfSections(in tableView: UITableView) -> Int {
    let imprintCount = issue?.imprint == nil ? 0 : 1
    return (issue?.sections?.count ?? 0) + imprintCount
  }
  
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if expandedSections.contains(section) == false { return 0 }
    return issue?.sections?.valueAt(section)?.articles?.count ?? 0
  }
  
  public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 41.0//WTF Figma says its 45.0, due Footer Seperators, we have nearly 45//in UIMeaurement its 41+2*footerseperators
  }
  
  public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: Self.SectionHeaderIdentifier)
            as? ContentTableHeaderFooterView else { return nil}
    
    if let ressort = issue?.sections?.valueAt(section) {
      header.label.text = ressort.name
      header.chevron.isHidden = ressort.type == .advertisement
      header.dottedLine.isHidden = ressort.type == .advertisement
    } else if section == issue?.sections?.count ?? 0 {
      header.label.text = issue?.imprint?.title ?? "Impressum"
      header.chevron.isHidden = true
      header.dottedLine.isHidden = true
    } else {
      header.label.text = nil
      header.chevron.isHidden = true
      header.dottedLine.isHidden = true
    }
    
    header.collapsed = !expandedSections.contains(section)

    header.tag = section
    
    let isImprint = section == issue?.sections?.count ?? 0
    
    header.onTapping { [weak self] gr in
      guard let _header = gr.view as? ContentTableHeaderFooterView else { return }
      self?.sectionPressedClosure?(_header.tag)
      _header.active = true
      _header.collapsed = false
      self?.collapseAll(expect: _header.tag)
      Usage.track(isImprint ? Usage.event.drawer.action_tap.Imprint : Usage.event.drawer.action_tap.Section)
    }
    
    header.chevronTapArea.onTapping {  [weak self] gr in
      ///fixes memory leak
      ///ugly but working first superview is _UITableViewHeaderFooterContentView due chevronTapArea is added to contentView
      ///on refactor my just pass closure/handler
      guard let _header = gr.view?.superview?.superview as? ContentTableHeaderFooterView else { return }
      _header.collapsed = self?.toggle(section: _header.tag) ?? true
      Usage.track(Usage.event.drawer.action_toggle.Section)
    }
    header.active = section == sectIndex
    return header
  }
  
  public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return 1.0
  }
  
  public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return tableView.dequeueReusableHeaderFooterView(withIdentifier: Self.SectionFooterIdentifier)
  }
  
  public func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
    if section < (issue?.sections?.count ?? 0) { return }
    (view as? ContentTableFooterView)?.seperator.isHidden = true
  }
  
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let art = issue?.sections?.valueAt(indexPath.section)?.articles?.valueAt(indexPath.row) else {
      log("Article you tapped not found for section: \(indexPath.section), row: \(indexPath.row)")
      return
    }
    Usage.track(Usage.event.drawer.action_tap.Article)
    articlePressedClosure?(art)
  }
  
  public func tableView(_ tableView: UITableView,
                                 cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell
    = tableView.dequeueReusableCell(withIdentifier: Self.CellIdentifier,
                                    for: indexPath) as? NewContentTableVcCell
    ?? NewContentTableVcCell()
    cell.article = issue?.sections?.valueAt(indexPath.section)?.articles?.valueAt(indexPath.row)
    cell.image = cell.article?.images?.first?.image(dir: issue?.dir)?.invertedIfNeeded
    cell.active = indexPath == activeItem
    return cell
  }
}


fileprivate class NewContentTableVcHeader: UIView, UIStyleChangeDelegate {
  func applyStyles() {
    self.backgroundColor = Const.SetColor.HBackground.color
    self.imageView.layer.shadowOpacity
    = Defaults.darkMode
    ? Const.Shadow.Dark.Opacity
    : Const.Shadow.Light.Opacity
    self.imageView.layer.shadowColor = Const.SetColor.CTDate.color.cgColor
    listenLabel.textColor = Const.SetColor.CTDate.color
    bottomBorder?.backgroundColor = Const.SetColor.CTDate.color
    collapseIcon.image
    = UIImage(named:"chevron-doubleup")?
      .withRenderingMode(.alwaysOriginal)
      .withTintColor(Const.SetColor.CTDate.color)
    updateListenIcon()
  }
  
  
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
  var listenLabel = UILabel()
  var listenIcon = UIImageView()
  var collapseIcon =  UIImageView()
  var bottomBorder: UIView?
  
  var imageAspectConstraint: NSLayoutConstraint?
  
  override func didMoveToSuperview() {
    if imageView.superview == nil { setup() }
    super.didMoveToSuperview()
  }
  
  func updateListenIcon(){
    /*ArticlePlayer.singleton.isPlaying*/
    listenIcon.image
    = UIImage(named: listenIconActive ?  "audio-active" : "audio")?
      .withRenderingMode(.alwaysOriginal)
      .withTintColor(Const.SetColor.CTDate.color)
  }
  
  var listenIconActive: Bool = false { didSet { updateListenIcon() }}
  
  var collapsed: Bool = false {
    didSet {
      if oldValue == collapsed { return }
      UIView.animateKeyframes(withDuration: 0.5, delay: 0.0, animations: {
        UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) { [weak self] in
          guard let self = self else { return }
          self.collapseIcon.transform = CGAffineTransform(rotationAngle: 0)
        }
        
        UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) { [weak self] in
          self?.rotateChevron()
        }
      })
    }
  }
  
  func rotateChevron(){
    collapseIcon.transform = CGAffineTransform(rotationAngle: self.collapsed ? CGFloat.pi : CGFloat.pi*2)
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
    self.addSubview(listenLabel)
    self.addSubview(listenIcon)
    self.addSubview(collapseIcon)
    
    listenIcon.contentMode = .scaleAspectFit
    imageView.contentMode = .scaleAspectFit
    imageView.shadow()
    
    topLabel.contentFont()
    listenLabel.contentFont(size: Const.Size.SmallerFontSize)
    listenLabel.textAlignment = .left
    
    listenIcon.image = UIImage(named: "audio")?.withRenderingMode(.alwaysOriginal)
    listenLabel.text = "ausgabe hören"
    topLabel.numberOfLines = 0
    
    pin(imageView.left, to: self.left, dist: Const.Size.DefaultPadding)
    pin(imageView.top, to: self.top, dist: Const.Size.DefaultPadding + 45)
    pin(imageView.bottom, to: self.bottom, dist: -52)
    
    pin(topLabel.left, to: imageView.right, dist: 10)
    pin(topLabel.right, to: self.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    pin(topLabel.top, to: imageView.top, dist: -3)
    pin(listenIcon.left, to: imageView.left, dist: 0, priority: .fittingSizeLevel)
    
    listenIcon.pinSize(CGSize(width: 24, height: 24))
    
    collapseIcon.pinSize(CGSize(width: 24, height: 24))
    
    pin(collapseIcon.right, to: self.right, dist: -Const.Size.DefaultPadding)
    
    pin(listenIcon.bottom, to: self.bottom, dist: -10.0)
    pin(listenLabel.bottom, to: self.bottom, dist: -13.0)
    pin(collapseIcon.bottom, to: self.bottom, dist: -10.0)
    
    pin(listenLabel.left, to: listenIcon.right, dist: 5, priority: .fittingSizeLevel)
    
    bottomBorder = self.addBorderView(Const.SetColor.CTDate.color, 0.7,
                                      edge: .bottom,
                                      insets: Const.Insets.Default)
    registerForStyleUpdates()
    rotateChevron()
    topLabel.textColor = Const.Colors.appIconGrey
  }
}

fileprivate  class NewContentTableVcCell: UITableViewCell {
  
  var imageZeroHeightConstraint: NSLayoutConstraint?
  var imageDefaultHeightConstraint: NSLayoutConstraint?
  
  var articleIdentifier: String?
  
  let starFill = UIImage(named: "star-fill")
  let star = UIImage(named: "star")
  
  var article: Article? { didSet {  updateStyles()  }  }
  
  func updateStyles(){
    titleLabel.textColor = Const.SetColor.HText.color
    customTextLabel.textColor = Const.SetColor.HText.color
    bookmarkButton.tintColor = Const.SetColor.HText.color
    bottomLabel.textColor = Const.SetColor.HText.color
    dottedLine.fillColor = Const.SetColor.HText.color
    dottedLine.strokeColor = Const.SetColor.HText.color
    
    articleIdentifier = article?.html?.name
    var autors = article?.authors() ?? ""
    if autors.length > 0 {
      autors.append(" ")
    }
    let attributedString = NSMutableAttributedString(string: autors)
    let range = NSRange(location: 0, length: attributedString.length)
    
    let boldFont = Const.Fonts.titleFont(size: 13.5)
    attributedString.addAttribute(.font, value: boldFont, range: range)
    attributedString.addAttribute(.backgroundColor, value: UIColor.clear, range: range)

    if let rd = article?.readingDuration {
      let timeString
      = NSMutableAttributedString(string: "\(rd)min")
      let trange = NSRange(location: 0, length: timeString.length)
      let thinFont = Const.Fonts.contentFont(size: 12.0)
      timeString.addAttribute(.font, value: thinFont, range: trange)
      timeString.addAttribute(.foregroundColor, value: Const.Colors.appIconGrey, range: trange)
      timeString.addAttribute(.backgroundColor, value: UIColor.clear, range: trange)
      attributedString.append(timeString)
    }
    bottomLabel.attributedText = attributedString
    
    titleLabel.text = article?.title
    customTextLabel.text = article?.teaser
    
    bookmarkButton.image = article?.hasBookmark ?? false ? starFill : star
    bookmarkButton.tintColor = Const.Colors.appIconGrey
    setActiveColorsIfNeeded()
  }
  
  func setActiveColorsIfNeeded(){
    if active == false {return }
    let color = Const.SetColor.CIColor.color
    titleLabel.textColor = color
    customTextLabel.textColor = color
    bookmarkButton.tintColor = color
    bottomLabel.textColor = color
  }
  
  var image: UIImage? {
    didSet {
      imageZeroHeightConstraint?.isActive = false
      imageDefaultHeightConstraint?.isActive = false
      customImageView.image = image
      
      if image == nil {
        imageZeroHeightConstraint?.isActive = true
      }
      else {
        imageDefaultHeightConstraint?.isActive = true
      }
    }
  }
  
  private let customImageView = UIImageView()
  let bookmarkButton = UIImageView()
  let titleLabel = UILabel()
  let customTextLabel = UILabel()
  let bottomLabel = UILabel()
  let dottedLine = DottedLineView()
  
  public override func prepareForReuse() {
    customImageView.image = nil
    article = nil
  }
  
  var active: Bool = false {
    didSet {
      if oldValue == active { return }
      if oldValue == true { updateStyles() }
      setActiveColorsIfNeeded()
    }
  }
  
  lazy var content: UIView = {
    let v = UIView()
    
    let rightCenterVerticalSpacer =  UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))

    v.addSubview(titleLabel)
    v.addSubview(customTextLabel)
    v.addSubview(bottomLabel)
    
//    titleLabel.addBorder(.red)
//    customTextLabel.addBorder(.yellow)
//    bottomLabel.addBorder(.green)
    
    rightCenterVerticalSpacer.pinWidth(10.0)
    rightCenterVerticalSpacer.pinHeight(10.0, priority: .fittingSizeLevel)
    
//    customImageView.addBorder(.red)
//    rightCenterVerticalSpacer.addBorder(.yellow)
//    bookmarkButton.addBorder(.green)
    
    v.addSubview(customImageView)
    v.addSubview(rightCenterVerticalSpacer)
    v.addSubview(bookmarkButton)
    
    titleLabel.numberOfLines = 2
    customTextLabel.numberOfLines = 3
    bottomLabel.numberOfLines = 0
        
    titleLabel.boldContentFont()
    customTextLabel.contentFont()
    bottomLabel.boldContentFont(size: 13.5)
    
    let imgWidth = 60.0
    imageZeroHeightConstraint = customImageView.pinHeight(1.0)
    imageZeroHeightConstraint?.isActive = false
    imageDefaultHeightConstraint = customImageView.pinSize(CGSize(width: imgWidth, height: imgWidth), priority: .defaultHigh).height
    imageDefaultHeightConstraint?.isActive = false
    
    customImageView.contentMode = .scaleAspectFill
    customImageView.clipsToBounds = true
    
    ///TOP 2 BOTTOM LEFT
    pin(titleLabel.top, to: v.top)
    pin(customTextLabel.top, to: titleLabel.bottom)
    pin(bottomLabel.top, to: customTextLabel.bottom, dist: 8.0)
    pin(bottomLabel.bottom, to: v.bottom)
    ///----------------------------------------
    titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
    customTextLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
    bottomLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
    
    titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
    customTextLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
    bottomLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
    
    ///TOP 2 BOTTOM Right
    pin(customImageView.top, to: v.top)
    pin(rightCenterVerticalSpacer.top, to: customImageView.bottom, dist: 10.0)
    pin(bookmarkButton.top, to: rightCenterVerticalSpacer.bottom)
    pin(bookmarkButton.bottom, to: v.bottom)
    ///----------------------------------------
    customImageView.setContentCompressionResistancePriority(.fittingSizeLevel, for: .vertical)
    customImageView.setContentHuggingPriority(.fittingSizeLevel, for: .vertical)
    rightCenterVerticalSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
    rightCenterVerticalSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    
    ///Left 2 Right
    pin(titleLabel.left, to: v.left)
    pin(titleLabel.right, to: v.right, dist: -(imgWidth + 10))
    
    pin(customTextLabel.left, to: v.left)
    pin(customTextLabel.right, to: v.right, dist: -(imgWidth + 10))
    
    pin(bottomLabel.left, to: v.left)
    pin(bottomLabel.right, to: v.right, dist: -(imgWidth + 10))
    
    pin(customImageView.right, to: v.right)
    pin(rightCenterVerticalSpacer.right, to: v.right)
    
    bookmarkButton.pinSize(CGSize(width: 26, height: 26))
    pin(bookmarkButton.right, to: v.right)
    
    bookmarkButton.onTapping {[weak self] _ in
      Usage.track(Usage.event.drawer.action_tap.Bookmark)
      self?.article?.hasBookmark.toggle()
    }
    
    return v
  }()
  
  func setup(){
    dottedLine.offset = 1.7
    self.contentView.addSubview(content)
    self.contentView.addSubview(dottedLine)
    dottedLine.pinHeight(Const.Size.DottedLineHeight*0.7)
    pin(dottedLine.left, to: self.contentView.left, dist: Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    pin(dottedLine.right, to: self.contentView.right, dist: -Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    pin(dottedLine.top, to: self.contentView.top)
    pin(content, to: contentView, dist: Const.Size.DefaultPadding)
    selectionStyle = .none
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

fileprivate class ContentTableFooterView: UITableViewHeaderFooterView, UIStyleChangeDelegate{
  
  var seperator = UIView(frame: CGRect(x: 0, y: 0, width: 1000, height: 0.7))
  
  func setup(){
    self.contentView.backgroundColor = Const.SetColor.ios(.systemBackground).color
    self.contentView.addSubview(seperator)
    pin(seperator.left, to: self.contentView.left, dist: Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    pin(seperator.right, to: self.contentView.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    pin(seperator.top, to: self.contentView.top)
    seperator.pinHeight(0.7)
    registerForStyleUpdates()
  }
  
  override func prepareForReuse() {
    seperator.isHidden = false
  }
  
  func applyStyles() {
    self.contentView.backgroundColor = Const.SetColor.HBackground.color
    seperator.backgroundColor = Const.SetColor.HText.color
  }
  
  override init(reuseIdentifier: String?) {
    super.init(reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
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
      if active == false && oldValue == true {
        contentView.layoutSubviews()
      }
    }
  }
  
  override func setup(){
    fontSize = 20.0
    dottedLine.offset = 1.55
    chevronYOffset = 2.0
    super.setup()
    dottedLine.isHorizontal = false
    self.contentView.addSubview(dottedLine)
    
    dottedLine.clipsToBounds = true
    pin(dottedLine.top, to: self.contentView.top, dist: 9.5, priority: .fittingSizeLevel)
    pin(dottedLine.bottom, to: self.contentView.bottom, dist: -5.5, priority: .fittingSizeLevel)
    pin(dottedLine.right, to: self.chevron.left, dist: -10.0)
    dottedLine.pinWidth(Const.Size.DottedLineHeight*0.6)
    dottedLine.fillColor = Const.SetColor.HText.color
    dottedLine.strokeColor = Const.SetColor.HText.color
//    chevron.activeColor = .lightGray
//    chevron.color = Const.SetColor.HText.color
    chevron.tintColor = Const.SetColor.HText.color

    label.setContentHuggingPriority(.defaultLow, for: .horizontal)
  }
  
  override func setColors() {
    super.setColors()
    chevron.tintColor = Const.SetColor.HText.color

//    chevron.color = Const.SetColor.HText.color
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
