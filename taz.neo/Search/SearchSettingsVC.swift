//
//  SearchSettingsVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib
import SwiftUI

class SearchSettingsVC: UITableViewController {
  
  var finishedClosure: ((Bool)->())?
  
  private let _data = TData()

  public var data: TData {
    get {
      /**
       Ugly but currently working, end input of textfield is maybe too late
       later improvement maybe to not close extended search if no valit search term
       */
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

    
  func restoreInitialState(){
    data.settings = SearchSettings()
    data.titleInpulCell.textField.text = nil
    data.authorInpulCell.textField.text = nil
    data.update()
    tableView.reloadData()
  }
  
  lazy var header:HeaderActionBar = {
    let h = HeaderActionBar()
    h.leftButton.onTapping {[weak self] _ in
      self?.dismiss(animated: true, completion: {[weak self] in
        self?.restoreInitialState()
        self?.finishedClosure?(false)
      })
    }
    h.rightButton.onTapping {[weak self] _ in
      self?.dismiss(animated: true, completion: {[weak self] in
        self?.finishedClosure?(true)
      })
    }
    return h
  }()
  
   
  var viewWidthConstraint: NSLayoutConstraint?
  
  
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
    }
    #warning("TODO ROW ANIMATION")
//    tableView.reloadData(); return;
    if (added.count + deleted.count) == 0 {
      tableView.reloadData()
      return
    }
    //middle or fade animation
    tableView.performBatchUpdates {
      if deleted.count > 0 { tableView.deleteRows(at: deleted, with: .none) }
      if added.count > 0 { tableView.insertRows(at: added, with: .none  ) }
    }
    onMainAfter {
      [weak self] in
        guard let self = self else { return }
        self.preferredContentSize = CGSize(width: self.preferredContentSize.width, height: self.tableView.contentSize.height + 50)
    }
  }
  
  func setup(){
//    viewWidthConstraint = self.tableView.pinWidth(UIWindow.size.width, priority: .defaultLow)//prevent size animation error
    tableView.register(TazHeaderFooterView.self,
                       forHeaderFooterViewReuseIdentifier: TazHeaderFooterView.reuseIdentifier)
    self.tableView.backgroundColor = .white
//    tableView.separatorInset = Const.Insets.Default //also for header inset
    tableView.separatorStyle = .none
//    tableView.preservesSuperviewLayoutMargins = false
//    tableView.insetsLayoutMarginsFromSafeArea = true
//    tableView.tableFooterView = footer
//        self.tableView.contentInset = UIEdgeInsets(top: 40, left: 20, bottom: Const.Size.SmallPadding, right: -80)
//  tableView.layoutMargins = .init(top: 0.0, left: 20, bottom: 0.0, right: 30)
        // if you want the separator lines to follow the content width
//        tableView.separatorInset = tableView.layoutMargins
    
    _data.reloadTable = { [weak self] in
      guard let self = self else { return }
      let oldContent = self._data.content
      self._data.update()
      self.reloadAnimatedIfNeeded(oldContent: oldContent)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if header.superview == nil, let sv = self.tableView.superview {
      if gt_iOS13 == false {
        /// unfortunately header height expands till sv bottom and overlays tableView so its not clickable anymore
        /// insert at 0 also not works then tv overlays header
        /// simple solution: make the header scrollable on ios 12
        let headerWrapper = UIView()
        headerWrapper.pinHeight(60)
        headerWrapper.pinWidth(sv.frame.size.width)
        headerWrapper.addSubview(header)
        pin(header, toSafe: headerWrapper,
            insets: UIEdgeInsets(top: 0,
                                 left: Const.Size.DefaultPadding,
                                 bottom: 0,
                                 right: -Const.Size.DefaultPadding))
        headerWrapper.doLayout()
        self.tableView.tableHeaderView = headerWrapper
        return
      }
      self.tableView.contentInset = UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0)
      self.tableView.scrollIndicatorInsets = UIEdgeInsets(top: 60, left: 0, bottom: 5, right: 0)
      header.pinHeight(60)
      sv.addSubview(header)
      pin(header, toSafe: sv, insets: UIEdgeInsets(top: 13, left: Const.Size.DefaultPadding, bottom: 0, right: -Const.Size.DefaultPadding), exclude: .bottom)
      
    }
  }
}

class HeaderActionBar: UIStackView {
  
  public lazy var leftButton: UIButton = {
    let btn = UIButton()
    btn.translatesAutoresizingMaskIntoConstraints = false
    btn.setTitle("Zurücksetzen", for: .normal)
    btn.titleLabel?.font = Const.Fonts.contentFont
    btn.setTitleColor(Const.SetColor.ios(.label).color, for: .normal)
    return btn
  }()
  
