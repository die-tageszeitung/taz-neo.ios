//
//  SettingsVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 21.09.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import Foundation

//
//  ContentVC.swift
//
//  Created by Norbert Thies on 25.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

extension Settings.LinkType {
  var cellDescription:String {
    switch self {
      case .onboarding: return "Erste Schritte";
      case .errorReport: return "Fehler melden";
      case .manageAccount: return "Konto Verwalten";
      case .terms: return "Allgemeine Geschäftsbedingungen (AGB)";
      case .privacy: return "Datenschutzerklärung";
      case .revocation: return "Widerruf";
    }
  }
}


extension Settings.CellType {
  var identifier:String {
    switch self {
      case .custom: return CustomSettingsCell.identifier;
      case .link: return LinkSettingsCell.identifier;
      case .toggle: return ToggleSettingsCell.identifier;
    }
  }
}

struct Settings {
  enum CellType { case link, toggle, custom }
  enum LinkType { case onboarding, errorReport, manageAccount, terms, privacy, revocation }
  
  struct Cell {
    var linkType:LinkType?
    let type:CellType
//    var view:UIView
    var text:String?
    var userSetting: Bool?
    var toggleiInitialValue:Bool?
    var toggleChangeHandler:((Bool)->())?
    var tapHandler:(()->())?
    init(toggleWithText text: String, initialValue: Bool, changeHandler: @escaping ((Bool)->())) {
//      view = UIView()
//      view.backgroundColor = .red
      self.toggleChangeHandler = changeHandler
      self.toggleiInitialValue = initialValue
      self.type = .toggle
      self.text = text
    }
    
    init(linkType: LinkType) {
      self.type = .link
      self.linkType = linkType
    }
    
    init(with customView: UIView) {
//      view = customView
      self.type = .custom
      self.text = nil
    }
  }
  typealias sectionContent = (title:String?, cells:[Cell])
  static let content : [sectionContent] =
    [
      ("allgemein",
       [
        Cell(with: SaveLastCountIssues()),
        Cell(toggleWithText: "Neue Ausgaben automatisch laden",
             initialValue: Defaults.autoloadNewIssues,
             changeHandler: { newValue in Defaults.autoloadNewIssues = newValue}),
        Cell(toggleWithText: "Nur im W-Lan herunterladen",
             initialValue: Defaults.autoloadInWLAN,
             changeHandler: { newValue in Defaults.autoloadInWLAN = newValue})
       ]
      ),
      ("darstellung",
       [
        Cell(with: TextSizeSetting()),
        Cell(toggleWithText: "Nachtmodus",
             initialValue: Defaults.darkMode,
             changeHandler: { newValue in Defaults.darkMode = newValue})
       ]
      ),
      ("support",
       [
        Cell(linkType: .onboarding),
        Cell(linkType: .errorReport)
       ]
      ),
      ("abo",
       [
        Cell(linkType: .manageAccount),
        Cell(linkType: .terms),
        Cell(linkType: .privacy),
        Cell(linkType: .revocation)
       ]
      )
    ]
    
}

/**
 
 2 Typen:
 - allgemein: Custom, Toggle, Link
 - konkret: remember, autoloadm ....
 
 Link Text:Handler/TargetView
 Toggle: Text/Setting (Bool)
 
 Data:
 Int:String?:

 Allgemein
 Die letzten XY Ausgaben speichern ? (Custom)
 Neue Ausgaben automatisch lagen (Toggle)
 Nur im W-Lan herunterladen (Toggle)

 Darstellung
 Textgröße (Custom)
 Nachtmodus (Toggle)

 Support
 Erste Schritte (Link)
 Fehler melden (Link)

 Abo
 Konto Verwalten / Anmelden (Link) => 1. Popup: Abmelden, Passwort zurücksetzen, Account Online verwalten, Abbrechen 2. Anmelden UI
 AGB (Link)
 Widerruf (Link)
 Datenschutzerklärung (Link)

 <None>
 Version (Info)
 
 */


/**
 A SettingsVC is a view controller to edit app's user Settings
 */

// MARK: - SettingsVC
open class SettingsVC: UITableViewController, UIStyleChangeDelegate {
  
