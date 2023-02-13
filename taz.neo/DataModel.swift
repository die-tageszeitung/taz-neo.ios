//
//  DataModel.swift
//
//  Created by Norbert Thies on 12.09.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import PDFKit

/**
 Errors a Feeder may encounter
 */
public enum FeederError: Error, Equatable {
  case invalidAccount(String?)
  case expiredAccount(String?)
  case changedAccount(String?)
  case unexpectedResponse(String?)
  
  public var description: String {
    switch self {
    case .invalidAccount(let msg): 
      return "Invalid Account: \(msg ?? "unknown reason")"
    case .expiredAccount(let msg): 
      return "Expired Account: \(msg ?? "unknown reason")"
    case .changedAccount(let msg): 
      return "Changed Account: \(msg ?? "unknown reason")"
    case .unexpectedResponse(let msg):
      return "Unexpected server response: \(msg ?? "unknown reason")"
    }
  }    
  public var errorDescription: String? { return description }
  
  public var associatedValue: String? {
    switch self {
      case .invalidAccount(let msg): return msg
      case .expiredAccount(let msg): return msg
      case .changedAccount(let msg): return msg
      case .unexpectedResponse(let msg): return msg
    }
  }
  
  public var expiredAccountDate: Date? {
    switch self {
      case .expiredAccount(let msg):
        guard let msg = msg else { return nil }
        return UsTime(iso:msg).date
      default: return nil
    }
  }
  
  public static func === (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
      case (let .invalidAccount(lhsString), let .invalidAccount(rhsString)):
        return lhsString == rhsString
      case (let .expiredAccount(lhsString), let .expiredAccount(rhsString)):
        return lhsString == rhsString
      case (let .changedAccount(lhsString), let .changedAccount(rhsString)):
        return lhsString == rhsString
      case (let .unexpectedResponse(lhsString), let .unexpectedResponse(rhsString)):
        return lhsString == rhsString
      default:
        return false
    }
  }
  
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
      case (.invalidAccount(_), .invalidAccount(_)): fallthrough
      case (.expiredAccount(_), .expiredAccount(_)): fallthrough
      case (.changedAccount(_), .changedAccount(_)): fallthrough
      case (.unexpectedResponse(_), .unexpectedResponse(_)):
        return true
      default:
        return false
    }
  }
  
} // FeederError

struct AuthStatusError: Swift.Error {
  var status:  GqlAuthStatus
  var customerType:  GqlCustomerType?
  var message: String?
  var token: String?
}

struct DefaultError: Swift.Error {
  var message: String?
}

struct DownloadError: Swift.Error {
  var message: String?
  var handled = false
  var enclosedError : Error?
}

/**
 A FileStorageType defines where a file is stored.
 */
public enum FileStorageType: String, CodableEnum {  
  case issue     = "issue"     /// issue local file
  case global    = "global"    /// global to all issues and feeds
  case resource  = "resource"  /// resource local file
  case unknown   = "unknown"   /// decoded from unknown string
} // FileStorageType

/**
 A FileEntry describes a file as a member of a Feed or an Issue
 */
public protocol FileEntry: DlFile, ToString, DoesLog {
  /// Name of file (no path)
  var name: String { get }
  /// Storage type (global, issue, ...)
  var storageType: FileStorageType { get }
  /// The file's modification time
  var moTime: Date { get }
  /// The size in bytes
  var size: Int64 { get }
  /// SHA256 of the file's contents
  var sha256: String { get }
}

public extension FileEntry {
  /// We are currently not interested in mime types
  var mimeType: String? { return nil }

  func toString() -> String {
    return "File \(name) (\(storageType.toString())), \(size) bytes, \(UsTime(moTime).toString())\n  SHA256: \(sha256)"
  }
  
  var fileName: String {
    switch storageType {
      case .global: return "global/\(name)"
      case .resource: return "resource/\(name)"
      default: return name
    }  
  }
  
  func fileNameExists(inDir: String) -> Bool {
    let f = File(dir: inDir, fname: fileName)
    let exists = f.exists 
    if exists && ((f.mTime != moTime) || (f.size != size)) {
      log("* Warning: File \(fileName) exists but mtime and/or size are wrong \(f.mTime) !=? \(moTime) || \(f.size) !=? \(size)")
    }
    return exists
  }  

}

/// Image resolution
public enum ImageResolution: String, CodableEnum {  
  case small  = "small"  /// small image resolution used eg. for thumpnails
  case normal = "normal" /// regular resolution used in Articles
  case high   = "high"   /// high resolution when Image is zoomed 
  case unknown = "unknown"   /// decoded from unknown string
} // ImageResolution

/// Image type
public enum ImageType: String, CodableEnum {  
  case picture       = "picture"       /// regular foto/graphic as used in articles
  case advertisement = "advertisement" /// an advertisement :-(
  case facsimile     = "facsimile"     /// eg. of a print page
  case button        = "button"        /// a button (eg. the slider button)
  case unknown       = "unknown"       /// decoded from unknown string
} // ImageType

