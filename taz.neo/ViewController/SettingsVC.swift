//
//  SettingsVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 21.09.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//
import UIKit
import NorthLib

typealias AttributedRawData = (String, String, String)

extension Settings.LinkType {
  var cellDescription:String {
    switch self {
      case .onboarding: return "Erste Schritte";
      case .errorReport: return "Fehler melden";
      case .manageAccount: return userInfo;
      case .terms: return "Allgemeine Geschäftsbedingungen (AGB)";
      case .privacy: return "Datenschutzerklärung";
      case .revocation: return "Widerruf";
      case .faq: return "FAQ (in Safari öffnen)";
      case .cleanMemory: return "Alte Ausgaben löschen";
    }
  }
  
  var attributedRawData:AttributedRawData? {
    guard self == .cleanMemory else { return nil}
    
    let storage = DeviceData().detailStorage
    let data = String(format: "%.1f",  10*Float(storage.data)/(1000*1000*10))
    let app =  String(format: "%.1f",  10*Float(storage.app)/(1000*1000*10))
    
    let txt = "App: \(app)MB, Daten: \(data)MB\nGedrückt halten für weitere Optionen"
    return ("Speichernutzung", "jetzt bereinigen", txt)
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
  
  @Default("isTextNotification")
  static var isTextNotification: Bool
    
  enum CellType { case link, toggle, custom }
  enum LinkType { case onboarding, faq, errorReport, manageAccount, terms, privacy, revocation, cleanMemory }
  
  struct Cell {
    var linkType:LinkType?
    let type:CellType
    var accessoryView:UIView?
    var customView:UIView?
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
    
    init(customView: UIView) {
      self.customView = customView
      self.type = .custom
    }
  }
  typealias sectionContent = (title:String?, collapseable:Bool, collapsed:Bool,  cells:[Cell])
  
  //Prototype Cells
  static func content() -> [sectionContent] {
    return [
      ("speicher", false, false,
       [
        Cell(customView: SaveLastCountIssues()),
        Cell(linkType: .cleanMemory),
       ]),/*
       ("ausgaben laden", false, false,
        [
         Cell(toggleWithText: "Neue Ausgaben automatisch laden",
              initialValue: Settings.autoloadNewIssues,
              changeHandler: { newValue in Settings.autoloadNewIssues = newValue}),
         Cell(toggleWithText: "Automatischer Download auch im Mobilfunknetz",
              initialValue: Settings.autoloadInWLAN,
              changeHandler: { newValue in Settings.autoloadInWLAN = newValue})
         ,
        ]
      ),*/
      ("darstellung", false,false,
       [
        Cell(withText: "Textgröße (Inhalte)", accessoryView: TextSizeSetting()),
        Cell(toggleWithText: "Nachtmodus",
             initialValue: Defaults.darkMode,
             changeHandler: { newValue in
               Defaults.darkMode = newValue
             })
       ]
      ),
      ("support", false,false,
       [
        Cell(linkType: .onboarding),
        Cell(linkType: .faq),
        Cell(linkType: .errorReport)
       ]
      ),
      ("abo", false,false,
       [
        Cell(linkType: .manageAccount),
        Cell(linkType: .terms),
        Cell(linkType: .privacy),
        Cell(linkType: .revocation)
       ]
      ),
      ("erweitert", true,true,
       [
        Cell(toggleWithText: "Mitteilungen erlauben",
             initialValue: Settings.isTextNotification,
             changeHandler: Settings.textNotificationsChanged(newValue:)),
        //        Cell(toggleWithText: "Rechtshändermodus",
        //             initialValue: true,
        //             changeHandler: { _ in }),
        //        Cell(toggleWithText: "Teilen in Ressortübersicht ausblenden",
        //             initialValue: true,
        //             changeHandler: { _ in })
       ]
      )
    ]
  }
  
  static func textNotificationsChanged(newValue:Bool){
    isTextNotification = newValue
    if newValue == false { return }
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { (settings) in
      if settings.soundSetting == .disabled
      && settings.alertSetting == .disabled
      && settings.badgeSetting == .disabled {
        Alert.confirm(message: "Bitte erlauben Sie Benachrichtigungen!") { _ in
          if let url = URL.init(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
          }
        }
      }
    }
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
  
  class Footer:UIView, UIStyleChangeDelegate{
    
    let label = UILabel()
    let background = UIView()

    
    func applyStyles() {
      background.backgroundColor = Const.Colors.opacityBackground
      label.textColor = Const.SetColor.ios(.secondaryLabel).color
    }
    
    func setup(){
      self.addSubview(background)
      self.addSubview(label)
      label.text = App.appInfo
      label.contentFont(size: 12)
      applyStyles()
      pin(label.left, to: self.left, dist: Const.Size.DefaultPadding)
      pin(label.right, to: self.right, dist: Const.Size.DefaultPadding)
      pin(label.top, to: self.top)
      pin(label.bottom, to: self.bottom)
      pin(background, toSafe: self, dist: 0, exclude: .bottom)
      pin(background.bottom, to: self.bottom, dist: UIWindow.maxInset)
      registerForStyleUpdates()
    }
    
    init() {
      super.init(frame: .zero)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }
  
  lazy var footer:Footer = Footer()
  
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
    xButton.tazX(true)
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setupXButtonIfNeeded()
  }
  
  open override func viewDidLoad() {
    self.tableView = UITableView(frame: .zero, style: .grouped)
    super.viewDidLoad()
    setup()
    applyStyles()
    registerForStyleUpdates()
    let longTap = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTap(sender:)))
    tableView.addGestureRecognizer(longTap)
  }
  
