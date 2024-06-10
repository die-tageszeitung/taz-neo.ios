//
//  TazAppEnvironment+ErrorHandling.swift
//  taz.neo
//
//  Created by Ringo Müller on 07.06.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import NorthLib
import MessageUI

extension TazAppEnvironment {
  
  func reportFatalError(err: Log.Message) {
    guard !isErrorReporting else { return }
    
    lastErrormessage = err.message
    
    isErrorReporting = true
    log("Errormessage: \(err.message ?? "-")")
    log("Error: \(err.toString())")
    let errorClass = err.className ?? ""
    let isGqlError 
    = errorClass.starts(with: "GraphQl")//GraphQlSession
    || errorClass.starts(with: "GqlFeeder")
    let canSendMail = MFMailComposeViewController.canSendMail()
    
    var msg
    = isGqlError
    ? "Bei der Kommunikation mit dem Server ist ein schwerwiegender interner Fehler aufgetreten."
    : "Es liegt ein schwerwiegender interner Fehler vor."
    
    msg.append(canSendMail ? "\nMöchten Sie uns darüber mit einer Nachricht informieren?" : "\nBitte informieren Sie uns darüber mit einer Nachricht.\nMit der Schaltfläche ‚Text kopieren‘ wird ein vorformulierter Text zu diesem Fehler in die Zwischenablage kopiert. Diesen können Sie in eine E-Mail an app@taz.de einfügen." )
    
    if let topVc = UIViewController.top(),
       topVc.presentedViewController != nil {
      topVc.dismiss(animated: false)
    }
    
    let sendAction = UIAlertAction(title: "Fehlerbericht senden",
                                   style: .default) {[weak self] _ in
      self?.produceErrorReport(recipient: "app@taz.de",
                               subject: "Interner Fehler")
    }
    
    let copyAction = UIAlertAction(title: "Text kopieren",
                                   style: .default) {[weak self] _ in
      self?.copyErrorReportToPasteboard()
    }

    let cancelAction = UIAlertAction(title: isGqlError ? "Erneut versuchen" : "Abbrechen",
                                     style: .cancel)  {[weak self] _ in
      self?.isErrorReporting = false
    }
    
    let msgAction = canSendMail ? sendAction : copyAction
    
    Alert.message(title: "Interner Fehler",
                  message: msg,
                  actions: [msgAction, cancelAction] )
    Usage.track(Usage.event.dialog.FatalError)
  }
  
  func copyErrorReportToPasteboard(){
    let appVersion = "\(App.name) (\(App.bundleIdentifier)) Ver.:\(App.bundleVersion) #\(App.buildNumber)"

    var logString = ""
    if let logData = fileLogger.mem?.data {
      logString = String(data: logData, encoding: .utf8) ?? "-"
    }
    let deviceData = DeviceData()
    let msg = """
    Betreff: Schwerwiegender interner Fehler der iOS App
      
    Bitte per E-Mail an: app@taz.de
        
    Bitte ergänzen Sie, falls bekannt, wie der Fehler entstanden ist.
    
    Technische Informationen:
    Abgelaufen: \(Defaults.expiredAccount)
    Angemeldet: \(isAuthenticated)
    Konto: \(DefaultAuthenticator.getUserData().id ?? "-")
    deviceName: \(Utsname.machineModel)
    appVersion: \(appVersion)
    deviceOS: iOS \(UIDevice.current.systemVersion)
    installationId: \(App.installationId)
    storageAvailable \(deviceData.storageAvailable ?? "-")
    storageUsed \(deviceData.storageUsed ?? "-")
    ramAvailable \(deviceData.ramAvailable ?? "-")
    ramUsed \(deviceData.ramUsed ?? "-")
    ---- LOG ---
    \(logString)
    """
    UIPasteboard.general.string = String(msg.prefix(12000))
    Alert.message(title: "Text in die Zwischenablage kopiert",
                  message: "Bitte per E-Mail an app@taz.de senden.") { [weak self] in
      self?.isErrorReporting = false
    }
  }
  
  func produceErrorReport(recipient: String,
                          subject: String = "Feedback",
                          logData: Data? = nil,
                          addScreenshot: Bool = true,
                          completion: (()->())? = nil) {
    if MFMailComposeViewController.canSendMail() {
      let mail =  MFMailComposeViewController()
      let screenshot = UIWindow.screenshot?.jpeg
      let logData = logData ?? fileLogger.mem?.data
      mail.mailComposeDelegate = self
      mail.setToRecipients([recipient])
      
      var tazIdText = ""
      let data = DefaultAuthenticator.getUserData()
      if let tazID = data.id, tazID.isEmpty == false {
        tazIdText = " taz-Konto: \(tazID)"
      }
      
      mail.setSubject("\(subject) \"\(App.name)\" (iOS)\(tazIdText)")
      mail.setMessageBody("App: \"\(App.name)\" \(App.bundleVersion)-\(App.buildNumber)\n" +
        "\(Device.singleton): \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n\n...\n",
        isHTML: false)
      if addScreenshot, let screenshot = screenshot {
        mail.addAttachmentData(screenshot, mimeType: "image/jpeg",
                               fileName: "taz.neo-screenshot.jpg")
      }
      if let logData = logData {
        mail.addAttachmentData(logData, mimeType: "text/plain",
                               fileName: "taz.neo-logfile.txt")
      }
      UIViewController.top()?.topmostModalVc.present(mail, animated: true){
        completion?()
        mail.becomeFirstResponder()
      }
    }
  }
}

extension TazAppEnvironment: MFMailComposeViewControllerDelegate {
  func mailComposeController(_ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true)
    onMainAfter(2.0) {[weak self] in
      self?.isErrorReporting = false
    }
  }
}
