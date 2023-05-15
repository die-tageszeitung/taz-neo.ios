//
//  NotificationsView.swift
//  taz.neo
//
//  Created by Ringo Müller on 03.05.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//
import UIKit
import NorthLib

/// Helper view to re-enable notifications if needed
/// Will be displayed nearly everywhere in the app on topmost in apps window
/// uses InfoToasterView to be displayed
class NotificationsView: InfoToasterView {
  private var titleLabel = UILabel()
  private var messageLabel = UILabel()
  
  private var activateNotificationsButton = Padded.Button(type: .newBlackOutline,
                                                          title: "Ja, Mitteilungen einschalten",
                                                          color: Const.SetColor.CTArticle.color,
                                                          textColor: Const.SetColor.CTArticle.color,
                                                          height: 46)
  
  
  private var dismissButton = Padded.Button(type: .newBlackOutline,
                                            title: "Nein, Einstellungen so lassen",
                                            color: Const.SetColor.CTArticle.color,
                                            textColor: Const.SetColor.CTArticle.color,
                                            height: 46)
  lazy var notNowButton: Padded.View = {
    let lbl = UILabel()
    lbl.text = "Jetzt nicht"
    lbl.contentFont()
    lbl.textAlignment = .center
    lbl.textColor = Const.SetColor.CTArticle.color
    lbl.addBorderView(.gray, edge: UIRectEdge.bottom)
    let wrapper = Padded.View()
    wrapper.addSubview(lbl)
    //Allow label to shink if wrapper shrinks, not alow to grow more than needed
    let c = pin(lbl, to: wrapper)
    c.right.priority = .defaultLow
    c.left.priority = .defaultLow
    lbl.centerY()
    lbl.onTapping {[weak self] _ in
      self?.handleNotNowTap()
    }
    return wrapper
  }()
  
  
  @objc private func handleActivateNotificationsButtonTap() {
    NotificationBusiness.sharedInstance.openAppInSystemSettings()
  }
  
  @objc private func handleDismissButtonTap() {
    Defaults.notificationsActivationPopupRejectedDate = Date()
    self.dismiss()
  }
  
  public func handleNotNowTap() {
    Defaults.notificationsActivationPopupRejectedTemporaryDate = Date()
    self.dismiss()
  }
  
  
  func setup(){
    setupUI()
    NotificationCenter.default
      .addObserver(self,
                   selector: #selector(applicationDidBecomeActive),
                   name: UIApplication.didBecomeActiveNotification,
                   object: nil)
    
    dismissButton.addTarget(self,
                            action: #selector(handleDismissButtonTap),
                            for: .touchUpInside)
    activateNotificationsButton.addTarget(self,
                                          action: #selector(handleActivateNotificationsButtonTap),
                                          for: .touchUpInside)
    onXButton { [weak self] in
      self?.handleNotNowTap()
    }
  }
  
  func setupUI(){
    titleLabel.titleFont(size: Const.Size.TitleFontSize)
    messageLabel.contentFont()

    titleLabel.numberOfLines = 0
    messageLabel.numberOfLines = 0

    addSubview(titleLabel)
    addSubview(messageLabel)
    addSubview(activateNotificationsButton)
    addSubview(dismissButton)
    addSubview(notNowButton)

    pin(titleLabel.top, to: self.top, dist: 40)
    pin(messageLabel.top, to: titleLabel.bottom, dist: 30)
    pin(activateNotificationsButton.top, to: messageLabel.bottom, dist: 50)
    pin(dismissButton.top, to: activateNotificationsButton.bottom, dist: 25)
    pin(notNowButton.top, to: dismissButton.bottom, dist: 50)
    pin(notNowButton.bottom, to: self.bottom, dist: -35)
    notNowButton.centerX()
    
    pin(titleLabel.left, to: self.left, dist: 15)
    pin(messageLabel.left, to: self.left, dist: 15)
    pin(activateNotificationsButton.left, to: self.left, dist: 15)
    pin(dismissButton.left, to: self.left, dist: 15)
    
    pin(titleLabel.right, to: self.right, dist: -35)//x-button!
    pin(messageLabel.right, to: self.right, dist: -15)
    pin(activateNotificationsButton.right, to: self.right, dist: -15)
    pin(dismissButton.right, to: self.right, dist: -15)
  }
  
  @objc func applicationDidBecomeActive(notification: NSNotification) {
    NotificationBusiness.sharedInstance.checkNotificationStatus {
      if NotificationBusiness.sharedInstance.systemNotificationsEnabled == false { return }
      ///Toast.show("Mitteilungen sind jetzt aktiviert! ❤️")
      onMain {[weak self] in
        self?.dismiss()
        self?.removeObservers()
      }
    }
  }
  
  func removeObservers(){
    NotificationCenter.default.removeObserver(self)
  }
  
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    guard superview == nil else { return }
    NotificationCenter.default.removeObserver(self)//not working indicates memory leak
  }
  
  required init(newIssueAvailableSince: TimeInterval) {
    let hours = Int(round(newIssueAvailableSince / 3600))
    titleLabel.text = "Immer Bescheid wissen"
    
    messageLabel.text =
    hours > 0
    ? "Willkommen zurück! Seit \(hours) Stunde\(hours > 1 ? "n":"") finden Sie die neue Ausgabe der taz in Ihrer App.\n\nSie möchten auch in Zukunft keine Ausgabe mehr verpassen? Dann informieren wir Sie ab sofort gern per Pushnachricht."
    : "Willkommen zurück! Wir haben etwas Brandneues für Sie: Bleiben Sie auf dem Laufendem mit Benachrichtigungen.\n\nSie möchten auch in Zukunft keine Ausgabe mehr verpassen? Schalten Sie die Mitteilungen an und verpassen Sie nichts."
    super.init(frame: .zero)
    setup()
  }
               
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
               
}