  public lazy var rightButton: UIButton = {
    let btn = UIButton()
    btn.translatesAutoresizingMaskIntoConstraints = false
    btn.setTitleColor(Const.SetColor.ios(.label).color, for: .normal)
    btn.setTitle("Suchen", for: .normal)
    btn.titleLabel?.font = Const.Fonts.contentFont
    btn.titleLabel?.textColor = .red
    return btn
  }()
  
  public lazy var label: UILabel = {
    let lbl = UILabel().boldContentFont()
    lbl.textColor = .black
    lbl.numberOfLines = 0
    lbl.textAlignment = .center
    lbl.text = "Suchoptionen"
    return lbl
  }()
  
  func setup(){
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    self.addSubview(blur)
    pin(blur, to: self, insets: UIEdgeInsets(top: -10, left: -Const.Size.DefaultPadding, bottom: 0, right: Const.Size.DefaultPadding))
    self.alignment = .fill
    self.distribution = .equalCentering
    self.spacing = 6.0
    self.axis = .horizontal
    addArrangedSubview(leftButton)
    addArrangedSubview(label)
    addArrangedSubview(rightButton)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}

// MARK: - cell data model
extension SearchSettingsVC {
  typealias tContent = (title:String?,
                        cells:[TazCell]?)
  
  struct TableData{
    public private(set) var content:[tContent]
    
    func cell(at indexPath: IndexPath) -> TazCell? {
      return self.content.valueAt(indexPath.section)?.cells?.valueAt(indexPath.row)
    }
  }
}


// MARK: - UITableViewDataSource
extension SearchSettingsVC {
  open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return data.content.valueAt(section)?.cells?.count ?? 0
  }
  
  open override func numberOfSections(in tableView: UITableView) -> Int {
    return data.content.count
  }
  
  open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return data.cell(at: indexPath) ?? UITableViewCell()
  }
  
  open override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let title = data.content.valueAt(section)?.title,
          let header = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: TazHeaderFooterView.reuseIdentifier) as? TazHeaderFooterView
    else { return nil }
    header.label.text = title
    return header
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return section == 0 ? 0 : UITableView.automaticDimension
  }
  
  open override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    if let cell = data.cell(at: indexPath),
       cell is RadioButtonCell || cell is MoreCell {
      return indexPath
    }
    return nil
  }

  open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    data.handle(selectRowAt: indexPath)
  }
}

// MARK: - UIStyleChangeDelegate
extension SearchSettingsVC : UIStyleChangeDelegate {
  func applyStyles() {
    print("DOTO")
  }
}

// MARK: - TextInputCell

/// A custom table view cell with TextInput
class TextInputCell: TazCell {
  let textField = UITextField()
  
  override func setup(){
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
    textField.backgroundColor = Const.SetColor.ios(.secondarySystemBackground).color
    //add some pading for corner radius
    textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 5))
    textField.leftViewMode = .always
    textField.clearButtonMode = .whileEditing
    let customClearButton = UIButton.appearance(whenContainedInInstancesOf: [UITextField.self])
    #warning("missing padding but work")
//    customClearButton.tintColor = Const.SetColor.ios(.secondaryLabel).color
//    customClearButton.setImage(UIImage(named: "xmark"), for: .normal)
//    textField.rightView = UIImageView(image: UIImage(named: "xmark"))
//    textField.rightViewMode = .whileEditing
    textField.pinHeight(Const.Size.NewTextFieldHeight)
    textField.clipsToBounds = true
    contentView.addSubview(textField)
    let insets = UIEdgeInsets(top: 8,
                              left: Const.Size.DefaultPadding,
                              bottom: -8,
                              right: -Const.Size.DefaultPadding)
    pin(textField, to: contentView, insets: insets)
    
    
  }
}

// MARK: - MoreCell

/// A custom table view cell with label and chevron right
class MoreCell: TazCell {
  let label = UILabel()
  
  override func setup(){
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
    label.contentFont().labelColor()
    accessoryType = .none
    contentView.addSubview(label)
    pin(label, to: contentView, dist: Const.Size.DefaultPadding)
    self.addBorderView(Const.SetColor.ios(.separator).color,
                              0.7,
                              edge: .bottom,
                              insets: Const.Insets.Default)
  }
}

// MARK: - RadioButtonCell

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
}

// MARK: - TazCell

/// A custom table view cell
class TazCell: UITableViewCell {
  
  func setup(){}//overwriteable
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }
}

/// A custom table view cell with TextInput
class TazHeaderFooterView: UITableViewHeaderFooterView {
  static let reuseIdentifier = "TazHeaderFooterView"
  
  var label: UILabel = UILabel().boldContentFont().labelColor()
  let chevron = UIImageView(image: UIImage(named: "chevron-up"))
  
