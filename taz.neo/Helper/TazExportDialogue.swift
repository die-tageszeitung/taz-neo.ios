//
//  TazExportDialogue.swift
//  taz.neo
//
//  Created by Ringo Müller on 25.09.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import NorthLib
import LinkPresentation
import MessageUI
import UniformTypeIdentifiers

/*************************************************************************************
 * ** ** ** ** ** Knowledge base ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** *    *
 * - handle everything in **func activityViewController(activityViewController, itemForActivityType) -> Any?**
 *   is verry fragile. If Share dialog did not disappear as fast as expected (may solve with close callback)
 *   next Popup for Save to files or Pint did not appear.
 * - ...return url
 * - if using url return **maybe** the system handler would be called
 *
 * - ArticleExportDialogue: UIActivityViewController uses: ArticleExportDialogueItemSource and present Dialogue
 * - ArticleExportDialogueItemSource
 *  - holds:
 *    - ArticleExportDialogueDelegate
 *    - Article
 *  - implements:
 *    - activityViewControllerPlaceholderItem for: Placeholder Item
 *      System Actions to be displyed when using empty `Data()`
 *      so using: empty `NSObject()`
 *    - func activityViewController(activityViewController, itemForActivityType) -> Any?
 *      varous Data types cannot be combined to have a good user experience,
 *      e.g. File and Text Dokument with just a link would be saved for `Save to files`
 *      ...or Copy To Pasteboard has ugly output
 *      **so finally using** `nil` with the  empty `NSObject()` as placeholder
 *    - activityViewControllerLinkMetadata for: Share Dialogue Header
 *      for share sheet header
 *
 *  - **ACTIONS **
 *    - Copy:  Custom Application Action; Copies Article Title, Into, Additional Text, Online Link and generated PDF to Pasteboard
 *    - Open in Safari: Custom Application Action to open online Link in Browser
 *    - Save Newspaper PDF to Files: Custom Application Action (may download first; async)
 *    - Print Newspaper PDF: Custom Application Action (may download first; async)
 *    - Print *Article PDF*:  Custom Application Action (create local PDF on startup first; sync)
 *    - Save *Article PDF* to files:  Custom Application Action (create local PDF on startup first; sync)
 *    - Save *Article PDF* to files:  Custom Application Action (create local PDF on startup first; sync)
 *
 *    *additionally:*
 *      - Air Drop: ArticlePDF
 *      - Messages, Mail: like Copy, but with implementation of
 *
 *  ToDoS
 *  - test all items with Article with no online link url...only one , both
 *    30.04.2015: taz plan:  "Kinotipp" (nur link), "Club 7" (nichts)
 *  - createPDFfromWebView: darkmode issue, mehrspaltigkeit issue
 *  - ✅ Air Drop: local generated file if online Link OR Pdf available (isShareable)
 *  - Message, Mail: text + online Link + optionally: local generated File if online Link OR Pdf available
 *  - ✅ open in Safari, if online Link available
 *  - Print Newspaper PDF: Download if needed Print NAME DELEGATE
 *  - Save Newspaper PDF: Download if needed Print
 *  - Print: Create & Print if not virtual Article, what About Section?
 *  - Save to Files: Create & Save if not virtual Article, what About Section?
 *
 * ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **/

/// A helper class to handle the export of an article by using applicationActivities only
/// providing empty `NSObject()` as Placeholder and nil for `itemForActivityType`
/// Implements: UIActivityItemSource
class ArticleExportDialogueItemSource: NSObject, DoesLog {
  
  /// The article to share.
  var article: Article
  /// An image for the share dialogue header (optional).
  var image: UIImage?
  /// A delegate, e.g., for rendering article PDF.
  var delegate: ArticleExportDialogueDelegate
  /// A message shown during download, if download required
  var downloadMessagePopup: UIAlertController?
  /// A flag indicating if the download has been canceled by user, to not show share/print dialoge after download
  var downloadCanceledByUser = false
  /// The activity caller if reference required
  var caller: CustomUIActivity?
  /// The source view for presenting the share dialogue.
  var sourceView: UIView
  
 
  
