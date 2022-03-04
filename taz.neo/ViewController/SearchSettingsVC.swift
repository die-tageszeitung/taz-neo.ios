//
//  SearchSettingsVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib

class SearchSettingsVC: UIViewController {
  
  var finishedClosure: ((Bool)->())?
  
  public var currentConfig: SearchSettings = SearchSettings()
  private var lastConfig: SearchSettings?
  
  private var settings = SearchSettingsView()
  private var scrollView = UIScrollView()
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    lastConfig = currentConfig
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    settings.pinWidth(size.width)
  }
  
  func setup(){
    settings.removeFromSuperview()
    settings = SearchSettingsView()
    settings.pinWidth(self.view.frame.size.width)
    self.view.addSubview(scrollView)
    pin(scrollView, toSafe: self.view)
    scrollView.addSubview(settings)
    pin(settings, to: scrollView)
    
    self.view.backgroundColor = Const.SetColor.ios(.systemGroupedBackground).color
    settings.applyButton.addTarget(self,
                                   action: #selector(handleApply),
                                   for: .touchUpInside)
    
    settings.cancelButton.addTarget(self,
                                    action: #selector(handleCancel),
                                    for: .touchUpInside)
    
    settings.sortingControl.addTarget(self,
                                      action: #selector(handleSorting),
                                      for: .valueChanged)
    
    
    handleSorting(sender: settings.sortingControl)
    
    settings.sortingControl.sorting = self.currentConfig.sorting
    switch self.currentConfig.searchLocation {
      case .article:
        settings.sltArticle.isOn = true
        settings.sltAuthor.isOn = false
      case .articleAndAuthor:
        settings.sltArticle.isOn = true
        settings.sltAuthor.isOn = true
      case .author:
        settings.sltAuthor.isOn = true
        settings.sltArticle.isOn = false
      default:
        settings.sltEverywhere.isOn = true
    }
    settings.fromPicker.minimumDate = self.currentConfig.minimumDate
    settings.toPicker.minimumDate = self.currentConfig.minimumDate
    settings.fromPicker.maximumDate = Date()
    settings.toPicker.maximumDate = Date()
    settings.fromPicker.date = self.currentConfig.from ?? self.currentConfig.minimumDate
    settings.fromSwitch.isOn = self.currentConfig.from != nil
    settings.toPicker.date = self.currentConfig.to ?? Date()
    settings.toSwitch.isOn = self.currentConfig.to != nil
    
  }
  
  @objc func handleCancel(){
    finishedClosure?(false)
    self.presentingViewController?.dismiss(animated: true)
  }
  
  @objc func handleApply(){
    self.currentConfig.sorting = settings.sortingControl.sorting
    
    switch (settings.sltEverywhere.isOn, settings.sltAuthor.isOn, settings.sltArticle.isOn) {
      case (true,_,_):
        self.currentConfig.searchLocation = .everywhere
      case (_,true,true):
        self.currentConfig.searchLocation = .articleAndAuthor
      case (_,true,_):
        self.currentConfig.searchLocation = .author
      case (_,_,true):
        self.currentConfig.searchLocation = .article
      default: break
    }
    
    self.currentConfig.from
      = settings.fromSwitch.isOn
      ? settings.fromPicker.date
      : nil
    
    self.currentConfig.to
      = settings.toSwitch.isOn
      ? settings.toPicker.date
      : nil

    if let last = lastConfig {
      finishedClosure?(last != currentConfig)
    } else {
      finishedClosure?(true)
    }
    
    self.presentingViewController?.dismiss(animated: true)
  }
  
  @objc func handleSorting(sender:Any){
    guard let segCtrl = sender as? SortingSegmentedControl else { return }
    settings.segmentedDescriptionLabel.text = segCtrl.sorting.detailDescription
  }
}

private class SearchSettingsView: UIView {
  
  ///Sorting
  public var sortingControl = SortingSegmentedControl()
  
  public var segmentedDescriptionLabel = UILabel("".uppercased(),
                                                 type: .small,
                                                 color: .ios(.secondaryLabel))
  
