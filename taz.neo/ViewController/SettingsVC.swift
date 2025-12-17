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
open class SettingsVC: UIViewController, UIStyleChangeDelegate {
  
  @Default("persistedIssuesCount")
  var persistedIssuesCount: Int
  
  
  @Default("autoloadPdf")
  var autoloadPdf: Bool
  
  @Default("autoloadNewIssues")
  var autoloadNewIssues: Bool {
    ///show/hide autoloadOnlyInWLAN
    didSet { if oldValue != autoloadNewIssues {  refreshAndReload()  }}
  }
  
  @Default("autoloadOnlyInWLAN2")
  var autoloadOnlyInWLAN: Bool
  
  @Default("autoloadAudio")
  var autoloadAudio: Bool
  
  @Default("autoloadNotifications")
  var autoloadNotifications: Bool
  
  @Default("showBarsOnContentChange")
  var showBarsOnContentChange: Bool
  
  @Default("resumeReadAccepted")
  public var resumeReadAccepted: Int
  
  @Default("resumeReadDismissed")
  public var resumeReadDismissed: Int
  
  @Default("reopenHintSetting")
  public var reopenHintSetting: Bool
  
  @Default("reopenAutomaticSetting")
  public var reopenAutomaticSetting: Bool
  
  @Default("reopenRessortSetting")
  public var reopenRessortSetting: Bool
  
  @Default("defaultToastsDisabled")
  public var defaultToastsDisabled: Bool
  
  private var orgOvwFields = GqlIssue.ovwFields
  private lazy var failureOvwFields : String = {
    ///WARNING AT FIRST Init Issue Fields, that this would be correct for later Access!!
    _ = GqlIssue.fields
    ///...DONE
    let wrongFacsimile =  """
    gqlFacsimile: facsimileTestForErrorAndEndlessReturn { \(GqlImage.fields) }
    """
    return orgOvwFields.replacingOccurrences(of: "gqlAudio: podcast", with: "\(wrongFacsimile) gqlAudio: podcast")
  }()
  private var sendFailureRequestToServer: Bool = false {
    didSet {
      GqlIssue.ovwFields = sendFailureRequestToServer ? failureOvwFields : orgOvwFields
    }
  }

  @Default("useTestServer")
  var useTestServer: Bool
  
  @Default("newIssueSystemSetting")
  var newIssueSystemSetting: Bool
  
  @Default("specialArticleSystemSetting")
  var specialArticleSystemSetting: Bool
  
  var extendedSettingsCollapsed: Bool = true
  
  @Default("isTextNotification")
  var isTextNotification: Bool
  
  @Default("usageTrackingAllowed")
  var usageTrackingAllowed: Bool
  
  @Default("tabbarInSection")
  var tabbarInSection: Bool
  
  @Default("animateArticleSectionChange")
  var animateArticleSectionChange: Bool
  
  @Default("autoHideToolbar")
  var autoHideToolbar: Bool

  @Default("smartBackFromArticle")
  var smartBackFromArticle: Bool
  
  @Default("showHelp")
  var showHelp: Bool

  @Default("articleFromPdf")
  public var articleFromPdf: Bool
  
  @Default("debuggingSwitchOne")
  public var debuggingSwitchOne: Bool
  
  @Default("openLinksInApp")
  public var openLinksInApp: Bool
  
  @Default("doubleTapToZoomPdf")
  public var doubleTapToZoomPdf: Bool
  
  ///Required rename to enable setting and intotruce feature with a coachmark
  ///if old value was already set to true just a coachmark will be shown
  ///if old setting was still false; now its true and a coachmark will be shown
  @Default("edgeTapToNavigate")
  public var edgeTapToNavigate: Bool
  
  @Default("edgeTapToNavigateVisible2")
  public var edgeTapToNavigateVisible2: Bool
  
  @Default("multiColumnSnap")
  public var multiColumnSnap: Bool
  
