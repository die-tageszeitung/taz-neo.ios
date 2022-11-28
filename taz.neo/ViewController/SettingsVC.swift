//
//  SettingsVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 21.09.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//
import NorthLib
import UIKit

/**
 A SettingsVC is a view controller to edit app's user Settings; Cells are not re-used!
 */
// MARK: - SettingsVC
open class SettingsVC: UITableViewController, UIStyleChangeDelegate {
  
  @Default("persistedIssuesCount")
  var persistedIssuesCount: Int
  
  @Default("autoloadOnlyInWLAN")
  var autoloadOnlyInWLAN: Bool
  
  @Default("showBarsOnContentChange")
  var showBarsOnContentChange: Bool
  
  @Default("autoloadPdf")
  var autoloadPdf: Bool
  
  @Default("autoloadNewIssues")
  var autoloadNewIssues: Bool {
    ///show/hide autoloadOnlyInWLAN
    didSet { if oldValue != autoloadNewIssues { refreshAndReload() }}
  }
  
  var extendedSettingsCollapsed: Bool = true
  
  @Default("isTextNotification")
  var isTextNotification: Bool
  
  @Default("bookmarksListTeaserEnabled")
  var bookmarksListTeaserEnabled: Bool
  
  @Default("tabbarInSection")
  var tabbarInSection: Bool
  
  @Default("smartBackFromArticle")
  var smartBackFromArticle: Bool
  
  var initialTextNotificationSetting: Bool?
  
  var data:TableData = TableData(sectionContent: [])
  
  var feederContext: FeederContext
  
  /// factory to create images for cells accessory view; attend every cell needs its own image!
  var webviewImage: UIImageView {
    get {
      let iv = UIImageView(image: UIImage(name: "safari"))
      iv.tintColor = Const.SetColor.ios(.secondaryLabel).color
      return iv
    }
  }
  
