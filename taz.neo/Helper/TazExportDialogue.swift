//
//  ArticleExportDialogue.swift
//  taz.neo
//
//  Created by Ringo Müller on 25.09.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import NorthLib
import LinkPresentation

class ArticleExportDialogueItemSource:NSObject, UIActivityItemSource, DoesLog {
  /// the article to share
  var article: Article
  /// a image for share dialogue
  var image: UIImage?
  /// source view from where share dialog is started
  var sourceView: UIView
  /// hepler e.g. for render article pdf
  var delegate: ArticleExportDialogueDelegate
  ///
  var articlePdfURL: URL?
  
  public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
    log("requested activityViewControllerPlaceholderItem for: \(activityViewController)")
    return articlePdfURL ?? "Fehler"
  }
  
  public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
    print("requested item for type: \(activityType?.rawValue ?? "-")")
    switch activityType {
      case .copyToPasteboard:
        
        print(">> return >>")
        print(articlePdfURL ?? article.onlineLink ?? "Noch nicht da zum drucken")
        print("<< return <<")
#warning("copyToPasteboard did not work and is called multiple times!")
//        UIPasteboard.general.string = String(msg.prefix(12000))
        return articlePdfURL ?? article.onlineLink ?? "Noch nicht da zum drucken"
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
  
  public func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = article.title
    
    if let img = image {
      metadata.iconProvider = NSItemProvider(object: img)
    }
    metadata.originalURL = URL(string: "Artikel:\(article.shareOptions)")
    return metadata
  }
  
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

extension ArticleExportDialogueItemSource: UIDocumentPickerDelegate {}

///just a Wrapper for UIActivityViewController to simplify Article sharing
class ArticleExportDialogue: UIActivityViewController {
  var itemSource: ArticleExportDialogueItemSource
  
  init(itemSource: ArticleExportDialogueItemSource){
    self.itemSource = itemSource
    super.init(activityItems:  [itemSource],
               applicationActivities: itemSource.applicationActivities)
  }
  
  static func show(article:Article, delegate: ArticleExportDialogueDelegate, image: UIImage?, sourceView: UIView){
    let dialogueItemSource = ArticleExportDialogueItemSource(article: article, image: image, delegate: delegate, sourceView: sourceView)
    let dialogue = ArticleExportDialogue(itemSource: dialogueItemSource)
    dialogue.presentAt(sourceView)
  }
}

extension ArticleExportDialogueItemSource {
  public var applicationActivities: [UIActivity]  {
    var items:[UIActivity] = []
    items.appendIfPresent(activityOpenOnlineLinkInSafari)
    items.appendIfPresent(activitySavePaperPDF)
    items.appendIfPresent(activityPrintPaperPDF)
    items.appendIfPresent(moreInfo)
    return items
  }
  
  private var onlineLinkUrl: URL? {
    guard let link = article.onlineLink else { return nil }
    return URL(string: link)
  }
  
  private var activityOpenOnlineLinkInSafari: UIActivity? {
    if self.onlineLinkUrl == nil { return nil }
    return CustomUIActivity(type: .openInSafari) {[weak self] finishCallback in
      guard let onlineLinkUrl = self?.onlineLinkUrl else {
        finishCallback(false)
        return
      }
      UIApplication.shared.open(onlineLinkUrl)
      finishCallback(true)
    }
  }
  
  private var moreInfo: UIActivity? {
    guard let message = article.shareInfoMessage else { return nil }
    return CustomUIActivity(type: .moreInfo) { finishCallback in
      Alert.message(title: "Informationen zum Teilen",
                    message: message)
      finishCallback(true)
    }
  }
  
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
  
  private var activityPrintPaperPDF: UIActivity? {
    guard let pdfFileName = article.pdf?.name else { return nil }
    return CustomUIActivity(type: .paperPdfPrint) {[weak self] finishCallback in
      self?.printPaperPdf(pdfFileName: pdfFileName, finishCallback: finishCallback)
    }
  }
  
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
  
