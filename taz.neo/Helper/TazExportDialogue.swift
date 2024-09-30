//
//  ArticleExportDialogue.swift
//  taz.neo
//
//  Created by Ringo Müller on 25.09.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import NorthLib
import LinkPresentation

///A helper class to handle the export of an article by providing various items to the iOS share sheet
///implements: UIActivityItemSource
class ArticleExportDialogueItemSource:NSObject, UIActivityItemSource, DoesLog {
  /// the article to share
  var article: Article
  /// a image for share dialogue
  var image: UIImage?
  /// source view from where share dialog is started
  var sourceView: UIView
  /// hepler e.g. for render article pdf
  var delegate: ArticleExportDialogueDelegate
  /// a URL pointing to the article's generated PDF. If the PDF is available, will be used in the share dialog.
  var articlePdfURL: URL?
  
  ///A lazily initialized array of items that will be provided to the sharing activity.
  ///The content varies depending on the user and article
  ///it provides default sharing text content with url link up to embedded pdf, if available
  lazy var itemsSource: [Any] = {
    var itms: [Any] =  [self]
    if DefaultAuthenticator.isTazLogin, let articlePdfURL = articlePdfURL {
      var intro:[String] = ["Aus der \(App.shortName) vom \(article.defaultIssueDate.short):\n"]
      intro.appendIfPresent(article.title)
      if article.title?.isEmpty == false && article.teaser?.isEmpty == false {
        intro.append(" ")
      }
      intro.appendIfPresent(article.teaser)
      if article.teaser?.isEmpty == false {
        intro.append("...")
      }
      itms.append(intro.joined(separator: "\n"))
      itms.appendIfPresent(image)
      itms.append(articlePdfURL)
    }
    else {
      itms.append("Aus der \(App.shortName) vom \(article.defaultIssueDate.short):")
      itms.appendIfPresent(article.onlineLinkUrl)
    }
    return itms
  }()
  
  ///Returns a placeholder item for the share sheet
  public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
    return articlePdfURL ?? "Fehler"
  }
  
  /// Provides the actual item for a specific activity type. Depending on the activity, it returns:
  /// - A combination of the article's text, image, and PDF for activities like copying to the clipboard, email, or messages.
  /// - The article's online link for activities like posting to social media.
  /// - The PDF URL for activities like saving to files.
  ///
  /// - Parameters:
  ///   - activityViewController: The activity view controller requesting the item.
  ///   - activityType: The specific type of activity for which the item is requested.
  /// - Returns: The item to share (text, image, pdf, link).
  public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
    debug("requested item for type: \(activityType?.rawValue ?? "-")")
    switch activityType {
      case .copyToPasteboard, .mail, .message:
        return itemsSource
      case .addToReadingList, .postToFacebook, .postToWeibo,
          .postToVimeo, .postToFlickr, .postToTwitter,
          .postToTencentWeibo: return article.onlineLink
      default:
        if activityType?.rawValue.contains("SaveToFiles") == true {
          return articlePdfURL
        }
        return articlePdfURL
    }
  }
  
  /// Generates metadata for share sheet header
  /// - Parameter activityViewController: The activity view controller requesting the metadata.
  /// - Returns: An instance of `LPLinkMetadata` containing the article's title, an optional image, and a URL with share options.
  public func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = article.title
    
    if let img = image {
      metadata.iconProvider = NSItemProvider(object: img)
    }
    metadata.originalURL = URL(string: "Artikel:\(article.shareOptions)")
    return metadata
  }
  
  /// Initializes the `ArticleExportDialogueItemSource` with the given article, image,
  /// delegate, and source view. It also triggers the delegate to create a PDF from the web view of the article.
  ///
  /// - Parameters:
  ///   - article: The article to be shared.
  ///   - image: An optional image to include in the share.
  ///   - delegate: The delegate responsible for handling PDF rendering.
  ///   - sourceView: The source view from which the share dialog is presented.
  init(article: Article, image: UIImage?, delegate: ArticleExportDialogueDelegate, sourceView: UIView) {
    self.article = article
    self.image = image
    self.delegate = delegate
    self.sourceView = sourceView
    self.articlePdfURL = article.generatedArticlePdfURL
    super.init()
    delegate.createPDFfromWebView()
  }
}

/// Extension to implement UIDocumentPickerDelegate
extension ArticleExportDialogueItemSource: UIDocumentPickerDelegate {}