/**
 An Image in a certain resolution
*/
public protocol ImageEntry: FileEntry {
  /// Resolution of image
  var resolution: ImageResolution { get }
  /// Type of image
  var type: ImageType { get }
  /// Transparency
  var alpha: Float? { get }
  /// Is the image sharable
  var sharable: Bool { get }
}

public extension ImageEntry { 
  
  /// Returns the prefix of an image name, ie. the name without resolution
  /// and extension: media.nnn.high.jpg -> media.nnn
  static func prefix(_ fname: String) -> String {
    File.progname(File.progname(fname)) 
  }
  
  /// Returns the high resolution filename, eg. media.nnn.high.jpg
  static func highRes(_ fname: String) -> String {
    let prefix = self.prefix(fname)
    let ext = File.extname(fname)
    return "\(prefix).high.\(ext)"
  }
  
  /// The prefix of the filename
  var prefix: String { Self.prefix(self.fileName) }
  
  /// The high resolution filename
  var highRes: String { Self.highRes(self.fileName) }
  
  func toString() -> String {
    var sAlpha = ""
    if let alpha = self.alpha { sAlpha = ", alpha=\(alpha)" }
    return "Image \(name) res \(resolution), type \(type) (\(storageType.toString()))\(sAlpha), \(size) bytes, \(UsTime(moTime).toString())\n  SHA256: \(sha256)"
  }
}

/**
 A list of files to transfer from the download server
 */
public protocol Payload: ToString {
  /// Number of bytes loaded from server
  var bytesLoaded: Int { get }
  /// Total number of bytes to load (of all files)
  var bytesTotal: Int { get }
  /// Date/Time of download start
  var downloadStarted: Date? { get }
  /// Date/Time when download finished
  var downloadStopped: Date? { get }
  /// Where to put downloaded files
  var localDir: String { get }
  /// URL of remote base directory
  var remoteBaseUrl: String { get }
  /// Name of zip-file containing the comple payload
  var remoteZipName: String? { get }
  /// Files to download
  var files: [FileEntry] { get }
  /// Issue containing this payload (if any)
  var issue: Issue? { get }
  /// Resources containing this payload (if any)
  var resources: Resources? { get }
}

public extension Payload {
  var bytesLoaded: Int { return 0 }
  var bytesTotal: Int { return 0 }
  var downloadStarted: Date? { return nil }
  var downloadStopped: Date? { return nil }
  var isComplete: Bool { bytesTotal <= bytesLoaded }
  func toString() -> String {
    "Payload \(files.count) files, bytes loaded: \(bytesLoaded)/\(bytesTotal)"
  }
}

/**
 A list of resource files
 */
public protocol Resources: ToString, AnyObject {
  /// Are these Resources currently being downloaded
  var isDownloading: Bool { get set }
  /// Have these Resources been downloaded
  var isComplete: Bool { get set }
  /// Resource list version
  var resourceVersion: Int { get }
  /// Base URL of resource files
  var resourceBaseUrl: String { get }
  /// name of resource zip file (under resourceBaseUrl)
  var resourceZipName: String { get }
  /// List of files
  var resourceFiles: [FileEntry] { get }
  /// Payload of files
  var payload: Payload { get }
} // ResourceList

public extension Resources {
  /// URL of zip file
  var resourceZipUrl: String { "\(resourceBaseUrl)/\(resourceZipName)" }
  func toString() -> String {
    var ret = "Resources (v) \(resourceVersion) @ \(resourceBaseUrl):\n"
    for f in resourceFiles {
      ret += "\(f.toString())\n".indent(by: 2, first: "- ")
    }
    return ret
  }
}

/**
 The author of an article
 */
public protocol Author: ToString {
  /// Complete name
  var name: String? { get }
  /// Photo of author
  var photo: ImageEntry? { get }
} // Author

public extension Author {
  func toString() -> String {
    return "author \(name ?? "unknown")"
  }
}

/**
 Some HTML content (eg. Article or Section)
 */
public protocol Content {
  /// File storing content HTML
  var html: FileEntry { get }
  /// Optional title of content
  var title: String? { get }
  /// List of images used in content
  var images: [ImageEntry]? { get }
  /// List of authors (if applicable)
  var authors: [Author]? { get }
  /// Issue where Content data is stored
  var primaryIssue: Issue? { get }
  /// Directory where Content is stored
  var dir: Dir { get }
  /// Absolute pathname of content
  var path: String { get }
  /// Date of Issue encompassing this Content
  var issueDate: Date { get }
  /// Title of Section refering to this content
  var sectionTitle: String? { get }
  /// BaseURL of server for this content 
  var baseURL: String { get }
}

public extension Content {
  
  func toString() -> String {
    var ret = "\(title ?? "[Unknown title]") ("
    if let au = authors, au.count > 0 {
      ret += au[0].toString()
    }
    else { ret += "author unknown" }
    ret += ")\n  \(html.name)"
    return ret
  }
  