  // MARK: Cell creation
  ///konto
  lazy var loginCell: XSettingsCell = {
    guard let feeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      return XSettingsCell(text: "..."){} }
    let authenticator = DefaultAuthenticator(feeder: feeder)
    return XSettingsCell(text: "Anmelden") { [weak self] in
      authenticator.authenticate(with: self)
    }
  }()
  
  lazy var logoutCell: XSettingsCell = {
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { _ in
      onMainAfter {[weak self] in self?.updateLogoutCell() }
    }
    Notification.receive(Const.NotificationNames.expiredAccountDateChanged) {  _ in
      onMainAfter {[weak self] in self?.updateLogoutCell() }
    }
    Notification.receive(Const.NotificationNames.logoutUserDataDeleted) { _ in
      onMainAfter {[weak self] in self?.refreshAndReload() }
    }
    return logoutCellPrototype
  }()
  
  func updateLogoutCell(){
    self.logoutCell = self.logoutCellPrototype
    self.refreshAndReload()
  }
  
  var logoutCellPrototype: XSettingsCell {
    return XSettingsCell(text: "Abmelden (\(SimpleAuthenticator.getUserData().id ?? "???"))",
                         detailText: Defaults.expiredAccountText,
                         tapHandler: {[weak self] in self?.requestLogout()} )}
  
  lazy var resetPasswordCell: XSettingsCell
  = XSettingsCell(text: "Passwort zurücksetzen",
                  tapHandler: {[weak self] in self?.resetPassword()} )
  lazy var manageAccountCell: XSettingsCell =
  XSettingsCell(text: "Konto online verwalten",
                    tapHandler: {[weak self] in self?.manageAccountOnline()},
                    accessoryView: webviewImage )
  
  lazy var deleteAccountCell: XSettingsCell
  = XSettingsCell(text: "Konto löschen",
                  isDestructive: true,
                  tapHandler: {[weak self] in self?.requestAccountDeletion()})
  ///ausgabenverwaltung
  lazy var maxIssuesCell: XSettingsCell
  = XSettingsCell(text: "Maximale Anzahl der zu speichernden Ausgaben",
                  detailText: "Nach dem Download einer weiteren Ausgabe, wird die älteste heruntergeladene Ausgabe gelöscht.",
                  accessoryView: SaveLastCountIssuesSettings())
  lazy var autoloadNewIssuesCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Neue Ausgaben automatisch laden",
                  initialValue: autoloadNewIssues,
                  onChange: {[weak self] newValue in
    self?.autoloadNewIssues = newValue
    if newValue == true { self?.checkNotifications() }
  })
  lazy var wlanCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Nur im WLAN herunterladen",
                  initialValue: autoloadOnlyInWLAN,
                  onChange: {[weak self] newValue in
    self?.autoloadOnlyInWLAN = newValue })
  lazy var epaperLoadCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Zeitungsansicht immer mit laden",
                  initialValue: autoloadPdf,
                  onChange: {[weak self] newValue in
    self?.autoloadPdf = newValue })
  lazy var deleteIssuesCell: XSettingsCell
  = XSettingsCell(text: "Alle Ausgaben löschen",
                  isDestructive: true,
                  tapHandler: {[weak self] in self?.requestDeleteAllIssues()} )
  ///darstellung
  lazy var textSizeSettingsCell: XSettingsCell
  = XSettingsCell(text: "Textgröße (Inhalte)", accessoryView: TextSizeSetting())
  lazy var darkmodeSettingsCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Nachtmodus",
                  initialValue: Defaults.darkMode,
                  onChange: { newValue in Defaults.darkMode = newValue })
  ///hilfe
  lazy var onboardingCell: XSettingsCell
  = XSettingsCell(text: "Erste Schritte",
                  tapHandler: {[weak self] in self?.showOnboarding()} )
  lazy var faqCell: XSettingsCell
  = XSettingsCell(text: "FAQ",
                  tapHandler: {[weak self] in self?.openFaq()},
                  accessoryView: webviewImage)
  lazy var reportErrorCell: XSettingsCell
  = XSettingsCell(text: "Fehler melden",
                  tapHandler: {TazAppEnvironment.sharedInstance.showFeedbackErrorReport(.error)} )
  lazy var feedbackCell: XSettingsCell
  = XSettingsCell(text: "Feedback geben",
                  tapHandler: {TazAppEnvironment.sharedInstance.showFeedbackErrorReport(.feedback)} )
  ///rechtliches
  lazy var termsCell: XSettingsCell
  = XSettingsCell(text: "Allgemeine Geschäftsbedingungen (AGB)",
                  tapHandler: {[weak self] in self?.showTerms()} )
  lazy var privacyCell: XSettingsCell
  = XSettingsCell(text: "Datenschutzerklärung",
                  tapHandler: {[weak self] in self?.showPrivacy()} )
  lazy var revokeCell: XSettingsCell
  = XSettingsCell(text: "Widerruf",
                  tapHandler: {[weak self] in self?.showRevocation()} )
  ///erweitert
  lazy var notificationsCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Mitteilungen erlauben",
                  detailText: "Zeige Mitteilungen außerhalb der App an (Banner, Sperrbildschirm)",
                  initialValue: isTextNotification,
                  onChange: {[weak self] newValue in
                    self?.isTextNotification = newValue
                    TazAppEnvironment.sharedInstance.feederContext?.setupRemoteNotifications(force: true)
                    if newValue == true { self?.checkNotifications() }
                  })
  
  lazy var bookmarksTeaserCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Leseliste Anrisstext",
                  detailText: "Zeige Anrisstext in Leseliste",
                  initialValue: bookmarksListTeaserEnabled,
                  onChange: {[weak self] newValue in
                    self?.bookmarksListTeaserEnabled = newValue
                    Notification.send("BookmarkChanged")
                  })
    
  lazy var tabbarInSectionCellALPHA: XSettingsCell
  = XSettingsCell(toggleWithText: "Teige Tabbar auf Sectionebene",
                  detailText: "Alpha Feature",
                  initialValue: tabbarInSection,
                  onChange: {[weak self] newValue in
                    self?.tabbarInSection = newValue
                  })
  
  lazy var smartBackFromArticleCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Intelligentes Zurück",
                  detailText: "Zurück im Artikel führt zu zugehörigem Eintrag",
                  initialValue: smartBackFromArticle,
                  onChange: {[weak self] newValue in
                    self?.smartBackFromArticle = newValue
                  })
  
  lazy var memoryUsageCell: XSettingsCell
  = XSettingsCell(text: "Speichernutzung", detailText: storageDetails)
  lazy var deleteDatabaseCell: XSettingsCell
  = XSettingsCell(text: "Daten zurücksetzen",
                  isDestructive: true,
                  tapHandler: {[weak self] in self?.requestDatabaseDelete()} )
  lazy var resetAppCell: XSettingsCell
  = XSettingsCell(text: "App in Auslieferungszustand zurück versetzen",
                  isDestructive: true,
                  tapHandler: {[weak self] in self?.requestResetApp()} )
  lazy var contentChangeSettingCellALPHA: XSettingsCell
  = XSettingsCell(toggleWithText: "Zeige Toolbar bei Artikelwechsel",
                  detailText: "Alpha Feature",
                  initialValue: showBarsOnContentChange,
                  onChange: {[weak self] newValue in
    self?.showBarsOnContentChange = newValue })
  
  /// UI Components
  lazy var footer:Footer = Footer()
  
  lazy var header:HeaderView = {
    let v = HeaderView()
    v.titletype = .bigLeft
    v.title = "einstellungen"
    return v
  }()
  
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
  
  open override func viewDidLoad() {
    self.tableView = UITableView(frame: .zero, style: .grouped)
    super.viewDidLoad()
    data = TableData(sectionContent: currentSectionContent())
    setup()
    registerForStyleUpdates()
    let longTap = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTap(sender:)))
    tableView.addGestureRecognizer(longTap)
    initialTextNotificationSetting = isTextNotification
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let sv = self.view.superview {
      sv.addSubview(header)
      pin(header, to: sv, exclude: .bottom)
      pin(self.tableView, toSafe: sv, exclude: .top).bottom?.constant = -50.0
      pin(self.tableView.top, to: header.bottom)
    }
  }
  
  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    checkNotifications()
  }
    
  required public init(feederContext: FeederContext) {
    self.feederContext = feederContext
    super.init(nibName: nil, bundle: nil)
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Helper
extension SettingsVC {
  @objc func applicationDidBecomeActive(notification: NSNotification) {
    guard (self.parent as? MainTabVC)?.selectedViewController == self else { return }
    checkNotifications()
  }
  
  func checkNotifications(){
    NotificationBusiness.sharedInstance.checkNotificationStatusIfNeeded {
      //disable notifications toggle / Do not disable autoload toggle!
      onMain {   [weak self] in
        guard let self = self else { return }
        if let toggle = self.notificationsCell.customAccessoryView as? UISwitch{
          toggle.isOn = self.isTextNotification
          if NotificationBusiness.sharedInstance.systemNotificationsEnabled {
            toggle.onTintColor = .systemGreen
          }
          else {
            toggle.onTintColor = UIColor(white: 0.95, alpha: 1.0)
          }
        }
      }
    }
  }
  
  public func applyStyles() {
    tableView.backgroundColor = Const.SetColor.CTBackground.color
    if let toggle = self.darkmodeSettingsCell.customAccessoryView as? UISwitch,
       toggle.isOn != Defaults.darkMode {
      toggle.isOn = Defaults.darkMode
    }
  }
  
  func setup(){
    tableView.separatorInset = .zero
    header.layoutIfNeeded()
    registerForStyleUpdates()
    NotificationCenter.default
      .addObserver(self,
                   selector: #selector(applicationDidBecomeActive),
                   name: UIApplication.didBecomeActiveNotification,
                   object: nil)
    checkNotifications()
  }
  
  func refreshAndReload() {
    let oldData = data
    data = TableData(sectionContent: currentSectionContent())
    
    if oldData.sectionsCount != data.sectionsCount {
      tableView.reloadData()
      return
    }
    
    let diff = data.changedIndexPaths(oldData: oldData)
        
    if (diff.added.count + diff.deleted.count) == 0 {
      tableView.reloadData()
      return
    }
    
    self.tableView.performBatchUpdates {   [weak self] in
      guard let self = self else { return }
      if diff.deleted.count > 0 {
        self.tableView.deleteRows(at: diff.deleted, with: .fade)
      }
      
      if diff.added.count > 0 {
        self.tableView.insertRows(at: diff.added, with: .fade)
      }
    }
  }
  
  @objc private func handleLongTap(sender: UILongPressGestureRecognizer) {
    if sender.state == .began {
      let touchPoint = sender.location(in: tableView)
      guard let indexPath = tableView.indexPathForRow(at: touchPoint) else { return }
      data.cell(at: indexPath)?.longTapHandler?()
    }
  }
}

extension SettingsVC {
  open override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    self.header.scrollViewDidScroll(scrollView.contentOffset.y)
  }
  
  open override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    self.header.scrollViewDidEndDragging(scrollView.contentOffset.y)
  }
  
  open override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    self.header.scrollViewWillBeginDragging(scrollView.contentOffset.y)
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
    let header = SectionHeader(text:title, collapseable: sectionData.collapseable)
    header.collapsed = self.extendedSettingsCollapsed
    header.onTapping { [weak self] _ in
      guard let self = self else { return }
      guard section == 5 else { return }
      guard let sectionData = self.data.sectionData(for: section) else { return }
      guard sectionData.collapseable else { return }
      self.extendedSettingsCollapsed = !self.extendedSettingsCollapsed
      header.collapsed = self.extendedSettingsCollapsed
      self.refreshAndReload()
    }
    return header
  }
  
  open override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return section == data.sectionsCount - 1 ? footer : nil
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

