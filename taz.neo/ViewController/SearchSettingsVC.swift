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
  
  lazy var footer:UIView = {
    // manuell size is a workaround due autolayout not working correctly in environment
    // autolayout in table Header or Footer is main reason
    let estimatedFooterHeight
    = 2*Const.Size.DefaultPadding
    + 2*UIButton.tazButtonHeight
    + 10
    let v = UIView(frame: CGRect(x: 0,
                                 y: 0,
                                 width: UIWindow.size.width,
                                 height: estimatedFooterHeight))
    let searchButton = UIButton().primary_CTA("Suche starten")
    let resetButton = UIButton().secondary_CTA("Zurücksetzen & Schließen")
    
    searchButton.onTapping {[weak self] _ in
      self?.finishedClosure?(true)
    }
    
    resetButton.onTapping {[weak self] _ in
      self?.restoreInitialState()
      self?.finishedClosure?(false)
    }
    
    
    v.addSubview(searchButton)
    v.addSubview(resetButton)
    
    pin(searchButton.left, to: v.left, dist: Const.Size.DefaultPadding, priority: .defaultHigh)
    pin(searchButton.right, to: v.right, dist: -Const.Size.DefaultPadding, priority: .defaultHigh)
    pin(resetButton.left, to: v.left, dist: Const.Size.DefaultPadding, priority: .defaultHigh)
    pin(resetButton.right, to: v.right, dist: -Const.Size.DefaultPadding, priority: .defaultHigh)
    
    pin(searchButton.top, to: v.top, dist: Const.Size.DefaultPadding, priority: .defaultHigh)
    pin(resetButton.top, to: searchButton.bottom, dist: 10)
    pin(resetButton.bottom, to: v.bottom, dist: -Const.Size.DefaultPadding, priority: .defaultHigh)
    
    return v
  }()
  
  var viewWidthConstraint: NSLayoutConstraint?
  
  func setup(){
    viewWidthConstraint = self.tableView.pinWidth(UIWindow.size.width, priority: .defaultLow)//prevent size animation error
    tableView.register(TazHeaderFooterView.self,
                       forHeaderFooterViewReuseIdentifier: TazHeaderFooterView.reuseIdentifier)
    self.tableView.contentInset = .zero
    tableView.separatorInset = Const.Insets.Default //also for header inset
    tableView.separatorStyle = .none
    self.view.backgroundColor = Const.SetColor.ios(.systemBackground).color
    tableView.tableFooterView = footer
//    tableView.setNeedsUpdateConstraints()
//    tableView.updateConstraintsIfNeeded()
//    tableView.setNeedsLayout()
//    tableView.layoutIfNeeded()
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
    data.handle(tableView, selectRowAt: indexPath)
  }
}

// MARK: - UIStyleChangeDelegate
extension SearchSettingsVC : UIStyleChangeDelegate {
  func applyStyles() {
    print("DOTO")
  }
}

//// MARK: - Cell Factorx
//extension SearchSettingsVC {
//  static func textInputCell(_ text: String?, _ placeholder: String ) {
//    print("DOTO")
//  }
//}

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
    let height = Const.Size.TextFieldHeight
    textField.pinHeight(height)
    textField.layer.cornerRadius = height/2
    
    textField.clipsToBounds = true
    contentView.addSubview(textField)
    let insets = UIEdgeInsets(top: 4,
                              left: Const.Size.DefaultPadding,
                              bottom: -4,
                              right: -Const.Size.DefaultPadding)
    pin(textField, to: contentView, insets: insets)
  }
}

/// A custom table view cell with label and chevron right
class MoreCell: TazCell {
  let label = UILabel()
  
  override func setup(){
    self.backgroundColor = Const.SetColor.ios(.systemBackground).color
    label.contentFont().labelColor()
    accessoryType = .disclosureIndicator
    contentView.addSubview(label)
    pin(label, to: contentView, dist: Const.Size.DefaultPadding)
    self.addBorderView(Const.SetColor.ios(.separator).color,
                              0.7,
                              edge: .bottom,
                              insets: Const.Insets.Default)
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
    self.backgroundColor = Const.SetColor.ios(.secondarySystemBackground).color
    contentView.addSubview(radioButton)
    contentView.addSubview(label)
    contentView.addSubview(additionalContentWrapper)
    additionalContentWrapper.pinHeight(0, priority: .defaultLow)
    label.contentFont().labelColor()
    pin(label.top, to: contentView.top, dist: 6)
    pin(label.right, to: contentView.right, dist: 6)
    pin(additionalContentWrapper, to: contentView, exclude: .top)
    pin(additionalContentWrapper.top, to: label.bottom, dist: 6)
    radioButton.isUserInteractionEnabled = false
    pin(radioButton.centerY, to: label.centerY)
    radioButton.pinSize(CGSize(width: 16, height: 16), priority: .required)
    pin(radioButton.left, to: contentView.left, dist: Const.Size.DefaultPadding)
    pin(radioButton.right, to: label.left, dist: -8)
  }
}