  /// Directory where Content is stored
  var dir: Dir { 
    guard let issue = primaryIssue
    else { fatalError("Undefined primaryIssue") }
    return issue.dir 
  }
  
  /// Absolute pathname of content
  var path: String { "\(dir.path)/\(html.name)" }
  
  /// Date of Issue encompassing this Content (refering to primaryIssue)
  var defaultIssueDate: Date { 
    guard let issue = primaryIssue
    else { fatalError("Undefined primaryIssue") }
    return issue.date
  }
  var issueDate: Date { defaultIssueDate }
  
  /// BaseURL of server for this content 
  var defaultBaseURL: String { 
    guard let issue = primaryIssue
    else { fatalError("Undefined primaryIssue") }
    return issue.baseUrl
  }
  var baseURL: String { defaultBaseURL }
  
  /// Title of Section refering to this content
  var sectionTitle: String? { nil }
 
  /// All files incl. normal res photos
  var files: [FileEntry] {
    var ret: [FileEntry] = [html]
    if let imgs = images, imgs.count > 0 {
      for img in imgs { if img.resolution == .normal { ret += img } }
    }
    if let auths = authors, auths.count > 0 {
      for au in auths { if let p = au.photo { ret += p } }
    }
    return ret
  }

  /// Only high res photos
  var photos: [ImageEntry] {
    var ret: [ImageEntry] = []
    if let imgs = images, imgs.count > 0 {
      for img in imgs { if img.resolution == .high { ret += img } }
    }
    return ret
  }
  
  /// photoDict returns a dictionary of images tuples
  var photoDict: [String : (normal: ImageEntry?, high: ImageEntry?)] {
    guard let images = self.images else { return [:] }
    var dict: [String : (normal: ImageEntry?, high: ImageEntry?)] = [:]
    for img in images {
      if img.resolution == .normal || img.resolution == .high {
        let key = img.prefix
        if let val = dict[key] {
          if img.resolution == .normal { dict[key] = (normal:img, high:val.high) }
          else { dict[key] = (normal:val.normal, high:img) }
        }
        else {
          if img.resolution == .normal { dict[key] = (normal:img, high:nil) }
          else { dict[key] = (normal:nil, high:img) }
        }
      }
    }
    return dict
  }
  
  /// photoPairs returns an array of images in resolutions (normal,high)
  var photoPairs: [(normal: ImageEntry?, high: ImageEntry?)] {
    var ret: [(normal: ImageEntry?, high: ImageEntry?)] = []
    let all = self.photos
    let pairs = self.photoDict
    for img in all {
      if let p = pairs[img.prefix] { ret += p }
    }
    return ret
  }

  func authors(_ separator: String = ", ") ->  String? {
    guard let a = authors else { return nil }
    return a.map{ $0.name ?? "" }.joined(separator: separator)
  }

} // Content

/**
 An Article
 */
public protocol Article: Content, ToString {
  /// File storing audio data
  var audio: FileEntry? { get }
  /// Teaser of article
  var teaser: String? { get }
  /// Link to online version
  var onlineLink: String? { get }
  /// Has Article been bookmarked
  var hasBookmark: Bool { get set }
  /// List of PDF page (-file) names containing this article
  var pageNames: [String]? { get }
  /// Server side article ID
  var serverId: Int? { get }
  /// Aprox. reading duration in minutes
  var readingDuration: Int? { get }
} // Article

public extension Article {
  
  func toString() -> String { "\(hasBookmark ? "Bookmarked " : "")Article \((self as Content).toString())" }
  
  /// Returns true if this Article can be played
  var canPlayAudio: Bool { ArticlePlayer.singleton.canPlay(art: self) }
  
  /// Start/stop audio play if available
  func toggleAudio(issue: Issue, sectionName: String) {
    ArticlePlayer.singleton.toggle(issue: issue, art: self, sectionName: sectionName)
  }
  
  // By default Articles don't have bookmarks
  var hasBookmark: Bool { get { false } set {} }
  
  func isEqualTo(otherArticle: Article) -> Bool{
    return self.html.sha256 == otherArticle.html.sha256
    && self.html.name == otherArticle.html.name
    && self.title == otherArticle.title
  }
} // Article

/**
 Section type
 */
public enum SectionType: String, CodableEnum {  
  case articles = "articles"  /// a list of articles
  case text     = "text"      /// a single HTML text (eg. imprint)
  case unknown  = "unknown"   /// decoded from unknown string
} // SectionType

/**
 A Section containing Articles
 */
public protocol Section: Content, ToString {
  /// Name of section
  var name: String { get }
  /// Optional title (not to display in table of contents)
  var extendedTitle: String? { get }  
  /// Type of section
  var type: SectionType { get }
  /// List of articles
  var articles: [Article]? { get }
  /// The image serving as a navigational button
  var navButton: ImageEntry? { get }
}

public extension Section {
  
