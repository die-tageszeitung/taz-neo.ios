//
//  SearchSettingsView.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

class SearchSettingsView: UITableView, UIStyleChangeDelegate {
  
  // MARK: *** Closures ***
  var propertyChanged: (()->())?
  
  // MARK: *** Delegates ***
  weak open var textFieldDelegate: UITextFieldDelegate?

  // MARK: *** Properties ***
  private let _data:TData

  var data: TData {
    get {
      _data.settings.title = _data.titleInpulCell.textField.text
      _data.settings.author = _data.authorInpulCell.textField.text
      
      if _data.settings.range.currentOption == .custom {
        _data.settings.from = _data.datePickers.fromPicker.date
        _data.settings.to = _data.datePickers.toPicker.date
      }
      else {
        _data.settings.from = _data.settings.range.currentOption.minimumDate
        _data.settings.to = _data.settings.range.currentOption.maximuDate
      }
      return _data
    }
  }
    
  var topConstraint: NSLayoutConstraint?
  var bottomConstraint: NSLayoutConstraint?
  
  var isOpen: Bool { get{ self.topConstraint?.constant == 0 }}
  
  // MARK: *** UI Elements ***
  #if LMD
    let searchButton = Padded.Button(title: "Suche starten")
  #else
    let searchButton = Padded.Button(title: "Suchen")
  #endif
  
  lazy var helpButton: UILabel = {
    let lbl = UILabel()
    lbl.text = "Hilfe"
    lbl.contentFont(size: Const.Size.SmallerFontSize)
    lbl.textColor = Const.SetColor.ios_opaque(.grey).color
    lbl.addBorderView(Const.SetColor.ios_opaque(.grey).color, edge: UIRectEdge.bottom)
    return lbl
  }()
  
  private lazy var searchFooterWrapper: UIView = {
    let v = UIView()
    v.addSubview(searchButton)
    v.addSubview(helpButton)
    
    pin(searchButton.top, to: v.top, dist: 5.0)
    pin(searchButton.right, to: v.right, dist: -Const.Size.DefaultPadding, priority: .defaultHigh)
    pin(searchButton.left, to: v.left, dist: Const.Size.DefaultPadding)
    
    pin(helpButton.top, to: searchButton.bottom, dist: Const.Size.DefaultPadding)
    pin(helpButton.left, to: v.left, dist: Const.Size.DefaultPadding)
    //No need to close Autolayout due Footer needs Fix Frame foe easier use
    v.frame = CGRect(x: 0, y: 0, width: 0, height: TazTextField.recomendedHeight+45)
    v.backgroundColor = Const.SetColor.ios(.systemBackground).color
    return v
  }()
  
  // MARK: *** Functions ***
  
  func toggle(toVisible: Bool? = nil){
    let currentOffset = self.topConstraint?.constant ?? 1
    let toVisible = toVisible ?? (currentOffset != 0)
   
    if toVisible == true {
      Usage.track(Usage.event.search.filterOpen)
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topConstraint?.constant = 0
        self?.bottomConstraint?.constant = 0
        self?.superview?.layoutIfNeeded()
      } completion: { [weak self] _ in
        self?.topBackground.isHidden = false
      }
      return
    }
    else {
      Usage.track(Usage.event.search.filterClose)
    }
    data.authorInpulCell.textField.resignFirstResponder()
    data.titleInpulCell.textField.resignFirstResponder()
    