/// Extension with helper functions to download, print, or convert the article to PDF
extension ArticleExportDialogueItemSource {
    /// Computed property to get the list of custom activities for the sharing dialog.
    /// includes actions like: opening a link in Safari, saving a PDF, printing a PDF, and showing more info.
    public var applicationActivities: [UIActivity] {
      var items: [UIActivity] = []
      items.appendIfPresent(activityOpenOnlineLinkInSafari)  // Add the 'Open in Safari' activity if available.
      items.appendIfPresent(activitySavePaperPDF)            // Add the 'Save PDF' activity if available.
      items.appendIfPresent(activityPrintPaperPDF)           // Add the 'Print PDF' activity if available.
      items.appendIfPresent(moreInfo)                        // Add the 'More Info' activity if available.
      return items
    }

  ///activity for open articles online URL if available
  private var activityOpenOnlineLinkInSafari: UIActivity? {
    if self.article.onlineLinkUrl == nil { return nil }
    return CustomUIActivity(type: .openInSafari) {[weak self] finishCallback in
      guard let onlineLinkUrl = self?.article.onlineLinkUrl else {
        finishCallback(false)
        return
      }
      UIApplication.shared.open(onlineLinkUrl)
      finishCallback(true)
    }
  }
  
  ///activity to show info for unavailable sharing options
  private var moreInfo: UIActivity? {
    guard let message = article.shareInfoMessage else { return nil }
    return CustomUIActivity(type: .moreInfo) { finishCallback in
      Alert.message(title: "Informationen zum Teilen",
                    message: message)
      finishCallback(true)
    }
  }
  
  ///activity to save the article after converting it to a PDF format
  private var activitySavePaperPDF: UIActivity? {
    if #available(iOS 14.0, *) {
      guard let pdfFileName = article.pdf?.name else { return nil }
      return CustomUIActivity(type: .paperPdfSave) {[weak self] finishCallback in
        self?.savePaperPdf(pdfFileName:pdfFileName, loadFileIfNeeded: true, finishCallback: finishCallback)
      }
    } else{
      return nil
    }
  }
  
  ///activity to print downloaded paper pdf
  private var activityPrintPaperPDF: UIActivity? {
    guard let pdfFileName = article.pdf?.name else { return nil }
    return CustomUIActivity(type: .paperPdfPrint) {[weak self] finishCallback in
      self?.printPaperPdf(pdfFileName: pdfFileName, finishCallback: finishCallback)
    }
  }
  
  ///helper to save downloaded paper pdf
  @available(iOS 14.0, *)
  func savePaperPdf(pdfFileName: String, loadFileIfNeeded: Bool, finishCallback: @escaping ActivityFinishCallback){
    let f = File(dir: article.dir.path, fname: pdfFileName)
    if f.exists == false && loadFileIfNeeded == false {
      Alert.message(message: Localized("error"))
      finishCallback(false)
      return
    }
    else if f.exists == false {
      loadPrintPdf(closure: {[weak self] err in
        self?.log("download finished for: \(pdfFileName) with err: \(err ?? "-")")
        self?.savePaperPdf(pdfFileName: pdfFileName, loadFileIfNeeded: false, finishCallback: finishCallback)
      }, finishCallback: finishCallback)
      return
    }
    saveToFiles(documentUrl: f.url)
    finishCallback(true)
  }
  
  ///helper to print downloaded paper pdf
  func printPaperPdf(pdfFileName: String, finishCallback: @escaping ActivityFinishCallback){
    let f = File(dir: article.dir.path, fname: pdfFileName)
    if f.exists == false {
      loadPrintPdf (closure: {[weak self] err in
        self?.log("download finished for: \(pdfFileName) with err: \(err ?? "-")")
        if err == nil {
          self?.printPaperPdf(pdfFileName: pdfFileName, finishCallback: finishCallback)
        }
        else {
          Alert.message(message: Localized("error"))
          finishCallback(false)
        }
      } ,finishCallback: finishCallback)
      return 
    }
    Print.print(pdf: f.url, finishCallback: finishCallback)
  }
  
  /// helper to present a document picker to save the file to the system
  @available(iOS 14.0, *)
  func saveToFiles(documentUrl:URL){
    let documentPicker = UIDocumentPickerViewController(forExporting: [documentUrl], asCopy: true)
    documentPicker.delegate = self
    UIWindow.keyWindow?.rootViewController?.present(documentPicker, animated: true, completion: nil)
  }
  
  ///helper to download downloaded paper pdf
  func loadPrintPdf(closure: @escaping (Error?)->(), finishCallback: @escaping ActivityFinishCallback){
    guard let vc = (delegate as? ArticleVC),
          let issue = article.primaryIssue,
          let pdf = article.pdf else { return }
    vc.dloader.downloadIssueFiles(issue: issue, files: [pdf], closure: closure)
  }
}

