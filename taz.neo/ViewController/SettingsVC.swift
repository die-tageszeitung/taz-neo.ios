//
//  SettingsVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 21.09.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//
import UIKit
import NorthLib

/**
 A SettingsVC is a view controller to edit app's user Settings
 Cells are not re-used!
 */
// MARK: - SettingsVC
open class SettingsVC: UITableViewController, UIStyleChangeDelegate, ModalCloseable {
  
  @Default("persistedIssuesCount")
  var persistedIssuesCount: Int
  
  @Default("autoloadOnlyInWLAN")
  var autoloadOnlyInWLAN: Bool
  
  @Default("autoloadPdf")
  var autoloadPdf: Bool
  
  @Default("autoloadNewIssues")
  var autoloadNewIssues: Bool
  
  @Default("isTextNotification")
  var isTextNotification: Bool
  
  lazy var data = prototypeTableData
  
  /// UI Components
  lazy var footer:Footer = Footer()
  
  lazy var header = SimpleHeaderView("einstellungen")
  ///Close X Button
  public lazy var xButton = Button<CircledXView>().tazX()
  
  let blockingView = BlockingProcessView()
  
  var uiBlocked:Bool = false {
    didSet{
      if uiBlocked {
        self.view.addSubview(blockingView)
        pin(blockingView, to:self.view)
      }
      blockingView.isHidden = !uiBlocked
      blockingView.enabled = uiBlocked
    }
  }
  
  // MARK: - Lifecycle
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    guard let wrapper =  self.tableView.superview else { return }
    setupXButtonIfNeeded(targetView:wrapper)
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
  
  open override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard self.presentedViewController == nil else { return }
    // free cells / prevent memory leaks
    // dismiss, willMove, didMove not called if presented modally
    data = TableData(sections:[])
    self.tableView.reloadData()
  }
}

// MARK: - Helper
extension SettingsVC {
  func setup(){
    tableView.tableHeaderView = header
    tableView.separatorStyle = .none
    header.layoutIfNeeded()
    registerForStyleUpdates()
  }
  
  public func applyStyles() {
    self.tableView.backgroundColor = Const.SetColor.CTBackground.color
    xButton.tazX(true)
  }
  
  @objc private func handleLongTap(sender: UILongPressGestureRecognizer) {
    if sender.state == .began {
      let touchPoint = sender.location(in: tableView)
      guard let indexPath = tableView.indexPathForRow(at: touchPoint) else { return }
      data.cell(at: indexPath)?.longTapHandler?()
    }
  }
}

// MARK: - UITableViewDataSource
extension SettingsVC {
  open override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return data.rowsIn(section: section)
  }
  
  open override func numberOfSections(in tableView: UITableView) -> Int {
    return data.sectionsCount
  }
  
  open override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return data.cell(at: indexPath) ?? UITableViewCell()
  }
  
  open override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let sectionData = data.sectionData(for: section),
          let title = sectionData.title else { return nil }
    let header = SectionHeader(text:title)
    header.onTapping { _ in
      guard sectionData.collapseable else { return }
      self.data.toggleSectionCollapse(for: section)
      self.tableView.reloadSections(IndexSet(integer: section), with: .fade)
    }
    return header
  }
  
  open override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return data.footer(for: section)
  }
  
  open override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
    view.backgroundColor = .clear
  }
  
  open override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return data.footerHeight(for: section)
  }
  
  open override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    return data.canTap(at: indexPath) ? indexPath : nil
  }
  
  open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    data.cell(at: indexPath)?.tapHandler?()
  }
}

// MARK: - Nested Classes: Footer
extension SettingsVC {
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
}


// MARK: - Nested Classes: LinkType
extension SettingsVC {
  enum CellLinkTarget { case onboarding, faq, errorReport, manageAccount, terms, privacy, revocation, cleanMemory }
}

extension SettingsVC {
  
  func refreshAndReload() {
    data = prototypeTableData
    self.tableView.reloadData()
  }
  
  var prototypeTableData: TableData { get {TableData(sections: self.prototypeCells())} }
  
