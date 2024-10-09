//
//  CustomUIActivity.swift
//  taz.neo
//
//  Created by Ringo Müller on 04.10.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import NorthLib
import LinkPresentation
import MessageUI

public class CustomUIActivity: UIActivity, DoesLog {
  /// hepler for everything, to reduce callback hell
  var delegate: CustomUIActivityActionDelegate?
  
  var type: CustomUIActivityType
  private var title: String?
  private var image: UIImage?
  
  /// The category of the activity. Default is set to action.
  public override class var activityCategory: UIActivity.Category {
    return .action // action/share Specifies the category as an action activity
  }
  
  /// Determines if the activity can be performed with the provided items.
  /// - Parameter activityItems: An array of items to be shared.
  /// - Returns: A Boolean value indicating whether the activity can perform the action.
  public override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
    return true // Always returns true, allowing the activity to appear in the share sheet
  }
  
  /// Prepares the activity for execution by loading necessary data.
  /// - Parameter activityItems: An array of items to be shared.
  public override func prepare(withActivityItems activityItems: [Any]) {
    // Here, you can load any necessary files or data for the activity
    // self.activityItems = activityItems // Uncomment to store activity items for later use
    delegate?.prepare(caller: self)
  }
  
  func trackUsage(_ completed: Bool){
    guard let article = delegate?.article else {
      debug("error: no article for tracking available")
      return
    }
    
    if completed == false {
      Usage.xtrack.share.article(article: article, event: Usage.event.share.Canceled)
      return
    }
    
    switch self.type {
      case .openInSafari:
        Usage.xtrack.share.article(article: article, event: Usage.event.share.Browser)
      case .paperPdfSave:
        Usage.xtrack.share.article(article: article, event: Usage.event.share.ArticlePDF2Files)
      case .paperPdfPrint:
        Usage.xtrack.share.article(article: article, event: Usage.event.share.ArticlePDF2Print)
      case .saveToFiles:
        Usage.xtrack.share.article(article: article, event: Usage.event.share.ArticleAppPDF2Files)
      case .print:
        Usage.xtrack.share.article(article: article, event: Usage.event.share.ArticleAppPDF2Print)
      case .moreInfo:
        Usage.xtrack.share.article(article: article, event: Usage.event.share.Info)
      case .copyToPasteboard:
        Usage.xtrack.share.article(article: article, event: Usage.event.share.Copy2Clipboard)
      case .mail:
        Usage.xtrack.share.article(article: article, event: Usage.event.share.Mail)
      case .message:
        Usage.xtrack.share.article(article: article, event: Usage.event.share.Message)
    }
  }
  
  public override func activityDidFinish(_ completed: Bool) {
    log("CustomUIActivity: \(title ?? "-") didFinish with completed: \(completed)")
    trackUsage(completed)
    super.activityDidFinish(completed)
  }
  
  /// Executes the activity's action and informs when it's finished.
  public override func perform() {
    guard let delegate = delegate else {
      activityDidFinish(true)
      return
    }
    delegate.perform(caller: self)
  }
  
  /// The title of the activity as displayed in the share sheet.
  public override var activityTitle: String? {
    if delegate?.article.printPdfLocalUrl == nil {
      return type.title
    }
  ///change: "Zeitungs PDF laden und in Dateien sichern" => "Zeitungs PDF in Dateien sichern"
  ///change: "Zeitungs PDF laden und drucken" => "Zeitungs PDF drucken"
    return type.title.replacingOccurrences(of: " laden und", with: "")
  }
  
  /// The image associated with the activity as displayed in the share sheet.
  public override var activityImage: UIImage? { type.image }
  
  /// The activity type identifier.
  override public var activityType: UIActivity.ActivityType? {type.type}
  
  /// Initializes a new instance of `CustomUIActivity`.
  /// - Parameters:
  ///   - type: The type of the activity, which includes the title and image.
  ///   - performAction: The closure that defines the action to be executed.
  required init(type: CustomUIActivityType,
       delegate: CustomUIActivityActionDelegate) {
    self.delegate = delegate
    self.type = type
    super.init()
  }
}

// An enumeration representing custom activity types for use in a share sheet.
/// Each case corresponds to a specific action, with associated title, type, and image.
public enum CustomUIActivityType {
  
  /// Open the article in Safari.
  case openInSafari
  
  /// Save the newspaper PDF to Files.
  case paperPdfSave
  
  /// Print the newspaper PDF.
  case paperPdfPrint
  
  /// Display more information about the sharing options.
  case moreInfo
  
  /// copy
  case copyToPasteboard
  