    let h = self.frame.size.height + 60
    self.topBackground.isHidden = true
    UIView.animate(seconds: 0.3) { [weak self] in
      self?.topConstraint?.constant = -h
      self?.bottomConstraint?.constant = -h
      self?.superview?.layoutIfNeeded()
    }
  }
  
  func applyStyles() {
    self.shadow()
    self.layer.shadowOpacity = Const.Shadow.Light.Opacity
    self.layer.shadowColor = Defaults.darkMode ? UIColor.white.cgColor : Const.Shadow.Color
  }
  
  func restoreInitialState(){
    data.settings = SearchSettings()
    data.titleInpulCell.textField.text = nil
    data.authorInpulCell.textField.text = nil
    data.update()
    reloadData()
  }
  
  /// get updated IndexPath...
  private func reloadAnimatedIfNeeded(oldContent: [tContent]) {
    var added:[IndexPath] = []
    var deleted:[IndexPath] = []
    
    for idSect in 0 ... max(_data.content.count, oldContent.count) - 1{
      let newCells = _data.content.valueAt(idSect)?.cells ?? []
      let oldCells = oldContent.valueAt(idSect)?.cells ?? []

      let addedCells = Set(newCells).subtracting(oldCells)
      let deletedCells = Set(oldCells).subtracting(newCells)

      for idRow in 0 ... (max(newCells.count, oldCells.count, 1) - 1){
        let ip = IndexPath(row: idRow , section: idSect)
        let newCell = _data.cell(at: ip)
        let oldCell = oldCells.valueAt(idRow)

        if let newCell = newCell, addedCells.contains(newCell){
          added.append(ip)
        }

        if let oldCell = oldCell, deletedCells.contains(oldCell){
          deleted.append(ip)
        }
      }
      propertyChanged?()
    }
    if (added.count + deleted.count) == 0 {
      reloadData()
      return
    }
    //middle or fade animation
    performBatchUpdates {
      if deleted.count > 0 { deleteRows(at: deleted, with: .none) }
      if added.count > 0 { insertRows(at: added, with: .none  ) }
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    searchFooterWrapper.backgroundColor = Const.SetColor.ios(.systemBackground).color
    topBackground.backgroundColor = Const.SetColor.ios(.systemBackground).color
  }
  
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    if let sv = self.superview,
        topBackground.superview == nil {
      topBackground.isHidden = true
      sv.insertSubview(topBackground, belowSubview: self)
      pin(topBackground.top, to: sv.top, dist: -50)
      pin(topBackground.left, to: sv.left)
      pin(topBackground.right, to: sv.right)
    }
  }
  
  lazy var topBackground: UIView = {
    let v = UIView()
    v.pinHeight(400)
    v.backgroundColor = Const.SetColor.ios(.systemBackground).color
    return v
  }()
  
  func setup(){
    self.register(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
    self.dataSource = self
    self.delegate = self
    self.tableFooterView = searchFooterWrapper
    self.backgroundColor = .clear
    self.separatorStyle = .none
    _data.reloadTable = { [weak self] in
      guard let self = self else { return }
      let oldContent = self._data.content
      self._data.update()
      self.reloadAnimatedIfNeeded(oldContent: oldContent)
    }
    registerForStyleUpdates()
    applyStyles()
  }

  // MARK: *** Lifecycle ***
  init(frame: CGRect, style: UITableView.Style, minimumSearchDate:Date) {
    _data = TData()
    _data.minimumSearchDate = minimumSearchDate
    super.init(frame: frame, style: style)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    _data = TData()
    _data.minimumSearchDate = Date(timeIntervalSinceReferenceDate: 0)
    super.init(coder: coder)
    setup()
  }
}

// MARK: - UITableViewDataSource -
extension SearchSettingsView: UITableViewDelegate {
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    return data.header(section: section)
  }
  
  func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return 15.0
  }
  
  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return SimpleFooterView()
  }
}

fileprivate class SimpleFooterView: UIView {
  override func layoutSubviews() {
    super.layoutSubviews()
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
  }
}


// MARK: - UITableViewDataSource -
extension SearchSettingsView: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return data.content.valueAt(section)?.cells?.count ?? 0
  }
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return data.content.count
  }
    
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = data.cell(at: indexPath)
    (cell as? TextInputCell)?.textField.delegate = textFieldDelegate
    return cell ?? UITableViewCell()
  }
    
  func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    if let cell = data.cell(at: indexPath),
       cell is RadioButtonCell || cell is MoreCell {
      return indexPath
    }
    return nil
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    data.handle(selectRowAt: indexPath)
  }
}