  public let applyButton = UIButton("Anwenden", type: .bold)
  public let cancelButton = UIButton("Abbrechen")
  
  ///SearchLocationSwitches
  public var sltEverywhere = UISwitch()
  public var sltArticle = UISwitch()
  public var sltAuthor = UISwitch()
  
  ///DatePicker
  public var fromPicker = UIDatePicker()
  public var toPicker = UIDatePicker()
  
  public var fromHeightContraint: NSLayoutConstraint?
  public var toHeightContraint: NSLayoutConstraint?
  
  public var fromSwitch = UISwitch()
  public var toSwitch = UISwitch()
  
  
  func hStackWith(text: String, control: UIView) -> UIView {
    let stack = UIStackView()
    stack.axis = .horizontal
    let label = UILabel(text)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    control.setContentHuggingPriority(.required, for: .horizontal)
    stack.addArrangedSubview(label)
    stack.addArrangedSubview(control)
    stack.isLayoutMarginsRelativeArrangement = true
    stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
    
    return stack
  }
  
  func vSpacer(_ height:CGFloat = 5.0) -> UIView {
    let v = UIView()
    v.pinHeight(height)
    return v
  }
  
  func vStackWith(_ views:UIView ...) -> UIStackView {
    
    func seperator() -> UIView {
      let v = UIView()
      v.pinHeight(0.5)
      v.backgroundColor =  Const.SetColor.ios(.separator).color
      return v
    }
    
    let stack = UIStackView()
    stack.axis = .vertical
    
    for v in views {
      stack.addArrangedSubview(v)
      //      if views.last != v || (v is UIDatePicker) == false {
      if views.last != v {
        stack.addArrangedSubview(seperator())
      }
    }
    
    stack.backgroundColor = Const.SetColor.ios(.secondarySystemGroupedBackground).color
    stack.layer.cornerRadius = 5.0
    return stack
  }
  
  @objc func dateSwitchChanged(sender:UISwitch!) {
    if sender == fromSwitch {
      fromHeightContraint?.isActive = !sender.isOn
      fromPicker.isHidden = !sender.isOn
    }
    else if sender == toSwitch {
      toHeightContraint?.isActive = !sender.isOn
      toPicker.isHidden = !sender.isOn
    }
  }
  
  @objc func searchLocationSwitchChange(sender:UISwitch!) {
    switch (sender, sltEverywhere.isOn, sltAuthor.isOn, sltArticle.isOn) {
      case (sltEverywhere,true,_,_):
        sltAuthor.isOn = false
        sltArticle.isOn = false
      case (sltEverywhere,false,_,_):
        sltAuthor.isOn = true
        sltArticle.isOn = true
      case (sltAuthor,true,true,_):
        sltEverywhere.isOn = false
      case (sltArticle,true,_,true):
        sltEverywhere.isOn = false
      case (sltArticle,false,false,_): fallthrough
      case (sltAuthor,false,_,false):
        sltEverywhere.isOn = !sender.isOn
      default: break
    }
  }
  
  private func setup(){
    [sltEverywhere, sltAuthor, sltArticle, fromSwitch, toSwitch].forEach { s in
      s.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
    }
    
    sltEverywhere.addTarget(self,
                            action: #selector(self.searchLocationSwitchChange),
                            for: .valueChanged)
    sltArticle.addTarget(self,
                         action: #selector(self.searchLocationSwitchChange),
                         for: .valueChanged)
    sltAuthor.addTarget(self,
                        action: #selector(self.searchLocationSwitchChange),
                        for: .valueChanged)
    
    fromSwitch.addTarget(self,
                         action: #selector(self.dateSwitchChanged),
                         for: .valueChanged)
    
    toSwitch.addTarget(self,
                       action: #selector(self.dateSwitchChanged),
                       for: .valueChanged)
    
    
    fromPicker.datePickerMode = .date
    toPicker.datePickerMode = .date
    
    fromPicker.isHidden = true
    toPicker.isHidden = true
    
    if #available(iOS 14.0, *) {
      fromPicker.preferredDatePickerStyle = .inline
      toPicker.preferredDatePickerStyle = .inline
    }
    
