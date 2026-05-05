//
//  MainNC.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import NorthLib
import UIKit

class MainTabVC: UITabBarController, UIStyleChangeDelegate {

  @Default("showHelp")
  var showHelp: Bool
  
  var feederContext: FeederContext
  var service: IssueOverviewService
  
  lazy var helpButton = HelpButton()
  var helpButtonBottomConstraint: NSLayoutConstraint?
  var helpButtonDefaultBottomDistance: CGFloat = 0.0
  
  var helpButtonPlayerOffset = 0.0 {
    didSet {
      guard oldValue != helpButtonPlayerOffset else { return }
      updateHelpButtonBottomConstraint()
    }
  }
  
  var helpButtonToolbarOffset = 0.0 {
    didSet {
      guard oldValue != helpButtonToolbarOffset else { return }
      updateHelpButtonBottomConstraint()
    }
  }
  
  var helpButtonAdditionalSheetOffset = 0.0 {
    didSet {
      guard oldValue != helpButtonAdditionalSheetOffset else { return }
      updateHelpButtonBottomConstraint()
    }
  }
  
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool

  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    TazAppEnvironment.sharedInstance.nextWindowSize = size
    Notification.send(Const.NotificationNames.viewSizeTransition,
                      content: size,
                      error: nil,
                      sender: nil)
    coordinator.animate(alongsideTransition: {_ in
    }, completion: {[weak self] _ in
      self?.updateTraitOverrides()
        self?.view.setNeedsLayout()
        self?.view.layoutIfNeeded()
    })
  }
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    Notification.send(Const.NotificationNames.traitCollectionDidChange,
                      content: self.traitCollection,
                      error: nil,
                      sender: nil)
    updateTraitOverrides()
  }
  
  private func updateTraitOverrides() {
    guard #available(iOS 18.0, *),
          Device.isIpad else { return }
    // Update the current size class to display original design
    traitOverrides.horizontalSizeClass = .unspecified
    if let original = UIWindow.activeKeyWindow?.traitCollection.horizontalSizeClass {
      // Updates every tab with the window size class
      viewControllers?.forEach { $0.traitOverrides.horizontalSizeClass = original }
      // restore Tabbar's size class: if enought space name left of icon
      tabBar.traitOverrides.horizontalSizeClass = original
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateTraitOverrides()
    setupHelpButton()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    /// **HACK iOS 28 Home Button iPhones e.g. iPhone SE3**
    /// move Tabbar Position down to avoid content cut off
    ///
    #warning("ToDO 1.6.0: deactivated moves tabbar on modern phones to low on home")
    //    if #available(iOS 26.0, *), let superview = tabBar.superview {
//      var frame = tabBar.frame
//      frame.origin.y = superview.bounds.height - 58
//      tabBar.frame = frame
//    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard let data = TazAppEnvironment.openedFromNotificationCenter else { return }
    TazAppEnvironment.openedFromNotificationCenter = nil
    gotoArticleInIssue(with: data)
  }
  
  override var selectedIndex: Int {
    didSet {
      if let vc = self.selectedViewController {
        self.tabBarController(self, didSelect: vc)
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupTabbar()
    self.navigationController?.isNavigationBarHidden = true
    registerForStyleUpdates()
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { [weak self] notif in
      self?.authenticationSucceededCheckReload(alertMessage: (notif.content as? String))
    }
    
    Notification.receive(Const.NotificationNames.searchSelectedText) { [weak self] notif in
      guard let searchString = notif.content as? String,
      let searchCtrl
              = ((self?.viewControllers?.valueAt(2) as? UINavigationController)?
        .viewControllers.first as? SearchController) else { return }
      self?.selectedIndex = 2
      searchCtrl.searchFor(searchString: searchString)
    }

    Notification.receive(Const.NotificationNames.gotoSettings) { [weak self] notif in
      self?.selectedIndex = 3
    }
    
    Notification.receive(Const.NotificationNames.closeOpenIssues) { [weak self] _ in
      (self?.viewControllers?.first as? UINavigationController)?.popToRootViewController(animated: false)
    }
    
    Notification.receive(Const.NotificationNames.gotoIssue) { [weak self] notif in
      self?.gotoIssue(at: notif.content as? Date)
    }
    
    Notification.receive(Const.NotificationNames.gotoArticleInIssue) { [weak self] notif in
      self?.selectedIndex = 0
      if let data = notif.content as? PushNotification.Payload.ArticlePushData {
        self?.gotoArticleInIssue(with: data)
        return 
      }
      else if let data = notif.content as? ArticleLinkOpen {
        self?.gotoArticleInIssue(with: data.issueDate, articleUrl: data.articleUrl)
        return
      }
      guard let article = notif.content as? Article else { return }
      self?.gotoArticleInIssue(article: article)
    }
    
    Notification.receive("issue") { [weak self] notification in
      self?.handleIssueDownloadNotification(notification: notification)
    }
    Notification.receive(Const.NotificationNames.issueUpdate) { [weak self] notification in
      self?.handleIssueDownloadNotification(notification: notification)
    }
  } // viewDidLoad
  
  var searchArticleToOpen: SearchArticle?
  
  func handleIssueDownloadNotification(notification: Notification){
    guard let art = searchArticleToOpen,
          art.originalIssueDate != nil,
          let issue = (notification.content as? Issue)
                    ?? (notification.content as? IssueCellData)?.issue,
          art.originalIssueDate?.issueKey == issue.date.issueKey else { return }
    openArticleFromSearch(article: art)
  }
  
  var isLoadingIssueInBackground = false
  
  func showLoadingOverlayIfNeeded(data: PushNotification.Payload.ArticlePushData){
    if isLoadingIssueInBackground { return }
    isLoadingIssueInBackground = true
    let snap = UIWindow.activeKeyWindow?.snapshotView(afterScreenUpdates: false)
    WaitingAppOverlay.show(alpha: 1.0,
                           backbround: snap,
                           showSpinner: true,
                           titleMessage: "Aktualisiere Daten",
                           bottomMessage: "lade \"\(data.articleTitle ?? "Artikel")\" aus Ausgabe: \(data.articleDate.short)\nBitte haben Sie einen Moment Geduld!",
                           dismissNotification: Const.NotificationNames.removeRefreshDataOverlay)
    onMainAfter(7.0) {[weak self] in
      Notification.send(Const.NotificationNames.removeRefreshDataOverlay)
      self?.isLoadingIssueInBackground = false
    }
  }
  
  func gotoArticleInIssue(with data: PushNotification.Payload.ArticlePushData){
    log("open issue with date: \(data.articleDate) and Article: \(data.articleTitle ?? "\(data.articleMsId)")")
    guard let issue = self.service.issue(at: data.articleDate) else {
      showLoadingOverlayIfNeeded(data: data)
      Notification.receiveOnce(Const.NotificationNames.issueUpdate) { [weak self] _ in self?.gotoArticleInIssue(with: data)}
      service.download(issueAt: data.articleDate, withAudio: false)
      gotoIssue(at: data.articleDate)
      return
    }
    if feederContext.needsUpdate(issue: issue, toShowPdf: self.service.isFacsimile) {
      showLoadingOverlayIfNeeded(data: data)
      Notification.receiveOnce("issue") { [weak self] _ in self?.gotoArticleInIssue(with: data)}
      service.download(issueAt: data.articleDate, withAudio: false)
      gotoIssue(at: data.articleDate)
      return
    }
    
    guard let issueArtIndex = issue.indexOfArticle(with: data.articleMsId),
          let artInTargetIssue = issue.allArticles.valueAt(issueArtIndex) else {
      gotoIssue(at: data.articleDate)
      return
    }
    gotoArticleInIssue(article: artInTargetIssue)
    onMainAfter(0.6) {[weak self] in
      Notification.send(Const.NotificationNames.removeRefreshDataOverlay)
      self?.isLoadingIssueInBackground = false
    }
  }
  
  func gotoArticleInIssue(with issueDate: Date, articleUrl: URL) {
    log("open issue with date: \(issueDate) and Article: \(articleUrl)")
    guard let issue = self.service.issue(at: issueDate) else {
      Notification.receiveOnce(Const.NotificationNames.issueUpdate) { [weak self] _ in self?.gotoArticleInIssue(with: issueDate, articleUrl: articleUrl)
      }
      service.download(issueAt: issueDate, withAudio: false)
      gotoIssue(at: issueDate)
      return
    }
    if feederContext.needsUpdate(issue: issue, toShowPdf: self.service.isFacsimile) {
      Notification.receiveOnce("issue") { [weak self] _ in self?.gotoArticleInIssue(with: issueDate, articleUrl: articleUrl)
      }
      service.download(issueAt: issueDate, withAudio: false)
      gotoIssue(at: issueDate)
      return
    }
    
    guard let issueArtIndex = issue.indexOfArticle(with: articleUrl),
          let artInTargetIssue = issue.allArticles.valueAt(issueArtIndex) else {
      gotoIssue(at: issueDate)
      return
    }
    gotoArticleInIssue(article: artInTargetIssue)
  }
  
  
  func gotoArticleInIssue(article: Article){
    if let art = article as? SearchArticle {
      self.openArticleFromSearch(article: art)
      return
    }
    self.searchArticleToOpen = nil
    guard let issue = article.primaryIssue as? StoredIssue,
          let home = ((self.selectedViewController as? UINavigationController)?
            .viewControllers.first as? HomeVC) else { return }
    if let sectVc = home.navigationController?.viewControllers.valueAt(1) as? SectionVC,
       let sectIssue = sectVc.issue as? StoredIssue,
       issue == sectIssue {
      sectVc.showArticle(article, animated: true)
    }
    else {
      home.navigationController?.popToRootViewController(animated: false)
      issue.lastArticle = issue.indexOf(article: article)
      if isFacsimile, let page = issue.pageIndexOf(article: article) { issue.lastPage = page }
      home.openIssue(issue, openLast: true)
    }
  }
  
  func openArticleFromSearch(article: SearchArticle){
    guard let date = article.originalIssueDate else {
      gotoIssue(at: nil)
      return
    }
    searchArticleToOpen = article
    guard let issue = self.service.issue(at: date) else {
      service.download(issueAt: date, withAudio: false)
      gotoIssue(at: date)
      return
    }
    if feederContext.needsUpdate(issue: issue, toShowPdf: self.service.isFacsimile) {
      service.download(issueAt: date, withAudio: false)
      gotoIssue(at: date)
      return
    }
    
    guard let issueArtIndex = issue.indexOf(article: article),
          let artInTargetIssue = issue.allArticles.valueAt(issueArtIndex) else {
      gotoIssue(at: date)
      return
    }
    gotoArticleInIssue(article: artInTargetIssue)
  }
  
  func gotoIssue(at date: Date?){
    self.selectedIndex = 0
    (self.selectedViewController as? UINavigationController)?.popToRootViewController(animated: false)
    guard let date = date,
        let home = ((self.selectedViewController as? UINavigationController)?
              .viewControllers.first as? HomeVC) else { return }
    let idx = home.service.nextIndex(for: date)
    home.collectionView
      .scrollToItem(at: IndexPath(row: idx, section: 0),
                    at: home.isHomeTiles ? .centeredVertically : .centeredHorizontally,
                    animated: true)
  }
  
  func setupTabbar() {
    self.tabBar.barTintColor = Const.Colors.iOSDark.secondarySystemBackground
    self.tabBar.backgroundColor = Const.Colors.iOSDark.secondarySystemBackground
    self.tabBar.isTranslucent = false
    self.tabBar.tintColor = .white
    
    let home = HomeVC(service: service, feederContext: feederContext)
    home.title = "Home"

    // generate TabBarItem
    let homeItem = UITabBarItem(
        title: "Home",
        image: UIImage(named: "home")?.tabBarSizedIcon(),
        selectedImage: nil
    )

    homeItem.accessibilityLabel = "Home"
    homeItem.accessibilityValue = "Doppelt tippen, um zur aktuellen Ausgabe zu gelangen."
    home.tabBarItem = homeItem
    home.tabBarItem.image = UIImage(named: "home")?.tabBarSizedIcon()
    
    let homeNc = NavigationController(rootViewController: home)
    homeNc.isNavigationBarHidden = true
    
    let bookmarksOverview = BookmarkTVC()
    let bookmarksNc = NavigationController(rootViewController: bookmarksOverview)
    bookmarksNc.title = "Leseliste"
    bookmarksNc.tabBarItem.image = UIImage(named: "star")?.tabBarSizedIcon()
    bookmarksNc.isNavigationBarHidden = true
    
    let search = SearchController(feederContext: feederContext )
    search.title = "Suche"
    search.tabBarItem.image = UIImage(named: "search-magnifier")?.tabBarSizedIcon()
    
    let searchNc = NavigationController(rootViewController: search)
    searchNc.isNavigationBarHidden = true
    
    let settings = SettingsVC(feederContext: feederContext)
    settings.title = "Einstellungen"
    settings.tabBarItem.image = UIImage(named: "settings")?.tabBarSizedIcon()

    self.viewControllers = [homeNc, bookmarksNc, searchNc, settings]
    self.selectedIndex = 0
    helpButton.alpha = 1.0
  }
  
  override var viewControllers: [UIViewController]? {
    didSet {
      setupNavigationDelegate()
    }
  }
  
  func setupNavigationDelegate(){
    for case let nc as UINavigationController in viewControllers ?? [] {
      nc.delegate = self
      (nc as? NavigationController)?.navigationDelegate = self
    }
  }
  
  func applyStyles() {
    self.view.backgroundColor = .clear
    setNeedsStatusBarAppearanceUpdate()
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return Defaults.darkMode ?  .lightContent : .default
  }
  
  required init(feederContext: FeederContext, service: IssueOverviewService) {
    self.feederContext = feederContext
    self.service = service
    super.init(nibName: nil, bundle: nil)
    delegate = self
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
} // MainTabVC

// MARK: - extension UINavigationControllerDelegate: magic tracking on VC show
extension MainTabVC: NavigationDelegate, UINavigationControllerDelegate {
  
  func popViewController() {
    Usage.shared.popViewController()
  }
  
  func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
    ///delegate nto usage
    Usage.shared.navigationController(navigationController, willShow: viewController, animated: animated)
  }
  
  func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
    Notification.send(Const.NotificationNames.helpProviderChanged)
  }
}


extension MainTabVC {
  /// Check whether it's necessary to reload the current Issue
  /// - Parameter alertMessage: optional alert message e.g. shown if reactivated subscription
  public func authenticationSucceededCheckReload(alertMessage: String? = nil) {
    feederContext.updateAuthIfNeeded()
    
    var reloadTargets: [ReloadAfterAuthChanged] = []
        
    for case let tabNav as UINavigationController in self.viewControllers ?? [] {
      let firstVc = tabNav.viewControllers.first
      let vcCount = tabNav.viewControllers.count
      if let home = firstVc as? HomeVC {
        ///if full issue > text settngs > settings > login no more refresh data will appear for compleete issue
        if let issue = (tabNav.viewControllers.valueAt(1) as? SectionVC)?.issue,
           feederContext.needsUpdate(issue: issue, toShowPdf: false) == false {
          continue
        }
        else if let issue = (tabNav.viewControllers.valueAt(1) as? TazPdfPagesViewController)?.issue,
           feederContext.needsUpdate(issue: issue, toShowPdf: true) == false {
          continue
        }
        ///Facsimile/PDF View or Article/Section VC wich need Update
        if vcCount > 1 { reloadTargets.append(home)}
      }
      else if let search = firstVc as? SearchController{
        if search.currentState == .result { reloadTargets.append(search)}
      }
      else if let bookmarks = firstVc as? BookmarkTVC{
        if bookmarks.navigationController?.viewControllers.last != bookmarks { reloadTargets.append(bookmarks)
        }
      }
      else if let target = firstVc as? ReloadAfterAuthChanged {
        reloadTargets.append(target)
      }
      else if let settings = firstVc as? SettingsVC {
        settings.refreshAndReload()
      }
    }
    if reloadTargets.count == 0 {
      if let alertMessage = alertMessage {
        Alert.message(message: alertMessage){
          Notification.send(Const.NotificationNames.dismissExpiredForm)
        }
      }
      return
    }
    if Defaults.expiredAccount {
      //DemoIssue only will be exchanged with DemoIssue
      log("not refresh if expired account")
      return
    }
    
    let snap = UIWindow.activeKeyWindow?.snapshotView(afterScreenUpdates: false)
    
    WaitingAppOverlay.show(alpha: 1.0,
                           backbround: snap,
                           showSpinner: true,
                           titleMessage: "\(alertMessage ?? "")\nAktualisiere Daten",
                           bottomMessage: "Bitte haben Sie einen Moment Geduld!",
                           dismissNotification: Const.NotificationNames.removeLoginRefreshDataOverlay)
    Notification.receiveOnce(Const.NotificationNames.articleLoaded) { _ in
      Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
    }
    Notification.receiveOnce(Const.NotificationNames.feederUnreachable) { _ in
      /// popToRootViewController is no more needed here due its done by reloadTarget.reloadOpened
      Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
      Toast.show(Localized("error"))
    }
    onMainAfter(1.0) {
      for reloadTarget in reloadTargets {
        reloadTarget.reloadOpened()
      }
    }
    onMainAfter(15.0) {
      //dirty hack sometimes reload opened did not work
      //had it unreproduceable in debug, and sendt the following notification enter foreground hock/Breakpoint
      Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
    }
  }
}

extension MainTabVC : UITabBarControllerDelegate {
  func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
    if tabBarController.selectedViewController != viewController { return true }
    
    if let firstVc = (viewController as? NavigationController)?.viewControllers.first,
       let home = firstVc as? HomeVC
    {
      home.onHome()
    }
    else if let firstVc = (viewController as? NavigationController)?.viewControllers.first,
       let searchController = firstVc as? SearchController
    {
      _ = searchController.restoreInitialState()
    }
    else if let firstVc = (viewController as? NavigationController)?.viewControllers.first,
       let content = firstVc as? ContentVC
    {
//      content.currentWebView?.scrollView.setContentOffset(CGPoint(x:0, y:0), animated: true)
    }
    else if let tvc = viewController as? UITableViewController
    {
      tvc.tableView.scrollRectToVisible(CGRect(x: 1, y: 1, width: 1, height: 1), animated: true)
    }
    return true
  }
  
  func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    Notification.send(Const.NotificationNames.helpProviderChanged)
  }
}