  /// Initializes the `ArticleExportDialogueItemSource` with the given article, image,
  /// delegate (for download and PDF Generation), and source view (for Popups)
  ///
  /// - Parameters:
  ///   - article: The article to be shared.
  ///   - image: An optional image to include in the share.
  ///   - delegate: The delegate responsible for handling PDF rendering.
  ///   - sourceView: The source view from which the share dialog is presented.
  init(article: Article, image: UIImage?, delegate: ArticleExportDialogueDelegate, sourceView: UIView) {
    self.article = article
    self.image = image ?? UIImage(named: "AppIcon60x60")
    self.delegate = delegate
    self.sourceView = sourceView
    super.init()
  }
}

/// Extension to implement UIActivityItemSource
extension ArticleExportDialogueItemSource: UIActivityItemSource {
  
  /// implements UIActivityItemSource function
  /// Returns a empty placeholder item for the share sheet.
  /// If using a URL or `Data()` `Save to Files` and `Mail`, `Message`, `AirDrop` is automatically available,
  /// but Mail has only the Filde, no additional Text, Subject and more
  /// CopyToPasteboard only can handle the URL, otherwise nothing happen
  public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
    return NSObject()
  }
  
  /// implements UIActivityItemSource function
  /// - Returns: nil due share uses custom applicationActivities
  public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
    return nil
  }
  
  /// Generates metadata for the share sheet header.
  /// - Parameter activityViewController: The activity view controller requesting the metadata.
  /// - Returns: Metadata containing the article's title, image, and a URL with share options.
  public func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = article.title
    
    if let img = image {
      metadata.iconProvider = NSItemProvider(object: img)
    }
    metadata.originalURL = URL(string: "Artikel:\(article.shareOptions)")
    return metadata
  }
}

/// A protocol to delegate UIActivity function calls
protocol CustomUIActivityActionDelegate {
  var article: Article { get }
  func prepare(caller: CustomUIActivity)
  func perform(caller: CustomUIActivity)
}

/// Extension to implement CustomUIActivityActionDelegate
extension ArticleExportDialogueItemSource: CustomUIActivityActionDelegate {
  
  /// Prepares the necessary actions for different sharing types.
  /// - Parameter caller: The CustomUIActivity calling the preparation.
  func prepare(caller: CustomUIActivity) {
    switch caller.type {
      case .print, .saveToFiles, .message, .copyToPasteboard, .mail:
        createPDFfromWebViewIfNeeded()
      default:
        break
    }
  }
  
  /// Executes the action corresponding to the selected sharing type.
  /// - Parameter caller: The CustomUIActivity requesting the action.
  func perform(caller: CustomUIActivity) {
    switch caller.type {
      case .openInSafari:
        guard let onlineLinkUrl = article.onlineLinkUrl else {
          caller.activityDidFinish(false)
          return
        }
        UIApplication.shared.open(onlineLinkUrl)
        caller.activityDidFinish(true)
      case .moreInfo:
        guard let message = article.shareInfoMessage else {
          caller.activityDidFinish(false)
          return
        }
        let strongSelf = self
        Alert.message(title: "Informationen zum Teilen", message: message){
          let dialogue = ArticleExportDialogue(itemSource: strongSelf)
          dialogue.presentAt(strongSelf.sourceView)
        }
        caller.activityDidFinish(true)
      case .print:
        guard let pdfFileUrl = article.generatedArticlePdfURL else {
          caller.activityDidFinish(false)
          return
        }
        Print.print(pdf: pdfFileUrl, finishCallback: caller.activityDidFinish)
      case .copyToPasteboard:
        handleCopyToPasteboard(for: caller)
      case .paperPdfPrint, .paperPdfSave:
        performPaperPdf(for: caller)
      case .mail:
        handleSendMail(for: caller)
      case .message:
        handleSendMessage(for: caller)
      case .saveToFiles:
        guard let pdfFileUrl = article.generatedArticlePdfURL else {
          caller.activityDidFinish(false)
          return
        }
        saveToFiles(documentUrl: pdfFileUrl, caller: caller)
    }
  }
}