  var feederContext: FeederContext?
  

  
  lazy var footerLabel = UILabel(App.appInfo).contentFont(size: 12).set(textColor: Const.SetColor.ios(.secondaryLabel).color)
  lazy var footer = footerLabel.wrapper(UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20))
  lazy var header = SimpleHeaderView("einstellungen")
  
  func setup(){
    tableView.register(ToggleSettingsCell.self, forCellReuseIdentifier: ToggleSettingsCell.identifier)
    tableView.register(LinkSettingsCell.self, forCellReuseIdentifier: LinkSettingsCell.identifier)
    tableView.register(CustomSettingsCell.self, forCellReuseIdentifier: CustomSettingsCell.identifier)
    tableView.tableHeaderView = header
//    tableView.contentInset = Const.Insets.Small
//    tableView.separatorColor = Const.SetColor.ios(.secondaryLabel).color
//    tableView.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    tableView.separatorStyle = .none
    header.layoutIfNeeded()
    header.xButton.onPress { [weak self] _ in
      guard let self = self else { return }
      self.navigationController?.dismiss(animated: true)
    }
    
  }
  
  public func applyStyles() {
    footer.backgroundColor = Const.SetColor.CTBackground.color.withAlphaComponent(0.9)
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    applyStyles()
  }
  
  open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return Settings.content[section].cells.count
  }
  
  open override func numberOfSections(in tableView: UITableView) -> Int {
    return Settings.content.count
  }
  
  open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellContent = Settings.content[indexPath.section].cells[indexPath.row]
    var cell = tableView.dequeueReusableCell(withIdentifier: cellContent.type.identifier,
                                             for: indexPath) as? TSettingsCell
    
    cell?.content = cellContent
    return cell as? UITableViewCell ?? UITableViewCell()
  }
  
  open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    Settings.content[section].title
  }
  
//  open override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//    return super.tableView(tableView, heightForHeaderInSection: section) + 80
//  }
  
  open override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    guard let header = view as? UITableViewHeaderFooterView else { return }
    header.textLabel?.boldContentFont(size: Const.Size.ContentTableFontSize)
//    header.tintColor = .yellow//
    header.tintColor = Const.SetColor.CTBackground.color.withAlphaComponent(0.9)
//    header.textLabel?.alignmentRectInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//    header.textLabel?.textC
//    header.textLabel?.backgroundColor = .red
//    header.textLabel.con
//    tableView.separatorInset = UIEdgeInsets(top: 0,
//                                          left: Const.ASize.DefaultPadding,
//                                          bottom: 0,
//                                          right: -Const.ASize.DefaultPadding)

  }

  open override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return section == Settings.content.count - 1 ? footer : UIView()
  }
  
  open override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return section == Settings.content.count - 1 ? 40.0 : 15
  }
  
  open override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    let cellContent = Settings.content[indexPath.section].cells[indexPath.row]
    if cellContent.tapHandler == nil,
       cellContent.type != .link { return nil }
    return indexPath
  }
  
  open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let cellContent = Settings.content[indexPath.section].cells[indexPath.row]
    guard let linkType = cellContent.linkType,
          cellContent.type == .link else { return }
    tableView.deselectRow(at: indexPath, animated: true)
    handleLink(linkType: linkType)
  }
}

// MARK: - Handler
extension SettingsVC {
  func handleLink(linkType:Settings.LinkType){
    switch linkType {
      case .errorReport:
        handleErrorReport()
      case .onboarding:
        showOnboarding()
      case .manageAccount:
        manageAccount()
      case .privacy:
        showPrivacy()
      case .terms:
        showTerms()
      case .revocation:
        showRevocation()
    }
  }
  
  func showPrivacy(){
    guard let feeder = MainNC.singleton.feederContext.gqlFeeder else { return }
    showLocalHtml(from: feeder.dataPolicy, scrollEnabled: true)
  }
  
  func showTerms(){
    guard let feeder = MainNC.singleton.feederContext.gqlFeeder else { return }
    showLocalHtml(from: feeder.terms, scrollEnabled: true)
  }
  
  func showRevocation(){
    guard let feeder = MainNC.singleton.feederContext.gqlFeeder else { return }
    showLocalHtml(from: feeder.revocation, scrollEnabled: true)
  }
  