public protocol ReloadAfterAuthChanged {
  func reloadOpened()
}

fileprivate extension UIImage {
    /// renders the image for TabBar Icon in 20x20pt
  /// - Parameter size: target size, default is 20x20pt
  /// using `preparingThumbnail(of:)` on iOS 15+ (performant for vectors)
  /// before iOS 15 returns the original image
    func tabBarSizedIcon(size: CGSize = CGSize(width: 27, height: 27)) -> UIImage {
        if #available(iOS 15.0, *) {
            return self.preparingThumbnail(of: size) ?? self
        } else {
            return self
        }
    }
}

extension UIView {
  func pulsate() {
    self.layer.shadowColor = UIColor.white.cgColor
    self.layer.shadowOpacity = 1.0
    self.layer.shadowOffset = CGSize(width: 0, height: 0)
    self.layer.shadowRadius = 0
    self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.layer.cornerRadius).cgPath
    let duration = 15.0
    let pulseAnimation = CAKeyframeAnimation(keyPath: "shadowRadius")
    pulseAnimation.values =   [0, 20,   4,   30,   4,   20,   4,    30,   4,   0]
    pulseAnimation.keyTimes = [0, 0.15, 0.3, 0.4,  0.5, 0.6,  0.7,  0.8,  0.9, 1]
    pulseAnimation.duration = duration
    pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    pulseAnimation.isRemovedOnCompletion = true  // Animation wird nach Ende entfernt
    self.layer.add(pulseAnimation, forKey: "pulsateShadow")
    