/// Extension for managing the creation of a PDF from a web view.
extension ArticleExportDialogueItemSource {
  
  /// Creates a PDF from the web view content if it hasn't been generated yet.
  func createPDFfromWebViewIfNeeded() {
    // Ensure the PDF is up to date (e.g., if the font has changed).
    delegate.createPDFfromWebView(for: article)
  }
  
  // MARK: - Mail Send Helper
  /// Prepares and sends an email with the article content and PDF as an attachment.
  /// - Parameter caller: The activity caller that initiated the email.
  func handleSendMail(for caller: CustomUIActivity) {
    guard MFMailComposeViewController.canSendMail() else {
      log("action abort: cannot send mail")
      caller.activityDidFinish(false)
      return
    }
    let subject = "Aus der \(App.shortName) vom \(article.issueDate.short)"
    var intro = ""
    if let title = article.title { intro.append(title.appending("\n")) }
    if let authors = article.authors() { intro.append(authors.prepend("von ")) }
    if let online = article.onlineLink { intro.append(online.prepend("\nonline unter:\n")) }
    
    let mailComposer = MFMailComposeViewController()
    self.caller = caller
    mailComposer.mailComposeDelegate = self
    mailComposer.setSubject(subject)
    mailComposer.setMessageBody("\(intro)", isHTML: false)
    if let pdfURL = article.generatedArticlePdfURL, let pdfData = try? Data(contentsOf: pdfURL) {
      mailComposer.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: "\(pdfURL.lastPathComponent)")
    }
    mailComposer.presentAt(sourceView)
  }
  
  // MARK: - Message Send Helper
  /// Prepares and sends a message with the article content and PDF as an attachment.
  /// - Parameter caller: The activity caller that initiated the message.
  func handleSendMessage(for caller: CustomUIActivity) {
    guard MFMessageComposeViewController.canSendText() else {
      log("action abort: cannot send message")
      caller.activityDidFinish(false)
      return
    }
    let subject = "Aus der \(App.shortName) vom \(article.issueDate.short)"
    var intro = ""
    if let title = article.title { intro.append(title.appending("\n")) }
    if let authors = article.authors() { intro.append(authors.prepend("von ")) }
    if let online = article.onlineLink { intro.append(online.prepend("\nonline unter:\n")) }
    
    let messageComposer = MFMessageComposeViewController()
    self.caller = caller
    messageComposer.messageComposeDelegate = self
    messageComposer.body = "\(subject)\n\(intro)\n"
    
    if let pdfURL = article.generatedArticlePdfURL, let pdfData = try? Data(contentsOf: pdfURL) {
      messageComposer.addAttachmentData(pdfData,
                                        typeIdentifier: "com.adobe.pdf",
                                        filename: "\(pdfURL.lastPathComponent)")
    }
    messageComposer.presentAt(sourceView) {
      caller.activityDidFinish(true)
    }
  }
  
  // MARK: - Copy to Pasteboard Helper
  /// Copies the article's text and PDF to the system clipboard.
  /// - Parameter caller: The activity caller that initiated the action.
  func handleCopyToPasteboard(for caller: CustomUIActivity) {
    guard #available(iOS 14.0, *) else {
      caller.activityDidFinish(false)
      return
    }
    var text = "Aus der \(App.shortName) vom \(article.issueDate.short)"
    if let title = article.title { text.append(title.prepend("\n"))}
    if let authors = article.authors() { text.append(authors.prepend("\nvon "))}
    if let online = article.onlineLink { text.append(online.prepend("\nonline unter:\n"))}
    
    var pasteboardItems: [[String: Any]]
    if let pdfURL = article.generatedArticlePdfURL, let pdfData = try? Data(contentsOf: pdfURL) {
      pasteboardItems = [
        [UTType.plainText.identifier: text],
        [UTType.pdf.identifier: pdfData]]
    } else {
      pasteboardItems = [[UTType.plainText.identifier: text]]
    }
    UIPasteboard.general.items = pasteboardItems
    caller.activityDidFinish(true)
  }
  
  /// helper to present a document picker to save the file to the system
  @available(iOS 14.0, *)
  private func doSaveToFiles(documentUrl:URL, caller: CustomUIActivity){
    guard self.downloadMessagePopup == nil else {
      ///should not be needed currently
      dismissDownloadMessagePopupIfNeeded {[weak self] in
        self?.doSaveToFiles(documentUrl: documentUrl, caller: caller)
      }
      return
    }
    self.caller = caller
    let documentPicker = UIDocumentPickerViewController(forExporting: [documentUrl], asCopy: true)
    documentPicker.delegate = self
    documentPicker.presentAt(sourceView)
  }
  
  // MARK: - Save to Files Helper
  /// This method serves as a wrapper for the `doSaveToFiles` method, which handles the actual saving
  /// process. It ensures that the saving functionality is only invoked on iOS 14.0 or later.
  /// If the device runs on an earlier iOS version, the caller is notified of the failure.
  ///
  /// - Parameters:
  ///   - documentUrl: The local URL of the document to be saved to Files.
  ///   - caller: The activity (`CustomUIActivity`) requesting the save operation.
  ///
  /// - Note: If the iOS version is below 14.0, the `activityDidFinish(false)` method is called
  ///   to notify the caller that the operation could not be completed due to an unsupported iOS version.
  func saveToFiles(documentUrl: URL, caller: CustomUIActivity) {
      if #available(iOS 14.0, *) {
          // Save to Files for iOS 14 or newer.
          doSaveToFiles(documentUrl: documentUrl, caller: caller)
      } else {
          // Notify the caller that the operation is not supported on older iOS versions.
          caller.activityDidFinish(false)
      }
  }

  
  // MARK: - Paper PDF Helper
  /// Handles the printing or saving of a PDF if it has already been downloaded.
  ///
  /// This method first checks if a download has been canceled or if a download message popup
  /// is still displayed. If the PDF is already downloaded, it proceeds to print or save it
  /// depending on the caller's type.
  ///
  /// - Parameters:
  ///   - caller: The activity requesting the PDF operation (`CustomUIActivity`), e.g., printing or saving.
  ///   - pdfUrl: The local URL of the downloaded PDF file.
  private func performPaperPdfIfDownloaded(for caller: CustomUIActivity, pdfUrl: URL) {
    // Check if the download was canceled; if yes, dismiss the popup and notify caller of failure.
    guard !downloadCanceledByUser else {
      dismissDownloadMessagePopupIfNeeded()
      caller.activityDidFinish(false)
      return
    }
    
    // If a download message popup is still being displayed, dismiss it before proceeding.
    guard self.downloadMessagePopup == nil else {
      dismissDownloadMessagePopupIfNeeded { [weak self] in
        self?.performPaperPdfIfDownloaded(for: caller, pdfUrl: pdfUrl)
      }
      return
    }
    
    // Handle the requested activity type (printing or saving the PDF).
    switch caller.type {
      case .paperPdfPrint:
        // Print the PDF using the Print helper and notify the caller of the result.
        Print.print(pdf: pdfUrl) { success in
          caller.activityDidFinish(success)
        }
        
      case .paperPdfSave:
        // Save the PDF to Files
        saveToFiles(documentUrl: pdfUrl, caller: caller)
        
      default:
        // Unsupported activity type or iOS version, signal failure.
        caller.activityDidFinish(false)
    }
  }
  
  /// Initiates the process of printing or saving a PDF, downloading it first if necessary.
  ///
  /// This method first checks if the PDF is already available locally. If not, it initiates
  /// the download process. Once the PDF is downloaded, it proceeds with printing or saving it
  /// based on the activity type.
  ///
  /// - Parameter caller: The activity requesting the PDF operation (`CustomUIActivity`).
  func performPaperPdf(for caller: CustomUIActivity) {
    // Check if the PDF is already available locally. If so, proceed directly with the action.
    if let pdfUrl = article.printPdfLocalUrl {
      performPaperPdfIfDownloaded(for: caller, pdfUrl: pdfUrl)
      return
    }
    
    // PDF download is required, ensure required information is available.
    guard let vc = delegate as? ContentVC,
          let issue = article.primaryIssue,
          let pdf = article.pdf else {
      // If necessary details are missing, notify the caller of failure.
      caller.activityDidFinish(false)
      return
    }
    
    // Show a download message popup and start downloading the PDF file.
    showDownloadMessagePopupIfNeeded()
    
    let downloadFinishedCallback:  (Error?)->() = { [weak self] error in
       // Handle the result of the download.
       
       // Ensure the downloaded PDF is available locally.
       guard let pdfUrl = self?.article.printPdfLocalUrl else {
         // Log the error and dismiss the download popup if the PDF is missing.
         self?.log("Missing PDF after download error: \(String(describing: error))")
         self?.dismissDownloadMessagePopupIfNeeded {
           Alert.message(message: Localized("error_download"))
         }
         caller.activityDidFinish(false)
         return
       }
       
       // PDF is downloaded, proceed with the requested action (print or save).
       self?.performPaperPdfIfDownloaded(for: caller, pdfUrl: pdfUrl)
    }
    
    if let searchArticle = article as? SearchArticle, let baseUrl = searchArticle.originalIssueBaseURL {
      vc.dloader.downloadSearchHitFiles(files: [pdf],
                                        baseUrl: baseUrl,
                                        closure: downloadFinishedCallback)
    }
    else {
      vc.dloader.downloadIssueFiles(issue: issue, files: [pdf], closure: downloadFinishedCallback)
    }
  }
  
  /// Show a download message popup
  func showDownloadMessagePopupIfNeeded(){
    guard downloadMessagePopup == nil else { return }
    downloadMessagePopup = Alert.message(title: "Datei wird geladen...",
                                         message: "\n\n",
                                         buttonTitle: "Abbrechen"){[weak self] in
      self?.downloadCanceledByUser = true
      self?.dismissDownloadMessagePopupIfNeeded()
    }
    let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10,y: 5,width: 50, height: 50))
    loadingIndicator.hidesWhenStopped = true
    loadingIndicator.style = UIActivityIndicatorView.Style.medium
    loadingIndicator.startAnimating();
    downloadMessagePopup?.view.addSubview(loadingIndicator)
    loadingIndicator.centerAxis()
  }
  
  /// Dismiss download message popup
  func dismissDownloadMessagePopupIfNeeded(closure: (()->())? = nil) {
    guard downloadMessagePopup != nil else {
      closure?()
      return
    }
    self.downloadMessagePopup?.dismiss(animated: true, completion: {[weak self] in
      self?.downloadMessagePopup = nil
      closure?()
    })
  }
}

