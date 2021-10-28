//
//  SettingsVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 21.09.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
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
      case .cleanMemory: return "Alte Ausgaben löschen";
    }
  }
  
  var attributedDescription:NSAttributedString? {
    guard self == .cleanMemory else { return nil}
    return attributedString(first: "Alte Ausgaben löschen",
                            firstColor: Const.SetColor.ios(.link).color,
                            second: "Gedrückt halten für weitere Optionen")
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
  
  @Default("autoloadInWLAN")
  static var autoloadInWLAN: Bool

  @Default("autoloadNewIssues")
  static var autoloadNewIssues: Bool
  
  @Default("persistedIssuesCount")
  static var persistedIssuesCount: Int
  
  
  enum CellType { case link, toggle, custom }
  enum LinkType { case onboarding, errorReport, manageAccount, terms, privacy, revocation, cleanMemory }
  
  struct Cell {
    var linkType:LinkType?
    let type:CellType
    var accessoryView:UIView?
    var text:String?
    var subText:String?
    var userSetting: Bool?
    var toggleiInitialValue:Bool?
    var toggleChangeHandler:((Bool)->())?
    var tapHandler:(()->())?
    init(toggleWithText text: String, initialValue: Bool, changeHandler: @escaping ((Bool)->())) {
      self.toggleChangeHandler = changeHandler
      self.toggleiInitialValue = initialValue
      self.type = .toggle
      self.text = text
    }
    
    init(linkType: LinkType) {
      self.type = .link
      self.linkType = linkType
    }

    init(withText text: String, subText: String? = nil, accessoryView: UIView) {
      self.accessoryView = accessoryView
      self.type = .custom
      self.text = text
      self.subText = subText
    }
  }
  typealias sectionContent = (title:String?, cells:[Cell])
  
  //Prototype Cells
  static func content() -> [sectionContent] {
    
    let storage = DeviceData().detailStorage
    let data = String(format: "%.1f",  10*Float(storage.data)/(1000*1000*10))
    let app =  String(format: "%.1f",  10*Float(storage.app)/(1000*1000*10))
    
    return [
      ("allgemein",
       [
        Cell(withText: "Maximale Anzahl der zu speichernden Ausgaben",
             subText: "Speichernutzung\nApp: \(app)MB, Daten: \(data)MB",
             accessoryView: SaveLastCountIssues()),
        Cell(linkType: .cleanMemory),
        Cell(toggleWithText: "Neue Ausgaben automatisch laden",
             initialValue: Settings.autoloadNewIssues,
             changeHandler: { newValue in Settings.autoloadNewIssues = newValue}),
        Cell(toggleWithText: "Automatischer Download auch im Mobilfunknetz",
             initialValue: Settings.autoloadInWLAN,
             changeHandler: { newValue in Settings.autoloadInWLAN = newValue})
        ,
//        Cell(toggleWithText: "Rechtshändermodus",
//             initialValue: true,
//             changeHandler: { _ in }),
//        Cell(toggleWithText: "Teilen in Ressortübersicht ausblenden",
//             initialValue: true,
//             changeHandler: { _ in })
       ]
      ),
      ("darstellung",
       [
        Cell(withText: "Textgröße (Inhalte)", accessoryView: TextSizeSetting()),
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
    
}

/**
 A SettingsVC is a view controller to edit app's user Settings
 */
// MARK: - SettingsVC
open class SettingsVC: UITableViewController, UIStyleChangeDelegate {
  
  @Default("persistedIssuesCount")
  private var persistedIssuesCount: Int
  
  var feederContext: FeederContext?
  
  public lazy var xButton = Button<CircledXView>().tazX()
  
  lazy var content = Settings.content()
  
  lazy var footer:UIView = {
    let background = UIView().set(backgroundColor: Const.Colors.opacityBackground)
    let label = UILabel(App.appInfo)
      .contentFont(size: 12)
      .set(textColor: Const.SetColor.ios(.secondaryLabel).color)
    
    let wrapper = label.wrapper(Const.Insets.Default)
    wrapper.insertSubview(background, at: 0)
    pin(background, toSafe: wrapper, dist: 0, exclude: .bottom)
    pin(background.bottom, to: wrapper.bottom, dist: UIWindow.maxInset)
    return wrapper
  }()
  
  lazy var header = SimpleHeaderView("einstellungen")
  
  func setup(){
    tableView.register(ToggleSettingsCell.self, forCellReuseIdentifier: ToggleSettingsCell.identifier)
    tableView.register(LinkSettingsCell.self, forCellReuseIdentifier: LinkSettingsCell.identifier)
    tableView.register(CustomSettingsCell.self, forCellReuseIdentifier: CustomSettingsCell.identifier)
    tableView.register(CustomSettingsCell.self, forCellReuseIdentifier: CustomSettingsCell.identifier)
    tableView.tableHeaderView = header
    tableView.separatorStyle = .none
    header.layoutIfNeeded()
    registerForStyleUpdates()
  }
  
  func setupXButtonIfNeeded(){
    if xButton.superview != nil { return }
    guard let wrapper =  self.tableView.superview else { return }
    wrapper.addSubview(xButton)
    pin(xButton.right, to: wrapper.right, dist: -Const.ASize.DefaultPadding)
    pin(xButton.top, to: wrapper.top, dist: Const.ASize.DefaultPadding)
    xButton.onPress { [weak self] _ in
      guard let self = self else { return }
      self.navigationController?.dismiss(animated: true)
    }
  }
  
  public func applyStyles() {
    self.tableView.backgroundColor = Const.SetColor.CTBackground.color
    footer.backgroundColor = Const.Colors.opacityBackground
    onMainAfter {   [weak self] in
      self?.tableView.reloadData()
    }
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setupXButtonIfNeeded()
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    applyStyles()
    
    let longTap = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTap(sender:)))
    tableView.addGestureRecognizer(longTap)
  }
  
  open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return content[section].cells.count
  }
  
  open override func numberOfSections(in tableView: UITableView) -> Int {
    return content.count
  }
  
  open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellContent = content[indexPath.section].cells[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: cellContent.type.identifier,
                                             for: indexPath) as? SettingsCell
    cell?.content = cellContent
    return cell ?? UITableViewCell()
  }
  
  open override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let sHead = UIView()
    let label = UILabel()
    label.text = content[section].title
    label.boldContentFont(size: Const.Size.ContentTableFontSize).set(textColor: Const.SetColor.ios(.label).color)
    sHead.addSubview(label)
    pin(label.top, to: sHead.top, dist: 10, priority: .defaultHigh)
    pin(label.bottom, to: sHead.bottom, dist: -10, priority: .defaultHigh)
    pin(label.left, to: sHead.left, dist: Const.ASize.DefaultPadding, priority: .defaultHigh)
    pin(label.right, to: sHead.right, dist: -Const.ASize.DefaultPadding, priority: .defaultHigh)
    sHead.set(backgroundColor: Const.Colors.opacityBackground)
    return sHead
  }
  
  open override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return section == content.count - 1 ? footer : UIView()
  }
  
  open override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
  }

  open override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
    view.backgroundColor = .clear
  }
  
  open override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return section == content.count - 1 ? 40.0 : 10
  }
  
  open override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    print("willSelectRowAt \(indexPath)\(Date().dateAndTime)")
    let cellContent = content[indexPath.section].cells[indexPath.row]
    if cellContent.tapHandler == nil,
       cellContent.type != .link { return nil }
    return indexPath
  }
  
  open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    print("didSelectRowAt \(indexPath)\(Date().dateAndTime)")
    let cellContent = content[indexPath.section].cells[indexPath.row]
    guard let linkType = cellContent.linkType,
          cellContent.type == .link else { return }
    tableView.deselectRow(at: indexPath, animated: true)
    handleLink(linkType: linkType)
  }
  
  @objc private func handleLongTap(sender: UILongPressGestureRecognizer) {
    if sender.state == .began {
      let touchPoint = sender.location(in: tableView)
      guard let indexPath = tableView.indexPathForRow(at: touchPoint) else { return }
      let cellContent = content[indexPath.section].cells[indexPath.row]
      guard let linkType = cellContent.linkType, cellContent.type == .link else { return }
      handleLongTapLink(linkType: linkType)
    }
  }
}