// MARK: - Nested Class: Footer
extension SettingsVC {
  class Footer:UIView{
    let label = UILabel()
    let background = UIView()
    
    func applyStyles() {
      background.backgroundColor = Const.Colors.opacityBackground
      label.textColor = Const.SetColor.ios(.secondaryLabel).color
    }
    
    override func layoutSubviews() {
      super.layoutSubviews()
      applyStyles()
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

// MARK: - cell data model
extension SettingsVC {
  typealias tSectionContent = (title:String?,
                               collapseable:Bool,
                               cells:[XSettingsCell])
  ///added, deleted, updated
  typealias tChangedIndexPaths = (added: [IndexPath],
                                  deleted: [IndexPath])
  
  struct TableData{
    @Default("autoloadNewIssues")
    var autoloadNewIssues: Bool
    private var sectionContent:[tSectionContent]
    init(sectionContent: [tSectionContent]) {
      self.sectionContent = sectionContent
    }
  }
}

// MARK: - cell data model access helper
extension SettingsVC.TableData{
  
  var sectionsCount: Int { return self.sectionContent.count }
  
  func rowsIn(section: Int) -> Int{
    guard let sectionContent = sectionData(for: section) else { return 0 }
    return sectionContent.cells.count
  }
  
  func canTap(at indexPath: IndexPath) -> Bool{
    return cell(at: indexPath)?.tapHandler != nil
  }
  
  func cell(at indexPath: IndexPath) -> XSettingsCell? {
    return self.sectionContent.valueAt(indexPath.section)?.cells.valueAt(indexPath.row)
  }
  
  func sectionData(for section: Int) -> SettingsVC.tSectionContent?{
    return self.sectionContent.valueAt(section)
  }
  
  func footerHeight(for section: Int) -> CGFloat{
    return 20
  }
  
  /// get updated IndexPath...
  func changedIndexPaths(oldData: SettingsVC.TableData) -> SettingsVC.tChangedIndexPaths {
    var added:[IndexPath] = []
    var deleted:[IndexPath] = []
    
    for idSect in 0 ... max(self.sectionsCount, oldData.sectionsCount) - 1{
      let newCells = self.sectionData(for: idSect)?.cells ?? []
      let oldCells = oldData.sectionData(for: idSect)?.cells ?? []
      
      let addedCells = Set(newCells).subtracting(oldCells)
      let deletedCells = Set(oldCells).subtracting(newCells)
      
      let newRows = self.rowsIn(section: idSect)
      let oldRows = oldData.rowsIn(section: idSect)
      for idRow in 0 ... (max(newRows, oldRows, 1) - 1){
        let ip = IndexPath(row: idRow , section: idSect)
        let newCell = self.cell(at: ip)
        let oldCell = oldData.cell(at: ip)
        
        if let newCell = newCell, addedCells.contains(newCell){
          added.append(ip)
        }
        
        if let oldCell = oldCell, deletedCells.contains(oldCell){
          deleted.append(ip)
        }
      }
    }
    return (added: added, deleted: deleted)
  }
}


// MARK: - cell data/creation/helper
extension SettingsVC {
  
  var isAuthenticated: Bool { return feederContext.isAuthenticated }
  
  var showDeleteAccountCell: Bool {
    if isAuthenticated == false { return false }
    let uid = SimpleAuthenticator.getUserData().id ?? ""
    ///id not saved but Auth Token availabe, something went wrong, existing error, reason unknown, GraphQL either gives an link or not
    if uid.length == 0 { return true }
    if uid.isNumber { return true }//abo-ID
    if uid.contains("@") { return true }//taz-ID
    return false //Special access, Promo Code/Login
  }
  
  var storageDetails: String {
    let storage = DeviceData().detailStorage
    let data = String(format: "%.1f",  10*Float(storage.data)/(1000*1000*10))
    let app =  String(format: "%.1f",  10*Float(storage.app)/(1000*1000*10))
    return "App: \(app) MB, Daten: \(data) MB"
  }
  
  var accountSettingsCells:[XSettingsCell] {
    ///ensure both cells are initialized, prevents edge case:
    ///login on article with expired AboID may end in deadlock, only app restart fix this
    _ = logoutCell
    _ = loginCell
    print("isAuthenticated: \(isAuthenticated)")
    var cells =
    [
      isAuthenticated ? logoutCell : loginCell,
      resetPasswordCell,
      manageAccountCell
    ]
    if showDeleteAccountCell {
      cells.append(deleteAccountCell)
    }
    return cells
  }
  
  var issueSettingsCells:[XSettingsCell] {
    var cells = [
      maxIssuesCell
    ]
    
    if App.isAvailable(.AUTODOWNLOAD) {
      cells.append(autoloadNewIssuesCell)
    }
    
    if autoloadNewIssues && App.isAvailable(.AUTODOWNLOAD) {
      cells.append(wlanCell)
    }
    cells.append(epaperLoadCell)
    cells.append(deleteIssuesCell)
    return cells
  }
  
  var extendedSettingsCells:[XSettingsCell] {
    var cells =  [
      notificationsCell,
      bookmarksTeaserCell,
      smartBackFromArticleCell,
      memoryUsageCell,
      deleteDatabaseCell,
      resetAppCell
    ]
    
    if App.isAlpha {
      cells.append(contentChangeSettingCellALPHA)
      cells.append(tabbarInSectionCellALPHA)
    }
    return cells
  }
  
  //Prototype Cells
  func currentSectionContent() -> [tSectionContent] {
    return [
      ("konto", false, accountSettingsCells),
      ("ausgabenverwaltung", false, issueSettingsCells),
      ("darstellung", false,
       [
        textSizeSettingsCell,
        darkmodeSettingsCell
       ]
      ),
      ("hilfe", false,
       [
        onboardingCell,
        faqCell,
        reportErrorCell,
        feedbackCell
       ]
      ),
      ("rechtliches", false,
       [
        termsCell,
        privacyCell,
        revokeCell
       ]
      ),
      ("erweitert", true,
       extendedSettingsCollapsed ? [] : extendedSettingsCells
      )
    ]
  }
}

// MARK: - Handler/Actions
extension SettingsVC {
  func requestLogout(){
    let alert = UIAlertController.init( title: "Abmelden?",
                                        message: "Heruntergeladene Ausgaben können weiterhin gelesen werden.",
                                        preferredStyle:  .alert )
    alert.addAction( UIAlertAction.init( title: "Ja, abmelden", style: .destructive,
                                         handler: { [weak self] _ in
      TazAppEnvironment.sharedInstance.deleteUserData()
      self?.refreshAndReload()
    } ) )
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    
    if (Defaults.expiredAccountText != nil) {
      alert.addAction( UIAlertAction.init( title: "Weitere Informationen", style: .default,
                                           handler: { [weak self] _ in
        guard let self = self else { return }
        guard let feeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else { return }
        DefaultAuthenticator(feeder: feeder).authenticate(with: self)
      } ) )
    }
    
    alert.presentAt(self.view)
  }
  
  func showAccountDeletionAlert(status:GqlCancellationStatus, wasForce: Bool = false){
    var title: String?
    var text: String?
    var actionButton: UIAlertAction?

    if status.canceled {
      ///Attention aboID force cancelation need some seconds only future Requests have status.canceled == true
      title = "Konto gelöscht"
      text = """
      \(wasForce ? "Wir haben Ihr Konto" : "Ihr Konto wurde bereits") zur Löschung vorgemerkt. Die Bearbeitung erfolgt normalerweise innerhalb eines Arbeitstages.\n\nWenn Ihr Konto endgültig gelöscht ist, werden Sie automatisch abgemeldet. Heruntergeladene Ausgaben können Sie weiterhin lesen."
      """
    }
    else if status.info == .aboId {
      text = "Möchten Sie Ihr Konto wirklich löschen?\nDiese Aktion kann nicht Rückgängig gemacht werden. Sie können keine weiteren Ausgaben herunterladen."
      actionButton = UIAlertAction.init( title: "Konto löschen",
                                         style: .destructive,
                                         handler: { [weak self] _ in
        self?.requestAccountDeletion(true)
      })
    }
    else if let cLink = status.cancellationLink,
              !cLink.isEmpty,
            let url = URL(string: cLink){
      text = "Webseite zum Löschen Ihres Konto aufrufen?"
      actionButton = UIAlertAction.init( title: "Webseite öffnen",
                                         style: .default,
                                         handler: { _ in
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      })
    }
    else if status.info == .specialAccess {
      text = "Sie verwenden kein selbst erstelltes Konto. Sie können dieses Konto nicht löschen."
      + "\n\nBei weiteren Fragen wenden Sie sich bitte an den Service unter app@taz.de."
    }
    else {
      text = "Es ist ein unbekannter Fehler aufgetreten.\n\nBitte wenden Sie sich mit Ihrem Anliegen an unseren Service unter app@taz.de."
    }
    
    let alert = UIAlertController.init( title: title,
                                        message: text,
                                        preferredStyle:  .alert )
    
    if let actionButton = actionButton {
      alert.addAction(actionButton)
      alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    }
    else {
      alert.addAction( UIAlertAction.init( title: "OK", style: .cancel) { _ in } )
    }
    
    alert.presentAt(self.view)
  }
  
  func requestAccountDeletion(_ force: Bool = false){
    guard let feeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else {
      Toast.show(Localized("something_went_wrong_try_later"), .alert)
      return
    }
    self.uiBlocked = true
    feeder.requestAccountDeletion(forceDelete: force) { [weak self] (result) in
      self?.uiBlocked = false
      switch result{
        case .success(let status):
          self?.log("Request account deletion request success: \(status)")
          self?.showAccountDeletionAlert(status: status, wasForce: force)
        case .failure(let err):
          self?.log("Request account deletion failure: \(err)")
          Toast.show(Localized("something_went_wrong_try_later"), .alert)
      }
    }
  }
  
  func requestDeleteAllIssues(){
    let alert = UIAlertController.init( title: "Alle Ausgaben löschen", message: nil,
                                        preferredStyle:  .alert )
    alert.addAction( UIAlertAction.init( title: "Löschen", style: .destructive,
                                         handler:  { [weak self] _ in
      guard let storedFeeder = TazAppEnvironment.sharedInstance.feederContext?.storedFeeder,
            let storedFeed = storedFeeder.storedFeeds.first else {
              return
            }
      TazAppEnvironment.sharedInstance.feederContext?.cancelAll()
      StoredIssue.removeOldest(feed: storedFeed, keepDownloaded: 0, keepPreviews: 20, deleteOrphanFolders: true)
      onMainAfter { [weak self] in
        self?.refreshAndReload()
        TazAppEnvironment.sharedInstance.feederContext?.resume()
        Notification.send("reloadIssues")
      }
    } ) )
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.view)
  }
  
  func requestDatabaseDelete(){
    let alert = UIAlertController.init( title: "Daten zurücksetzen", message: "Falls Ihre App wiederholt ungewollt beendet wird, benutzen Sie diese Aktion. Die App wird nach Ausführung der Aktion automatisch beendet und kann von Ihnen erneut gestartet werden.\nBei dieser Aktion bleiben viele Daten erhalten, es wird nur eine geringe Menge Daten zum Abgleich der Ausgaben erneut heruntergeladen.\nBitte nutzen Sie auch auch unsere \"Fehler melden\" Funktion um uns Fehler in der App mitzuteilen!",
                                        preferredStyle:  .actionSheet)
    
    alert.addAction( UIAlertAction.init( title: "Daten zurücksetzen", style: .destructive,
                                         handler: { _ in
//      TazAppEnvironment.sharedInstance.popToRootViewController(animated: false)
      TazAppEnvironment.sharedInstance.feederContext?.cancelAll()
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
    let alert = UIAlertController.init( title: "App in Auslieferungszustand zurück versetzen", message: "Löscht alle Daten und Einstellungen der App.\nDie App wird nach dem Zurücksetzen beendet und kann von Ihnen neu gestartet werden. Sie müssen sich im Anschluss neu anmelden.",
                                        preferredStyle:  .actionSheet )
    
    
    alert.addAction( UIAlertAction.init( title: "Zurücksetzen", style: .destructive,
                                         handler: { _ in
      TazAppEnvironment.sharedInstance.deleteUserData()
      Defaults.singleton.setDefaults(values: ConfigDefaults,
                                     isNotify: false,
                                     forceWrite: true)
      TazAppEnvironment.sharedInstance.deleteAll()
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.view)
  }
  
  func showPrivacy(){
    guard let feeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else { return }
    showLocalHtml(from: feeder.dataPolicy, scrollEnabled: true)
  }
  
  func showTerms(){
    guard let feeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else { return }
    showLocalHtml(from: feeder.terms, scrollEnabled: true)
  }
  
  func showRevocation(){
    guard let feeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else { return }
    showLocalHtml(from: feeder.revocation, scrollEnabled: true)
  }
  func resetPassword(){
    let id = SimpleAuthenticator.getUserData().id
    guard let feeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else { return }
    let childVc = PwForgottController(id: id, auth: DefaultAuthenticator.init(feeder: feeder))
    childVc.modalPresentationStyle = .formSheet
    self.present(childVc, animated: true)
  }
  
  func manageAccountOnline(){
    guard let url = URL(string: "https://portal.taz.de/") else { return }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
  }
  
  func showOnboarding(){
    guard let feeder = TazAppEnvironment.sharedInstance.feederContext?.gqlFeeder else { return }
    showLocalHtml(from: feeder.welcomeSlides, scrollEnabled: false)
  }
  
  func openFaq(){
    guard let url = URL(string: "https://blogs.taz.de/app-faq/") else { return }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
  }
  
  func showLocalHtml(from urlString:String, scrollEnabled: Bool){
    let introVC = IntroVC()
    introVC.htmlIntro = urlString
    introVC.topOffset = 40
    let intro = File(urlString)
    introVC.webView.webView.load(url: intro.url)
    introVC.webView.webView.scrollView.contentInsetAdjustmentBehavior = .never
    introVC.webView.webView.scrollView.isScrollEnabled = scrollEnabled
    
    introVC.webView.onX { _ in
      introVC.dismiss(animated: true, completion: nil)
    }
    self.modalPresentationStyle = .fullScreen
    introVC.modalPresentationStyle = .fullScreen
    introVC.webView.webView.scrollDelegate.atEndOfContent {_ in }
    self.present(introVC, animated: true) {
      //Overwrite Default in: IntroVC viewDidLoad
      introVC.webView.buttonLabel.text = nil
      //fix X-Button color due meta pages (terms, privacy) are currently not in darkmode
      guard let bv = introVC.webView.xButton as? Button<ImageView> else { return }
      bv.buttonView.color =  Const.Colors.iOSLight.secondaryLabel
      bv.layer.backgroundColor = Const.Colors.iOSLight.secondarySystemFill.cgColor
    }
  }
}

// MARK: - Nested Classes / UI Components

// MARK: -
class XSettingsCell:UITableViewCell {
  var tapHandler:(()->())?
  var isDestructive: Bool = false
  var longTapHandler:(()->())?
  private var toggleHandler: ((Bool)->())?
  
  private(set) var customAccessoryView:UIView?
  
  override var accessoryView: UIView? {
    set { self.customAccessoryView = newValue }
    get { return nil }//ensure custom layout
  }
  
  deinit {
    debug("XSettingsCell deinit \(self.textLabel?.text ?? "-")")
  }
  
  override func prepareForReuse() {
    debug("XSettingsCell prepareForReuse ...should not be called due not reuse cells!")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    applyStyles()
  }
  
  func applyStyles() {
    self.textLabel?.contentFont()
    self.textLabel?.numberOfLines = 0
    self.backgroundColor = .clear
    self.backgroundView?.backgroundColor = .clear
    self.contentView.backgroundColor = .clear
    self.detailTextLabel?.contentFont(size: Const.Size.SmallerFontSize)
    self.detailTextLabel?.numberOfLines = 0
    
    self.textLabel?.textColor
    = isDestructive
    ? .red
    : Const.SetColor.ios(.label).color
    self.detailTextLabel?.textColor
    = Const.SetColor.ios(.secondaryLabel).color
    
    //not implemented for stepper, not needed yet
    //self.accessoryView?.isUserInteractionEnabled = self.isUserInteractionEnabled
    
    (self.accessoryView as? UISwitch)?.isEnabled
    = self.isUserInteractionEnabled
  }
  
  init(text: String,
       detailText: String? = nil,
       isDestructive: Bool = false,
       tapHandler: (()->())?,
       accessoryView: UIView? = nil,
       longTapHandler: (()->())? = nil) {
    super.init(style: detailText == nil ? .default : .subtitle,
               reuseIdentifier: nil)
    self.textLabel?.text = text
    self.detailTextLabel?.text = detailText
    self.customAccessoryView = accessoryView
    self.isDestructive = isDestructive
    self.tapHandler = tapHandler
    self.longTapHandler = longTapHandler
    setupLayout()
  }
  
  init(toggleWithText text: String,
       detailText: String? = nil,
       initialValue value:Bool,
       onChange: @escaping ((Bool)->())){
    super.init(style: detailText == nil ? .default : .subtitle,
               reuseIdentifier: nil)
    self.textLabel?.text = text
    self.detailTextLabel?.text = detailText
    self.toggleHandler = onChange
    let toggle: UISwitch = UISwitch()
    toggle.isOn = value
    toggle.addTarget(self, action: #selector(handleToggle(sender:)),
                     for: .valueChanged)
    self.customAccessoryView = toggle
    setupLayout()
  }
  
  init(text: String,
       detailText: String? = nil,
       accessoryView: UIView? = nil){
    super.init(style: detailText == nil ? .default : .subtitle,
               reuseIdentifier: nil)
    self.textLabel?.text = text
    self.customAccessoryView = accessoryView
    self.detailTextLabel?.text = detailText
    setupLayout()
  }
  
  func setupLayout(){
    guard let label = self.textLabel else { return }
    
    let dist = Const.ASize.DefaultPadding
    
    if let av = self.customAccessoryView {
      av.setNeedsUpdateConstraints()
      av.setNeedsLayout()
      av.updateConstraintsIfNeeded()
      av.layoutIfNeeded()
      self.contentView.addSubview(av)
      av.pinWidth(av.bounds.size.width)
      pin(av.right, to: contentView.right, dist: -dist)
      if self.detailTextLabel == nil{
        av.centerY()
      }
      else {
        pin(av.top, to: self.contentView.top, dist: 10)
      }
      pin(label.right, to: av.left, dist: -dist)
      label.heightAnchor.constraint(greaterThanOrEqualToConstant: av.frame.size.height).isActive = true
    }
    else {
      pin(label.right, to: contentView.right, dist: -dist)
    }
    
    pin(label.left, to: contentView.left, dist: dist)
    pin(label.top, to: contentView.top, dist: 10, priority: .defaultHigh)
    
    if let dtl = self.detailTextLabel{
      pin(label.bottom, to: dtl.top)
    }
    else {
      pin(label.bottom, to: contentView.bottom, dist: -10, priority: .defaultHigh)
    }
    
    if let subLabel = self.detailTextLabel {
      pin(subLabel.left, to: contentView.left, dist: dist)
      pin(subLabel.right, to: contentView.right, dist: -dist)
      pin(subLabel.bottom, to: contentView.bottom, dist: -10)
    }
    self.setNeedsUpdateConstraints()
    self.setNeedsLayout()
    self.updateConstraintsIfNeeded()
    self.layoutIfNeeded()
  }
  
  @objc public func handleToggle(sender: UISwitch) {
    toggleHandler?(sender.isOn)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: -
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
  
  override func applyStyles() {
    super.applyStyles()
    updatePersistedIssuesCount()
  }
  
  override func setup(){
    super.setup()
    label.text = "\(persistedIssuesCount)"
    
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

// MARK: -
class TextSizeSetting: CustomHStack, UIStyleChangeDelegate {
  
  let leftButton = Button<ImageView>()
  let rightButton = Button<ImageView>()
  let label = UILabel()
  
  @Default("articleTextSize")
  private var articleTextSize: Int
  
  func applyStyles() {
    label.textColor =  Const.SetColor.ios(.label).color
    leftButton.circleIconButton(true)
    rightButton.circleIconButton(true)
    label.text = "\(articleTextSize)%"
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    applyStyles()
  }
  
  override func setup(){
    super.setup()
    label.contentFont()
    label.labelColor()
    registerForStyleUpdates()
    label.text = "\(articleTextSize)%"
    
    leftButton.circleIconButton(symbol: "minus")
    rightButton.circleIconButton(symbol: "plus")
    
    leftButton.buttonView.hinset = 0.23
    rightButton.buttonView.hinset = 0.23
    
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
    self.pinSize(CGSize(width: 122, height: 40), priority: .defaultHigh)
  }
}

// MARK: -
class CustomHStack: UIStackView {
  init(){
    super.init(frame: .zero)
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

// MARK: -
class SimpleHeaderView: UIView,  UIStyleChangeDelegate{
  
  private let titleLabel = Label().titleFont(size: Const.Size.TitleFontSize)
  private let line = DottedLineView()
  
  override func layoutSubviews() {
    super.layoutSubviews()
    applyStyles()
  }
  
  private func setup() {
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

// MARK: -
class SectionHeader: UIView {
  
  let label = UILabel()
  var chevron: UIImageView?
  
  var collapsed: Bool = true {
    didSet {
      if oldValue == collapsed { return }
      UIView.animateKeyframes(withDuration: 0.5, delay: 0.0, animations: {
        UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) { [weak self] in
          guard let self = self, let c = self.chevron else { return }
          c.transform = CGAffineTransform(rotationAngle: 0)
        }
        
        UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) { [weak self] in
          self?.rotateChevron()
        }
      })
    }
  }
  
  func rotateChevron(){
    chevron?.transform = CGAffineTransform(rotationAngle: self.collapsed ? CGFloat.pi : CGFloat.pi*2)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    applyStyles()
  }
  
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
    if let c = chevron {
      self.addSubview(c)
      c.pinSize(CGSize(width: 20, height: 20))
      pin(c.right, to: self.right, dist: -Const.ASize.DefaultPadding)
      c.centerY()
      self.rotateChevron()
    }
    label.titleFont(size: Const.Size.SubtitleFontSize)
  }
  
  init(text:String, collapseable: Bool){
    super.init(frame: .zero)
    label.text = text
    if collapseable {
      chevron = UIImageView(image: UIImage(named: "chevron-up"))
      chevron?.tintColor = Const.SetColor.ios(.secondaryLabel).color
    }
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