  func toString() -> String {
    var ret = "Section \"\(name)\""
    if let tit = extendedTitle { ret += " (\(tit))" }
    ret += ", type: \(type.toString())\n  \(html.toString())"
    if let button = navButton { ret += "\n  navButton: \(button.toString())" }
    if let arts = articles {
      ret += ":\n"
      for a in arts { ret += "  - \(a.toString())\n" }
    }
    else { ret += ": Section is empty\n" }
    return ret
  }
  
  /// Section files plus all Article files in this section
  var allFiles: [FileEntry] {
    var ret = self.files
    if let arts = articles, arts.count > 0 {
      for art in arts { ret.append(contentsOf: art.files) }
    }
    return ret
  }
  
  /// articleHtml returns an array of filenames with article HTML
  var articleHtml: [String] {
    var ret: [String] = []
    if let arts = articles, arts.count > 0 {
      for art in arts { ret += art.html.fileName }
    }
    return ret
  }
  
  /// Title - either extendedTitle (if available) or name
  var title: String? { return extendedTitle ?? name }
  
} // extension Section

/**
 A Frame represents one frame of an article or other
 box on a PDF page
 */
public protocol Frame: ToString {
  /// Coordinates of frame
  var x1: Float { get }
  var y1: Float { get }
  var x2: Float { get }
  var y2: Float { get }
  /// Link to either local file (eg. Article) or to remote object
  var link: String? { get }
} // Frame

public extension Frame {
  
  func toString() -> String {
    var ret = "(\(x1),\(y1)), (\(x2),\(y2))"
    if let l = link { ret += "-> \(l)" }
    return ret
  }
  
  /// Returns whether a given coordinate is inside this frame
  func isInside(x: Float, y: Float) -> Bool {
    return (x >= x1) && (x <= x2) && (y >= y1) && (y <= y2)
  }
}

/**
 Page type
 */
public enum PageType: String, CodableEnum {  
  case left     = "left"              /// a left page
  case right    = "right"             /// a right page
  case double   = "double(panorama)"  /// a double spread
  case unknown  = "unknown"   /// decoded from unknown string
} // PageType

/**
 A PDF page of an Issue
 */
public protocol Page: ToString {
  /// File storing PDF
  var pdf: FileEntry? { get }
  /// Facsimile of page PDF (eg. Jpeg)
  var facsimile: ImageEntry? { get }
  /// Page title (if any)
  var title: String? { get }
  /// Page number (or some String numbering the page in some way)
  var pagina: String? { get }
  /// Type of page
  var type: PageType { get }
  /// Frames in page
  var frames: [Frame]? { get }
} // Page  

public extension Page {
  
  func toString() -> String {
    var ret = title ?? "unknown"
    if let pg = pagina { ret += " (#\(pg))" }
    ret += " in \(String(describing: pdf))"
    if let fs = frames { ret += " \(fs.count) frames"}
    return ret
  }
  
  /**
   Returns a String to interprete as follows:
     - name of HTML-file (eg. art001.html) is link to local article
     - name of PDF-file (eg. s001.pdf) is link to local PDF file
     - external URL (eg. https://www.taz.de/...) should bve opened
       with system application (Safari, Mail, ...)
     - nil if the tap is outside linked frames
   All local files may or may be not currently available (eg. in download
   queue)
   */
  func tap2link(x: Float, y: Float) -> String? {
    if let frames = frames, frames.count > 0 {
      for frame in frames {
        if frame.isInside(x: x, y: y) { return frame.link }
      }
    }
    return nil
  }
  
  func pdfDocument(inIssueDir:Dir?) -> PDFDocument? {
    guard let issueDir = inIssueDir,
          let pdfName = self.pdf?.fileName else { return nil }
    let path = issueDir.path + "/"
    return PDFDocument(url: File(path + pdfName).url)
  }
}

/**
 The Moment is a list of Images describing an Issue.
 
 Depending on the need an image with fitting resolution should be used to
 display the image.
 */
public protocol Moment: ToString {
  /// The images in different resolutions
  var images: [ImageEntry] { get }
  /// Images with additional data about creator(s)
  var creditedImages: [ImageEntry] { get }
  /// A number of files comprising an animation e.g. a gif file
  var animation: [FileEntry] { get }
  /// The first PDF page as JPG image
  var facsimile: ImageEntry? { get }
}

public extension Moment {
  
  func toString() -> String {
    var ret = "Moment (\(images.count) images, \(creditedImages.count) credits):"
    for img in images { ret += "\n  \(img.toString())" }
    for img in creditedImages { ret += "\n  credit: \(img.toString())"}
    for img in animation { ret += "\n  animation: \(img.toString())"}
    return ret
  }
  
  var facsimile: ImageEntry? { return nil }
  
  /// Moment images in all resolutions and with credits
  var allImages: [ImageEntry] { images + creditedImages }
  var files: [FileEntry] { images + creditedImages + animation }
  
  /// Highres Moment files
  var highresFiles: [ImageEntry] {
    let h = self.highres!
    let c = self.creditedHighres
    var ret = [h]
    if let img = c, img.name != h.name { ret += img }
    return ret
  }
  
