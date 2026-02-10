//
//  PdfGenerationService.swift
//  taz.neo
//
//  Created by Ringo Müller on 17.01.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import UIKit
import WebKit

/// Handles the generation of PDFs for articles.
class PdfGenerationService: DoesLog {
  
  private var article: Article
  private var webView: WebView?
  private var loaded = false
  private var missingFilesCount: Int
  
  /// Initializes the service with the provided article.
  /// - Parameter article: The article to generate a PDF for.
  init(article: Article) {
    self.article = article
    self.missingFilesCount = article.files.count - 1
    prepare()
  }
  
  /// Prepares the article for PDF generation by loading HTML and downloading necessary files.
  private func prepare() {
    let group = DispatchGroup()
    group.enter()
    
    Task {
      await loadHtml()
      await downloadFilesIfNeeded()
      await loadHtml()
      group.leave()
    }
    
    group.notify(queue: .main) {[weak self] in
      self?.debug("PDF preparation complete.")
    }
  }
    
  /// Downloads required files for the article if they are missing.
  private func downloadFilesIfNeeded() async {
    let filesToDownload = article.files.filter { $0.fileName != article.html?.fileName }
    guard filesToDownload.count > 0 else {
      debug("no files to download!")
      return
    }
    guard let downloader = TazAppEnvironment.sharedInstance.feederContext?.dloader else {
      debug("no downloader available")
      return
    }
    
    if let searchArticle = article as? SearchArticle {
      guard let baseUrl = searchArticle.baseURL else{
        debug("Error: baseUrl for serachArticle not set")
        return
      }
      await downloadSearchArticleFiles(downloader: downloader, files: filesToDownload, baseUrl: baseUrl)
    } else if let issue = article.primaryIssue{
      
      await downloadIssueFiles(downloader: downloader, files: filesToDownload, issue: issue)
    }
  }
  
  
  private func downloadSearchArticleFiles(downloader: Downloader, files: [FileEntry], baseUrl: String) async {
    do {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        downloader.downloadSearchHitFiles(files: article.files, baseUrl: baseUrl) { error in
          if let error = error {
            continuation.resume(throwing: error)
          } else {
            self.missingFilesCount = 0
            continuation.resume(returning: ())
          }
        }
      }
    } catch {
      log("Error during file download: \(error)")
    }
  }
  
  private func downloadIssueFiles(downloader: Downloader, files: [FileEntry], issue: Issue) async {
    do {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        downloader.downloadIssueFiles(issue: issue, files: files) { error in
          if let error = error {
            continuation.resume(throwing: error)
          } else {
            self.missingFilesCount = 0
            continuation.resume(returning: ())
          }
        }
        
      }
    } catch {
      log("Error during file download: \(error)")
    }
  }
  
  /// Loads the article's HTML into the WebView.
  @MainActor
  private func loadHtml() async {
    webView = WebView()
    if let webView = webView {
      webView.isHidden = true
      UIWindow.activeKeyWindow?.addSubview(webView)
      webView.frame = CGRect(x: 0, y: 0, width: 600, height: 900)
    }
      
    if article is SearchArticle == false {
      webView?.baseDir =  TazAppEnvironment.sharedInstance.feederContext?.storedFeeder.baseDir.path
    }
    webView?.load(url: File(article.path).url)
    debug("HTML loaded.")
    loaded = true
  }
  
  /// Creates a PDF from the loaded WebView content.
  func createPDF() {
    guard loaded,
          let printFormatter = webView?.viewPrintFormatter() else {
      Toast.show("PDF could not be created.")
      return
    }
    
    if missingFilesCount > 0 {
      log("Some images may be missing in the PDF. Missing Files: \(missingFilesCount)")
    }
    
    let renderer = CustomPrintPageRenderer()
    
    // Add metadata to the PDF.
    if let date = article.issueDate ?? article.primaryIssue?.date {
      renderer.customText = "\(App.shortName) vom \(date.short)"
    }
    if let title = article.title {
      renderer.customText.append(" - \(title.prefix(50))")
      if title.count > 50 {
        renderer.customText.append("...")
      }
    }
    
    // Define A4 page size and margins.
    let pageSize = CGSize(width: 595.2, height: 841.8) // A4 at 72 DPI
    let margin = UIEdgeInsets(top: 30, left: 30, bottom: 60, right: 30)
    
    renderer.setValue(NSValue(cgRect: CGRect(origin: .zero, size: pageSize)), forKey: "paperRect")
    renderer.setValue(NSValue(cgRect: CGRect(x: margin.left,
                                             y: margin.top,
                                             width: pageSize.width - margin.left - margin.right,
                                             height: pageSize.height - margin.top - margin.bottom)),
                      forKey: "printableRect")
    renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
    
    // Metadaten definieren
    let pdfMetadata: [String: Any] = [
      kCGPDFContextTitle as String: "\(article.title ?? "Artikel")",
      kCGPDFContextAuthor as String: article.authors() ?? "-",
      kCGPDFContextSubject as String: "taz vom: \(article.issueDate?.short ?? "???")"
    ]
    
    // Create the PDF.
    let pdfData = NSMutableData()
    UIGraphicsBeginPDFContextToData(pdfData, .zero, pdfMetadata)
    
    for pageIndex in 0..<renderer.numberOfPages {
      UIGraphicsBeginPDFPage()
      let bounds = UIGraphicsGetPDFContextBounds()
      renderer.drawPage(at: pageIndex, in: bounds)
    }
    UIGraphicsEndPDFContext()
    
    // Save the PDF.
    do {
      try pdfData.write(to: article.generatedArticlePdfTargetURL)
    } catch {
      log("Error saving PDF: \(error.localizedDescription)")
    }
    self.webView?.removeFromSuperview()
  }
}

// MARK: - UIPrintPageRenderer Extension
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


// MARK: - Article Extensions

extension Article {
  /// Generates the PDF file name based on the article's HTML filename.
  var pdfFileName: String {
    guard let htmlFilename = html?.name else { return "tazArticle.pdf" }
    return htmlFilename.replacingOccurrences(of: ".html", with: "-app.pdf")
  }
  
  /// Provides the URL of the generated article PDF if it exists.
  var generatedArticlePdfURL: URL? {
    let file = File(generatedArticlePdfTargetURL)
    return file.exists ? generatedArticlePdfTargetURL : nil
  }
  
  /// Provides the target URL for the generated article PDF.
  var generatedArticlePdfTargetURL: URL {
    return Dir.cache.url.appendingPathComponent(pdfFileName)
  }
}