///just a Wrapper for UIActivityViewController to simplify article sharing
class ArticleExportDialogue: UIActivityViewController {
  
  /// Initializer for `ArticleExportDialogue`.
  /// - Parameter itemSource: An instance of `ArticleExportDialogueItemSource` that provides the article and its data to be shared
   init(itemSource: ArticleExportDialogueItemSource){
     super.init(activityItems:  itemSource.itemsSource,
               applicationActivities: itemSource.applicationActivities)
  }
  
  /// Static function to present the `ArticleExportDialogue`.
  /// This method simplifies the use of the UIActivityViewController and handles the configuration of the dialogue.
  /// - Parameter article: The article to be shared.
  /// - Parameter delegate: A delegate for additional tasks e.g. download
  /// - Parameter image: An optional image to show in share dialogue header
  /// - Parameter sourceView: The view (e.g., a button) from which the dialogue is presented.
  static func show(article:Article, delegate: ArticleExportDialogueDelegate, image: UIImage?, sourceView: UIView){
    let dialogueItemSource = ArticleExportDialogueItemSource(article: article, image: image, delegate: delegate, sourceView: sourceView)
    let dialogue = ArticleExportDialogue(itemSource: dialogueItemSource)
    dialogue.presentAt(sourceView)
  }
}

/// A protocol defining a delegate for exporting article HTML as PDFs using web view's content.
/// This protocol is intended to be adopted by view controllers that can generate a PDF from a
public protocol ArticleExportDialogueDelegate  where Self: UIViewController{
  func createPDFfromWebView()
}

///implementation of ArticleExportDialogueDelegate by ArticleVC
extension ArticleVC:ArticleExportDialogueDelegate {
  ///create printable pdf from current webviev content
  public func createPDFfromWebView() {
    guard let printFormatter = currentWebView?.viewPrintFormatter(),
          let article = article else {
      return
    }
    let renderer = UIPrintPageRenderer()
    
    // Page bounds for paperformat A4
    let pageSize = CGSize(width: 595.2, height: 841.8) // A4 in points (72 DPI)
    let margin: CGFloat = 20.0
    
    renderer.setValue(NSValue(cgRect: CGRect(x: 0,
                                             y: 0,
                                             width: pageSize.width,
                                             height: pageSize.height)),
                      forKey: "paperRect")
    renderer.setValue(NSValue(cgRect: CGRect(x: margin,
                                             y: margin,
                                             width: pageSize.width - margin * 2,
                                             height: pageSize.height - margin * 2)),
                      forKey: "printableRect")
    
    renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
    
    let pdfData = NSMutableData()
    
    UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, nil)
    for i in 0..<renderer.numberOfPages {
      UIGraphicsBeginPDFPage()
      let bounds = UIGraphicsGetPDFContextBounds()
      renderer.drawPage(at: i, in: bounds)
    }
    UIGraphicsEndPDFContext()
    let tempURL = article.generatedArticlePdfURL
    do {
      try pdfData.write(to: tempURL)
    } catch {
      log("Fehler beim Speichern des PDFs: \(error.localizedDescription)")
    }
  }
}


/// An enumeration representing custom activity types for use in a share sheet.
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
  
  /// The title for the activity as displayed in the share sheet.
  /// - Returns: A localized string corresponding to the activity type.
  public var title: String {
    switch self {
      case .openInSafari:    return "In Safari öffnen"  // "Open in Safari"
      case .paperPdfSave:  return "Zeitungs PDF in Dateien sichern"  // "Save Newspaper PDF in Files"
      case .paperPdfPrint:  return "Zeitungs PDF drucken"  // "Print Newspaper PDF"
      case .moreInfo:  return "Informationen zum teilen"  // "More Information about Sharing"
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
    }
  }
  
  /// The image associated with the activity, displayed in the share sheet.
  /// Uses SF Symbols to represent each activity visually.
  /// - Returns: A `UIImage?` for the corresponding activity or `nil` if none is available.
  public var image: UIImage? {
    switch self {
      case .openInSafari: return UIImage(systemName: "safari")  // SF Symbol: Safari browser icon
      case .paperPdfSave: return UIImage(systemName: "folder")  // SF Symbol: Folder icon
      case .paperPdfPrint: return UIImage(systemName: "printer")  // SF Symbol: Printer icon
      case .moreInfo: return UIImage(systemName: "info")  // SF Symbol: Information icon
    }
  }
}