  @Default("multiColumnFixedScrolling")
  public var multiColumnFixedScrolling: Bool
  
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
                  detailText: autoloadCellDetailText(autoloadNewIssues),
                  initialValue: autoloadNewIssues,
                  onChange: {[weak self] newValue in
    self?.autoloadNewIssuesCell.detailTextLabel?.text
    = self?.autoloadCellDetailText(newValue)
    self?.autoloadNewIssues = newValue //perform reload!
    if newValue == true { self?.checkNotifications() }
  })
  
  func autoloadCellDetailText(_ enabled: Bool) -> String? {
    let loginInfo = feederContext.gqlFeeder.hasValidAbo ? "": "Sie müssen mit einem gültigen Abo angemeldet sein.\n"
    return enabled
    ? "\(loginInfo)Lädt neue Ausgaben nur, wenn die App nicht manuell beendet wurde."
    : " "
  }
  
  lazy var wlanCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Nur im WLAN herunterladen",
                  detailText: "Automatischer Download nur im WLAN",
                  initialValue: autoloadOnlyInWLAN,
                  onChange: {[weak self] newValue in
    self?.autoloadOnlyInWLAN = newValue
    if newValue == true { return }//No Warning if Download only in WLAN
    let audio = self?.autoloadAudio == true
    let message
    = audio
    ? "Der Download von Audiodateien kann Ihr mobiles Datenvolumen stark beanspruchen. Eine Werktagsausgabe benötigt etwa 100 MB, eine Wochentaz oder LMd Ausgabe etwa 250 MB. Wir empfehlen den Download über WLAN."
    : "Der Download einer Ausgabe kann Ihr mobiles Datenvolumen beanspruchen. Die Downloadgröße pro Ausgabe beträgt ca. 10-20 MB ohne Audiodateien."
    Alert.message(title: audio ? "Achtung" : "Hinweis", message: message)
  })
  
  lazy var autoloadAudioCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Audiodateien ebenfalls automatisch herunterladen",
                  detailText: "Hinweis: Führt zu höherem Datenverbrauch und erheblich höherer Speicherbelegung.",
                  initialValue: autoloadAudio,
                  onChange: {[weak self] newValue in
    self?.autoloadAudio = newValue })
  
  
  lazy var autoloadNotificationsCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Benachrichtigung bei neuen Downloads",
                  detailText: "Erhalte Mitteilungen auf dem Sperrbildschirm und in der Mitteilungszentrale, wenn neue Ausgaben automatisch heruntergeladen werden.",
                  initialValue: autoloadNotifications,
                  onChange: {[weak self] newValue in
    self?.autoloadNotifications = newValue })
  
  lazy var reopenHintSettingCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Weiterlesen anzeigen",
                  detailText: "Zeigt beim Öffnen einer Ausgabe ein Hinweisfenster zum Fortsetzen an der zuletzt gelesenen Stelle  (Artikel, Seite oder ggf. Ressort).",
                  initialValue: reopenHintSetting,
                  onChange: {[weak self] newValue in
    self?.reopenHintSetting = newValue
    self?.resumeReadAccepted = 0
    self?.resumeReadDismissed = 0
  })
  
  lazy var reopenAutomaticSettingCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Automatisch Weiterlesen",
                  detailText: "Springt beim Öffnen einer Ausgabe automatisch zur zuletzt gelesenen Stelle (Artikel oder Seite), ohne Nachfrage.",
                  initialValue: reopenAutomaticSetting,
                  onChange: {[weak self] newValue in
    self?.reopenAutomaticSetting = newValue
    self?.reopenHintSettingCell.isEnabled = !newValue
    self?.resumeReadAccepted = 0
    self?.resumeReadDismissed = 0
  })
  
  lazy var reopenRessortSettingCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Ressort merken",
                  detailText: "Speichert in der App-Ansicht das zuletzt angezeigte Ressort. \nAchtung: Nach 'Zurück' vom Artikel wird bei 'Weiterlesen' nicht mehr der letzte Artikel aufgerufen, sondern das zuletzt angezeigte Ressort.",
                  initialValue: reopenRessortSetting,
                  onChange: {[weak self] newValue in
    self?.reopenRessortSetting = newValue
  })
  
  lazy var defaultToastsDisabledCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Standard Toast Nachrichten",
                  detailText: "Zeige Toasts bei Bookmarks und PDF Umschaltung (nur für @taz.de Accounts)",
                  initialValue: !defaultToastsDisabled,
                  onChange: {[weak self] newValue in
    self?.defaultToastsDisabled = !newValue })
  
  lazy var epaperLoadCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Zeitungsansicht immer mit laden",
                  initialValue: autoloadPdf,
                  onChange: {[weak self] newValue in
    self?.autoloadPdf = newValue })
  
  lazy var testServerCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Testserver",
                  detailText: "nur für @taz.de Accounts",
                  initialValue: useTestServer,
                  onChange: {[weak self] newValue in
    self?.useTestServer = newValue
    Toast.show("Zum Anwenden: App neu staren!")
  })
  
  
  
  lazy var deleteIssuesCell: XSettingsCell
  = XSettingsCell(text: "Alle Ausgaben löschen",
                  isDestructive: true,
                  tapHandler: {[weak self] in self?.requestDeleteAllIssues()} )
  ///notifications, mitteilungen
  var notificationsCell: NotificationsSettingsCell {
    
    let cell = NotificationsSettingsCell(
      toggleWithText: "Mitteilungen erlauben".lowerIfTaz,
      detailText: NotificationBusiness.sharedInstance.settingsDetailText,
      initialValue: isTextNotification,
      onChange: {[weak self] newValue in
        self?.isTextNotification = newValue
        TazAppEnvironment.sharedInstance.feederContext?.setupRemoteNotifications(force: true)
        NotificationBusiness.sharedInstance.updateSettingsDetailText()
        self?.refreshAndReload()
    })
    
    if NotificationBusiness.sharedInstance.settingsDetailTextAlert {
      cell.detailLabelTextColor = .red
      cell.applyStyles()
      (cell.customAccessoryView as? UISwitch)?.onTintColor = UIColor(white: 0.6, alpha: 1.0)
    }
    if NotificationBusiness.sharedInstance.settingsLink {
      cell.tapHandler = { NotificationBusiness.sharedInstance.openAppInSystemSettings() }
    }
    return cell
  }
  
  lazy var specialArticleNotificationCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Besonderer Artikel",
                    detailText: "Benachrichtigung in der Mitteilungszentrale für redaktionell ausgewählte Artikel",
                  initialValue: specialArticleSystemSetting,
                  onChange: {[weak self] newValue in
    self?.specialArticleSystemSetting = newValue })
  
  
  lazy var newIssueNotificationCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Neue Ausgabe",
                  detailText: "Benachrichtigung in der Mitteilungszentrale bei neuer Ausgabe",
                  initialValue: newIssueSystemSetting,
                  onChange: {[weak self] newValue in
    self?.newIssueSystemSetting = newValue })
  

  ///darstellung
  lazy var textSizeSettingsCell: XSettingsCell
  = XSettingsCell(text: "Textgröße (Inhalte)", accessoryView: TextSizeSetting())
  lazy var articleFromPdfCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Einfacher Tap",
                  detailText: "öffnen der mobil optimierten Artikelansicht",
                  initialValue: articleFromPdf,
                  onChange: {[weak self] newValue in self?.articleFromPdf = newValue })
  lazy var doubleTapToZoomPdfCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Doppel Tap",
                  detailText: "Zoom in PDF",
                  initialValue: doubleTapToZoomPdf,
                  onChange: {[weak self] newValue in self?.doubleTapToZoomPdf = newValue })
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
  
  lazy var usageCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Nutzungsdaten senden",
                  detailText: "anonym und sicher",
                  initialValue: usageTrackingAllowed,
                  onChange: {[weak self] newValue in
                    self?.usageTrackingAllowed = newValue
                  })
  
  ///erweitert
  lazy var edgeTapToNavigateCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Tap am Rand",
                  detailText: "Tap am unteren Rand einer Seite oder eines Artikels, um zu scrollen oder zum nächsten Element zu gelangen.",
                  initialValue: edgeTapToNavigate,
                  onChange: {[weak self] newValue in
    self?.edgeTapToNavigate = newValue
    Usage.track(Usage.event.tapEdge.state, name: newValue ? "Ein" : "Aus")
    (self?.edgeTapToNavigateVisibleCell.customAccessoryView as? UISwitch)?.isEnabled = newValue
  })
  lazy var edgeTapToNavigateVisibleCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Tap am Rand sichtbar",
                  detailText: "Bereich für \"Tap am Rand\" sichtbar (Alpha Feature)",
                  initialValue: edgeTapToNavigateVisible2,
                  onChange: {[weak self] newValue in
    self?.edgeTapToNavigateVisible2 = newValue
    Usage.track(Usage.event.tapEdge.visibility, name: newValue ? "Ein" : "Aus")

  })
  lazy var multiColumnSnapCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Mehrspaltigkeit einrasten",
                  detailText: "Beim manuellem Scrollen in der mehrspaltigen Ansicht automatisch Spaltenweise einrasten.",
                  initialValue: multiColumnSnap,
                  onChange: {[weak self] newValue in
    self?.multiColumnSnap = newValue
  })
  lazy var debuggingSwitchOneCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Debugging (intern)",
                  detailText: "Aktiviert einzelne experimentelle oder zu testende Umgebungsvariablen in Releasebuld. Aktuell: Bugfix in IPv4 Rechabillity funktioniert nicht",
                  initialValue: debuggingSwitchOne,
                  onChange: {[weak self] newValue in
    self?.debuggingSwitchOne = newValue
  })
  lazy var openLinksInAppCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Links in der App öffnen",
                  detailText: "Artikel-Links zu taz.de in der App öffnen, sofern der entsprechende Inhalt lokal verfügbar ist.",
                  ///später, wenn laden implementiert: Artikel-Links zu taz.de nach Möglichkeit in der App statt im Browser öffnen.
                  initialValue: openLinksInApp,
                  onChange: {[weak self] newValue in
    self?.openLinksInApp = newValue
  })
  lazy var multiColumnFixedScrollingCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Mehrspaltigkeit gleichmäßiges Scrollen",
                  detailText: "In der mehrspaltigen Ansicht bei 'Tap am Rand' immer die gleiche Anzahl von Spalten weiterscrollen.\nDies wirkt sich nur beim 'vorwärts Tap' auf dem letzten Bildschirmbereich (Seite) aus und kann dazu führen, dass dort nur eine dicke Linie zu sehen ist.",
                  initialValue: multiColumnFixedScrolling,
                  onChange: {[weak self] newValue in
    self?.multiColumnFixedScrolling = newValue
  })
  lazy var tabbarInSectionCellALPHA: XSettingsCell
  = XSettingsCell(toggleWithText: "Zeige Tabbar auf Sectionebene",
                  detailText: "Alpha Feature",
                  initialValue: tabbarInSection,
                  onChange: {[weak self] newValue in
                    self?.tabbarInSection = newValue
                  })
  
  lazy var animateArticleSectionChangeCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Animierte Ressortwechsel auf Artikelebene",
                  detailText: "Alpha Feature",
                  initialValue: animateArticleSectionChange,
                  onChange: {[weak self] newValue in
                    self?.animateArticleSectionChange = newValue
                  })
  
  
  lazy var smartBackFromArticleCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Intelligentes Zurück",
                  detailText: "Zurück im Artikel führt zu zugehörigem Ressort",
                  initialValue: smartBackFromArticle,
                  onChange: {[weak self] newValue in
                    self?.smartBackFromArticle = newValue
                  })
  
  lazy var hideToolbarCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Toolbar ausblenden",
                  detailText: "Automatisches ausblenden der Toolbar in Artikel- und Zeitungsansicht.\nAchtung: bei aktiver Vorlesefunktion oder Demo Inhalten blendet die Toolbar ebenfalls nicht aus.",
                  initialValue: autoHideToolbar,
                  onChange: {[weak self] newValue in
                    self?.autoHideToolbar = newValue
                  })
  
  lazy var showHelpCell: XSettingsCell
  = XSettingsCell(toggleWithText: "Hilfe anzeigen",
                  initialValue: showHelp,
                  onChange: {[weak self] newValue in
    self?.showHelp = newValue
    if newValue == true {
      HelpBusiness.shared.resetHelp()
      Toast.show("Hilfe zurückgesetzt!")
    }
  })
  
  lazy var memoryUsageCell: XSettingsCell
  = XSettingsCell(text: "Speichernutzung",
                  detailText: storageDetails,
                  tapHandler: {[weak self] in
    self?.log("StorageDetails tapped")
  })
  
  lazy var deleteDatabaseCell: XSettingsCell
  = XSettingsCell(text: "Daten zurücksetzen",
                  isDestructive: true,
                  tapHandler: {[weak self] in self?.requestDatabaseDelete()} )
  lazy var resetAppCell: XSettingsCell
  = XSettingsCell(text: "App in Auslieferungszustand zurück versetzen",
                  isDestructive: true,
                  tapHandler: {[weak self] in self?.requestResetApp()} )
  
  lazy var sendFailureRequestCell: XSettingsCell
  = XSettingsCell(text: "Sende fehlerhaften Page Request für die Ausgabenübersicht",
                  detailText: "ALPHA-App :: erneut antippen zum Wechsel",
                  isDestructive: true,
                  tapHandler: {[weak self] in
    self?.sendFailureRequestToServer = !(self?.sendFailureRequestToServer ?? true)
    Toast.show("Nachfolgende Page Requests sind: \(self?.sendFailureRequestToServer == true ? "fehlerhaft" : "normal")")
  })
    
  lazy var deleteSearchResultsFolder: XSettingsCell
  = XSettingsCell(text: "Lösche Search Results Folder",
                  detailText: "ALPHA-App!",
                  isDestructive: true,
                  tapHandler: {[weak self] in
    Dir.searchResults.remove()
  })
  
  lazy var contentChangeSettingCellALPHA: XSettingsCell
  = XSettingsCell(toggleWithText: "Zeige Toolbar bei Artikelwechsel",
                  detailText: "Alpha Feature",
                  initialValue: showBarsOnContentChange,
                  onChange: {[weak self] newValue in
    self?.showBarsOnContentChange = newValue })
  
  /// UI Components
  lazy var footer:Footer = Footer()
  
  lazy var header:SettingsHeaderView = {
    let v = SettingsHeaderView()
    v.titletype = .bigLeft
    v.title = App.isLMD ? "Einstellungen" : "einstellungen"
    return v
  }()
  
  private lazy var settingsTable:UITableView = {
    let tv = UITableView(frame: .zero, style: .grouped)
    tv.estimatedRowHeight = 100.0
    tv.separatorInset = .zero
    if #available(iOS 15.0, *) {
      tv.sectionHeaderTopPadding = 0
    }
    tv.dataSource = self
    tv.delegate = self
    
    let longTap = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTap(sender:)))
    tv.addGestureRecognizer(longTap)
    
    tv.tableFooterView = footer
    tv.bounces = true
    return tv
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
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    self.view.addSubview(header)
    pin(header, to: self.view, exclude: .bottom)
    
    self.view.addSubview(settingsTable)
    pin(settingsTable, to: self.view, exclude: .top)

    pin(settingsTable.top, to: header.bottom, dist: -2)
    
    data = TableData(sectionContent: currentSectionContent())
    setup()

    initialTextNotificationSetting = isTextNotification
    $articleFromPdf.onChange{[weak self] _ in
      guard let self = self else { return }
      (self.articleFromPdfCell.customAccessoryView as? UISwitch)?.isOn = self.articleFromPdf
    }
    $doubleTapToZoomPdf.onChange{[weak self] _ in
      guard let self = self else { return }
      (self.doubleTapToZoomPdfCell.customAccessoryView as? UISwitch)?.isOn = self.doubleTapToZoomPdf
    }
    $reopenHintSetting.onChange{[weak self] _ in
      guard let self = self else { return }
      (self.reopenHintSettingCell.customAccessoryView as? UISwitch)?.isOn = self.reopenHintSetting
    }
    $reopenAutomaticSetting.onChange{[weak self] _ in
      guard let self = self else { return }
      (self.reopenAutomaticSettingCell.customAccessoryView as? UISwitch)?.isOn = self.reopenAutomaticSetting
    }
    $showHelp.onChange{[weak self] _ in
      guard let self = self else { return }
      (self.showHelpCell.customAccessoryView as? UISwitch)?.isOn = self.showHelp
    }
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    checkNotifications()
    trackScreen()
    memoryUsageCell.detailTextLabel?.text = storageDetails
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
    NotificationBusiness.sharedInstance.checkNotificationStatus {
      onMain {[weak self] in
        self?.refreshAndReload()
      }
    }
  }
  
  public func applyStyles() {
    settingsTable.backgroundColor = Const.SetColor.HBackground.color
    if let toggle = self.darkmodeSettingsCell.customAccessoryView as? UISwitch,
       toggle.isOn != Defaults.darkMode {
      toggle.isOn = Defaults.darkMode
    }
  }
  
  func setup(){
    settingsTable.separatorInset = .zero
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
      settingsTable.reloadData()
      return
    }
    
    let diff = data.changedIndexPaths(oldData: oldData)
        
    if (diff.added.count + diff.deleted.count) == 0 {
      settingsTable.reloadData()
      return
    }
    
    self.settingsTable.performBatchUpdates {   [weak self] in
      guard let self = self else { return }
      if diff.deleted.count > 0 {
        self.settingsTable.deleteRows(at: diff.deleted, with: .fade)
      }
      
      if diff.added.count > 0 {
        self.settingsTable.insertRows(at: diff.added, with: .fade)
      }
    }
  }
  
  @objc private func handleLongTap(sender: UILongPressGestureRecognizer) {
    if sender.state == .began {
      let touchPoint = sender.location(in: settingsTable)
      guard let indexPath = settingsTable.indexPathForRow(at: touchPoint) else { return }
      data.cell(at: indexPath)?.longTapHandler?()
    }
  }
}