/// A protocol defining a delegate for exporting article HTML as PDFs using web view's content.
/// This protocol is intended to be adopted by view controllers that can generate a PDF from a
public protocol ArticleExportDialogueDelegate  where Self: UIViewController{
  func createPDFfromWebView(for article: Article)
}

typealias ActivityFinishCallback = ((Bool) -> ())

/// Extension to implement MFMailComposeViewControllerDelegate
extension ArticleExportDialogueItemSource: MFMailComposeViewControllerDelegate {
  
  
  func mailComposeController(_ controller: MFMailComposeViewController,
                             didFinishWith result: MFMailComposeResult,
                             error: (any Error)?) {
    log("finished with result: \(result.rawValue)")
    controller.dismiss(animated: true)
    self.caller?.activityDidFinish(true)
  }
}

/// Extension to implement MFMessageComposeViewControllerDelegate
extension ArticleExportDialogueItemSource: MFMessageComposeViewControllerDelegate {
  func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    log("finished with result: \(result.rawValue)")
    controller.dismiss(animated: true)
    self.caller?.activityDidFinish(true)
  }
}

/// Extension to implement UIDocumentPickerDelegate
extension ArticleExportDialogueItemSource: UIDocumentPickerDelegate {
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    caller?.activityDidFinish(false)
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    caller?.activityDidFinish(true)
  }
  
}

