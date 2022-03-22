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
  
  public var currentConfig: SearchSettings = SearchSettings()
  
  class TazHeaderFooterView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "TazHeaderFooterView"
  }
  
  lazy var titleInpulCell: TextInputCell = {
    let cell = TextInputCell()
    cell.textInput.text = currentConfig.title
    cell.textInput.placeholder = "Titel"
    return cell
  }()
  
  lazy var authorInpulCell: TextInputCell = {
    let cell = TextInputCell()
    cell.textInput.text = currentConfig.author
    cell.textInput.placeholder = "AutoIn"
    return cell
  }()
  
  lazy var rangeSectionColapsedCell: MoreCell = {
    let cell = MoreCell()
    cell.label.text = currentConfig.author
    return cell
  }()
  
  lazy var rangeSectionExpandedCells: [RadioButtonCell] = {
    return [
      RadioButtonCell().set("Überall", true),
      RadioButtonCell().set("Letzter Tag"),
      RadioButtonCell().set("Letzte Woche"),
      RadioButtonCell().set("Letzter Monat"),
      RadioButtonCell().set("Letztes Jahr"),
      RadioButtonCell().set("Zeitraum")]
  }()
  
  lazy var originColapsedCell: MoreCell = {
    let cell = MoreCell()
    cell.label.text = currentConfig.author
    return cell
  }()
  
  lazy var originnExpandedCells: [RadioButtonCell] = {
    return [
      RadioButtonCell().set("Überall", true),
      RadioButtonCell().set("taz"),
      RadioButtonCell().set("Le Monde diplomatique"),
      RadioButtonCell().set("Kontext")]
  }()
  
  var expandedSection: Int?
  
//  let extendedSearchSectionContent: tSectionContent
//  = ( nil,
//      [titleInpulCell, TextInputCell()],
//      nil)
//
//  let rangeSectionContent: tSectionContent
//  = ( "zeitraum",
//      [MoreCell()],
//      [RadioButtonCell(), RadioButtonCell(), RadioButtonCell()])
//
//  let sourceSectionContent: tSectionContent
//  = ( "erschienen in",
//      [MoreCell()],
//      [RadioButtonCell(), RadioButtonCell(), RadioButtonCell()])
//
//
//
//  var data:TableData = TableData(sectionContent: []) {
//    didSet {
//      print("Need Update")
//    }
//  }
  
//  var finishedClosure: ((Bool)->())?
  
  private var lastConfig: SearchSettings?
  
  private var searchFooterButton:UIButton = UIButton("Suche starten", type: .bold)
  
  func restoreInitialState(){
    currentConfig = SearchSettings()
    lastConfig = nil
  }
  
  func setup(){
    tableView.register(TazHeaderFooterView.self,
                       forHeaderFooterViewReuseIdentifier: TazHeaderFooterView.reuseIdentifier)
//    data = TableData(sectionContent: [extendedSearchSectionContent, rangeSectionContent, sourceSectionContent])
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    lastConfig = currentConfig
  }
}

// MARK: - cell data model
extension SearchSettingsVC2 {
  typealias tSectionContent = (title:String?,
                               collapsedCells:[TazCell],
                               expandedCells:[TazCell]?)
  
  struct TableData{
    private var expandedSection: Int?
    private var sectionContent:[tSectionContent]
    init(sectionContent: [tSectionContent]) {
      self.sectionContent = sectionContent
    }
  }
}

// MARK: - cell data model access helper
extension SearchSettingsVC2.TableData{

  var sectionsCount: Int { return self.sectionContent.count }

  func rowsIn(section: Int) -> Int{
    guard let sectionContent = sectionData(for: section) else { return 0 }
    return expandedSection == section
    ? sectionContent.expandedCells?.count ?? 0
    : sectionContent.collapsedCells.count
  }

//  func canTap(at indexPath: IndexPath) -> Bool{
//    return cell(at: indexPath)?.tapHandler != nil
//  }

  func cell(at indexPath: IndexPath) -> TazCell? {
    guard let sectionContent = sectionData(for: indexPath.section) else {
      return nil
    }
    return expandedSection == indexPath.section
    ? sectionContent.expandedCells?.valueAt(indexPath.row)
    : sectionContent.collapsedCells.valueAt(indexPath.row)
  }