// MARK: - UITableViewDataSource
extension SettingsVC: UITableViewDataSource, UITableViewDelegate {
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return data.rowsIn(section: section)
  }
  
  public func numberOfSections(in tableView: UITableView) -> Int {
    return data.sectionsCount
  }
  
  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return data.cell(at: indexPath) ?? UITableViewCell()
  }
  
  public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let sectionData = data.sectionData(for: section),
          let title = sectionData.title else { return nil }
    let header = SectionHeader(text:title, collapseable: sectionData.collapseable)
    if section == data.sectionsCount - 1 {
      header.label.accessibilityLabel = "\(title) \(self.extendedSettingsCollapsed ? "zum öffnen doppelt tippen" : "geöffnet")"
      header.label.accessibilityTraits = .header
    }
    header.collapsed = self.extendedSettingsCollapsed
    header.onTapping { [weak self] _ in
      guard let self = self else { return }
      ///WARNING IN CASE OF SETTINGS CHANGE THE EXPAND EXTENDED SETTINGS DID NOT WORK!
      guard section == data.sectionsCount - 1 else { return }
      guard let sectionData = self.data.sectionData(for: section) else { return }
      guard sectionData.collapseable else { return }
      self.extendedSettingsCollapsed = !self.extendedSettingsCollapsed
      header.collapsed = self.extendedSettingsCollapsed
      self.refreshAndReload()
    }
    return header
  }
  
  public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    return section == data.sectionsCount - 1 ? footer : nil
  }
  
  public func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
    view.backgroundColor = .clear
  }
  
  public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return data.footerHeight(for: section)
  }
  
  public func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    return data.canTap(at: indexPath) ? indexPath : nil
  }
  
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
      background.backgroundColor = Const.SetColor.HBackground.color
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
  
  var showPasswordCell: Bool {
    if isAuthenticated == false { return true }///all not logged in users
    guard let uid = SimpleAuthenticator.getUserData().id else { return true }///also not logged in
    if uid.hasSuffix("@taz.de") { return false }
    return uid.isValidEmail()//All E-Mails, not 12345 Abo-ID's not SpecialLoginForGroups
  }
  
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
    var cells = [isAuthenticated ? logoutCell : loginCell]

    if App.isLMD {
      cells.append(notificationsCell)
      return cells
    }
    
    cells.append(manageAccountCell)
    
    if showPasswordCell {
      cells.insert(resetPasswordCell, at: 1)
    }
    if showDeleteAccountCell {
      cells.append(deleteAccountCell)
    }
    cells.append(notificationsCell)
    cells.append(newIssueNotificationCell)
    cells.append(specialArticleNotificationCell)
    return cells
  }
  
  var issueSettingsCells:[XSettingsCell] {
    var cells = [
      maxIssuesCell,
      autoloadNewIssuesCell
    ]
    
    if autoloadNewIssues {
      cells.append(wlanCell)
    }
    
    #if TAZ
    cells.append(epaperLoadCell)
    #endif
    if autoloadNewIssues {
      cells.append(autoloadAudioCell)
      cells.append(autoloadNotificationsCell)
    }
    cells.append(deleteIssuesCell)
    return cells
  }
  
  var extendedSettingsCells:[XSettingsCell] {
    (edgeTapToNavigateVisibleCell.customAccessoryView as? UISwitch)?.isEnabled = edgeTapToNavigate
    var cells =  [
      openLinksInAppCell,
      memoryUsageCell,
      deleteDatabaseCell,
      resetAppCell
    ]
    
    if App.isTAZ {///only for taz
      ///in LMd this is required for page Header, otherwise current page is not displayed correctly
      cells.insert(smartBackFromArticleCell, at: 0)
      ///reopen only work in app view, noit available in LMd
    }
    
    if Device.isIpad {
      cells.insert(multiColumnFixedScrollingCell, at: 1)
      cells.insert(multiColumnSnapCell, at: 1)
    }
    
    if Device.isIphone {
      cells.insert(hideToolbarCell, at: 0)
    }
    
    if isSpecialSettingAvailable {
      cells.append(debuggingSwitchOneCell)
      cells.append(sendFailureRequestCell)
      cells.append(deleteSearchResultsFolder)
      cells.append(contentChangeSettingCellALPHA)
      cells.append(tabbarInSectionCellALPHA)
      cells.append(animateArticleSectionChangeCell)
    }

    if DefaultAuthenticator.isTazLogin
    || isSpecialSettingAvailable
    {
      cells.append(defaultToastsDisabledCell)
    }
    
    if DefaultAuthenticator.isTazLogin
        || isSpecialSettingAvailable
        || useTestServer {
      cells.append(testServerCell)
    }

    return cells
  }
  
  //Prototype Cells
  func currentSectionContent() -> [tSectionContent] {
    ///**WARNING IN CASE OF SETTINGS CHANGE THE EXPAND EXTENDED SETTINGS DID NOT WORK!
    #if TAZ
    let rechtlichesCells = [termsCell, privacyCell, usageCell]
    #else
    let rechtlichesCells = [termsCell, privacyCell, revokeCell]
    #endif
    
    reopenHintSettingCell.isEnabled = !reopenAutomaticSetting
    
    let displayCells
    = App.isAlpha
    ? [textSizeSettingsCell, darkmodeSettingsCell, edgeTapToNavigateCell, edgeTapToNavigateVisibleCell]
    : [textSizeSettingsCell, darkmodeSettingsCell, edgeTapToNavigateCell]
    
    return [
      ("Konto".lowerIfTaz, false, accountSettingsCells),
      ("Ausgabenverwaltung".lowerIfTaz, false, issueSettingsCells),
      ("Darstellung".lowerIfTaz, false, displayCells),
      (  App.isTAZ
         ? "steuerung in der Zeitungsansicht"
         : "Steuerung in der Zeitungsansicht", false,
       [
        articleFromPdfCell,
        doubleTapToZoomPdfCell
       ]
      ),
      ("Weiterlesen".lowerIfTaz, false, [reopenHintSettingCell, reopenAutomaticSettingCell, reopenRessortSettingCell]
      ),
      ("Hilfe".lowerIfTaz, false,
       [
        showHelpCell,
        onboardingCell,
        faqCell,
        reportErrorCell,
        feedbackCell
       ]
      ),
      ("Rechtliches".lowerIfTaz, false, rechtlichesCells),
      ///WARNING IN CASE OF SETTINGS CHANGE THE EXPAND EXTENDED SETTINGS DID NOT WORK!
      ("Erweitert".lowerIfTaz, true,
       extendedSettingsCollapsed ? [] : extendedSettingsCells
      )
    ]
  }
}