// MARK: - Table Components -
// MARK: *** Cells ***
/// A custom table view cell with TextInput
class TextInputCell: TazCell {
  let textField = UITextField()
  
  override func setup(){
    //add some pading for corner radius
    textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 5))
    textField.leftViewMode = .always
    textField.clearButtonMode = .whileEditing
    textField.returnKeyType = .search
    textField.pinHeight(Const.Size.NewTextFieldHeight)
    textField.clipsToBounds = true
    contentView.addSubview(textField)
    let insets = UIEdgeInsets(top: 2,
                              left: Const.Size.DefaultPadding,
                              bottom: -5,
                              right: -Const.Size.DefaultPadding)
    pin(textField, to: contentView, insets: insets)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    applyStyles()
  }
  
  override func applyStyles() {
    super.applyStyles()
    self.textField.defaultStyle(placeholder: self.textField.attributedPlaceholder?.string, cornerRadius: 0)
    self.textField.textColor = Const.SetColor.ios(.label).color
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
    textField.backgroundColor =  Const.SetColor.taz(.textFieldBackground).color
  }
}

/// A custom table view cell with label and chevron right
class MoreCell: TazCell {
  let label = UILabel()
  
  override func setup(){
    label.contentFont().labelColor()
    accessoryType = .none
    contentView.addSubview(label)
    let insets = UIEdgeInsets(top: 11,
                              left: Const.Size.DefaultPadding,
                              bottom: -11,
                              right: -Const.Size.DefaultPadding)
    pin(label, to: contentView, insets: insets)
    self.addBorderView(Const.SetColor.ios(.separator).color,
                              0.7,
                              edge: .bottom,
                              insets: Const.Insets.Default)
  }
  
  override func applyStyles() {
    super.applyStyles()
    self.label.textColor = Const.SetColor.ios(.label).color
  }
}

/// A custom table view cell with radioButton and label
class RadioButtonCell: TazCell {
  private let label = UILabel()
  let additionalContentWrapper = UIView()
  public let radioButton = RadioButton()
  
  var filter:GqlSearchFilter? {
    didSet {
      self.label.text = filter?.labelText
    }
  }
  
  var sorting:GqlSearchSorting? {
    didSet {
      self.label.text = sorting?.labelText
    }
  }
  
  var range:SearchRangeOption? {
    didSet {
      self.label.text = range?.rawValue
    }
  }
  
  override func setup(){
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
    contentView.addSubview(radioButton)
    contentView.addSubview(label)
    contentView.addSubview(additionalContentWrapper)
    additionalContentWrapper.pinHeight(0, priority: .defaultLow)
    label.contentFont().labelColor()
    pin(label.top, to: contentView.top, dist: 18)
    pin(label.right, to: contentView.right, dist: 6)
    pin(additionalContentWrapper, to: contentView, exclude: .top)
    pin(additionalContentWrapper.top, to: label.bottom, dist: 16)
    radioButton.isUserInteractionEnabled = false
    pin(radioButton.centerY, to: label.centerY)
    radioButton.pinSize(CGSize(width: 28, height: 28), priority: .required)
    pin(radioButton.left, to: contentView.left, dist: Const.Size.DefaultPadding)
    pin(radioButton.right, to: label.left, dist: -18)
  }
  
  override func applyStyles() {
    super.applyStyles()
    self.label.textColor = Const.SetColor.ios(.label).color
    radioButton.isSelected = radioButton.isSelected
  }
}

/// A custom table view cell
class TazCell: UITableViewCell, UIStyleChangeDelegate {
  func applyStyles() {
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
  }
  
  
  func setup(){}//overwriteable
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
    registerForStyleUpdates()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
    registerForStyleUpdates()
  }
}