///implementation of ArticleExportDialogueDelegate by ContentVC
extension ContentVC:ArticleExportDialogueDelegate {
  ///create printable pdf from current webviev content
  public func createPDFfromWebView(for article: Article) {
    guard let printFormatter = currentWebView?.viewPrintFormatter() else {
      return
    }
    let renderer = CustomPrintPageRenderer()
    renderer.customText = "\(App.shortName) vom \(issue.date.short)"
    if let title = article.title {
      renderer.customText.append(" - \(title.prefix(50))")
      if title.length > 50 {
        renderer.customText.append("...")
      }
    }
    
    // Page bounds for paperformat A4
    /// 21.0 * 72 / 2,54 #  29.7*72/2,54 => 595,275 # 841,889
    let pageSize = CGSize(width: 595.2, height: 841.8) // A4 in points (72 DPI)
    /// 1.5 * 72 / 2,54 #  3*72/2,54 =>  42,519 # 85,039 => 40 & 80
    let margin: UIEdgeInsets = UIEdgeInsets(top: 30, left: 30, bottom: 60, right: 30)
    
    renderer.setValue(NSValue(cgRect: CGRect(x: 0,
                                             y: 0,
                                             width: pageSize.width,
                                             height: pageSize.height)),
                      forKey: "paperRect")
    renderer.setValue(NSValue(cgRect: CGRect(x: margin.left,
                                             y: margin.top,
                                             width: pageSize.width - (margin.left + margin.right),
                                             height: pageSize.height - (margin.top + margin.bottom))),
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
    do {
      try pdfData.write(to: article.generatedArticlePdfTargetURL)
    } catch {
      log("Fehler beim Speichern des PDFs: \(error.localizedDescription)")
    }
  }
}

///just a Wrapper for UIActivityViewController to simplify article sharing
class ArticleExportDialogue: UIActivityViewController {
  