// MARK: - SettingsVC Extension
extension SettingsVC {
  var isSpecialSettingAvailable: Bool {
    let uid = SimpleAuthenticator.getUserData().id
    if App.isAlpha { return true}
    if Device.isSimulator { return true}
    if uid == "145489" { return true}
    if uid == "ringo.mueller@taz.de" { return true}
    return false
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
      TazAppEnvironment.sharedInstance.deleteUserData(resetAppState: false)
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
    
    alert.presentAt(self.logoutCell)
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
      text = "Webseite zum Löschen Ihres Kontos aufrufen?"
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
    
    alert.presentAt(self.deleteAccountCell)
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
    let isDownloading = TazAppEnvironment.sharedInstance.feederContext?.dloader.isDownloading == true
    
    let title = isDownloading ? "Achtung aktiver Download" : "Alle Ausgaben löschen?"
    let message = isDownloading ? "Möchten Sie den Download abbrechen und alle Ausgaben löschen?" : nil
    
    let alert = UIAlertController.init( title: title, message: message,
                                        preferredStyle:  .alert )
    alert.addAction( UIAlertAction.init( title: "Löschen", style: .destructive,
                                         handler:  { [weak self] _ in
      guard let storedFeeder = TazAppEnvironment.sharedInstance.feederContext?.storedFeeder,
            let storedFeed = storedFeeder.storedFeeds.first else {
        return
      }
      if isDownloading {
        TazAppEnvironment.sharedInstance.feederContext?.stopDownloadsAndResetDownloader()
      }
      Notification.send(Const.NotificationNames.closeOpenIssues)
      TazAppEnvironment.sharedInstance.feederContext?.openedIssue = nil
      StoredIssue.deleteAllIssues(feed: storedFeed)
      onMainAfter { [weak self] in
        self?.refreshAndReload()
        self?.memoryUsageCell.detailTextLabel?.text = self?.storageDetails
        Notification.send(Const.NotificationNames.refreshOverview)
        TazAppEnvironment.sharedInstance.feederContext?.checkForNewIssues()
      }
    } ) )//eof: alert.addAction
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.deleteIssuesCell)
  }
  
  func requestDatabaseDelete(){
    let alert = UIAlertController.init( title: "Daten zurücksetzen", message: "Falls diese App wiederholt ungewollt beendet wird, benutzen Sie diese Aktion. Die App wird nach Ausführung der Aktion automatisch beendet und kann von Ihnen erneut gestartet werden.\nBei dieser Aktion bleiben viele Daten erhalten, es wird nur eine geringe Menge Daten zum Abgleich der Ausgaben erneut heruntergeladen.\nBitte nutzen Sie auch auch unsere \"Fehler melden\" Funktion um uns Fehler in der App mitzuteilen!\nAchtung, es werden auch die Lesezeichen gelöscht.",
                                        preferredStyle:  .actionSheet)
    
    alert.addAction( UIAlertAction.init( title: "Daten zurücksetzen", style: .destructive,
                                         handler: { _ in
      TazAppEnvironment.sharedInstance.reset(isDelete: true)
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.deleteDatabaseCell)
  }
  
  func requestResetApp(){
    let alert = UIAlertController.init( title: "App in Auslieferungszustand zurück versetzen", message: "Löscht alle Daten und Einstellungen der App.\nDie App wird nach dem Zurücksetzen beendet und kann von Ihnen neu gestartet werden. Sie müssen sich im Anschluss neu anmelden.",
                                        preferredStyle:  .actionSheet )
    
    
    alert.addAction( UIAlertAction.init( title: "Zurücksetzen", style: .destructive,
                                         handler: { _ in
      TazAppEnvironment.sharedInstance.deleteUserData(resetAppState: true)
      Defaults.singleton.setDefaults(values: ConfigDefaults,
                                     isNotify: false,
                                     forceWrite: true)
      HelpBusiness.shared.resetHelp()
      TazAppEnvironment.sharedInstance.deleteAll()
    } ) )
    
    alert.addAction( UIAlertAction.init( title: "Abbrechen", style: .cancel) { _ in } )
    alert.presentAt(self.resetAppCell)
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
    if StoreBusiness.canRegister == false {
      Alert.message(message: "Leider können wir Ihnen keinen direkten Link zu unseren häufig gestellten Fragen zur App (App-FAQ) anbieten. Sie finden diese Informationen auf unserer Webseite.")
      return
    }
    guard let url = Const.Urls.faqUrl else { return }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
  }
  
  func showLocalHtml(from urlString:String, scrollEnabled: Bool){
    let introVC = TazIntroVC()
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
      ///Overwrite Default in: IntroVC viewDidLoad, hide Accept Button from former ux
      introVC.webView.buttonLabel.text = nil
    }
  }
}