  func manageAccount(){
    let actions = UIAlertController.init( title: nil, message: nil,
      preferredStyle:  .actionSheet )
    actions.addAction( UIAlertAction.init( title: "Abmelden", style: .default,
      handler: { [weak self] handler in
//        //previously used PDFEXPORT Compiler Flags
//        if App.isAvailable(.PDFEXPORT), #available(iOS 14, *) {
//          self?.exportPdf(article: art, from: button)
//        } else {
//          let dialogue = ExportDialogue<Any>()
//          dialogue.present(item: "\(art.teaser ?? "")\n\(art.onlineLink!)",
//                           view: button, subject: art.title)
//        }
    } ) )
    actions.addAction( UIAlertAction.init( title: "Konto online verwalten", style: .default,
    handler: {
      (handler: UIAlertAction) in
//      self.debug("Going to online version: \(link)")
//      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    } ) )
    actions.addAction( UIAlertAction.init( title: "Passwort zurücksetzen", style: .default,
    handler: {
      (handler: UIAlertAction) in
//      self.debug("Going to online version: \(link)")
//      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    } ) )
    actions.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel,
    handler: {
      (handler: UIAlertAction) in
    } ) )
    actions.presentAt(self.view)
  }
  
  func handleErrorReport(){
    
  }
  
  func showOnboarding(){
    guard let feeder = MainNC.singleton.feederContext.gqlFeeder else { return }
    showLocalHtml(from: feeder.welcomeSlides, scrollEnabled: false)
  }
  
  func showLocalHtml(from urlString:String, scrollEnabled: Bool){
    let introVC = IntroVC()
    introVC.htmlIntro = urlString
    let intro = File(urlString)
    introVC.webView.webView.load(url: intro.url)
    introVC.webView.webView.scrollView.contentInsetAdjustmentBehavior = .never
    introVC.webView.webView.scrollView.isScrollEnabled = scrollEnabled
    introVC.webView.buttonLabel.text = nil
    introVC.webView.onX { _ in
      introVC.dismiss(animated: true, completion: nil)
    }
    self.modalPresentationStyle = .fullScreen
    introVC.modalPresentationStyle = .fullScreen
    introVC.webView.webView.atEndOfContent {_ in }
    self.present(introVC, animated: true)
  }
}

// MARK: - ToggleSettingsCell
class ToggleSettingsCell: UITableViewCell, TSettingsCell {
  var content: Settings.Cell? {
    didSet {
      self.textLabel?.text = content?.text
      self.toggle.isOn = content?.toggleiInitialValue ?? false
    }
  }

  lazy var toggle: UISwitch = {
    let toggle = UISwitch()
    toggle.addTarget(self, action: #selector(handleToggle(sender:)), for: .valueChanged)
    return toggle
  }()
  
  @objc public func handleToggle(sender: UISwitch) {
    content?.toggleChangeHandler?(sender.isOn)
  }
  
  func setup(){
    self.accessoryView = toggle
    self.textLabel?.numberOfLines = 0
    self.textLabel?.contentFont()
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  
  static let identifier = "toggleSettingsCell"
}


// MARK: - LinkSettingsCell
class LinkSettingsCell: UITableViewCell, TSettingsCell {
  var content: Settings.Cell? {
    didSet {
      self.textLabel?.text = content?.linkType?.cellDescription
      setup()
    }
  }
  
  static let identifier = "linkSettingsCell"
  
  func setup(){
    self.textLabel?.contentFont().ciColor()
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) {fatalError("init(coder:) has not been implemented")  }
}

// MARK: - CustomSettingsCell
class CustomSettingsCell: UITableViewCell, TSettingsCell {
  var content: Settings.Cell? {
    didSet {
      self.textLabel?.text = content?.text
    }
  }
  
  static let identifier = "customSettingsCell"
  
  func setup(){
    print("setup for CustomSettingsCell")
    self.textLabel?.contentFont().ciColor()
  }
  
}

//// MARK: - CustomSettingsCell
//class SettingsCell: UITableViewCell, TSettingsCell {
//  static let identifier = "SettingsCell"
//
//  var content: Settings.Cell? {
//    didSet {
//      self.textLabel?.text = content?.text
//    }
//  }
//
//  override func prepareForReuse() {
//    self.textLabel?.contentFont().ciColor()
//  }
//
//}


// MARK: - Prot. TSettingsCell
protocol TSettingsCell where Self: UITableViewCell {
  static var identifier:String {get}
  var content:Settings.Cell? {set get}
  func setup()
  
}

extension TSettingsCell where Self: UITableViewCell {
  init() {
    self.init(frame: .zero)
    setup()
  }
  
//  init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
//    self = UITableViewCell(style: style, reuseIdentifier: reuseIdentifier) as! Self
//    setup()
//  }

//  init?(coder: NSCoder){
//
//  }
  
  func prepareForReuse() {
    setup()
  }
  
//  override static func prepareForInterfaceBuilder() {
//    <#code#>
//  }
}

/**
 Problem:
 3 Cells => setup should be called
 
 after init
 
 
 */

class SaveLastCountIssues: UIView {
  
  func setup(){
    
  }
}

class TextSizeSetting: UIView {
  
  func setup(){
    
  }
}

// MARK: - ext. App
extension App {
  static var appInfo:String {
    let appTitle = App.isAlpha ? "Alpha" : App.isBeta ? "Beta" : "taz"
    return "\(appTitle) (v) \(App.version)-\(App.buildNumber)"
  }
  
  static func authInfo(with feederContext: FeederContext) -> String {
    let authInfo = feederContext.isAuthenticated ? "angemeldet" : "NICHT ANGEMELDET"
    return "\(authInfo), gespeicherte taz-ID: \(DefaultAuthenticator.getUserData().id ?? "-")"
  }
}

// MARK: - SimpleHeaderView
class SimpleHeaderView: UIView,  UIStyleChangeDelegate{
  
  public lazy var xButton = Button.xTazButton
  
  private let titleLabel = Label().boldContentFont(size: Const.Size.ContentTableFontSize).align(.right)
  private let line = DottedLineView()
  
  private func setup() {
    registerForStyleUpdates()
    applyStyles()
    
    self.addSubview(titleLabel)
    self.addSubview(line)
    self.addSubview(xButton)
    
    pin(xButton.right, to: self.right, dist: -Const.ASize.DefaultPadding)
    pin(xButton.top, to: self.topGuide(), dist: 5)
    pin(titleLabel.top, to: xButton.bottom)
    
    pin(titleLabel.left, to: self.left, dist: Const.ASize.DefaultPadding)
    pin(titleLabel.right, to: self.right, dist: -Const.ASize.DefaultPadding)
    
    pin(line, to: self, dist: Const.ASize.DefaultPadding,exclude: .top)
    line.pinHeight(Const.Size.DottedLineHeight)
    pin(line.top, to: titleLabel.bottom, dist: Const.Size.TinyPadding)
    pinWidth(UIWindow.size.width)
  }
  
  public func applyStyles() {
    titleLabel.textColor = Const.SetColor.HText.color
    line.fillColor = Const.SetColor.HText.color
    line.strokeColor = Const.SetColor.HText.color
  }
  
  init(_ title: String) {
    titleLabel.text = title
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - ext. UIView (Wrapper)
extension UIView {
  
  /// add self to a wrapper View, pin with dist and return wrapper view
  /// - Parameter dist: dist to pin between wrapper and self
  /// - Returns: wrapper
  @discardableResult
  func wrapper(_ insets: UIEdgeInsets = Const.Insets.Small) -> UIView {
    let wrapper = UIView()
    wrapper.addSubview(self)
    pin(self.left, to: wrapper.left, dist: insets.left)
    pin(self.right, to: wrapper.right, dist: insets.right)
    pin(self.top, to: wrapper.top, dist: insets.top)
    pin(self.bottom, to: wrapper.bottom, dist: insets.bottom)
    return wrapper
  }
  
  /// set backgroundColor and return self (for chaining)
  /// - Parameter backgroundColor: backgroundColor to set
  /// - Returns: self
  @discardableResult
  func set(backgroundColor: UIColor) -> UIView {
    self.backgroundColor = backgroundColor
    return self
  }
  
//  ///Blur Idea from: https://stackoverflow.com/questions/30953201/adding-blur-effect-to-background-in-swift
//  /// not working here for chaining, need also effect style depending dark/light
//  func addBlur() -> UIView {
//    let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.extraLight)
//    let blurEffectView = UIVisualEffectView(effect: blurEffect)
//    blurEffectView.frame = self.bounds
//    blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//    self.addSubview(blurEffectView)
//    return self
//  }
}

extension Button{
  static var xTazButton: Button<CircledXView> {
    get{
      let xButton = Button<CircledXView>()
      xButton.pinHeight(35)
      xButton.pinWidth(35)
      xButton.buttonView.isCircle = false
      xButton.buttonView.activeColor = Const.Colors.ciColor.withAlphaComponent(0.5)
      xButton.buttonView.color = Const.Colors.ciColor
      return xButton
    }
  }
}