  struct TableData{
    private var sections:[tSectionContent]
    init(sections: [tSectionContent]) {
      self.sections = sections
    }
  }
}

extension SettingsVC.TableData{
  
  var sectionsCount: Int { return self.sections.count }
  
  func rowsIn(section: Int) -> Int{
    guard let sectionContent = sectionData(for: section),
          !sectionContent.collapsed else { return 0 }
    return sectionContent.cells.count
  }
  
  func canTap(at indexPath: IndexPath) -> Bool{
    return cell(at: indexPath)?.tapHandler != nil
  }
  
  func cell(at indexPath: IndexPath) -> XSettingsCell? {
    return self.sections.valueAt(indexPath.section)?.cells.valueAt(indexPath.row)
  }
  
  func sectionData(for section: Int) -> SettingsVC.tSectionContent?{
    return self.sections.valueAt(section)
  }
  
  mutating func toggleSectionCollapse(for section: Int){
    guard var sectionContent = sectionData(for: section) else { return }
    sectionContent.collapsed = !sectionContent.collapsed
    self.sections[section] = sectionContent
    
  }
  
  func footer(for section: Int) -> UIView?{
    return nil
  }
  
  func footerHeight(for section: Int) -> CGFloat{
    return 0
  }
}

// MARK: - Arraydata
extension SettingsVC {
  
}



// MARK: - Nested Classes: CellData
extension SettingsVC {
  typealias tSectionContent = (title:String?, collapseable:Bool, collapsed:Bool,  cells:[XSettingsCell])
}

extension SettingsVC {
  //Prototype Cells
  var accountCells:[XSettingsCell] {
    var cells =
    [
      authCell(),
      XSettingsCell(text: "Passwort zurücksetzen", tapHandler: resetPassword),
      XSettingsCell(text: "Konto online verwalten", tapHandler: manageAccountOnline)
    ]
    if isAuthenticated {
      cells.append(XSettingsCell(text: "Konto löschen", color: .red, tapHandler: requestAccountDeletion))
    }
    return cells
  }
    
  func prototypeCells() -> [tSectionContent] {
    return [
      ("konto", false,false, accountCells ),
      ("ausgabenverwaltung", false, false,
       [
        XSettingsCell(text: "Maximale Anzahl der zu speichernden Ausgaben",
                      accessoryView: SaveLastCountIssuesSettings()),
        XSettingsCell(toggleWithText: "Neue Ausgaben automatisch laden",
                      initialValue: autoloadNewIssues,
                      onChange: {[weak self] newValue in self?.autoloadNewIssues = newValue }),
        XSettingsCell(toggleWithText: "Nur im WLAN herunterladen",
                      initialValue: autoloadOnlyInWLAN,
                      onChange: {[weak self] newValue in self?.autoloadOnlyInWLAN = newValue }),
        XSettingsCell(toggleWithText: "E-Paper automatisch herunterladen",
                      initialValue: autoloadPdf,
                      onChange: {[weak self] newValue in self?.autoloadPdf = newValue }),
        XSettingsCell(text: "Alle Ausgaben löschen", color: .red, tapHandler: requestDeleteAllIssues),
       ]
      ),
      ("darstellung", false,false,
       [
        XSettingsCell(text: "Textgröße (Inhalte)", accessoryView: TextSizeSetting()),
        XSettingsCell(toggleWithText: "Nachtmodus",
                      initialValue: Defaults.darkMode,
                      onChange: { newValue in Defaults.darkMode = newValue })
       ]
      ),
      ("hilfe", false,false,
       [
        XSettingsCell(text: "Erste Schritte", tapHandler: showOnboarding),
        XSettingsCell(text: "FAQ (im Browser öffnen)", tapHandler: openFaq),
        XSettingsCell(text: "Fehler melden")
        {MainNC.singleton.showFeedbackErrorReport(.error)},
        XSettingsCell(text: "Feedback geben")
        {MainNC.singleton.showFeedbackErrorReport(.feedback)},
       ]
      ),
      ("rechtliches", false,false,
       [
        XSettingsCell(text: "Allgemeine Geschäftsbedingungen (AGB)", tapHandler: showOnboarding),
        XSettingsCell(text: "Datenschutzerklärung", tapHandler: showPrivacy),
        XSettingsCell(text: "Widerruf", tapHandler: showRevocation),
       ]
      ),
      ("erweitert", true,true,
       [
        XSettingsCell(toggleWithText: "Mitteilungen erlauben",
                      initialValue: isTextNotification,
                      onChange: textNotificationsChanged(newValue:)),
        XSettingsCell(text: "Speichernutzung", detailText: storageDetails),
        XSettingsCell(text: "Datenbank löschen", color: .red, tapHandler: requestDatabaseDelete),
        XSettingsCell(text: "App zurücksetzen", color: .red, tapHandler: requestResetApp)
       ]
      )
    ]
  }
  