// MARK: - Nested Classes / UI Components

// MARK: -
class XSettingsCell:UITableViewCell, UIStyleChangeDelegate {
  var padding = 10.0
  var tapHandler:(()->())?
  var isDestructive: Bool = false
  var isEnabled: Bool = true {
    didSet {
      self.isUserInteractionEnabled = isEnabled
      self.textLabel?.alpha = isEnabled ? 1.0 : 0.4
      self.detailTextLabel?.alpha = isEnabled ? 1.0 : 0.5
      self.customAccessoryView?.alpha = isEnabled ? 1.0 : 0.4
      (self.customAccessoryView as? UISwitch)?.isEnabled = isEnabled
      if isEnabled {
        self.accessibilityLabel = "Weiterlesen anzeigen"
        self.accessibilityValue = (self.customAccessoryView as? UISwitch)?.isOn ?? false ? "Ein" : "Aus"
        self.accessibilityHint = "Zeigt beim Öffnen der Ausgabe ein Hinweisfenster zum Fortsetzen an."
      } else {
        self.accessibilityLabel = "Weiterlesen anzeigen, deaktiviert"
        self.accessibilityValue = "Nicht verfügbar"
        self.accessibilityHint = "Nicht änderbar, da 'Automatisch Weiterlesen' aktiviert ist."
      }
    }
  }
  var longTapHandler:(()->())?
  private var toggleHandler: ((Bool)->())?
  