/// A custom user interface activity class that allows defining specific actions
/// to be performed within the share sheet.
public class CustomUIActivity: UIActivity {
  
  /// The type of the custom activity, including its title and image.
  var type: CustomUIActivityType
  
  /// The action to be performed when the activity is selected.
  var action: (@escaping ActivityFinishCallback) -> Void
  
  /// Initializes a new instance of `CustomUIActivity`.
  /// - Parameters:
  ///   - type: The type of the activity, which includes the title and image.
  ///   - performAction: The closure that defines the action to be executed.
  init(type: CustomUIActivityType, performAction: @escaping (@escaping ActivityFinishCallback) -> Void) {
    self.type = type
    action = performAction
    super.init()
  }
  
  /// The title of the activity as displayed in the share sheet.
  public override var activityTitle: String? {
    return type.title // Returns the title from the custom activity type
  }
  
  /// The image associated with the activity as displayed in the share sheet.
  public override var activityImage: UIImage? {
    return type.image // Returns the image from the custom activity type
  }
  
  /// The activity type identifier.
  override public var activityType: UIActivity.ActivityType? {
    return type.type // Returns the activity type from the custom activity type
  }
  
  /// The category of the activity. Default is set to action.
  public override class var activityCategory: UIActivity.Category {
    return .action // Specifies the category as an action activity
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
  }
  
  /// Executes the activity's action and informs when it's finished.
  public override func perform() {
    action { [weak self] ret in
      self?.activityDidFinish(ret) // Calls the finish handler with the result of the action
    }
  }
}

/// A type alias for the callback used to indicate the completion of an activity.
/// - Parameter success: A Boolean indicating whether the action was successful.
typealias ActivityFinishCallback = ((Bool) -> ())

///helper extension for article
extension Article {
  /// A computed property that checks if the article is shareable.
  /// An article is considered shareable if it has a valid online link or a the pdf property is set
  var isShareable: Bool {
    if self.onlineLink?.isEmpty == false { return true }
    if self.pdf != nil { return true }
    return false
  }
}

///fileprivate helper extension for article
fileprivate extension Article {
  /// A computed property that generates the PDF file name based on the article's HTML filename.
  var pdfFileName: String {
    guard let htmlFilename = html?.name else { return "tazArtikel.pdf"}
    return htmlFilename.replacingOccurrences(of: ".html", with: "HTML.pdf")
  }
  
  /// articles online URL, if available
  var onlineLinkUrl: URL? {
    guard let link = self.onlineLink else { return nil }
    return URL(string: link)
  }
  
  /// helper to generate the URL for the article PDF.
  var generatedArticlePdfURL:URL {
    return Dir.cache.url.appendingPathComponent(pdfFileName)
  }
  
  ///string for share sheet header
  var shareOptions: String {
    if self.onlineLink?.isEmpty == true { return "Drucken/Exportieren"}
    return "Teilen/Drucken/Exportieren"
  }
  
  ///message for potentially not available share options
  var shareInfoMessage: String? {
    if onlineLink?.isEmpty == true &&  pdf == nil {
      return "Für diesen Artikel existiert leider kein Online-Link oder ein PDF der Zeitungsansicht. Sie können jedoch ein PDF aus der Artikelansicht erstellen, speichern oder teilen."
    }
    else if onlineLink?.isEmpty == true {
      return "Für diesen Artikel existiert leider kein Online-Link. Sie können jedoch das PDF speichern oder teilen."
    }
    else if pdf == nil {
      return "Für diesen Artikel existiert leider kein PDF der Zeitungsansicht. Sie können jedoch den Online Link teilen sowie ein PDF aus der Artikelansicht erstellen, speichern oder teilen"
    }
    return nil
  }
}

/// helper extension for handling print operations in iOS.
extension Print {
  /// Static function to print a PDF document.
  /// It uses the `UIPrintInteractionController` to initiate and manage the printing job.
  ///
  /// - Parameters:
  ///   - pdf: The URL of the PDF file to be printed.
  ///   - finishCallback: A callback function that is invoked when the print process is completed.
  static func print(pdf: URL, finishCallback: @escaping ActivityFinishCallback) {
      let printController = UIPrintInteractionController.shared
      let printInfo = UIPrintInfo(dictionary: nil)
      printInfo.outputType = .general
    printInfo.jobName = pdf.lastPathComponent
      printController.printInfo = printInfo
      printController.printingItem = pdf
    printController.present(animated: true, completionHandler: {_,_,_ in
      finishCallback(true)
    })
  }
}