  /// print local generated article pdf
  case print
  case mail
  case message
  case saveToFiles
  
  /// The title for the activity as displayed in the share sheet.
  /// - Returns: A localized string corresponding to the activity type.
  public var title: String {
    switch self {
      case .openInSafari:    return "In Safari öffnen"  // "Open in Safari"
      case .paperPdfSave:  return "Zeitungs PDF laden und in Dateien sichern"  // "Save Newspaper PDF in Files"
      case .paperPdfPrint:  return "Zeitungs PDF laden und drucken"  // "Print Newspaper PDF"
      case .moreInfo:  return "Informationen zum teilen"  // "More Information about Sharing"
      case .copyToPasteboard:  return  "Kopieren"
      case .print:  return  "Drucken"
      case .mail:  return  "Als E-Mail versenden"
      case .message:  return  "Als Nachricht versenden"
      case .saveToFiles:  return  "In Dateien sichern"
    }
  }
  
  /// The unique identifier for the activity type, used by the system to identify the custom activity.
  /// - Returns: A `UIActivity.ActivityType` instance with a unique raw value.
  public var type: UIActivity.ActivityType {
    switch self {
      case .openInSafari:    return UIActivity.ActivityType(rawValue: "de.taz.open.in.safari")
      case .paperPdfSave:  return UIActivity.ActivityType(rawValue: "de.taz.paperPdf.save")
      case .paperPdfPrint:  return UIActivity.ActivityType(rawValue: "de.taz.paperPdf.print")
      case .moreInfo:  return UIActivity.ActivityType(rawValue: "de.taz.share.moreinfo")
      case .copyToPasteboard:  return UIActivity.ActivityType.copyToPasteboard
      case .print:  return UIActivity.ActivityType.print
      case .mail:  return UIActivity.ActivityType(rawValue: "de.taz.share.mail")
      case .message:  return UIActivity.ActivityType(rawValue: "de.taz.share.message")
      case .saveToFiles:  return UIActivity.ActivityType(rawValue: "de.taz.share.localPdf2Files")
    }
  }
  
  /// The image associated with the activity, displayed in the share sheet.
  /// Uses SF Symbols to represent each activity visually.
  /// - Returns: A `UIImage?` for the corresponding activity or `nil` if none is available.
  public var image: UIImage? {
    switch self {
      case .openInSafari: return UIImage(systemName: "safari")  // SF Symbol: Safari browser icon
      case .paperPdfSave, .saveToFiles: return UIImage(systemName: "folder")  // SF Symbol: Folder icon
      case .paperPdfPrint: return UIImage(systemName: "printer")  // SF Symbol: Printer icon
      case .moreInfo: return UIImage(systemName: "info")  // SF Symbol: Information icon
      case .copyToPasteboard: return UIImage(systemName: "doc.on.doc")  // SF Symbol: Copy icon
      case .print: return UIImage(systemName: "printer")  // SF Symbol: Copy icon
      case .mail:  return UIImage(systemName: "envelope")
      case .message:  return UIImage(systemName: "message")
    }
  }
}

/// Eine Factory-Klasse zur Erzeugung von benutzerdefinierten UIActivity-Objekten.
class CustomUIActivityFactory {
  
  /// static fabric function to generate available `CustomUIActivities` based on article
  /// - Parameter delegate: Der Typ der benutzerdefinierten Aktivität.
  /// - Returns: array of `[CustomUIActivity]`.
  static func createAvailableApplicationActivities(with delegate: CustomUIActivityActionDelegate) -> [UIActivity] {
    var items: [UIActivity] = [CustomUIActivity(type: .copyToPasteboard, delegate: delegate)]
    
    let article = delegate.article
    
    if MFMailComposeViewController.canSendMail() {
      items.append(CustomUIActivity(type: .mail, delegate: delegate))
    }

    if MFMessageComposeViewController.canSendText() {
      items.append(CustomUIActivity(type: .message, delegate: delegate))
    }
    
    if article.onlineLink?.isEmpty == false {///add 'Open in Safari' activity if available.
      items.append(CustomUIActivity(type: .openInSafari, delegate: delegate))
    }
    
    items.append(CustomUIActivity(type: .print, delegate: delegate))
    items.append(CustomUIActivity(type: .saveToFiles, delegate: delegate))
    
    if article.pdf != nil {
      items.append(CustomUIActivity(type: .paperPdfPrint, delegate: delegate))
      items.append(CustomUIActivity(type: .paperPdfSave, delegate: delegate))
    }
    
    if article.shareInfoMessage != nil{
      items.append(CustomUIActivity(type: .moreInfo, delegate: delegate))
    }
    return items
  }
}