    fromHeightContraint = fromPicker.pinHeight(0)
    toHeightContraint = toPicker.pinHeight(0)
    
    let hStack = UIStackView()
    hStack.axis = .horizontal
    let titleLabel = UILabel("Sucheinstellungen", type: .bold, align: .center)
    titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    applyButton.setContentHuggingPriority(.required, for: .horizontal)
    cancelButton.setContentHuggingPriority(.required, for: .horizontal)
    hStack.addArrangedSubview(cancelButton)
    hStack.addArrangedSubview(titleLabel)
    hStack.addArrangedSubview(applyButton)
    hStack.isLayoutMarginsRelativeArrangement = true
    
    let verticalStack = UIStackView()
    verticalStack.spacing = UIStackView.spacingUseSystem
    verticalStack.alignment = .fill
    verticalStack.distribution = .fill
    verticalStack.axis = .vertical
    
    verticalStack.isLayoutMarginsRelativeArrangement = true
    verticalStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    
    sortingControl.selectedSegmentIndex = 0
    
    verticalStack.addArrangedSubview(hStack)
    verticalStack.addArrangedSubview(vSpacer())
    verticalStack.addArrangedSubview( UILabel("Sortierung".uppercased(),
                                              type: .small,
                                              color: .ios(.secondaryLabel)))
    verticalStack.addArrangedSubview(sortingControl)
    verticalStack.addArrangedSubview(segmentedDescriptionLabel)
    verticalStack.addArrangedSubview(vSpacer())
    
    verticalStack.addArrangedSubview( UILabel("Suche in".uppercased(),
                                              type: .small,
                                              color: .ios(.secondaryLabel)))
    verticalStack.addArrangedSubview(
      vStackWith(hStackWith(text: "Überall suchen", control: sltEverywhere),
                 hStackWith(text: "In Artikel Titel", control: sltArticle),
                 hStackWith(text: "Nach Autoren", control: sltAuthor))
    )
    
    verticalStack.addArrangedSubview(vSpacer())
    verticalStack.addArrangedSubview(UILabel("Zeitraum".uppercased(), type: .small, color: .ios(.secondaryLabel)))
    
    verticalStack.addArrangedSubview(
      vStackWith(
        hStackWith(text: "Von", control: fromSwitch),
        fromPicker,
        hStackWith(text: "Bis", control: toSwitch),
        toPicker
      )
    )
    
    verticalStack.addArrangedSubview(UIView())
    self.addSubview(verticalStack)
    pin(verticalStack, to: self)
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
}

private class SortingSegmentedControl: UISegmentedControl {
  
  private let items:[GqlSearchSorting] = GqlSearchSorting.allCases
  
  init(){
    super.init(items: items.map{$0.labelText})
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public var sorting:GqlSearchSorting {
    get{
      return items[self.selectedSegmentIndex]
    }
    set{
      if let i = items.firstIndex(where: { $0 == newValue }) {
        self.selectedSegmentIndex = i
      }
    }
  }
}


public extension UIButton {
  internal convenience init(_ _text : String,
                            type: tazFontType = .content) {
    self.init()
    self.setTitle(_text, for: .normal)
    switch type {
      case .bold:
        self.titleLabel?.font = Const.Fonts.titleFont(size: Const.Size.DefaultFontSize)
      case .content:
        self.titleLabel?.font = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)
      case .small:
        self.titleLabel?.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
      case .title:
        self.titleLabel?.font = Const.Fonts.titleFont(size: Const.Size.LargeTitleFontSize)
    }
    self.setTitleColor(Const.SetColor.ios(.tintColor).color, for: .normal)
    self.setTitleColor(Const.SetColor.ios(.tintColor).color.withAlphaComponent(0.7), for: .highlighted)
    
  }
}
