//
//  SettingsVC+ChildVcSelection.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 29.10.26.
//  Copyright © 2026 Ringo Müller-Gromes. All rights reserved.
//

import NorthLib
import UIKit

extension SettingsVC{
  func updateFilterSelectionCell(){
    filterSelectionCell.setValue(currentFilterSelection.title)
  }
  
  func showFilterSelection() {
    let items = [
      SettingsSelectionViewController<FilterSelection>.Item(
        .menu,
        title: FilterSelection.menu.title,
        detailText: FilterSelection.menu.detailText
      ),
      SettingsSelectionViewController<FilterSelection>.Item(
        .buttons,
        title: FilterSelection.buttons.title,
        detailText: FilterSelection.buttons.detailText
      ),
      SettingsSelectionViewController<FilterSelection>.Item(
        .both,
        title: FilterSelection.both.title,
        detailText: FilterSelection.both.detailText
      )
    ]
    
    let controller = SettingsSelectionViewController(
      title: "Filterauswahl",
      explanation: "Lege fest, wie die Filterauswahl in der Ausgabenübersicht (Home) angezeigt wird.",
      items: items,
      selectedOption: currentFilterSelection
    ) { [weak self] selection in
      guard let self else { return }
      self.currentFilterSelection = selection
      self.updateFilterSelectionCell()
    }
    
    navigationController?.pushViewController(
      controller,
      animated: true
    )
  }
}

enum FilterSelection: String, CaseIterable {
  case menu
  case buttons
  case both
  
  var title: String {
    switch self {
      case .menu:    return "Menü"
      case .buttons: return "Schaltflächen"
      case .both:    return "Menü und Schaltflächen"
    }
  }
  
  var detailText: String? {
    switch self {
      case .both:
        return "Zeigt die Filterauswahl sowohl im Darstellungsmenü als auch direkt als Schaltflächen in der Ausgabenübersicht an."
      case .menu:
        return "Zeigt die Filterauswahl ausschließlich im Darstellungsmenü der Ausgabenübersicht an."
      case .buttons:
        return "Zeigt die Filterauswahl ausschließlich als Schaltflächen in der Ausgabenübersicht an. (Standard)"
    }
  }
}

class SettingsSelectionViewController<Option: Hashable>: UITableViewController {
  
  struct Item {
    let option: Option
    let title: String
    let detailText: String?
    
    init(
      _ option: Option,
      title: String,
      detailText: String? = nil
    ) {
      self.option = option
      self.title = title
      self.detailText = detailText
    }
  }
  
  private let items: [Item]
  private var selectedOption: Option
  private let explanation: String
  private let onSelect: (Option) -> Void
  
  private var lastHeaderWidth: CGFloat = 0
  
  private func updateTableHeader() {
    guard tableView.bounds.width > 0,
          let header = tableView.tableHeaderView,
          let label = header.subviews.first as? UILabel else {
      return
    }
    
    let width = tableView.bounds.width
    
    let labelSize = label.sizeThatFits(
      CGSize(
        width: width - 32,
        height: .greatestFiniteMagnitude
      )
    )
    
    let height = labelSize.height + 24
    
    header.frame = CGRect(
      x: 0,
      y: 0,
      width: width,
      height: height
    )
    
    tableView.tableHeaderView = header
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    let width = tableView.bounds.width
    guard width > 0, width != lastHeaderWidth else { return }
    
    lastHeaderWidth = width
    updateTableHeader()
  }
  
  init(
    title: String,
    explanation: String,
    items: [Item],
    selectedOption: Option,
    onSelect: @escaping (Option) -> Void
  ) {
    self.explanation = explanation
    self.items = items
    self.selectedOption = selectedOption
    self.onSelect = onSelect
    
    super.init(style: .insetGrouped)
    
    self.title = title
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(false, animated: animated)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    installCustomBackButton()
    
    tableView.register(
      UITableViewCell.self,
      forCellReuseIdentifier: "Option"
    )
    tableView.insetsLayoutMarginsFromSafeArea = false
    tableView.layoutMargins = .zero
    
    
    let label = UILabel()
    label.text = explanation
    label.numberOfLines = 0
    label.contentFont()
    label.textColor = Const.SetColor.ios(.secondaryLabel).color
    
    let header = UIView()
    header.addSubview(label)
    //    pin(label, to: header, insets: UIEdgeInsets(top: 12, left: 15, bottom: -12, right: -15))
    pin(label.left, to: header.left, dist: 16)
    pin(label.right, to: header.right, dist: -16)
    pin(label.top, to: header.top, dist: 12)
    pin(label.bottom, to: header.bottom, dist: -12)
    
    header.frame.size.height = label.systemLayoutSizeFitting(
      CGSize(
        width: tableView.bounds.width - 32,
        height: UIView.layoutFittingCompressedSize.height
      )
    ).height + 24
    
    tableView.tableHeaderView = header
    
    ///apply styles
//    tableView.backgroundColor = Const.SetColor.HBackground.color
    tableView.backgroundColor = Const.SetColor.taz(.textFieldBackground).color
  }
  