  /// Highres + animation files
  var carouselFiles: [FileEntry] { highresFiles + animation }
 
  /// Return the image with the highest resolution
  func highest(images: [ImageEntry]) -> ImageEntry? {
    var ret: ImageEntry?
    for img in images {
      if let highest = ret, img.resolution.rawValue <= highest.resolution.rawValue
      { continue }
      else { ret = img }
    }
    return ret
  }
  
  /// Return the image with the highest resolution
  func lowest(images: [ImageEntry]) -> ImageEntry? {
    var ret: ImageEntry?
    for img in images {
      if let lowest = ret, img.resolution.rawValue >= lowest.resolution.rawValue
      { continue }
      else { ret = img }
    }
    return ret
  }

  /// Image in highest resolution
  var highres: ImageEntry? { highest(images: images) }

  /// Image in lowest resolution
  var lowres: ImageEntry? { highest(images: images) }
  
  /// Credited image in highest resolution
  var creditedHighres: ImageEntry? { highest(images: creditedImages) }
  
  /// Animated Gif if available
  var animatedGif: FileEntry? {
    for f in animation {
      if File.basename(f.name) == "moment.gif" { return f }
    }
    return nil
  }

} // Moment

/**
 Access status of an Issue
 */
public enum IssueStatus: String, CodableEnum {  
  case regular = "regular"          /// authenticated Issue access 
  case demo    = "demo"             /// demo Issue
  case locked  = "locked"           /// no access
  case reduced = "reduced(public)"  /// available for everybody/incomplete articles
  case unknown = "unknown"          /// decoded from unknown string
} // IssueStatus

public extension IssueStatus {
  var watchable : Bool { return self != .unknown}
}

/// PublicationDate
public protocol PublicationDates: ToString, AnyObject {
  /// Publication dates array
  var dates: [Date] { get }
  /// Publication cycle
  var cycle: PublicationCycle { get }
}

public extension PublicationDates {
  func toString() -> String {
    var range: [String] = []
    if let min = self.dates.min(){ range.append(min.short) }
    if let max = self.dates.max(){ range.append(max.short) }
    return "Cycle: \(self.cycle), Range: \(range.joined(separator: " - "))"
  }
}

/// One Issue of a Feed
public protocol Issue: ToString, AnyObject {  
  /// Is this Issue currently being downloaded
  var isDownloading: Bool { get set }
  /// Has this Issue been downloaded
  var isComplete: Bool { get set }
  /// Reference to Feed providing this Issue
  var feed: Feed { get set }
  /// Issue date
  var date: Date { get }
  /// date until issue is valid if more then one
  var validityDate: Date? { get }
  /// The date/time of the latest modification
  var moTime: Date { get }
  /// Is this Issue a week end edition
  var isWeekend: Bool { get }
  /// Issue defining images
  var moment: Moment { get }
  /// persistent Issue key
  var key: String? { get }
  /// Base URL of all files of this Issue
  var baseUrl: String { get }
  /// Issue status
  var status: IssueStatus { get }
  /// Minimal resource version for this issue
  var minResourceVersion: Int { get }
  /// Name of zip file with all data minus PDF
  var zipName: String? { get }
  /// Name of zip file with all data plus PDF
  var zipNamePdf: String? { get }
  /// Issue imprint
  var imprint: Article? { get }
  /// List of sections in this Issue
  var sections: [Section]? { get }
  /// List of PDF pages (if any)
  var pages: [Page]? { get }
  /// Last Section read (if any)
  var lastSection: Int? { get set }
  /// Last Article read (if nil, then only use lastSection)
  var lastArticle: Int? { get set }
  /// Last Article read (if nil, then only use lastSection)
  var lastPage: Int? { get set }
  /// Payload of files
  var payload: Payload { get }
  /// Directory where all issue specific data is stored
  var dir: Dir { get }
}

public extension Issue {
  
  func validityDateText(timeZone:String,
                        short:Bool = false,
                        shorter:Bool = false,
                        leadingText: String? = "woche, ") -> String {
    guard let endDate = validityDate, isWeekend else {
      return shorter ? date.shorter
      : short ? date.short
      : date.gLowerDate(tz: timeZone)
    }
    
    let mSwitch = endDate.components().month != date.components().month
    
    let dfFrom = DateFormatter()
    dfFrom.dateFormat = mSwitch ? "d.M." : "d."
    
    let dfTo = DateFormatter()
    dfTo.dateFormat = shorter ? "d.M.yy" : "d.M.yyyy"
    
    let from = dfFrom.string(from: date)
    let to = dfTo.string(from: endDate)
    
    return "\(leadingText ?? "")\(from) – \(to)"
  }
  
  func toString() -> String {
    var ret = "Issue \(date.isoDate()), key: \(key ?? "[undefined]"), " +
              "status: \(status.toString())"
    if let sec = sections {
      for s in sec { ret += "\n  \(s.toString())" }
    }
    if let pgs = pages {
      for pg in pgs { ret += "\n  \(pg.toString())" }
    }
    return ret
  }
  