  open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let content = content[section]
    if content.collapseable && content.collapsed { return 0 }
    return content.cells.count
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
    let header = SectionHeader(text:content[section].title ?? "")
    header.onTapping { [weak self] _ in
      guard let self = self else { return }
      let content = self.content[section]
      guard content.collapseable else { return }
      self.content[section].collapsed = !content.collapsed
      self.tableView.reloadSections(IndexSet(integer: section), with: .fade)
    }
    return header
  }
  
  open override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return section == content.count - 1 ? footer : UIView()
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
      case .faq:
        openFaq()
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
    return UIAlertAction(title: Localized("open_faq_in_browser"), style: .default) { [weak self] _ in
      self?.openFaq()
    }
  }
  
  func openFaq(){
    guard let url = URL(string: "https://blogs.taz.de/app-faq/") else { return }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
  }
  
  func cleanMemoryMenu(){
    let alert = UIAlertController.init( title: "Daten Löschen", message: "erweiterte Optionen",
      preferredStyle:  .actionSheet )
  
    
    alert.addAction( UIAlertAction.init( title: "Hilfe", style: .default,
      handler: { [weak self] handler in
      self?.showHelp()
    }))
      
    alert.addAction( UIAlertAction.init( title: "Alle Vorschaudaten löschen", style: .destructive,
      handler: { [weak self] handler in
      self?.cleanMemory(keepPreviewsCount:0)
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Heruntergeladene Ausgaben löschen", style: .destructive,
      handler: { [weak self] handler in
      self?.cleanMemory()
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Datenbank löschen", style: .destructive,
      handler: { _ in
      MainNC.singleton.popToRootViewController(animated: false)
      MainNC.singleton.feederContext.cancelAll()
      ArticleDB.singleton.reset { [weak self] err in
        self?.log("delete database done")
        exit(0)//Restart, resume currently not possible
        //#warning("ToDo: 0.9.4 enable resume of feederCOntext / Re-Init here")
        //onMainAfter { [weak self]  in
        //  self?.content[0] = Settings.content()[0]
        //  let ip0 = IndexPath(row: 1, section: 0)
        //  self?.tableView.reloadRows(at: [ip0], with: .fade)
        //  MainNC.singleton.feederContext.resume()
        //  MainNC.singleton.showIssueVC()
        //}
      }
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
      let ip0 = IndexPath(row: 1, section: 0)
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
  
  func showHelp(){
    ///Help html content is bundled due it may depends on current app version
    guard let url = Bundle.main.url(forResource: "SettingsHelp",
                                 withExtension: "html",
                                 subdirectory: "BundledResources")
    else { return }
    ///Do not write file to App Bundle - its read only result in "unexpectedError &  Crash"
//    ///Apply dark/bright mode
//    let f = File(url)
//    var content = f.string
//
//    if Defaults.darkMode {
//      content = content.replacingOccurrences(
//        of: "<link rel=\"stylesheet\" type=\"text/css\" href=\"../files/themeNormal.css\">",
//        with: "<link rel=\"stylesheet\" type=\"text/css\" href=\"../files/themeNight.css\">")
//    }
//    else {
//      content = content.replacingOccurrences(
//        of: "<link rel=\"stylesheet\" type=\"text/css\" href=\"../files/themeNight.css\">",
//        with: "<link rel=\"stylesheet\" type=\"text/css\" href=\"../files/themeNormal.css\">")
//    }
//
//    f.string = content

    let webviewVC = IntroVC()
   
    webviewVC.webView.webView.load(url: url)
    webviewVC.webView.webView.scrollView.contentInsetAdjustmentBehavior = .never
    webviewVC.webView.webView.scrollView.isScrollEnabled = true
    
    webviewVC.webView.xButton.tazX()
    
    webviewVC.webView.onX { _ in
      webviewVC.dismiss(animated: true, completion: nil)
    }
    self.modalPresentationStyle = .fullScreen
    webviewVC.modalPresentationStyle = .fullScreen
    webviewVC.webView.webView.atEndOfContent {_ in }
    self.present(webviewVC, animated: true) {
      //Overwrite Default in: IntroVC viewDidLoad
      webviewVC.webView.buttonLabel.text = nil
    }
    webviewVC.webView.webView.whenLinkPressed { arg in
      guard let to = arg.to else { return }
      if UIApplication.shared.canOpenURL(to) {
        UIApplication.shared.open(to, options: [:], completionHandler: nil)
      }
    }
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

class SectionHeader: UIView, UIStyleChangeDelegate {
  
  let label = UILabel()
  
  func applyStyles() {
    label.textColor =  Const.SetColor.ios(.label).color
    self.backgroundColor = Const.SetColor.CTBackground.color.withAlphaComponent(0.9)
  }
  
  func setup(){
    self.addSubview(label)
    pin(label.top, to: self.top, dist: 10, priority: .defaultHigh)
    pin(label.bottom, to: self.bottom, dist: -10, priority: .defaultHigh)
    pin(label.left, to: self.left, dist: Const.ASize.DefaultPadding, priority: .defaultHigh)
    pin(label.right, to: self.right, dist: -Const.ASize.DefaultPadding, priority: .defaultHigh)
    label.boldContentFont(size: Const.Size.ContentTableFontSize)
    registerForStyleUpdates()
    applyStyles()
  }
  
  init(text:String){
    super.init(frame: .zero)
    label.text = text
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - ToggleSettingsCell
class ToggleSettingsCell: SettingsCell {
  static let identifier = "toggleSettingsCell"
  
  lazy var toggle: UISwitch = {
    let toggle = UISwitch()
    toggle.addTarget(self, action: #selector(handleToggle(sender:)), for: .valueChanged)
    return toggle
  }()
  
  @objc public func handleToggle(sender: UISwitch) {
    content?.toggleChangeHandler?(sender.isOn)
  }
  
  override func setup(){
    super.setup()
    self.accessoryView = toggle
    self.textLabel?.numberOfLines = 0
    self.textLabel?.contentFont().labelColor()
    self.textLabel?.text = content?.text
    self.toggle.isOn = content?.toggleiInitialValue ?? false
    self.backgroundColor = .clear
  }
  
  override func applyStyles() {
    self.textLabel?.labelColor()
  }
}

class LinkSettingsCell: SettingsCell {
  static let identifier = "linkSettingsCell"
  var attributedRawData:AttributedRawData?
  
  override func setup(){
    super.setup()
    self.textLabel?.text = content?.linkType?.cellDescription
    self.textLabel?.contentFont()
    attributedRawData = content?.linkType?.attributedRawData
    applyStyles()
  }

  override func applyStyles() {

    if let data = attributedRawData {
      self.textLabel?.attributedText =  attributedString(firstLeft: data.0,
                                                         firstRight: data.1,
                                                         second: data.2)
    }
    else {
      self.textLabel?.linkColor()
    }
  }
}

// MARK: - CustomSettingsCell
class CustomSettingsCell: SettingsCell {
  static let identifier = "customSettingsCell"
  
  override func setup(){
    super.setup()
    ///either custom view or labels with optional accessory view
    if let customView = content?.customView {
      self.contentView.addSubview(customView)
      pin(customView, to: contentView, dist: Const.Size.DefaultPadding)
      return
    }
    self.accessoryView = content?.accessoryView
    

    
  }
  
  override func applyStyles() {
    if content?.customView != nil { return }
    self.accessoryView = content?.accessoryView
    
    if let t = content?.text, let s = content?.subText {
      self.textLabel?.attributedText = attributedString(first: t, second: s)
    }
    else {
      self.textLabel?.text = content?.text ?? nil
      self.textLabel?.labelColor()
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

func attributedString(firstLeft:String,
                      firstRight:String,
                      second:String) -> NSAttributedString {
  let pStyle = NSMutableParagraphStyle()
  pStyle.tabStops = [NSTextTab(textAlignment: .left, location: 0.0, options: [:]),
                     NSTextTab(textAlignment: .right, location: UIScreen.main.bounds.size.width - 2*Const.Size.DefaultPadding - 10, options: [:])]

  let aFirst = NSMutableAttributedString(string: firstLeft, attributes: [.foregroundColor: Const.SetColor.ios(.label).color])
  aFirst.append(NSAttributedString(string: "\t"))
  let right = NSAttributedString(string: firstRight, attributes: [.foregroundColor: Const.SetColor.ios(.link).color])
  aFirst.append(right)
  
  aFirst.addAttribute(.paragraphStyle, value: pStyle, range: NSRange(location: 0, length: aFirst.length-1))
  
  let aSecond = NSAttributedString(string: "\n\(second)", attributes: [.foregroundColor: Const.SetColor.ios(.secondaryLabel).color, .font: Const.Fonts.contentFont(size: Const.Size.SmallerFontSize)])
  aFirst.append(aSecond)
  return aFirst
}


class SettingsCell:UITableViewCell, UIStyleChangeDelegate {
  var content:Settings.Cell? { didSet { setup() } }
  
  func setup() {
    applyDefaultStyles()
    registerForStyleUpdates()
    applyStyles()
  }
  
  func applyStyles() { }///Overwrite in inherited classes
  
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
    super.init(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: reuseIdentifier)
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

class SaveLastCountIssues: UIView, UIStyleChangeDelegate {
  
  @Default("persistedIssuesCount")
  private var persistedIssuesCount: Int {
    didSet { updatePersistedIssuesCount() }
  }
  
  let mainLabel = UILabel()
  let detailLabel = UILabel()
  
  let accessoryView = TextSizeSetting() //Stepper/Controlls
  
  func updatePersistedIssuesCount(){
    accessoryView.label.text
    = persistedIssuesCount > 0
    ? "\(persistedIssuesCount)"
    : "alle"
  }
  
  func applyStyles() {
    mainLabel.set(textColor: Const.SetColor.ios(.label).color)
    detailLabel.set(textColor: Const.SetColor.ios(.secondaryLabel).color)
  }
    
  func setup(){
    registerForStyleUpdates()
    ///Labels
    mainLabel.text = "Maximale Anzahl der zu speichernden Ausgaben"
    detailLabel.text = "Alte Ausgaben und Vorschaudaten werden automatisch gelöscht."
    mainLabel.contentFont().set(textColor: Const.SetColor.ios(.label).color)
    detailLabel.contentFont(size: Const.Size.SmallerFontSize)
      .set(textColor: Const.SetColor.ios(.secondaryLabel).color)
    mainLabel.numberOfLines = 0
    detailLabel.numberOfLines = 0
    
    ///Stepper left
    accessoryView.label.text = "\(persistedIssuesCount)"
    accessoryView.leftButton.buttonView.text = "-"
    accessoryView.rightButton.buttonView.text = "+"
    
    accessoryView.leftButton.buttonView.font = Const.Fonts.contentFont(size: 16)
    accessoryView.rightButton.buttonView.font = Const.Fonts.contentFont(size: 16)
    
    accessoryView.leftButton.buttonView.label.textInsets = UIEdgeInsets(top: -1.65, left:0.2 , bottom: 1.65, right: -0.2)
    accessoryView.rightButton.buttonView.label.textInsets = UIEdgeInsets(top: -1.2, left:0.2 , bottom: 1.2, right: -0.2)
    
    accessoryView.leftButton.onPress { [weak self] _ in
      guard let self = self, self.persistedIssuesCount > 0 else { return }
      /// 3 is minumum
      if self.persistedIssuesCount == 3 { self.persistedIssuesCount = 0}
      else { self.persistedIssuesCount -= 1 }
    }
    
    accessoryView.rightButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.persistedIssuesCount < 3 { self.persistedIssuesCount = 3}
      else {self.persistedIssuesCount += 1}
    }
    
    accessoryView.label.onTapping { [weak self] _ in
      self?.persistedIssuesCount = 20
    }
    
    accessoryView.pinWidth(110)
    updatePersistedIssuesCount()
    
    ///Layout
    self.addSubview(accessoryView)
    self.addSubview(mainLabel)
    self.addSubview(detailLabel)
    
    pin(accessoryView.top, to: self.top, dist: -2.5)
    pin(accessoryView.right, to: self.right)
    
    pin(mainLabel.top, to: self.top)
    pin(mainLabel.left, to: self.left)
    pin(mainLabel.right, to: accessoryView.left, dist: -Const.Size.SmallPadding)
    
    pin(detailLabel.left, to: self.left)
    pin(detailLabel.right, to: self.right)
    pin(detailLabel.top, to: mainLabel.bottom)
    pin(detailLabel.bottom, to: self.bottom)
  }
  
  init(){
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class TextSizeSetting: CustomHStack, UIStyleChangeDelegate {
  
  let leftButton = Button<TextView>()
  let rightButton = Button<TextView>()
  let label = UILabel()
  
  @Default("articleTextSize")
  private var articleTextSize: Int
  
  func applyStyles() {
    label.labelColor()
    leftButton.tazButton(true)
    rightButton.tazButton(true)
  }
  
  override func setup(){
    super.setup()
    label.contentFont()
    registerForStyleUpdates()
    label.text = "\(articleTextSize)%"

    leftButton.tazButton()
    rightButton.tazButton()

    leftButton.buttonView.text = "a"
    rightButton.buttonView.text = "a"
    
    leftButton.buttonView.label.baselineAdjustment = .alignCenters
    rightButton.buttonView.label.baselineAdjustment = .alignCenters
    
    leftButton.buttonView.label.textInsets = UIEdgeInsets(top: -1.65, left:0.2 , bottom: 1.65, right: -0.2)
    rightButton.buttonView.label.textInsets = UIEdgeInsets(top: -2.5, left:0.2 , bottom: 2.5, right: -0.2)
    // Default is: 16
    leftButton.buttonView.font
    = Const.Fonts.contentFont(size: 12)//-4
    rightButton.buttonView.font
    = Const.Fonts.contentFont(size: 20)//+4
    
    leftButton.onPress { [weak self] _ in
      self?.label.text = "\(Defaults.articleTextSize.decrease())%"
    }
    
    rightButton.onPress { [weak self] _ in
      self?.label.text = "\(Defaults.articleTextSize.increase())%"
    }
    
    label.onTapping { [weak self] _ in
      self?.label.text = "\(Defaults.articleTextSize.set())%"
    }
    label.textAlignment = .center
    self.addArrangedSubview(leftButton)
    self.addArrangedSubview(label.wrapper(UIEdgeInsets(top: -0.5, left: 0, bottom: -0.5, right: 0)))
    self.addArrangedSubview(rightButton)
  }
}

class CustomHStack: UIStackView {
  init(){
    super.init(frame: CGRect(x: 0, y: 0, width: 110, height: 30))
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
    line.layoutSubviews()
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

class FooterView: UITableViewHeaderFooterView{}
