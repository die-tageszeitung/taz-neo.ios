//
//  SearchSettingsVC2.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib
import SwiftUI

class SearchSettingsVC2: UITableViewController {
  
  fileprivate var data = TData()
  
  func restoreInitialState(){
//    currentConfig = SearchSettings()
//    lastConfig = nil
  }
  
  

  
  func setup(){
    tableView.register(TazHeaderFooterView.self,
                       forHeaderFooterViewReuseIdentifier: TazHeaderFooterView.reuseIdentifier)
    tableView.separatorInset = Const.Insets.Default //also for header inset
    tableView.separatorStyle = .none
    self.view.backgroundColor = Const.SetColor.ios(.systemBackground).color
//    data = TableData(sectionContent: [extendedSearchSectionContent, rangeSectionContent, sourceSectionContent])
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
}

// MARK: - cell data model
extension SearchSettingsVC2 {
  typealias tContent = (title:String?,
                        cells:[TazCell]?)
  
  struct TableData{
    public private(set) var content:[tContent]
    
    func cell(at indexPath: IndexPath) -> TazCell? {
      return self.content.valueAt(indexPath.section)?.cells?.valueAt(indexPath.row)
    }
    
    #warning("add a tablechange handler")
    init(content: [tContent]) {
      self.content = content
    }
  }
}


// MARK: - UITableViewDataSource
extension SearchSettingsVC2 {
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
    guard let title = data.content.valueAt(section)?.title else { return nil }
    let header = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: TazHeaderFooterView.reuseIdentifier)
    header?.textLabel?.text = title

    return header
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
extension SearchSettingsVC2 : UIStyleChangeDelegate {
  func applyStyles() {
    print("DOTO")
  }
}

//// MARK: - Cell Factorx
//extension SearchSettingsVC2 {
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
    let height = 34.0
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
  public let radioButton = RadioButton()
  
  var filter:GqlSearchFilter? {
    didSet {
      self.label.text = filter?.rawValue
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
    pin(label, to: contentView, dist: 6, exclude: .left)
    radioButton.isUserInteractionEnabled = false
    radioButton.centerY()
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
  
  func setup(){
    self.textLabel?.boldContentFont().black()
    self.contentView.layoutMargins.left = Const.Size.DefaultPadding
    self.contentView.layoutMargins.right = Const.Size.DefaultPadding
    self.addBorderView(Const.SetColor.ios(.separator).color,
                              0.7,
                              edge: .bottom,
                              insets: Const.Insets.Default)
    
//    guard let label = self.textLabel else { return }
//    label.backgroundColor = .yellow
//
//    pin(label.left, to: self.contentView.left, dist: Const.Size.DefaultPadding)
//    pin(label.right, to: self.contentView.right, dist: -Const.Size.DefaultPadding)
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


fileprivate class TData {
  
  typealias tContent = (title:String?,
                        cells:[TazCell]?)
  ///added, deleted
  typealias tChangedIndexPaths = (added: [IndexPath],
                                  deleted: [IndexPath])
  
  public private(set) var content:[tContent] = []
  
  var settings = SearchSettings()
  var expandedSection: Int?
  
  lazy var authorInpulCell: TextInputCell = {
    let cell = TextInputCell()
    cell.textField.text = settings.author
    cell.textField.placeholder = "AutoIn"
    return cell
  }()
  
  lazy var titleInpulCell: TextInputCell = {
    let cell = TextInputCell()
    cell.textField.text = settings.title
    cell.textField.placeholder = "Titel"
    return cell
  }()
  
  lazy var rangeCells: [RadioButtonCell] = {
    var cells: [RadioButtonCell] = []
    for rangeOption in SearchRangeOption.allItems {
      let cell = RadioButtonCell()
      cell.range = rangeOption
      cells.append(cell)
    }
    return cells
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
    rangeMoreCell.label.text = settings.range.currentOption.rawValue
    filterMoreCell.label.text = settings.filter.rawValue
    sortingMoreCell.label.text = settings.sorting.labelText

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
      case (rangeMoreCell, _):
        expandedSection = 1
      case let (_, rbCell) where rbCell?.range != nil:
        settings.range.currentOption = rbCell!.range!
        expandedSection = nil
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
    
    update()
    tableView.reloadData()
  }
  
  /// get updated IndexPath...
  private func changedIndexPaths(oldData: SettingsVC.TableData) -> SettingsVC.tChangedIndexPaths {
    var added:[IndexPath] = []
    var deleted:[IndexPath] = []
    
//    for idSect in 0 ... max(self.sectionsCount, oldData.sectionsCount) - 1{
//      let newCells = self.sectionData(for: idSect)?.cells ?? []
//      let oldCells = oldData.sectionData(for: idSect)?.cells ?? []
//
//      let addedCells = Set(newCells).subtracting(oldCells)
//      let deletedCells = Set(oldCells).subtracting(newCells)
//
//      let newRows = self.rowsIn(section: idSect)
//      let oldRows = oldData.rowsIn(section: idSect)
//      for idRow in 0 ... (max(newRows, oldRows, 1) - 1){
//        let ip = IndexPath(row: idRow , section: idSect)
//        let newCell = self.cell(at: ip)
//        let oldCell = oldData.cell(at: ip)
//
//        if let newCell = newCell, addedCells.contains(newCell){
//          added.append(ip)
//        }
//
//        if let oldCell = oldCell, deletedCells.contains(oldCell){
//          deleted.append(ip)
//        }
//      }
//    }
    return (added: added, deleted: deleted)
  }
  
  init() {
    update()
  }
  
//  func cell(for indexPath: IndexPath) -> UITableViewCell {
//    let rbCell = RadioButtonCell()
//    rbCell.filter = .all
//    if settings.filter == .all { rbCell.radioButton.isSelected = true }
//    tableView.dequeueReusableCell(identifier: "identifier", for: indexPath)
//  dequeueReusableCellWithIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath
//  }
}