  var storageDetails: String {
    let storage = DeviceData().detailStorage
    let data = String(format: "%.1f",  10*Float(storage.data)/(1000*1000*10))
    let app =  String(format: "%.1f",  10*Float(storage.app)/(1000*1000*10))
    return "App: \(app) MB, Daten: \(data) MB"
  }
}

// MARK: - Cell Creation Factory
extension SettingsVC {
  
  var isAuthenticated: Bool { return MainNC.singleton.feederContext.isAuthenticated }
  
  //Factory not needed here!
  func authCell() -> XSettingsCell {
    
    if isAuthenticated {
      let id = SimpleAuthenticator.getUserData().id
      return XSettingsCell(text: "Abmelden (\(id ?? "???"))") { [weak self] in
        self?.requestLogout()
      }
    }
    else {
      guard let feeder = MainNC.singleton.feederContext.gqlFeeder else { return XSettingsCell(text: "..."){} }
      let authenticator = DefaultAuthenticator(feeder: feeder)
      Notification.receiveOnce("authenticationSucceeded") { [weak self]_ in
        self?.refreshAndReload()
        Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
      }
      return XSettingsCell(text: "Anmelden") { [weak self] in
        authenticator.authenticate(with: self)
      }
    }
  }
  
  func requestLogout(){
    let alert = UIAlertController.init( title: "Abmelden?",
                                        message: "Heruntergeladene Ausgaben können weiterhin gelesen werden.",
                                        preferredStyle:  .alert )
    alert.addAction( UIAlertAction.init( title: "Ja, abmelden", style: .destructive,
                                         handler: { [weak self] _ in
      MainNC.singleton.deleteUserData()
      self?.refreshAndReload()
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.view)
  }
  
  func requestAccountDeletion(){
    let alert = UIAlertController.init( title: "Konto löschen", message: "Hiermit können Sie die Löschung Ihres Kontos und die Beendigung Ihres Abonements anfordern.\nWir senden Ihnen eine E-Mail mit einem Bestätigungslink. Falls ein laufendes Abonement mit Ihrem Konto verknüpft ist, wird ihr Konto zur Löschung nach Ablauf des Abo's vorgemerkt. Details entnehmen Sie bitte der E-Mail.",
                                        preferredStyle:  .alert )
    
    alert.addAction( UIAlertAction.init( title: "Löschen anfordern", style: .destructive,
                                         handler: { [weak self] _ in
      guard let feeder = MainNC.singleton.feederContext.gqlFeeder else {
        Toast.show(Localized("something_went_wrong_try_later"), .alert)
        return
      }
      self?.uiBlocked = true
      feeder.requestAccountDeletion { [weak self] (result) in
        self?.uiBlocked = false
        switch result{
          case .success(let msg):
            self?.log("Request account deletion success: \(msg)")
            self?.showRequestAccountDeletionSuccessAlert()
          case .failure(let err):
            self?.log("Request account deletion failure: \(err)")
            Toast.show(Localized("something_went_wrong_try_later"), .alert)
        }
      }
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.view)
  }
  
  func showRequestAccountDeletionSuccessAlert(){
    let alert = UIAlertController.init( title: "Hinweis", message: "Ihre Anfrage wird bearbeitet. Sie erhalten in den nächsten Minuten eine E-Mail mit Hinweisen zum weiteren Vorgehen und dem Bestätigungslink.\nBeachten Sie bitte, dass ihr Konto erst gelöscht werden kann, wenn Sie den Bestätigungslink in der E-Mail klicken. Der Bestätigungslink ist 24h gültig.\nFalls Sie Ihr Konto nicht löschen möchten, ignorieren Sie einfach die E-Mail.",
                                        preferredStyle:  .alert )
    alert.addAction( UIAlertAction.init( title: "OK", style: .default) { _ in } )
    alert.presentAt(self.view)
  }

  func requestDeleteAllIssues(){
    let alert = UIAlertController.init( title: "Alle Ausgaben löschen", message: nil,
                                        preferredStyle:  .alert )
    alert.addAction( UIAlertAction.init( title: "Löschen", style: .destructive,
                                         handler:  { [weak self] _ in
      guard let storedFeeder = MainNC.singleton.feederContext.storedFeeder,
            let storedFeed = storedFeeder.storedFeeds.first else {
              return
      }
      MainNC.singleton.feederContext.cancelAll()
      StoredIssue.removeOldest(feed: storedFeed, keepDownloaded: 0, deleteOrphanFolders: true)
      onMainAfter { [weak self] in
        self?.refreshAndReload()
        MainNC.singleton.feederContext.resume()
        Notification.send("reloadIssues")
      }
    } ) )
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.view)
  }
  
  func requestDatabaseDelete(){
    let alert = UIAlertController.init( title: "Datenbank zurücksetzen", message: "Benutzen Sie diese Funktion, falls die App wiederholt bei einer bestimmten Aktion (z.B. Ausgabe öffnen) beendet wird.\nDie App wird nach dem Zurücksetzen der Datenbank beendet und kann von Ihnen neu gestartet werden.\nBitte nutzen Sie im Fehlerfall bitte auch unsere \"Fehler melden\" Funktion!",
                                        preferredStyle:  .actionSheet )
    
    alert.addAction( UIAlertAction.init( title: "Datenbank zurücksetzen", style: .destructive,
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
    
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.view)
  }
  
  func requestResetApp(){
    let alert = UIAlertController.init( title: "App zurücksetzen", message: "Löscht alle Daten und Einstellungen der App.\nDie App wird nach dem Zurücksetzen beendet und kann von Ihnen neu gestartet werden. Sie müssen sich im Anschluss neu anmelden.",
                                        preferredStyle:  .actionSheet )
    
    
    alert.addAction( UIAlertAction.init( title: "App zurücksetzen", style: .destructive,
                                         handler: { _ in
      MainNC.singleton.deleteUserData()
      MainNC.singleton.deleteAll()
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.view)
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
  
  func resetPassword(){
    self.modalPresentationStyle = .fullScreen
    let id = SimpleAuthenticator.getUserData().id
    guard let feeder = MainNC.singleton.feederContext.gqlFeeder else { return }
    let childVc = PwForgottController(id: id, auth: DefaultAuthenticator.init(feeder: feeder))
    childVc.modalPresentationStyle = .fullScreen
    self.present(childVc, animated: true)
  }
  
  func manageAccountOnline(){
    guard let url = URL(string: "https://portal.taz.de/") else { return }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
  }
  
  func showOnboarding(){
    guard let feeder = MainNC.singleton.feederContext.gqlFeeder else { return }
    showLocalHtml(from: feeder.welcomeSlides, scrollEnabled: false)
  }
  
  func openFaq(){
    guard let url = URL(string: "https://blogs.taz.de/app-faq/") else { return }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
  
  func textNotificationsChanged(newValue:Bool){
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


class XSettingsCell:UITableViewCell, UIStyleChangeDelegate {
  var tapHandler:(()->())?
  var longTapHandler:(()->())?
  private var toggleHandler: ((Bool)->())?
  
  deinit {
    print("XSettingsCell deinit")
  }
  
  override func prepareForReuse() {
    print("XSettingsCell prepareForReuse ...should not be called due not reuse cells!")
  }
  
  func applyStyles() {
    self.textLabel?.contentFont()
    self.textLabel?.numberOfLines = 0
    self.backgroundColor = .clear
    self.backgroundView?.backgroundColor = .clear
    self.contentView.backgroundColor = .clear
    self.detailTextLabel?.contentFont(size: Const.Size.SmallerFontSize)
    self.detailTextLabel?.numberOfLines = 0
    self.detailTextLabel?.textColor = Const.SetColor.ios(.secondaryLabel).color
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    if var frame = self.textLabel?.frame {
      frame.origin.x = Const.ASize.DefaultPadding
      textLabel?.frame = frame
    }
    if var frame = self.detailTextLabel?.frame {
      frame.origin.x = Const.ASize.DefaultPadding
      detailTextLabel?.frame = frame
    }
  }
  
  init(text: String,
       color:UIColor = Const.SetColor.ios(.link).color,
       tapHandler: (()->())?,
       longTapHandler: (()->())? = nil) {
    super.init(style: .default, reuseIdentifier: nil)
    self.textLabel?.text = text
    self.textLabel?.textColor = color
    self.tapHandler = tapHandler
    self.longTapHandler = longTapHandler
    applyStyles()
  }
  
  init(toggleWithText text: String,
       initialValue value:Bool,
       onChange: @escaping ((Bool)->())){
    super.init(style: .default, reuseIdentifier: nil)
    self.textLabel?.text = text
    self.toggleHandler = onChange
    let toggle: UISwitch = UISwitch()
    toggle.isOn = value
    toggle.addTarget(self, action: #selector(handleToggle(sender:)),
                     for: .valueChanged)
    self.accessoryView = toggle
    applyStyles()
  }
  
  init(text: String,
       detailText: String? = nil,
       accessoryView: UIView? = nil){
    super.init(style: detailText == nil ? .default : .subtitle,
               reuseIdentifier: nil)
    self.textLabel?.text = text
    self.accessoryView = accessoryView
    self.detailTextLabel?.text = detailText
    applyStyles()
  }
  
  @objc public func handleToggle(sender: UISwitch) {
    toggleHandler?(sender.isOn)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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
    //    detailLabel.text = "Alte Ausgaben und Vorschaudaten werden automatisch gelöscht."
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

class SaveLastCountIssuesSettings: TextSizeSetting {
  
  @Default("persistedIssuesCount")
  private var persistedIssuesCount: Int {
    didSet { updatePersistedIssuesCount() }
  }
  
  func updatePersistedIssuesCount(){
    label.text
    = persistedIssuesCount > 0
    ? "\(persistedIssuesCount)"
    : "alle"
  }
  
  override func setup(){
    super.setup()
    label.text = "\(persistedIssuesCount)"
    leftButton.buttonView.text = "-"
    rightButton.buttonView.text = "+"
    
    leftButton.buttonView.font = Const.Fonts.contentFont(size: 16)
    rightButton.buttonView.font = Const.Fonts.contentFont(size: 16)
    
    leftButton.buttonView.label.textInsets = UIEdgeInsets(top: -1.65, left:0.2 , bottom: 1.65, right: -0.2)
    rightButton.buttonView.label.textInsets = UIEdgeInsets(top: -1.2, left:0.2 , bottom: 1.2, right: -0.2)
    
    leftButton.onPress { [weak self] _ in
      guard let self = self, self.persistedIssuesCount > 0 else { return }
      /// 3 is minumum
      if self.persistedIssuesCount == 3 { self.persistedIssuesCount = 0}
      else { self.persistedIssuesCount -= 1 }
    }
    
    rightButton.onPress { [weak self] _ in
      guard let self = self else { return }
      if self.persistedIssuesCount < 3 { self.persistedIssuesCount = 3}
      else {self.persistedIssuesCount += 1}
    }
    
    label.onTapping { [weak self] _ in
      self?.persistedIssuesCount = 20
    }
    updatePersistedIssuesCount()
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