  @available(iOS 14.0, *)
  func saveToFiles(documentUrl:URL){
    let documentPicker = UIDocumentPickerViewController(forExporting: [documentUrl], asCopy: true)
    documentPicker.delegate = self
    UIWindow.keyWindow?.rootViewController?.present(documentPicker, animated: true, completion: nil)
  }
  
  func loadPrintPdf(closure: @escaping (Error?)->(), finishCallback: @escaping ActivityFinishCallback){
    guard let vc = (delegate as? ArticleVC),
          let issue = article.primaryIssue,
          let pdf = article.pdf else { return }
    vc.dloader.downloadIssueFiles(issue: issue, files: [pdf], closure: closure)
  }
}

public protocol ArticleExportDialogueDelegate  where Self: UIViewController{
  func createPDFfromWebView()
}

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


public enum CustomUIActivityType {
  case openInSafari, paperPdfSave, paperPdfPrint,  moreInfo
  
  public var title: String {
    switch self {
      case .openInSafari:    return "In Safari öffnen"
      case .paperPdfSave:  return "Zeitungs PDF in Dateien sichern"
      case .paperPdfPrint:  return "Zeitungs PDF drucken"
      case .moreInfo:  return "Informationen zum teilen"
    }
  }
  
  public var type: UIActivity.ActivityType {
    switch self {
      case .openInSafari:    return UIActivity.ActivityType(rawValue: "de.taz.open.in.safari")
      case .paperPdfSave:  return UIActivity.ActivityType(rawValue: "de.taz.paperPdf.save")
      case .paperPdfPrint:  return UIActivity.ActivityType(rawValue: "de.taz.paperPdf.print")
      case .moreInfo:  return UIActivity.ActivityType(rawValue: "de.taz.share.moreinfo")
    }
  }
  
  public var image: UIImage? {
    switch self {
      case .openInSafari: return UIImage(systemName: "safari")
      case .paperPdfSave: return UIImage(systemName: "folder")
      case .paperPdfPrint: return UIImage(systemName: "printer")
      case .moreInfo: return UIImage(systemName: "info")
    }
  }
}


public class CustomUIActivity: UIActivity {
  var type: CustomUIActivityType
  var action: (@escaping ActivityFinishCallback) -> Void
  
  init(type: CustomUIActivityType, performAction: @escaping( @escaping ActivityFinishCallback) -> Void) {
    self.type = type
    action = performAction
    super.init()
  }
  public override var activityTitle: String? {
    return type.title
  }
  
  public override var activityImage: UIImage? {
    return type.image
  }
  
  override public var activityType: UIActivity.ActivityType? {
    return type.type
  }
  
  public override class var activityCategory: UIActivity.Category {
    return .action
  }
  public override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
    return true///return false removes this Activity Option from share dialog
  }
  public override func prepare(withActivityItems activityItems: [Any]) {
    //Load file muss hierhin!!!
    //    self.activityItems = activityItems
  }
  public override func perform() {
    action{[weak self] ret in self?.activityDidFinish(ret) }
  }
}
typealias ActivityFinishCallback = ((Bool)->())

extension Article {
  var isShareable: Bool {
    if self.onlineLink?.isEmpty == false { return true }
    if self.pdf != nil { return true }
    return false
  }
}

fileprivate extension Article {
  var pdfFileName: String {
    guard let htmlFilename = html?.name else { return "tazArtikel.pdf"}
    return htmlFilename.replacingOccurrences(of: ".html", with: "HTML.pdf")
  }
  
  var generatedArticlePdfURL:URL {
    return Dir.cache.url.appendingPathComponent(pdfFileName)
  }
  
  var shareOptions: String {
    if self.onlineLink?.isEmpty == true { return "Drucken/Exportieren"}
    return "Teilen/Drucken/Exportieren"
  }
  
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

extension Print {
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