/// A custom table view cell
class TazCell: UITableViewCell {
  
  func setup(){}//overwriteable
  
  // MARK: - Initialization
  
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
  
  func setup(){
    self.contentView.addSubview(label)
    pin(label.top, to: self.contentView.top)
    pin(label.left, to: self.contentView.left, dist: Const.Size.DefaultPadding)
    pin(label.right, to: self.contentView.right, dist: -Const.Size.DefaultPadding, priority: .defaultLow)
    pin(label.bottom, to: self.contentView.bottom, dist: -Const.Size.DefaultPadding, priority: .defaultLow)
    self.contentView.layoutMargins.left = Const.Size.DefaultPadding
    self.contentView.layoutMargins.right = Const.Size.DefaultPadding
    self.addBorderView(Const.SetColor.ios(.separator).color,
                              0.7,
                              edge: .bottom,
                              insets: Const.Insets.Default)
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
    cell.textField.defaultStyle(placeholder: "Autor*innen")
    return cell
  }()
  
  lazy var titleInpulCell: TextInputCell = {
    let cell = TextInputCell()
    cell.textField.text = settings.title
    cell.textField.defaultStyle(placeholder: "Titel")
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
  
  lazy var customRangeCellExpanded: RadioButtonCell = {
    let cell = RadioButtonCell()
    cell.range = .custom
    if true {
      let datePickers = CustomRangeDatePickerView()
      cell.additionalContentWrapper.addSubview(datePickers)
      pin(datePickers, to: cell.additionalContentWrapper)
    }
    else {
      let v = UIView()
      v.pinHeight(60, priority: .required)
      v.backgroundColor = .yellow.withAlphaComponent(0.4)
      cell.additionalContentWrapper.addSubview(v)
      pin(v, to: cell.additionalContentWrapper)
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
    cell.label.text = settings.range.currentOption.rawValue
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
    
//    if let customRangeCell = rangeCells.last {
//      UIView.animate(withDuration: 0.5) {
//        customRangeCell.additionalContentWrapperHeightConstraint?.constant = 0
//      } completion: { _ in
//        customRangeCell.additionalContentWrapper.subviews.forEach { $0.removeFromSuperview() }
//      }
//    }
    
    rangeMoreCell.label.text = settings.range.currentOption.rawValue
    filterMoreCell.label.text = settings.filter.rawValue
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
  
  func handle(_ tableView: UITableView, selectRowAt indexPath: IndexPath) {
    let cell = cell(at: indexPath)
    let rbCell = cell as? RadioButtonCell
    
    switch (cell, rbCell) {
      case let (_, rbCell) where rbCell?.range == .custom:
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
    let oldContent = content
    update()
    reloadAnimatedIfNeeded(tableView: tableView, oldContent: oldContent)
  }
  
  /// get updated IndexPath...
  private func reloadAnimatedIfNeeded(tableView: UITableView, oldContent: [tContent]) {
    var added:[IndexPath] = []
    var deleted:[IndexPath] = []
    
    for idSect in 0 ... max(content.count, oldContent.count) - 1{
      let newCells = content.valueAt(idSect)?.cells ?? []
      let oldCells = oldContent.valueAt(idSect)?.cells ?? []

      let addedCells = Set(newCells).subtracting(oldCells)
      let deletedCells = Set(oldCells).subtracting(newCells)

      for idRow in 0 ... (max(newCells.count, oldCells.count, 1) - 1){
        let ip = IndexPath(row: idRow , section: idSect)
        let newCell = self.cell(at: ip)
        let oldCell = oldCells.valueAt(idRow)

        if let newCell = newCell, addedCells.contains(newCell){
          added.append(ip)
        }

        if let oldCell = oldCell, deletedCells.contains(oldCell){
          deleted.append(ip)
        }
      }
    }
    
    if (added.count + deleted.count) == 0 {
      tableView.reloadData()
      return
    }
    //middle or fade animation
    tableView.performBatchUpdates {
      if deleted.count > 0 { tableView.deleteRows(at: deleted, with: .middle) }
      if added.count > 0 { tableView.insertRows(at: added, with: .middle) }
    }
  }
  
  init() {
    update()
  }
}

class CustomRangeDatePickerView: UIView {
  
  public var fromPicker = UIDatePicker()
  public var toPicker = UIDatePicker()
  
  func setup(){
    fromPicker.datePickerMode = .date
    toPicker.datePickerMode = .date
    
    if #available(iOS 14.0, *) {
      fromPicker.preferredDatePickerStyle = .inline
      toPicker.preferredDatePickerStyle = .inline
    }
    
    self.addSubview(fromPicker)
    self.addSubview(toPicker)
    pin(fromPicker, to: self, exclude: .bottom)
    pin(toPicker, to: self, exclude: .top)
    pin(toPicker.top, to:fromPicker.bottom, dist: 5)
    self.backgroundColor = .systemRed.withAlphaComponent(0.3)
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