  /// Initializer for `ArticleExportDialogue`.
  /// - Parameter itemSource: An instance of `ArticleExportDialogueItemSource` that provides the article and its data to be shared
  init(itemSource: ArticleExportDialogueItemSource){
    super.init(activityItems: [itemSource],
               applicationActivities: CustomUIActivityFactory.createAvailableApplicationActivities(with: itemSource))
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


//helper extension for article
extension Article {
  /// A computed property that checks if the article is shareable.
  /// An article is considered shareable if it has a valid online link or a the pdf property is set
  var isShareable: Bool {
    if self.onlineLink?.isEmpty == false { return true }
    if self.pdf != nil { return true }
    return false
  }
  
  var printPdfLocalUrl: URL? {
    guard let fileName = pdf?.fileName else { return nil }
    let file = File(dir: self.dir.path, fname: fileName)
    if file.exists { return file.url }
    return nil
  }
  
  ///message for potentially not available share options
  var shareInfoMessage: String? {
    let printInfo = "Die Optionen \"Drucken\" und \"In Dateien sichern\" erzeugt auf Ihrem \(Device.singleton.description) ein PDF mit den aktuellen Schrifteinstellungen. Wenn Sie also größere oder kleinere Schrift in dem PDF bevorzugen, stellen Sie diese bitte vorher um."
    if onlineLink?.isEmpty == true &&  pdf == nil {
      return "Für diesen Artikel existiert leider kein Online-Link oder ein PDF der Zeitungsansicht. Sie können jedoch ein PDF aus der Artikelansicht erstellen, speichern oder teilen.".appending("\n\(printInfo)")
    }
    else if onlineLink?.isEmpty == true {
      return "Für diesen Artikel existiert leider kein Online-Link. Sie können jedoch das PDF speichern oder teilen.".appending("\n\(printInfo)")
    }
    else if pdf == nil {
      return "Für diesen Artikel existiert leider kein PDF der Zeitungsansicht. Sie können jedoch den Online Link teilen sowie ein PDF aus der Artikelansicht erstellen, speichern oder teilen".appending("\n\(printInfo)")
    }
    return printInfo
  }
}

///fileprivate helper extension for article
fileprivate extension Article {
  /// A computed property that generates the PDF file name based on the article's HTML filename.
  var pdfFileName: String {
    guard let htmlFilename = html?.name else { return "tazArtikel.pdf"}
    return htmlFilename.replacingOccurrences(of: ".html", with: "-app.pdf")

  }
  
  /// articles online URL, if available
  var onlineLinkUrl: URL? {
    guard let link = self.onlineLink else { return nil }
    return URL(string: link)
  }
  
  /// helper to generate the URL for the article PDF.
  var generatedArticlePdfTargetURL:URL {
    return Dir.cache.url.appendingPathComponent(pdfFileName)
  }
  
  /// helper to generate the URL for the article PDF.
  var generatedArticlePdfURL:URL? {
    let url = generatedArticlePdfTargetURL
    let file = File(generatedArticlePdfTargetURL)
    if file.exists { return url }
    return nil
  }
  
  ///string for share sheet header
  var shareOptions: String {
    if self.onlineLink?.isEmpty == true { return "Drucken/Exportieren"}
    return "Teilen/Drucken/Sichern"
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
    ///in case of save to files prevent duplicate file ending .pdf
    printInfo.jobName = pdf.lastPathComponent.replacingOccurrences(of: ".pdf", with: "")
    printController.printInfo = printInfo
    printController.printingItem = pdf
    finishCallback(true)
    printController.present(animated: true, completionHandler: {_,success,_ in
      Log.debug("print done")
    })
  }
}


/// A custom page renderer that handles drawing a footer on each printed page.
/// Inherits from `UIPrintPageRenderer` and provides a custom footer with page numbering.
///
/// This class is designed to be used when printing documents with a custom footer
/// that includes the app's name and the page number (e.g., "AppName - 1/5") centered in the footer area.
class CustomPrintPageRenderer: UIPrintPageRenderer {
  
  /// The default height for the footer area in the printed page.
  let defaultFooterHeight: CGFloat = 50
  
  /// The text to be displayed in the footer. By default, it is the app's name.
  /// It can be modified to include different text as required.
  var customText: String = App.shortName
  
  /// Initializes the `CustomPrintPageRenderer` with a default footer height.
  /// This constructor sets the footer height to `defaultFooterHeight` and ensures
  /// that every printed page will have a footer of the specified height.
  override init() {
    super.init()
    self.footerHeight = defaultFooterHeight
  }
  
  /// Draws the footer on the printed page at the given index.
  ///
  /// This method calculates the text size and position and then renders the footer text,
  /// which includes the `customText` and the current page number (`pageIndex + 1`)
  /// out of the total number of pages (`numberOfPages`), centered at the bottom of the page.
  ///
  /// - Parameters:
  ///   - pageIndex: The index of the current page (zero-based).
  ///   - footerRect: The rectangle defining the area of the footer on the page.
  ///
  /// The text is drawn with the app's name followed by the page number (e.g., "AppName - 1/3"),
  /// using a small gray font. The text is centered horizontally within the footer area.
  override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
    // Construct the footer text with the app's name and the current page number
    let footerText = customText.appending(" - \(pageIndex + 1)/\(numberOfPages)")
    
    // Define the font and color for the footer text
    let textFont = Const.Fonts.contentFont(size: 12)  // Small font for the footer
    let textColor = UIColor.gray  // Gray color for the footer text
    
    // Set up the attributes for the text (font and color)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: textFont,
      .foregroundColor: textColor
    ]
    
    // Calculate the size of the text to determine its position
    let textSize = footerText.size(withAttributes: attributes)
    
    // Calculate the point at which to draw the text, centering it in the footer rectangle
    let drawPoint = CGPoint(
      x: footerRect.midX - textSize.width / 2,  // Center horizontally
      y: footerRect.midY - textSize.height / 2  // Center vertically within the footer
    )
    
    // Draw the footer text at the calculated position
    footerText.draw(at: drawPoint, withAttributes: attributes)
  }
}