  func setup(){
    self.contentView.addSubview(label)
    self.contentView.addSubview(chevron)
    
    chevron.iosLower13?.contentMode = .scaleAspectFit
    chevron.tintColor = Const.SetColor.ios(.secondaryLabel).color
    chevron.pinSize(CGSize(width: 24, height: 24))
    pin(chevron.right, to: self.contentView.right, dist: -Const.ASize.DefaultPadding)
    chevron.centerY()

    pin(label.top, to: self.contentView.top)
    pin(label.left, to: self.contentView.left, dist: Const.Size.DefaultPadding)
    pin(label.right, to: chevron.right, dist: -Const.Size.DefaultPadding, priority: .defaultLow)
    pin(label.bottom, to: self.contentView.bottom, dist: -Const.Size.DefaultPadding, priority: .defaultLow)
    self.contentView.layoutMargins.left = Const.Size.DefaultPadding
    self.contentView.layoutMargins.right = Const.Size.DefaultPadding
    self.addBorderView(Const.SetColor.ios(.separator).color,
                              0.7,
                              edge: .bottom,
                              insets: Const.Insets.Default)
    
    self.rotateChevron()
  }
  
  var collapsed: Bool = true {
    didSet {
      if oldValue == collapsed { return }
      UIView.animateKeyframes(withDuration: 0.5, delay: 0.0, animations: {
        UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) { [weak self] in
          guard let self = self else { return }
          self.chevron.transform = CGAffineTransform(rotationAngle: 0)
        }
        
        UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) { [weak self] in
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
}

class TData {
  
  var reloadTable: (()->())?
  
  typealias tContent = (title:String?,
                        cells:[TazCell]?)
  ///added, deleted
  typealias tChangedIndexPaths = (added: [IndexPath],
                                  deleted: [IndexPath])
  
  public private(set) var content:[tContent] = []
  
  var settings = SearchSettings()
  var expandedSection: Int?
  
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
      = datePickers.fromPicker.date.shortest
      + " - "
      + datePickers.toPicker.date.shortest
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

    rangeCells.forEach{ $0.radioButton.isSelected = $0.range == settings.range.currentOption }
    filterCells.forEach{ $0.radioButton.isSelected = $0.filter == settings.filter }
    sortingCells.forEach{ $0.radioButton.isSelected = $0.sorting == settings.sorting }
    
    content = [
      (nil, [titleInpulCell, authorInpulCell]),
      ("zeitraum", expandedSection == 1 ? rangeCells : [rangeMoreCell]),
      ("erschienen in", expandedSection == 2 ? filterCells : [filterMoreCell]),
      ("sortierung", expandedSection == 3 ? sortingCells : [sortingMoreCell])
    ]
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
        settings.range.currentOption = rbCell!.range!
        expandedSection = nil
        customRange = false
      case (filterMoreCell, _):
        expandedSection = 2
      case let (_, rbCell) where rbCell?.filter != nil:
        settings.filter = rbCell!.filter!
        expandedSection = nil
      case (sortingMoreCell, _):
        expandedSection = 3
      case let (_, rbCell) where rbCell?.sorting != nil:
        settings.sorting = rbCell!.sorting!
        expandedSection = nil
      default:
        break
    }
    reloadTable?()
  }
  
  
  
  init() {
    update()
  }
}

class CustomRangeDatePickerView: UIView {
  
  public let fromPicker = UIDatePicker()
  public let toPicker = UIDatePicker()
  
  public let fromCloseLabel = UILabel("Übernehmen")
  public let toCloseLabel = UILabel("Übernehmen")
  
  @objc public func dateChanged(_ sender: UIControl) {
    if sender == fromPicker {
      toPicker.minimumDate = fromPicker.date
    }
    else if sender == toPicker {
      fromPicker.maximumDate = toPicker.date
    }
  }
  
  func setup(){
    fromPicker.datePickerMode = .date
    toPicker.datePickerMode = .date
    
    fromPicker.maximumDate = Date()
    toPicker.maximumDate = Date()
    
    toPicker.minimumDate = Date(timeIntervalSinceReferenceDate: 0)
    fromPicker.minimumDate = Date(timeIntervalSinceReferenceDate: 0)
    
    fromPicker.date = Date(timeIntervalSinceReferenceDate: 0)
    toPicker.date = Date()
    
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
    pin(fromPicker.top, to: fromLabel.bottom, dist: 3)
    pin(fromPicker.left, to: self.left)
    pin(fromPicker.right, to: self.right)
    pin(toLabel.top, to: fromPicker.bottom, dist: 3)
    pin(toLabel.left, to: self.left)
    pin(toLabel.right, to: self.right)
    pin(toCloseLabel.right, to: self.right)
    pin(toCloseLabel.centerY, to: toLabel.centerY)
    pin(toPicker.top, to:toLabel.bottom, dist: 5)
    pin(toPicker, to: self, exclude: .top)
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