  fileprivate(set) var customAccessoryView:UIView?
  
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
    registerForStyleUpdates()
    guard let label = self.textLabel else { return }
    
    let dist = Const.ASize.DefaultPadding
    
    if let av = self.customAccessoryView {
      av.setNeedsUpdateConstraints()
      av.setNeedsLayout()
      av.updateConstraintsIfNeeded()
      av.layoutIfNeeded()
      self.contentView.addSubview(av)
      av.pinWidth(av.bounds.size.width, priority: .defaultHigh)
      pin(av.right, to: contentView.right, dist: -dist)
      if self.detailTextLabel == nil{
        av.centerY()
      }
      else {
        pin(av.top, to: self.contentView.top, dist: padding)
      }
      pin(label.right, to: av.left, dist: -dist)
      label.heightAnchor.constraint(greaterThanOrEqualToConstant: av.frame.size.height).isActive = true
    }
    else {
      pin(label.right, to: contentView.right, dist: -dist)
    }
    
    pin(label.left, to: contentView.left, dist: dist)
    pin(label.top, to: contentView.top, dist: padding, priority: .defaultHigh)
    
    if let dtl = self.detailTextLabel{
      pin(label.bottom, to: dtl.top)
    }
    else {
      pin(label.bottom, to: contentView.bottom, dist: -padding, priority: .defaultHigh)
    }
    