  /// directory where all issue specific data is stored
  var dir: Dir { Dir(dir: feed.dir.path, fname: feed.feeder.date2a(date)) }
  
  /// All Articles in one Issue (one Article may appear multiple
  /// times in the resulting array if it is referenced in more than
  /// one section).
  var allArticles: [Article] {
    var ret: [Article] = []
    if let sects = sections, sects.count > 0 {
      for sect in sects { 
        if let arts = sect.articles { ret.append(contentsOf: arts) } 
      }
    }
    if let imp = imprint { ret += imp }
    return ret
  }
  
  /// Returns the Article to given file name (if any)
  func article(artname: String) -> Article? {
    if let sects = sections, sects.count > 0 {
      for sect in sects { 
        if let arts = sect.articles { 
          for art in arts {
            if art.html.name == artname || art.html.name == "\(artname).html" 
              { return art }
          }
        } 
      }
    }
    return nil
  }
   
  /// The first facsimile page (if available)
  var pageOneFacsimile: FileEntry? {
    if let pgs = pages, pgs.count > 0 {
      return pgs[0].pdf
    }
    return nil
  }
    
  /// The first facsimile page ad PDFPage (if available)
  var pageOneFacsimilePdfPage: PDFPage? {
    if let page0 = pages?.valueAt(0),
       let pdfName = page0.pdf?.fileName,
       let doc = PDFDocument(url: File(baseUrl + pdfName).url),
       let pdfPage = doc.page(at: 0) {
      return pdfPage
    }
    return nil
  }
  
  #warning("expensive call todo: may remember status")
  //Pro fast //Con: what if other process killed a File?
  //May remember temporary? / In Memory ...until: isOvwComplete, isComplete, status changed ...in St
  func isCompleetePDF(in localDir:Dir) -> Bool {
    guard let pgs = pages else { return false }
    if pgs.count == 0 { return false }
//    print("call isCompleetePDF for \(self.date.short) pagecount: \(pgs.count)")
    //=> Up/downscrolling re-calls function, if PDF view!
    for p in pgs {
      if let pdf = p.pdf,
         pdf.exists(inDir: localDir.path) == false {
        return false
      }
    }
    return true
  }
  
  /// All facsimiles
  var facsimiles: [FileEntry]? {
    if let pgs = pages, pgs.count > 0 {
      var ret: [FileEntry] = []
      for pg in pgs { if let pdf = pg.pdf { ret += pdf} }
      return ret
    }
    return nil
  }
  
  /// Content files
  var contentFiles: [FileEntry] {
    var ret: [FileEntry] = []
    if let sects = sections, sects.count > 0 {
      for sect in sects { ret.append(contentsOf: sect.allFiles) }
    }
    if let imp = imprint { ret.append(contentsOf: imp.files) }
    return ret
  }
  
  /// Overview files
  var overviewFiles: [FileEntry] {
    var ret = moment.files
    if let fac1 = pageOneFacsimile { ret += fac1 }
    return ret
  }
  
  /// All files with article photos in normal resolution and pg1 facsimile
  var files: [FileEntry] {
    var ret = contentFiles
    ret.append(contentsOf: overviewFiles)
    return ret
  }
    
  /// Returns files and facsimiles if isPages == true
  func files(isPages: Bool = false) -> [FileEntry] {
    var ret = files
    if isPages {
      if let facs = facsimiles { ret.append(contentsOf: facs) }
    }
    return ret
  }

  /// sectionHtml returns an array of filenames with section content plus imprint
  var sectionHtml: [String] {
    var ret: [String] = []
    if let sects = sections, sects.count > 0 {
      for sect in sects { ret += sect.html.fileName }
    }
    ret += imprint?.html.fileName ?? ""
    return ret
  }
  
  /// articleHtml returns an array of file names with article content
  var articleHtml: [String] {
    var ret: [String] = []
    if let sects = sections, sects.count > 0 {
      for sect in sects { ret.append(contentsOf: sect.articleHtml) }
    }
    return ret
  }
  
  /// article2sectionHtml returns a Dictionary with keys of articleHtml
  /// file names and values of arrays of sectionHtml file names which 
  /// refer to that article named in the key
  var article2sectionHtml: [String:[String]] {
    var ret: [String:[String]] = [:]
    if let sects = sections, sects.count > 0 {
      for sect in sects { 
        let sectHtml = sect.html.fileName
        for art in sect.articles ?? [] {
          let artHtml = art.html.fileName
          if ret[artHtml] != nil { ret[artHtml]! += sectHtml }
          else { ret[artHtml] = [sectHtml] }
        }
      }
    }
    return ret
  }
  