// MARK: - Handler
extension SettingsVC {
  func handleLongTapLink(linkType:Settings.LinkType){
    switch linkType {
      case .cleanMemory:
        cleanMemoryMenu()
      default:
        break;
    }
  }
  
  func handleLink(linkType:Settings.LinkType){
    print("handleLink for: \(linkType)")
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
      case .cleanMemory:
        cleanMemory()
    }
  }
  
  func openFaqAction() -> UIAlertAction {
    return UIAlertAction(title: Localized("open_faq_in_browser"), style: .default) { _ in
      guard let url = URL(string: "https://blogs.taz.de/app-faq/") else { return }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
  
  func cleanMemoryMenu(){
    let alert = UIAlertController.init( title: "Daten Löschen", message: "erweiterte Optionen",
      preferredStyle:  .actionSheet )
    
    alert.addAction( UIAlertAction.init( title: "Hilfe", style: .default,
      handler: { [weak self] handler in
      guard let self = self else { return }
      
      let cntTxt
      = self.persistedIssuesCount > 0
      ? "\(self.persistedIssuesCount)"
      : "alle"
      
      Alert.message(title: Localized("help"), message: Localized(keyWithFormat: "clean_memory_help", cntTxt), additionalActions:[self.openFaqAction()])
    }))
      
    alert.addAction( UIAlertAction.init( title: "Alle Vorschaudaten löschen", style: .default,
      handler: { [weak self] handler in
      self?.cleanMemory(keepPreviewsCount:0)
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Heruntergeladene Ausgaben löschen", style: .default,
      handler: { [weak self] handler in
      self?.cleanMemory()
    } ) )
    
    

    alert.addAction( UIAlertAction.init( title: "Alles löschen", style: .destructive,
      handler: { _ in
        MainNC.singleton.deleteAll()
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.view)
  }
  
  
  func cleanMemory(keepPreviewsCount:Int = 30){
    guard let storedFeeder = MainNC.singleton.feederContext.storedFeeder,
          let storedFeed = storedFeeder.storedFeeds.first,
          persistedIssuesCount > 0 else { return }
    MainNC.singleton.feederContext.cancelAll()
    StoredIssue.removeOldest(feed: storedFeed, keepDownloaded: persistedIssuesCount, keepPreviews: keepPreviewsCount, deleteOrphanFolders: true)
    onMainAfter {   [weak self]  in
      self?.content[0] = Settings.content()[0]
      let ip0 = IndexPath(row: 0, section: 0)
      self?.tableView.reloadRows(at: [ip0], with: .fade)
      MainNC.singleton.feederContext.resume()
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
class ToggleSettingsCell: SettingsCell {
  static let identifier = "toggleSettingsCell"
  
  lazy var toggle: UISwitch = {
    let toggle = UISwitch()
    toggle.onTintColor = Const.SetColor.ios(.link).color
    toggle.addTarget(self, action: #selector(handleToggle(sender:)), for: .valueChanged)
    return toggle
  }()
  
  @objc public func handleToggle(sender: UISwitch) {
    content?.toggleChangeHandler?(sender.isOn)
  }
  
  override func setup(){
    self.accessoryView = toggle
    self.textLabel?.numberOfLines = 0
    self.textLabel?.contentFont().labelColor()
    self.textLabel?.text = content?.text
    self.toggle.isOn = content?.toggleiInitialValue ?? false
  }
}


// MARK: - LinkSettingsCell
class LinkSettingsCell: SettingsCell {
  static let identifier = "linkSettingsCell"
  
  override func setup(){
    super.setup()
    self.textLabel?.text = content?.linkType?.cellDescription
    self.textLabel?.contentFont().linkColor()
    
    if let attributedText = content?.linkType?.attributedDescription {
     self.textLabel?.attributedText = attributedText
   }
  }
}

// MARK: - CustomSettingsCell
class CustomSettingsCell: SettingsCell {
  static let identifier = "customSettingsCell"
  
  override func setup(){
    super.setup()
    self.accessoryView = content?.accessoryView
    
    if let t = content?.text, let s = content?.subText {
      self.textLabel?.attributedText = attributedString(first: t, second: s)
    }
    else {
      self.textLabel?.text = content?.text ?? nil
    }
  }
}


func attributedString(first:String,
                      firstColor: UIColor = Const.SetColor.ios(.label).color,
                      second:String) -> NSAttributedString {
  let aFirst = NSMutableAttributedString(string: first, attributes: [.foregroundColor: firstColor])
  let aSecond = NSMutableAttributedString(string: "\n\(second)", attributes: [.foregroundColor: Const.SetColor.ios(.secondaryLabel).color, .font: Const.Fonts.contentFont(size: Const.Size.SmallerFontSize)])
  aFirst.append(aSecond)
  return aFirst
}


class SettingsCell:UITableViewCell {
  var content:Settings.Cell? { didSet { setup() } }
  
  func setup() {
    applyDefaultStyles()
  }
  
  func applyDefaultStyles(){
    self.textLabel?.numberOfLines = 0
    self.backgroundColor = .clear
    self.backgroundView?.backgroundColor = .clear
    self.contentView.backgroundColor = .clear
  }
  
  
  override func prepareForReuse() {
    accessoryView = nil
    textLabel?.text = nil
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    if var frame = self.textLabel?.frame {
      frame.origin.x = Const.ASize.DefaultPadding
      textLabel?.frame = frame
    }
  }
}

class SaveLastCountIssues: CustomHStack {
  
  @Default("persistedIssuesCount")
  private var persistedIssuesCount: Int {
    didSet {
      label.text
      = persistedIssuesCount > 0
      ? "\(persistedIssuesCount)"
      : "alle"
    }
  }
  
  let leftButton = Button<TextView>()
  let rightButton = Button<TextView>()
  let label = UILabel()
  
  override func setup(){
    super.setup()
    label.text = "\(persistedIssuesCount)"
    leftButton.buttonView.text = "-"
    rightButton.buttonView.text = "+"
    
    leftButton.buttonView.activeColor = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
    rightButton.buttonView.activeColor = Const.SetColor.ios(.link).color.withAlphaComponent(0.5)
    
    leftButton.pinWidth(22)
    rightButton.pinWidth(22)
    leftButton.buttonView.label.baselineAdjustment = .alignCenters
    rightButton.buttonView.label.baselineAdjustment = .alignCenters
    
    leftButton.buttonView.font
    = Const.Fonts.contentFont(size: Const.Size.ContentTableFontSize)//14
    
    rightButton.buttonView.font
    = Const.Fonts.contentFont(size: Const.Size.ContentTableFontSize)//14

    label.textAlignment = .center
    self.addArrangedSubview(leftButton)
    self.addArrangedSubview(label)
    self.addArrangedSubview(rightButton)
    
    leftButton.onPress { [weak self] _ in
      guard let self = self, self.persistedIssuesCount > 0 else { return }
      self.persistedIssuesCount -= 1
    }
    
    rightButton.onPress { [weak self] _ in
      self?.persistedIssuesCount += 1
    }
    
    label.onTapping { [weak self] _ in
      self?.persistedIssuesCount = 20
    }
  }
}

class TextSizeSetting: SaveLastCountIssues {
  
  @Default("articleTextSize")
  private var articleTextSize: Int
  
  override func setup(){
    super.setup()
    label.text = "\(articleTextSize)%"
    leftButton.buttonView.text = "a"
    rightButton.buttonView.text = "a"
    leftButton.buttonView.font
    = Const.Fonts.contentFont(size: Const.Size.SmallerFontSize)//14
    rightButton.buttonView.font
    = Const.Fonts.contentFont(size: Const.Size.ContentTableRowHeight)//30
    
    leftButton.onPress { [weak self] _ in
      self?.label.text = "\(Defaults.articleTextSize.decrease())%"
    }
    
    rightButton.onPress { [weak self] _ in
      self?.label.text = "\(Defaults.articleTextSize.increase())%"
    }
    
    label.onTapping { [weak self] _ in
      self?.label.text = "\(Defaults.articleTextSize.set())%"
    }
  }
}

class CustomHStack: UIStackView {
  init(){
    super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
    self.axis = .horizontal
    self.distribution = .fill
    self.spacing = 2
    setup()
  }
  
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setup(){}
}

// MARK: - ext. App
extension App {
  static var appInfo:String {
    let appTitle = App.isAlpha ? "Alpha" : App.isBeta ? "Beta" : "taz"
    return "\(appTitle) (v) \(App.version)-\(App.buildNumber)"
  }
  
  static func authInfo(with feederContext: FeederContext) -> String {
    let authInfo = feederContext.isAuthenticated ? "angemeldet" : "NICHT ANGEMELDET"
    return "\(authInfo), taz-ID: \(DefaultAuthenticator.getUserData().id ?? "-")"
  }
}

// MARK: - SimpleHeaderView
class SimpleHeaderView: UIView,  UIStyleChangeDelegate{
  
  private let titleLabel = Label().titleFont()
  private let line = DottedLineView()
  
  private func setup() {
    registerForStyleUpdates()
    applyStyles()
    
    self.addSubview(titleLabel)
    self.addSubview(line)
    
    pin(titleLabel.top, to: self.topGuide(), dist: 15)
    
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

class XUITableViewHeaderFooterView: UITableViewHeaderFooterView{}