// MARK: *** UIComponents ***
/// A custom table view cell with TextInput
class TazHeaderFooterView: UITableViewHeaderFooterView {
  var label: UILabel = UILabel()
  let chevron = UIImageView(image: UIImage(named: "chevron-up"))
  let chevronTapArea = UIView()
  
  var topDist = 8.0
  var bottomDist = 10.0
  var fontSize = Const.Size.DefaultFontSize
  var chevronYOffset = -2.0
  
  func setup(){
    label.boldContentFont(size: fontSize).labelColor()
    self.contentView.backgroundColor = Const.SetColor.ios(.systemBackground).color
    self.contentView.addSubview(label)
    self.contentView.addSubview(chevron)
    self.contentView.addSubview(chevronTapArea)
    chevron.tintColor = Const.SetColor.ios(.secondaryLabel).color
    chevron.pinSize(CGSize(width: 24, height: 24))
    pin(chevron.right, to: self.contentView.right, dist: -Const.ASize.DefaultPadding)
    chevron.centerY(dist: chevronYOffset)
    
    pin(chevronTapArea.top, to: self.contentView.top)
    pin(chevronTapArea.right, to: self.contentView.right)
    pin(chevronTapArea.bottom, to: self.contentView.bottom)
    pin(chevronTapArea.left, to: chevron.left, dist: -15)
    
    pin(label.top, to: self.contentView.top, dist: topDist)
    pin(label.left, to: self.contentView.left, dist: Const.Size.DefaultPadding)
    pin(label.right, to: chevron.right, dist: -Const.Size.DefaultPadding, priority: .defaultLow)
    pin(label.bottom, to: self.contentView.bottom, dist: -bottomDist, priority: .defaultLow)
    self.contentView.layoutMargins.top = 0.0
    self.contentView.layoutMargins.left = Const.Size.DefaultPadding
    self.contentView.layoutMargins.right = Const.Size.DefaultPadding
    self.rotateChevron()
    registerForStyleUpdates()
  }
  