  func sectionData(for section: Int) -> SearchSettingsVC2.tSectionContent?{
    return self.sectionContent.valueAt(section)
  }

  func footerHeight(for section: Int) -> CGFloat{
    return 20
  }
}



// MARK: - UITableViewDataSource
extension SearchSettingsVC2 {
  open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch (section, expandedSection) {
      case (0, _): return 2 //extended search
      case (1, 1): return 6 //range expanded
      case (1, _): return 1 //range
      case (2, 2): return 4 //origin expanded
      case (2, _): return 1 //origin
      default: return 0
    }
  }
  
  open override func numberOfSections(in tableView: UITableView) -> Int {
    return 3
  }
  
  open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch (indexPath.section, expandedSection, indexPath.row) {
      case (0, _, 0): return titleInpulCell
      case (0, _, 1): return authorInpulCell
      case (1, 1, _): return rangeSectionExpandedCells.valueAt(indexPath.row) ?? UITableViewCell()
      case (1, _, 0): return rangeSectionColapsedCell
      case (2, 2, _): return originnExpandedCells.valueAt(indexPath.row) ?? UITableViewCell()
      case (2, _, 0): return originColapsedCell
      default: return UITableViewCell()
    }
  }
  
  open override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    if !(section == 1 || section == 2) { return nil }
    let header = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: TazHeaderFooterView.reuseIdentifier)
    header?.textLabel?.text
    = section == 1
    ? "zeitraum"
    : "erschienen in"
    header?.textLabel?.boldContentFont().black()
    return header
  }
  
  open override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return nil
  }
  
  open override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
    view.backgroundColor = .clear
  }
  
//  open override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
//    return data.footerHeight(for: section)
//  }
  
  open override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    if indexPath.section == 1 || indexPath.section == 2 { return indexPath }
    return nil
  }

  open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    let rbCell = tableView.cellForRow(at: indexPath) as? RadioButtonCell
    
    var ani: UITableView.RowAnimation = .none//.automatic
    var animation: UITableView.RowAnimation = .fade//.automatic
//    tableView.beginUpdates()
    if expandedSection == indexPath.section {
      let cells
      = indexPath.row == 1
      ? rangeSectionExpandedCells
      : originnExpandedCells
      cells.map{ $0.radioButton.isSelected = false }
      rbCell?.radioButton.isSelected = true
      
      expandedSection = nil;
      animation = ani//.top
    }
    else {
//      if let oldExpanded = expandedSection {
//        self.tableView.reloadSections(IndexSet(integer: oldExpanded),
//                                      with: ani)//.top)
//      }
      expandedSection = indexPath.section;
      animation = .bottom

    }
    self.tableView.reloadData()
//    self.tableView.reloadSections(IndexSet(integer: indexPath.section),
//                                  with: ani)
//    tableView.endUpdates()
  }
  
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 30
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
  let textInput = UITextField()
  
  override func setup(){
    contentView.backgroundColor = .green
    contentView.addSubview(textInput)
    pin(textInput, to: contentView)
  }
}

/// A custom table view cell with label and chevron right
class MoreCell: TazCell {
  let label = UILabel()
  
  override func setup(){
    contentView.backgroundColor = .blue
    accessoryType = .disclosureIndicator
    contentView.addSubview(label)
    pin(label, to: contentView)
  }
}

/// A custom table view cell with radioButton and label
class RadioButtonCell: TazCell {
  let label = UILabel()
  let radioButton = RadioButton()
  
  
  func set(_ text:String, _ selected:Bool = false) -> Self {
    self.label.text = text
    self.radioButton.isSelected = selected
    return self
  }
  
  override func setup(){
    contentView.backgroundColor = .red
    contentView.addSubview(radioButton)
    contentView.addSubview(label)
    pin(label, to: contentView, exclude: .left)
    radioButton.centerY()
    radioButton.pinSize(CGSize(width: 30, height: 20), priority: .required)
    pin(radioButton.left, to: contentView.left)
    pin(radioButton.right, to: label.left, dist: 8)
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


extension SearchSettings {
  
}