  /// article2section returns a Dictionary with keys of articleHtml
  /// file names and values of arrays of Sections which 
  /// refer to that article named in the key
  var article2section: [String:[Section]] {
    var ret: [String:[Section]] = [:]
    if let sects = sections, sects.count > 0 {
      for sect in sects { 
        for art in sect.articles ?? [] {
          let artHtml = art.html.fileName
          if ret[artHtml] != nil { ret[artHtml]! += sect }
          else { ret[artHtml] = [sect] }
        }
      }
    }
    return ret
  }
  
  /// isReduced returns true if the Issue references "shortened" Articles
  var isReduced: Bool { return status == .reduced }
  
  /// isOverview returns true if the Issue only contains overview data 
  /// (no sections or articles)
  var isOverview: Bool { return (sections == nil) || sections!.count == 0 }

} // extension Issue

/// PublicationCycle of a Feed
public enum PublicationCycle: String, CodableEnum {  
  case daily     = "daily"     /// published daily
  case weekly    = "weekly"    /// published every week
  case monthly   = "monthly"   /// published every month
  case quarterly = "quarterly" /// published every quarter
  case yearly    = "yearly"    /// published once a year
  case unknown   = "unknown"   /// decoded from unknown string
} // PublicationCycle

/// Type of a Feed
public enum FeedType: String, CodableEnum {  
  case publication = "publication" /// regular publication
  case bookmarks   = "bookmarks"   /// a feed of bookmarks
  case info        = "info"        /// info and help texts
  case unknown     = "unknown"     /// decoded from unknown string
} // FeedType

/**
 A Feed is a somewhat abstract form of a publication
 */
public protocol Feed: ToString {
  /// Name of Feed
  var name: String { get }
  /// Feeder offering this Feed
  var feeder: Feeder { get }
  /// Publication cycle
  var cycle: PublicationCycle { get }
  /// Feed type
  var type: FeedType { get }
  /// width/height of "Moment"-Image
  var momentRatio: Float { get }  
  /// Number of issues available
  var issueCnt: Int { get }
  /// Date of last issue available (newest)
  var lastIssue: Date { get }
  /// Date of issue last read
  var lastIssueRead: Date? { get }
  /// Date/Time of last server update regarding this feed
  var lastUpdated: Date? { get }
  /// Date of first issue available (oldest)  
  var firstIssue: Date { get }
  /// Date of first searchable issue (oldest)
  var firstSearchableIssue: Date? { get }
  /// Issues availaible in this Feed
  var issues: [Issue]? { get }
  /// publicationDates this Feed
  var publicationDates: PublicationDates? { get }
  /// Directory where all feed specific data is stored
  var dir: Dir { get }
} // Feed

public extension Feed {  
  var dir: Dir { Dir(dir: feeder.baseDir.path, fname: name) }
  var type: FeedType { .publication }
  var lastIssueRead: Date? { nil }
  var lastUpdated: Date? { nil }
  var firstSearchableIssue: Date? { nil }
  func toString() -> String {
    return "\(name): \(cycle), \(issueCnt) issues total"
  }
  
} // Feed

/** 
 A Feeder is an abstract datatype handling the communication with a server
 providing Feeds.
 */
public protocol Feeder: ToString {  
  /// Timezone Feeder lives in
  var timeZone: String { get }
  /// URL of GraphQL server
  var baseUrl: String { get }
  /// base URL of global files
  var globalBaseUrl: String { get }
  /// base URL of resource files
  var resourceBaseUrl: String { get }
  /// Authentication token got from server
  var authToken: String? { get }
  /// title/name of Feeder
  var title: String { get }
  /// The last time feeds have been requested
  var lastUpdated: Date? { get }
  /// Current resource version
  var resourceVersion: Int { get }
  /// The Feeds this Feeder is providing
  var feeds: [Feed] { get }
  /// Directory where all Feeder specific data is stored
  var dir: Dir { get }
  
  /// Initilialize with name/title and URL of server
  init(title: String, url: String, closure: @escaping(Result<Feeder,Error>)->())
  
  /// Request authentication token from GraphQL server
  func authenticate(account: String, password: String,
                    closure: @escaping(Result<String,Error>)->())
  
  /// Request list of resource files
  func resources(closure: @escaping(Result<Resources,Error>)->())  
} // Feeder

extension Feeder {
  
  public func toString() -> String {
    var ret = "Feeder \"\(title)\" (\(timeZone)), \(feeds.count) feeds:\n"
    ret += "  baseUrl         = \(baseUrl)\n"
    ret += "  globalBaseUrl   = \(globalBaseUrl)\n"
    ret += "  authToken       = \((authToken ?? "[undefined]").prefix(20))...\n"
    ret += "  resourceVersion = \(resourceVersion)\n"
    ret += "  lastUpdated     = \(lastUpdated?.isoTime() ?? "[undefined]")\n"
    if feeds.count > 0 {
      ret += "  Feeds:"
      for f in feeds { ret += "\n\(f.toString().indent(by: 4))" }
    }
    return ret
  }
  