  var collapsed: Bool = true {
    didSet {
      if oldValue == collapsed { return }
      UIView.animateKeyframes(withDuration: 0.5, delay: 0.0, animations: {
        UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.49) { [weak self] in
          guard let self = self else { return }
          self.chevron.transform = CGAffineTransform(rotationAngle: 0)
        }
        
        UIView.addKeyframe(withRelativeStartTime: 0.51, relativeDuration: 0.48) { [weak self] in
          self?.rotateChevron()
        }
      })
    }
  }
  
  func rotateChevron(){
    chevron.transform = CGAffineTransform(rotationAngle: self.collapsed ? CGFloat.pi : CGFloat.pi*2)
  }
  
  override init(reuseIdentifier: String?) {
    super.init(reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  func setColors(){
    self.contentView.backgroundColor = Const.SetColor.ios(.systemBackground).color
    chevron.tintColor = Const.SetColor.ios(.secondaryLabel).color
    label.textColor = Const.SetColor.ios(.label).color
  }
}

extension TazHeaderFooterView:UIStyleChangeDelegate{
  func applyStyles() {setColors() }
}

class CustomRangeDatePickerView: UIView, UIStyleChangeDelegate {
  
  public let fromPicker = UIDatePicker()
  public let toPicker = UIDatePicker()
  
  public let fromCloseLabel = UILabel("Übernehmen")
  public let toCloseLabel = UILabel("Übernehmen")
  
  @objc public func dateChanged(_ sender: UIControl) {
    if #available(iOS 16, *) {
      dateChangedWorkaround(sender)
    }
    else {
      dateChangedLegacy(sender)
    }
  }
  
  func dateChangedLegacy(_ sender: UIControl) {
    if sender == fromPicker {
      toPicker.minimumDate = fromPicker.date
    }
    else if sender == toPicker {
      fromPicker.maximumDate = toPicker.date
    }
  }
  
  @available(iOS 16, *)
  /// fixes ios 16 crash Bug if to picker selects lower date then from picker.minimum date
  /// other fixes are also possible but then ux changes
  /// ios below 16 handles error itself
  /// strage other behaviours only when in wheels mode
  /// this solution seam to work
  func dateChangedWorkaround(_ sender: UIControl) {
    if sender == fromPicker {
      toPicker.preferredDatePickerStyle = .wheels
      if toPicker.date < fromPicker.date {
        toPicker.date = fromPicker.date
      }
      toPicker.minimumDate = fromPicker.date
      toPicker.preferredDatePickerStyle = .inline
    }
    else if sender == toPicker {
      fromPicker.preferredDatePickerStyle = .wheels
      if toPicker.date < fromPicker.date {
        fromPicker.date = toPicker.date
      }
      fromPicker.maximumDate = toPicker.date
      fromPicker.preferredDatePickerStyle = .inline
    }
  }
  
  func applyStyles() {
    fromPicker.tintColor = Const.SetColor.ios(.label).color
    toPicker.tintColor = Const.SetColor.ios(.label).color

    fromPicker.layer.backgroundColor = Const.SetColor.CTBackground.color.cgColor
    toPicker.layer.backgroundColor = Const.SetColor.CTBackground.color.cgColor
  }
  
  func setup(){
    fromPicker.layer.cornerRadius = 12.0
    toPicker.layer.cornerRadius = 8.0
    
    fromPicker.shadow()
    toPicker.shadow()
    
    fromPicker.datePickerMode = .date
    toPicker.datePickerMode = .date
    
    toPicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
    fromPicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
    
    if #available(iOS 14.0, *) {
      fromPicker.preferredDatePickerStyle = .inline
      toPicker.preferredDatePickerStyle = .inline
    }
    
    let fromLabel = UILabel("Suche von:")
    let toLabel = UILabel("Suche bis:")

    fromLabel.contentFont()
    toLabel.contentFont()
    fromCloseLabel.contentFont()
    toCloseLabel.contentFont()
    self.addSubview(fromLabel)
    self.addSubview(fromCloseLabel)
    self.addSubview(fromPicker)
    self.addSubview(toLabel)
    self.addSubview(toCloseLabel)
    self.addSubview(toPicker)
    pin(fromLabel, to: self, exclude: .bottom)
    pin(fromCloseLabel.right, to: self.right)
    pin(fromCloseLabel.centerY, to: fromLabel.centerY)
    pin(fromPicker.top, to: fromLabel.bottom, dist: 15)
    pin(fromPicker.left, to: self.left)
    pin(fromPicker.right, to: self.right)
    pin(toLabel.top, to: fromPicker.bottom, dist: 25)
    pin(toLabel.left, to: self.left)
    pin(toLabel.right, to: self.right)
    pin(toCloseLabel.right, to: self.right)
    pin(toCloseLabel.centerY, to: toLabel.centerY)
    pin(toPicker.top, to:toLabel.bottom, dist: 15)
    pin(toPicker, to: self, exclude: .top)
    registerForStyleUpdates()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}


// MARK: - Table Datamodel -
// MARK: *** cell data model ***
extension SearchSettingsView {
  typealias tContent = (title:String?,
                        cells:[TazCell]?)
  
  struct TableData{
    public private(set) var content:[tContent]
    
    func cell(at indexPath: IndexPath) -> TazCell? {
      return self.content.valueAt(indexPath.section)?.cells?.valueAt(indexPath.row)
    }
  }
}

// MARK: *** cell data model ***
class TData {
  fileprivate var minimumSearchDate:Date = Date(timeIntervalSinceReferenceDate: 0){
    didSet {
      datePickers.fromPicker.minimumDate = minimumSearchDate
      datePickers.fromPicker.maximumDate = Date()
      datePickers.fromPicker.date = minimumSearchDate
      datePickers.toPicker.minimumDate = minimumSearchDate
      datePickers.toPicker.maximumDate =  Date()
      datePickers.toPicker.date =  Date()
    }
  }