  override func tableView(
    _ tableView: UITableView,
    numberOfRowsInSection section: Int
  ) -> Int {
    items.count
  }
  
  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  ) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(
      withIdentifier: "Option",
      for: indexPath
    )
    
    let item = items[indexPath.row]
    
    var content = UIListContentConfiguration.subtitleCell()
    content.text = item.title
    content.textProperties.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
    content.secondaryText = item.detailText
    content.secondaryTextProperties.font = Const.Fonts.contentFont(size: Const.Size.SmallerFontSize)
    content.secondaryTextProperties.color = Const.SetColor.ios(.secondaryLabel).color
    
    cell.contentConfiguration = content
    cell.tintColor = .label
    cell.accessoryType =
    item.option == selectedOption ? .checkmark : .none
    
    return cell
  }
  
  override func tableView(
    _ tableView: UITableView,
    didSelectRowAt indexPath: IndexPath
  ) {
    tableView.deselectRow(at: indexPath, animated: true)
    
    let option = items[indexPath.row].option
    selectedOption = option
    tableView.reloadData()
    
    onSelect(option)
    navigationController?.popViewController(animated: true)
  }
}


final class XSettingsSelectionCell: XSettingsCell {
  
  private let valueLabel = UILabel()
  private let chevronView = UIImageView(
    image: UIImage(systemName: "chevron.right")
  )
  
  init(
    text: String,
    value: String,
    tapHandler: (() -> ())?
  ) {
    super.init(
      text: text,
      tapHandler: tapHandler,
      customLayout: true
    )
    
    valueLabel.text = value
    valueLabel.textAlignment = .right
    valueLabel.setContentHuggingPriority(
      .defaultHigh,
      for: .horizontal
    )
    valueLabel.setContentCompressionResistancePriority(
      .defaultHigh,
      for: .horizontal
    )
    
    chevronView.contentMode = .scaleAspectFit
    
    contentView.addSubview(valueLabel)
    contentView.addSubview(chevronView)
    
    let padding = Const.ASize.DefaultPadding
    
    pin(textLabel!.left, to: contentView.left, dist: padding)
    pin(textLabel!.top, to: contentView.top, dist: self.padding)
    pin(textLabel!.bottom, to: contentView.bottom, dist: -self.padding)
    
    pin(chevronView.right, to: contentView.right, dist: -padding)
    chevronView.centerY()
    chevronView.pinWidth(8)
    chevronView.pinHeight(17)
    
    pin(valueLabel.right, to: chevronView.left, dist: -8)
    valueLabel.centerY()
    
    pin(textLabel!.right, to: valueLabel.left, dist: -8)
    valueLabel.widthAnchor.constraint(
      greaterThanOrEqualToConstant: 1
    ).isActive = true
    
    applyStyles()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setValue(_ value: String) {
    valueLabel.text = value
  }
  
  override func applyStyles() {
    super.applyStyles()
    valueLabel.contentFont(size: Const.Size.SmallerFontSize)
    valueLabel.textColor = Const.SetColor.ios(.secondaryLabel).color
    chevronView.tintColor = .label
  }
}

@propertyWrapper
struct DefaultEnum<Enum: RawRepresentable> where Enum.RawValue == String {
  
  private let key: String
  private let defaultValue: Enum
  
  var wrappedValue: Enum {
    get {
      guard let rawValue = UserDefaults.standard.string(forKey: key),
            let value = Enum(rawValue: rawValue) else {
        return defaultValue
      }
      return value
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: key)
    }
  }
  
  init(
    _ key: String,
    default defaultValue: Enum
  ) {
    self.key = key
    self.defaultValue = defaultValue
  }
}