  /// The base directory
  public var baseDir: Dir { return Dir(dir: Dir.appSupportPath, fname: title) }
  public var dir: Dir { baseDir }
  /// The resources directory
  public var resourcesDir: Dir { return Dir(dir: baseDir.path, fname: "resources") }
  /// The global directory
  public var globalDir: Dir { return Dir(dir: baseDir.path, fname: "global") }
  /// The resources version file
  public var resVersionFile: File { return File(dir: resourcesDir.path, 
                                                fname: "ResourceVersion") }
  /// Pathname to Welcome slides (in HTML)
  public var welcomeSlides: String { resourcesDir.path + "/" + Const.Filename.welcomeSlides }
  /// Pathname data policy
  public var dataPolicy: String { resourcesDir.path + "/" + Const.Filename.dataPolicy }
  /// Pathname to declaration of revocation
  public var revocation: String { resourcesDir.path + "/" + Const.Filename.revocation }
  /// Pathname to terms & conditions
  public var terms: String { resourcesDir.path + "/" + Const.Filename.terms }
  /// Pathname to terms & conditions
  public var passwordCheckJs: String { resourcesDir.path + "/" + Const.Filename.passwordCheckJs }
  public var passwordCheckJsUrl: URL? { File(passwordCheckJs).url }
  
  /// resource version as Int
  public var storedResVersion: Int {
    get { return Int(resVersionFile.string.trim) ?? 0 }
    set { File.open(path: resVersionFile.path, mode: "w") 
            { file in file.writeline("\(newValue)") }
    }
  }
  
  /// Returns true if successfully authenticated
  public var isAuthenticated: Bool { return authToken != nil }
  
  /// Returns directory where all feed specific data is stored
  public func feedDir(_ feed: String) -> Dir { return Dir(dir: baseDir.path, fname: feed) }

  /// Returns directory where all issue specific data is stored
  public func issueDir(feed: String, issue: String) -> Dir 
    { return Dir(dir: feedDir(feed).path, fname: issue) }
  
  /// Returns directory where all issue specific data is stored
  public func issueDir(issue: Issue) -> Dir {
    if issue is SearchResultIssue { return Dir.searchResults }
    return issueDir(feed: issue.feed.name, issue: date2a(issue.date))
  }
  
  /// Returns the "Moment" Image file name as Gif-Animation or in highest resolution
  public func momentImageName(issue: Issue, isCredited: Bool = false,
                              isPdf: Bool = false)
    -> String? {
    var file: FileEntry?
    if isPdf { file = issue.moment.facsimile }
    else {
      file = issue.moment.animatedGif
      if isCredited, let highres = issue.moment.creditedHighres {
        file = highres
      }
    }
      #warning("TODODOD")
    if file == nil { file = issue.moment.highres }///Agrrrr
    if let img = file {
      return "\(issueDir(issue: issue).path)/\(img.fileName)"
    }
    return nil
  }
  
  /// Returns the "Moment" Image file name as Gif-Animation or in highest resolution
  public func smallMomentImageName(issue: Issue, isPdf: Bool = false)
    -> String? {
    var file: FileEntry?
    if isPdf { file = issue.moment.facsimile }
    else { file = issue.moment.lowres }
    if let img = file {
      return "\(issueDir(issue: issue).path)/\(img.fileName)"
    }
    return nil
  }

  /// Returns the name of the first PDF page file name (if available)
  public func momentPdfName(issue: Issue) -> String? {
    if let fac1 = issue.pageOneFacsimile {
      return "\(issueDir(issue: issue).path)/\(fac1.fileName)"
    }
    return nil
  }
  
  /// Returns the first PDF page file (if available)
  public func momentPdfFile(issue: Issue) -> File? {
    guard let fn = momentPdfName(issue: issue) else { return nil }
    guard File.extname(fn) == "pdf" else { return nil }
    guard File(fn).exists else { return nil }
    return File(fn)
  }

  /// Returns the "Moment" Image as Gif-Animation or in highest resolution
  public func momentImage(issue: Issue, isCredited: Bool = false,
                          isPdf: Bool = false) -> UIImage? {
    if let fn = momentImageName(issue: issue, isCredited: isCredited,
                                isPdf: isPdf) {
      if File.extname(fn) == "gif" {
        return UIImage.animatedGif(File(fn).data)
      }
      else {
        return UIImage(contentsOfFile: fn)
      }
    }
    return nil
  }

  /// Returns a Date for a String in ISO format relative to the
  /// Feeder's time zone.
  public func a2date(_ iso: String) -> Date {
    UsTime(iso: iso, tz: timeZone).date
  }
  
  /// Returns a String in ISO format relative to the Feeder's
  /// time zone
  public func date2a(_ date: Date) -> String {
    UsTime(date).isoDate(tz: timeZone)
  }
  
} // extension Feeder

/**
 Type of silent push notifications
 */
public enum NotificationType: String, CodableEnum { 
  /// new subscription info available
  case subscription = "subscription(subscriptionPoll)" 
  /// new issue available
  case newIssue     = "newIssue(aboPoll)"    
  case unknown      = "unknown"   /// decoded from unknown string
} // NotificationType