  var reloadTable: (()->())?
  typealias tContent = (title:String, cells:[TazCell]?)
  ///added, deleted
  typealias tChangedIndexPaths = (added: [IndexPath],
                                  deleted: [IndexPath])
  
  public private(set) var content:[tContent] = []
  private var headerViews:[TazHeaderFooterView] = []
  
  var settings = SearchSettings()
  var expandedSection: Int? {
    didSet {
      headerViews.enumerated().forEach( { (index,view) in
        view.collapsed = index != (expandedSection ?? -1)
      } )
    }
  }
  
  var customRange: Bool = false
  
  lazy var authorInpulCell: TextInputCell = {
    let cell = TextInputCell()
    cell.textField.text = settings.author
    cell.textField.defaultStyle(placeholder: "Autor*innen", cornerRadius: 0)
    return cell
  }()
  
  lazy var titleInpulCell: TextInputCell = {
    let cell = TextInputCell()
    cell.textField.text = settings.title
    cell.textField.defaultStyle(placeholder: "Titel", cornerRadius: 0)
    return cell
  }()
  
  lazy var defaultRangeCells: [RadioButtonCell] = {
    var cells: [RadioButtonCell] = []
    for rangeOption in SearchRangeOption.allItems {
      if rangeOption == .custom { continue }
      let cell = RadioButtonCell()
      cell.range = rangeOption
      cells.append(cell)
    }
    return cells
  }()
  
  let datePickers = CustomRangeDatePickerView()
  
  lazy var customRangeCellExpanded: RadioButtonCell = {
    let cell = RadioButtonCell()
    cell.range = .custom
    cell.additionalContentWrapper.addSubview(datePickers)
    pin(datePickers, to: cell.additionalContentWrapper, dist: Const.Size.DefaultPadding)
    datePickers.fromCloseLabel.onTapping { [weak self] _ in
      self?.expandedSection = nil
      self?.reloadTable?()
    }
    datePickers.toCloseLabel.onTapping { [weak self] _ in
      self?.expandedSection = nil
      self?.reloadTable?()
    }
    
    return cell
  }()
  
  lazy var customRangeCellColapsed: RadioButtonCell = {
    let cell = RadioButtonCell()
    cell.range = .custom
    return cell
  }()
  
  lazy var rangeMoreCell: MoreCell = {
    let cell = MoreCell()
    cell.label.text = settings.range.currentOption.textWithDate
    return cell
  }()
  
  lazy var filterCells: [RadioButtonCell] = {
    var cells: [RadioButtonCell] = []
    for filter in GqlSearchFilter.allItems {
      let cell = RadioButtonCell()
      cell.filter = filter
      cells.append(cell)
    }
    return cells
  }()
  
  lazy var filterMoreCell: MoreCell = {
    let cell = MoreCell()
    cell.label.text = settings.filter.rawValue
    return cell
  }()
  
  lazy var sortingCells: [RadioButtonCell] = {
    var cells: [RadioButtonCell] = []
    for sorting in GqlSearchSorting.allItems {
      let cell = RadioButtonCell()
      cell.sorting = sorting
      cells.append(cell)
    }
    return cells
  }()
  
  lazy var sortingMoreCell: MoreCell = {
    let cell = MoreCell()
    cell.label.text = settings.filter.rawValue
    return cell
  }()
  
