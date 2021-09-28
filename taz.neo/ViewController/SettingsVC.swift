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
      case .manageAccount: return userInfo;
      case .terms: return "Allgemeine Geschäftsbedingungen (AGB)";
      case .privacy: return "Datenschutzerklärung";
      case .revocation: return "Widerruf";
    }
  }
  
  private var userInfo: String {
    let isAuth = MainNC.singleton.feederContext.isAuthenticated
    let (id,_,token) = SimpleAuthenticator.getUserData()
    if isAuth, (id != nil), (token != nil) {
      return "Konto Verwalten (\(id ?? ""))"
    }
    else {
      return "Anmelden"
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
        Cell(toggleWithText: "Letzten Ausgaben laden TBD", initialValue: false, changeHandler: {_ in }),
//        Cell(with: SaveLastCountIssues()),
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
        Cell(toggleWithText: "Texteinstellungen TBD", initialValue: false, changeHandler: {_ in }),
//        Cell(with: TextSizeSetting()),
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
    tableView.register(CustomSettingsCell.self, forCellReuseIdentifier: CustomSettingsCell.identifier)
    tableView.tableHeaderView = header
    tableView.separatorStyle = .none
    header.layoutIfNeeded()
    header.xButton.onPress { [weak self] _ in
      guard let self = self else { return }
      self.navigationController?.dismiss(animated: true)
    }
    registerForStyleUpdates()
    
  }
  
  public func applyStyles() {
    self.tableView.backgroundColor = Const.SetColor.CTBackground.color
    footer.backgroundColor = Const.SetColor.CTBackground.color.withAlphaComponent(0.9)
    onMainAfter {   [weak self] in
      self?.tableView.reloadData()
    }

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
    let cell = tableView.dequeueReusableCell(withIdentifier: cellContent.type.identifier,
                                             for: indexPath) as? TSettingsCell
    
    cell?.content = cellContent
    return cell ?? UITableViewCell()
  }
  
//  open override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//    Settings.content[section].title
//  }
  
  open override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let v = UIView()
    let l = UILabel()
    l.text = Settings.content[section].title
    l.boldContentFont(size: Const.Size.ContentTableFontSize).set(textColor: Const.SetColor.ios(.label).color)
    v.addSubview(l)
            pin(l.top, to: v.top, dist: 30, priority: .defaultHigh)
           pin(l.bottom, to: v.bottom, dist: -10, priority: .defaultHigh)
            pin(l.left, to: v.left, dist: Const.ASize.DefaultPadding, priority: .defaultHigh)
            pin(l.right, to: v.right, dist: -Const.ASize.DefaultPadding, priority: .defaultHigh)
    return v
  }
  
  open override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return section == Settings.content.count - 1 ? footer : UIView()
  }
  
  open override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return section == Settings.content.count - 1 ? 40.0 : 0
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
    let isAuth = MainNC.singleton.feederContext.isAuthenticated
    
    let actions = UIAlertController.init( title: nil, message: nil,
      preferredStyle:  .actionSheet )
    
    if isAuth {
      actions.addAction( UIAlertAction.init( title: "Abmelden", style: .default,
        handler: { [weak self] handler in
          MainNC.singleton.deleteUserData()
          self?.tableView.reloadData()
      } ) )
    }
    else {
      actions.addAction( UIAlertAction.init( title: "Anmelden", style: .default,
                                             handler: {   [weak self] _ in
                                              guard let self = self else { return }
          guard let feeder = MainNC.singleton.feederContext.gqlFeeder else { return }
          let authenticator = DefaultAuthenticator(feeder: feeder)
          authenticator.authenticate(with: self)
          Notification.receiveOnce("authenticationSucceeded") { [weak self]_ in
            self?.tableView.reloadData()
            Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
          } } ) )
    }

    actions.addAction( UIAlertAction.init( title: "Konto online verwalten", style: .default,
    handler: {_ in
      guard let url = URL(string: "https://portal.taz.de/") else { return }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    } ) )
    
    
    actions.addAction( UIAlertAction.init( title: "Passwort zurücksetzen", style: .default,
    handler: {
      [weak self] _ in
      self?.modalPresentationStyle = .fullScreen
      let id = SimpleAuthenticator.getUserData().id
      guard let feeder = MainNC.singleton.feederContext.gqlFeeder else { return }
      let childVc = PwForgottController(id: id, auth: DefaultAuthenticator.init(feeder: feeder))
      childVc.modalPresentationStyle = .fullScreen
      self?.present(childVc, animated: true) 
    } ) )
    actions.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel,
    handler: {
      (handler: UIAlertAction) in
    } ) )
    actions.presentAt(self.view)
  }
  
  func handleErrorReport(){
    MainNC.singleton.showFeedbackErrorReport(.error)
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
    
    introVC.webView.xButton.tazX()
    
    introVC.webView.onX { _ in
      introVC.dismiss(animated: true, completion: nil)
    }
    self.modalPresentationStyle = .fullScreen
    introVC.modalPresentationStyle = .fullScreen
    introVC.webView.webView.atEndOfContent {_ in }
    self.present(introVC, animated: true) {
      //Overwrite Default in: IntroVC viewDidLoad
      introVC.webView.buttonLabel.text = nil
    }
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
    toggle.onTintColor = Const.SetColor.ios(.link).color
    toggle.addTarget(self, action: #selector(handleToggle(sender:)), for: .valueChanged)
    return toggle
  }()
  
  @objc public func handleToggle(sender: UISwitch) {
    content?.toggleChangeHandler?(sender.isOn)
  }
  
  func setup(){
    self.backgroundColor = .clear
    if let tl =  self.textLabel, let sv = tl.superview {
      pin(tl.left, to: sv.left, dist: Const.ASize.DefaultPadding, priority: .defaultHigh)
      pin(tl.right, to: sv.right, dist: -Const.ASize.DefaultPadding, priority: .defaultHigh)
      pin(tl.top, to: sv.top, dist: Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
      pin(tl.bottom, to: sv.bottom, dist: -Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    }
    
    self.accessoryView = toggle
    self.textLabel?.numberOfLines = 0
    self.textLabel?.contentFont().labelColor()
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
    self.backgroundColor = .clear
    if let tl =  self.textLabel, let sv = tl.superview {
      pin(tl.left, to: sv.left, dist: Const.ASize.DefaultPadding, priority: .defaultHigh)
      pin(tl.right, to: sv.right, dist: -Const.ASize.DefaultPadding, priority: .defaultHigh)
      pin(tl.top, to: sv.top, dist: Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
      pin(tl.bottom, to: sv.bottom, dist: -Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    }
    self.textLabel?.contentFont().linkColor()
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
    self.backgroundColor = .clear
    self.backgroundView?.backgroundColor = .clear
    self.contentView.backgroundColor = .clear
    if let tl =  self.textLabel, let sv = tl.superview {
      pin(tl.left, to: sv.left, dist: Const.ASize.DefaultPadding, priority: .defaultHigh)
      pin(tl.right, to: sv.right, dist: -Const.ASize.DefaultPadding, priority: .defaultHigh)
      pin(tl.top, to: sv.top, dist: Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
      pin(tl.bottom, to: sv.bottom, dist: -Const.ASize.DefaultPadding, priority: .fittingSizeLevel)
    }
    
    print("setup for CustomSettingsCell")
    self.textLabel?.contentFont().linkColor()
//    self.textLabel?.backgroundColor = .red
//    self.tintColor = .yellow
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
  
  func prepareForReuse() {
    setup()
  }
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
  
  public lazy var xButton = Button<CircledXView>().tazX()
  
  private let titleLabel = Label().titleFont()
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
    self.backgroundColor = .clear
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


extension ButtonControl {
  
  @discardableResult
  func tazX() -> Self {
    guard let bv = self as? Button<CircledXView> else { return self }
    self.pinHeight(35)
    self.pinWidth(35)
    self.color = .black
    bv.buttonView.isCircle = true
    bv.buttonView.circleColor = Const.SetColor.ios(.secondarySystemFill).color
    bv.buttonView.color = Const.SetColor.ios(.link).color
    bv.buttonView.activeColor = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
    bv.buttonView.innerCircleFactor = 0.5
    return self
  }
}

extension UIView {
  
  func inset(insets: UIEdgeInsets) {
    guard let superview = self.superview else { return }
    
    self.leftAnchor.constraint(equalTo: superview.leftAnchor,
                               constant: insets.left,
                               priority: .defaultHigh,
                               activate: true)
    self.rightAnchor.constraint(equalTo: superview.rightAnchor, constant: -insets.right,
                                priority: .defaultHigh,
                                activate: true)
    self.topAnchor.constraint(equalTo: superview.topAnchor, constant: insets.top,
                              priority: .defaultHigh,
                              activate: true)
    self.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -insets.bottom,
                                 priority: .defaultHigh,
                                 activate: true)
  }
}

extension NSLayoutAnchor {
  @discardableResult
  @objc open func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat, priority: UILayoutPriority, activate: Bool = false) -> NSLayoutConstraint {
    let constraint = self.constraint(equalTo: anchor, constant: c)
    constraint.priority = priority
    if activate { constraint.isActive = true}
    return constraint
  }
}


//extension UIView {
//  public func removeAllSuperviewConstraints() {
//    guard let sv = self.superview else {return}
//
//    for constraint in sv.constraints {
//      print("fount sv constrauint: \(constraint)")
//    }
//
//    for constraint in sv.constraints {
//      if let first = constraint.firstItem as? UIView, first == self {
//        sv.removeConstraint(constraint)
//      }
//      if let second = constraint.secondItem as? UIView, second == self {
//        sv.removeConstraint(constraint)
//      }
//    }
//
//    for constraint in self.constraints {
//      print("fount different constrauint: \(constraint)")
//    }
//  }
//}


class XUITableViewHeaderFooterView: UITableViewHeaderFooterView{}