    if let subLabel = self.detailTextLabel {
      pin(subLabel.left, to: contentView.left, dist: dist)
      pin(subLabel.right, to: contentView.right, dist: -dist)
      pin(subLabel.bottom, to: contentView.bottom, dist: -padding)
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


class NotificationsSettingsCell:XSettingsCell {
  
  var detailLabelTextColor: UIColor?
  
  override func setupLayout() {
    padding = 30.0
    super.setupLayout()
  }
  
  override func applyStyles() {
    super.applyStyles()
    self.textLabel?.titleFont(size: Const.Size.SubtitleFontSize)
    self.detailTextLabel?.textColor
    = detailLabelTextColor ?? Const.SetColor.ios(.secondaryLabel).color
  }
  
  init(toggleWithText text: String,
       detailText: NSAttributedString,
       initialValue:Bool,
       onChange: @escaping ((Bool)->())){
    super.init(toggleWithText: text, detailText: ".", initialValue: initialValue, onChange: onChange)
    self.detailTextLabel?.attributedText = detailText
    setupLayout()
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
    leftButton.accessibilityLabel = "kleiner"
    rightButton.accessibilityLabel = "größer"
    
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
class SectionHeader: UIView, UIStyleChangeDelegate {
  
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
  
  
  func applyStyles() {
    label.textColor =  Const.SetColor.ios(.label).color
    self.backgroundColor = Const.SetColor.HBackground.color
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
    registerForStyleUpdates()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class SettingsHeaderView: HeaderView {
}

extension String {
  var lowerIfTaz:String {
    return App.isTAZ ? self.lowercased() : self
  }
}