  func update(){
    if settings.range.currentOption == .custom {
      rangeMoreCell.label.text
      = datePickers.fromPicker.date.shorter
      + " - "
      + datePickers.toPicker.date.shorter
    }
    else {
      rangeMoreCell.label.text = settings.range.currentOption.textWithDate
    }
    
    filterMoreCell.label.text = settings.filter.labelText
    sortingMoreCell.label.text = settings.sorting.labelText
    
    var rangeCells:[RadioButtonCell] = []
    rangeCells.append(contentsOf: defaultRangeCells)
    if customRange {
      rangeCells.append(contentsOf: [customRangeCellExpanded])
    }
    else {
      rangeCells.append(contentsOf: [customRangeCellColapsed])
    }

    rangeCells.forEach{
      $0.radioButton.isSelected = $0.range == settings.range.currentOption
      let disabled = settings.filter == .LMd && ($0.range == .lastDay || $0.range == .lastWeek)
      $0.contentView.alpha = disabled ? 0.3 : 1.0
      $0.radioButton.isEnabled = !disabled
    }
    filterCells.forEach{ $0.radioButton.isSelected = $0.filter == settings.filter }
    sortingCells.forEach{ $0.radioButton.isSelected = $0.sorting == settings.sorting }
    ///Title no more used!!
    #if LMD
    content = [
      ("Erweiterte suche", [titleInpulCell, authorInpulCell]),
      ("Zeitraum", expandedSection == 1 ? rangeCells : [rangeMoreCell]),
      ("Sortierung", expandedSection == 2 ? sortingCells : [sortingMoreCell])
    ]
    #else
    content = [
      ("erweiterte suche", [titleInpulCell, authorInpulCell]),
      ("zeitraum", expandedSection == 1 ? rangeCells : [rangeMoreCell]),
      ("erschienen in", expandedSection == 2 ? filterCells : [filterMoreCell]),
      ("sortierung", expandedSection == 3 ? sortingCells : [sortingMoreCell])
    ]
    #endif
  }
  
  func createHeaders(){
    let titles = content.map {$0.title}
    titles.enumerated().forEach( { (index, title) in
      let section = index
      let header = TazHeaderFooterView()
      header.label.text = title
      if index == 0 {
        header.chevron.isHidden = true
        headerViews.append(header)
        return//break/continue in enumerated.forEach
      }
      header.onTapping { [weak self] _ in
        guard let self = self else { return }
        header.collapsed = !header.collapsed
        self.expandedSection 
        = self.expandedSection == section
        ? nil
        : section
        self.reloadTable?()
      }
      header.addBorderView(Const.SetColor.ios(.separator).color,
                                0.7,
                                edge: .bottom,
                                insets: Const.Insets.Default)
      headerViews.append(header)
    })
  }
  
  func header(section: Int) -> UIView? {
    return headerViews.valueAt(section)
  }
  
  func cell(at indexPath: IndexPath) -> TazCell? {
    return self.content.valueAt(indexPath.section)?.cells?.valueAt(indexPath.row)
  }
  
  func handle(selectRowAt indexPath: IndexPath) {
    let cell = cell(at: indexPath)
    let rbCell = cell as? RadioButtonCell
    
    switch (cell, rbCell) {
      case let (_, rbCell) where rbCell?.range == .custom:
        if let d = settings.range.currentOption.minimumDate {
          datePickers.fromPicker.date = d
        }
        if let d = settings.range.currentOption.maximuDate {
          datePickers.toPicker.date = d
        }
        settings.range.currentOption = rbCell!.range!
        self.customRange = true
        
      case (rangeMoreCell, _):
        expandedSection = 1
      case let (_, rbCell) where rbCell?.range != nil:
        if settings.range.currentOption == rbCell!.range! { expandedSection = nil}
        settings.range.currentOption = rbCell!.range!
        customRange = false
      case (filterMoreCell, _):
        expandedSection = 2
      case let (_, rbCell) where rbCell?.filter != nil:
        if settings.filter == rbCell!.filter! { expandedSection = nil}
        settings.filter = rbCell!.filter!
      case (sortingMoreCell, _):
        expandedSection = App.isLMD ? 2 : 3
      case let (_, rbCell) where rbCell?.sorting != nil:
        if settings.sorting == rbCell!.sorting! { expandedSection = nil}
        settings.sorting = rbCell!.sorting!
      default:
        break
    }
    
    if settings.filter == .LMd &&
        (settings.range.currentOption == .lastDay || settings.range.currentOption == .lastWeek)
    {
      settings.range.currentOption = .all
    }
    reloadTable?()
  }
  
  init() {
    update()
    createHeaders()
  }
}