    // sanft Schatten zurücksetzen
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      CATransaction.begin()
      CATransaction.setAnimationDuration(0.8)
      self.layer.shadowOpacity = 0.0
      self.layer.shadowRadius = 0
      CATransaction.commit()
    }
  }
  
  private func pulsate1() {

    self.layer.shadowColor = UIColor.white.cgColor
    self.layer.shadowOpacity = 1.0
    self.layer.shadowOffset = CGSize(width: 0, height: 0)
    self.layer.shadowRadius = 8
    self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.layer.cornerRadius).cgPath
    
    let pulseAnimation = CAKeyframeAnimation(keyPath: "shadowRadius")
    pulseAnimation.values = [14, 40, 14, 40, 14, 30]
    pulseAnimation.keyTimes = [0, 0.2, 0.4, 0.6, 0.8, 1]
    pulseAnimation.duration = 5.0
    pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    pulseAnimation.isRemovedOnCompletion = true  // Animation wird nach Ende entfernt
    self.layer.add(pulseAnimation, forKey: "pulsateShadow")
    
    // sanft Schatten zurücksetzen
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
      CATransaction.begin()
      CATransaction.setAnimationDuration(0.3)
      self.layer.shadowOpacity = 0.0
      self.layer.shadowRadius = 0
      CATransaction.commit()
    }
  }
    
  /// animate a outer ring for the view
  /// - Parameters:
  ///   - color: color of the ring, default white
  ///   - maxRadius: maximal radius of the ring from center (default: 200)
  ///   - duration: animation duration (default: 2.5s)
  func animateFocus(color: UIColor = .white, maxRadius: CGFloat = 200.0, duration: CFTimeInterval = 2.5) {
      guard let superview = self.superview else { return }
      
      let radius = min(bounds.width, bounds.height) / 2

      // place layer below the view
      let shapeLayer = CAShapeLayer()
      shapeLayer.path = UIBezierPath(arcCenter: center,
                                     radius: radius,
                                     startAngle: 0,
                                     endAngle: 2 * .pi,
                                     clockwise: true).cgPath
      shapeLayer.fillColor = UIColor.clear.cgColor
      shapeLayer.strokeColor = color.cgColor
      shapeLayer.lineWidth = 0
      shapeLayer.opacity = 0.8
      
      superview.layer.insertSublayer(shapeLayer, below: self.layer)

      let widthAnim = CABasicAnimation(keyPath: "lineWidth")
      widthAnim.fromValue = 0
      widthAnim.toValue = maxRadius

      let fadeAnim = CABasicAnimation(keyPath: "opacity")
      fadeAnim.fromValue = 0.8
      fadeAnim.toValue = 0.0

      let group = CAAnimationGroup()
      group.animations = [widthAnim, fadeAnim]
      group.duration = duration
      group.timingFunction = CAMediaTimingFunction(name: .easeOut)
      group.fillMode = .forwards
      group.isRemovedOnCompletion = true

      shapeLayer.add(group, forKey: "pulseRing")

      // remove layer after animation
      DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
          shapeLayer.removeFromSuperlayer()
      }
  }
  
  func pulsateX2() {
      let borderAnimation = CABasicAnimation(keyPath: "borderWidth")
      borderAnimation.fromValue = 0.0
      borderAnimation.toValue = 200.0
      borderAnimation.duration = 1.3
      borderAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

      self.layer.add(borderAnimation, forKey: "borderWidthAnimation")
      self.layer.borderWidth = 200.0 // finaler Wert bleibt gesetzt

      let colorAnimation = CABasicAnimation(keyPath: "borderColor")
      colorAnimation.fromValue = UIColor.white.cgColor
      colorAnimation.toValue = UIColor.clear.cgColor
      colorAnimation.duration = 1.3
      colorAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

      self.layer.add(colorAnimation, forKey: "borderColorAnimation")
      self.layer.borderColor = UIColor.clear.cgColor

      // Danach wieder zurücksetzen
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
          self.layer.borderWidth = 0.0
          self.layer.borderColor = UIColor.white.cgColor
      }
  }
  
  
  func highlight(with color: UIColor = .white, width: CGFloat = 1.0) {
    let radius = min(bounds.width, bounds.height) / 2
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    
    let circlePath = UIBezierPath(
      arcCenter: center,
      radius: radius,
      startAngle: -.pi/2,
      endAngle: 1.5 * .pi,
      clockwise: true
    )
    
    let circleLayer = CAShapeLayer()
    circleLayer.path = circlePath.cgPath
    circleLayer.strokeColor = color.cgColor
    circleLayer.fillColor = UIColor.clear.cgColor
    circleLayer.lineWidth = width
    circleLayer.strokeStart = 0
    circleLayer.strokeEnd = 0
    self.layer.addSublayer(circleLayer)
    
    let stepDuration: CFTimeInterval = 1.0
    let now = CACurrentMediaTime()
    
    // fill from 12>12
    let fill1 = CABasicAnimation(keyPath: "strokeEnd")
    fill1.fromValue = 0
    fill1.toValue = 1
    fill1.duration = stepDuration
    fill1.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    fill1.beginTime = now
    fill1.fillMode = .forwards
    fill1.isRemovedOnCompletion = false
    circleLayer.add(fill1, forKey: "fill1")
    
    // remove fill from 12>12
    let erase = CABasicAnimation(keyPath: "strokeStart")
    erase.fromValue = 0
    erase.toValue = 1
    erase.duration = stepDuration
    erase.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    erase.beginTime = now + stepDuration
    erase.fillMode = .forwards
    erase.isRemovedOnCompletion = true
    circleLayer.add(erase, forKey: "erase")
    
    // fill from 12>12
    let fill2 = CABasicAnimation(keyPath: "strokeEnd")
    fill2.fromValue = 0
    fill2.toValue = 1
    fill2.duration = stepDuration
    fill2.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    fill2.beginTime = now + 2 * stepDuration
    fill2.fillMode = .forwards
    fill2.isRemovedOnCompletion = false
    circleLayer.add(fill2, forKey: "fill2Clockwise")
    
    //Fade-Out
    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = 1
    fade.toValue = 0
    fade.duration = 0.8
    fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    fade.beginTime = now + 4 * stepDuration
    fade.fillMode = .forwards
    fade.isRemovedOnCompletion = false
    circleLayer.add(fade, forKey: "fade")
    
    // finally remove layer
    DispatchQueue.main.asyncAfter(deadline: .now() + 4 * stepDuration + 0.8) { [weak self] in
      circleLayer.removeFromSuperlayer()
//      self?.pulsate()
    }
  }
  
  func highlightOnce(with color: UIColor = .white, width: CGFloat = 1.0) {
    let radius = min(bounds.width, bounds.height) / 2
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    
    let circlePath = UIBezierPath(
      arcCenter: center,
      radius: radius,
      startAngle: -.pi/2,
      endAngle: 1.5 * .pi,
      clockwise: true
    )
    
    let circleLayer = CAShapeLayer()
    circleLayer.path = circlePath.cgPath
    circleLayer.strokeColor = color.cgColor
    circleLayer.fillColor = UIColor.clear.cgColor
    circleLayer.lineWidth = width
    circleLayer.strokeStart = 0
    circleLayer.strokeEnd = 0
    self.layer.addSublayer(circleLayer)
    
    let stepDuration: CFTimeInterval = 1.0
    let now = CACurrentMediaTime()
    
    // fill from 12>12
    let fill1 = CABasicAnimation(keyPath: "strokeEnd")
    fill1.fromValue = 0
    fill1.toValue = 1
    fill1.duration = stepDuration
    fill1.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    fill1.beginTime = now
    fill1.fillMode = .forwards
    fill1.isRemovedOnCompletion = false
    circleLayer.add(fill1, forKey: "fill1")
    
    //Fade-Out
    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = 1
    fade.toValue = 0
    fade.duration = stepDuration
    fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    fade.beginTime = now + stepDuration
    fade.fillMode = .forwards
    fade.isRemovedOnCompletion = false
    circleLayer.add(fade, forKey: "fade")
    
    // finally remove layer
    DispatchQueue.main.asyncAfter(deadline: .now() + 2 * stepDuration + 0.2) { [weak self] in
      circleLayer.removeFromSuperlayer()
      self?.pulsate()
    }
  }
}
