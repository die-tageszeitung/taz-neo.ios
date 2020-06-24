//
//  DataModel.swift
//
//  Created by Norbert Thies on 12.09.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/**
 Errors a Feeder may encounter
 */
public enum FeederError: LocalizedError {
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
} // FeederError

/**
 A FileStorageType defines where a file is stored.
 */
@objc public enum FileStorageType: Int16, Decodable, ToString {  
  case issue     = 0  /// issue local file
  case global    = 1  /// global to all issues and feeds
  case resource  = 2  /// resource local file
  case unknown   = 3  /// unknown storage type
  
  public func toString() -> String {
    switch self {
    case .issue:    return "issue"
    case .global:   return "global"
    case .resource: return "resource"
    case .unknown:  return "unknown"
    }
  }
  
  public init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "issue":    self = .issue
    case "global":   self = .global
    case "resource": self = .resource
    default:         self = .unknown
    }
  }  
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
    if exists && (f.mTime == moTime) && (f.size == size) {
      log("* Warning: File \(fileName) exists but mtime and/or size are wrong")
    }
    return exists
  }  

}

/// Image resolution
@objc public enum ImageResolution: Int16, Decodable, ToString {  
  case small    = 0  /// small image resolution used eg. for thumpnails
  case normal   = 1  /// regular resolution used in Articles
  case high     = 2  /// high resolution when Image is displayed in zoom mode
  case unknown  = -1 /// unknown image resolution
  
  public func toString() -> String {
    switch self {
    case .small:   return "small"
    case .normal:  return "normal"
    case .high:    return "high"
    case .unknown: return "unknown"
    }
  }
  
  public init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "small"   : self = .small
    case "normal"  : self = .normal
    case "high"    : self = .high
    default:         self = .unknown
    }
  }  
} // ImageResolution

/// Image type
@objc public enum ImageType: Int16, Decodable, ToString {  
  case picture         = 0  /// regular foto/graphic as used in articles
  case advertisement   = 1  /// an advertisement :-(
  case facsimile       = 2  /// eg. of a print page
  case button          = 3  /// a button (eg. the slider button)
  case unknown         = 4  /// unknown image type
  
  public func toString() -> String {
    switch self {
    case .picture      : return "picture"
    case .advertisement: return "advertisement"
    case .facsimile    : return "facsimile"
    case .button       : return "button"
    case .unknown      : return "unknown"
    }
  }
  
  public init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "picture"       : self = .picture
    case "advertisement" : self = .advertisement
    case "facsimile"     : self = .facsimile
    case "button"        : self = .button
    default:               self = .unknown
    }
  }  
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
 A list of resource files
 */
public protocol Resources: ToString, AnyObject {
  /// Are these Resources currently being downloaded
  var isDownloading: Bool { get set }
  /// Have these Ressources been downloaded
  var isComplete: Bool { get set }
  /// Resource list version
  var resourceVersion: Int { get }
  /// Base URL of resource files
  var resourceBaseUrl: String { get }
  /// name of resource zip file (under resourceBaseUrl)
  var resourceZipName: String { get }
  /// List of files
  var resourceFiles: [FileEntry] { get }
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
}

public extension Content {
  
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

} // Content

/**
 An Article
 */
public protocol Article: Content, ToString {
  /// File storing audio data
  var audio: FileEntry? { get }
  /// Title of article
  var teaser: String? { get }
  /// Link to online version
  var onlineLink: String? { get }
  /// List of PDF page (-file) names containing this article
  var pageNames: [String]? { get }
} // Article

public extension Article {
  
  func toString() -> String {
    var ret = "\(title ?? "[Unknown title]") ("
    if let au = authors, au.count > 0 {
      ret += au[0].toString()
    }
    else { ret += "author unknown" }
    ret += ")"
    return ret
  }
  
}

/**
 Section type
 */
@objc public enum SectionType: Int16, Decodable, ToString {  
  case articles   = 0      /// a list of articles
  case text       = 1      /// a single HTML text (eg. imprint)
  case unknown    = 100    /// unknown section type  
  public func toString() -> String {
    switch self {
    case .articles     : return "articles"
    case .text         : return "text"
    case .unknown      : return "unknown"
    }
  }  
  public init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "articles"      : self = .articles
    case "text"          : self = .text    
    default:               self = .unknown
    }
  }  
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
    ret += ", type: \(type.toString())"
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
}

/**
 Page type
 */
@objc public enum PageType: Int16, Decodable, ToString {  
  case left     = 0  /// a left page
  case right    = 1  /// a right page
  case double   = 2  /// a double spread
  case unknown  = 3  /// unknown page type  
  public func toString() -> String {
    switch self {
    case .left     : return "left"
    case .right    : return "left"
    case .double   : return "left"
    case .unknown  : return "unknown"
    }
  }  
  public init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "left"     : self = .left
    case "right"    : self = .right
    case "panorama" : self = .double
    default:          self = .unknown
    }
  }  
} // PageType

/**
 A PDF page of an Issue
 */
public protocol Page: ToString {
  /// File storing PDF
  var pdf: FileEntry { get }
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
    ret += " in \(pdf)"
    if let fs = frames { ret += " \(fs.count) frames"}
    return ret
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
}

public extension Moment {
  
  func toString() -> String {
    var ret = "Moment (\(images.count) images, \(creditedImages.count) credits):"
    for img in images { ret += "\n  \(img.toString())" }
    for img in creditedImages { ret += "\n  credit: \(img.toString())"}
    for img in animation { ret += "\n  animation: \(img.toString())"}
    return ret
  }
  
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

  /// Image in highest resolution
  var highres: ImageEntry? { highest(images: images) }
  
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
@objc public enum IssueStatus: Int16, Decodable, ToString {  
  case regular = 0  /// authenticated Issue acces
  case demo    = 1  /// demo Issue
  case locked  = 2  /// no access
  case open    = 3  /// available for everybody
  case unknown = 4  /// undefined status
  
  public func toString() -> String {
    switch self {
    case .regular: return "regular"
    case .demo:    return "demo"
    case .locked:  return "locked"
    case .open:    return "public"
    case .unknown: return "unknown"
    }
  }
  
  public init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "regular" : self = .regular
    case "demo"    : self = .demo
    case "locked"  : self = .locked
    case "public"  : self = .open
    default        : self = .unknown
    }
  }  
} // IssueStatus

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
  /// List of files in this Issue without PDF
  var fileList: [String]? { get }
  /// List of files in this Issue with PDF
  var fileListPdf: [String]? { get }
  /// Issue imprint
  var imprint: Article? { get }
  /// List of sections in this Issue
  var sections: [Section]? { get }
  /// List of PDF pages (if any)
  var pages: [Page]? { get }
}

public extension Issue {
  
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
  
  /// All Articles in one Issue (one Article may be appear multiple
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
  
  /// All files with article photos in normal resolution
  var files: [FileEntry] {
    var ret: [FileEntry] = moment.files
    if let sects = sections, sects.count > 0 {
      for sect in sects { ret.append(contentsOf: sect.allFiles) }
    }
    if let imp = imprint { ret.append(contentsOf: imp.files) }
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

} // extension Issue

/// PublicationCycle of a Feed
@objc public enum PublicationCycle: Int16, Decodable, ToString {  
  case daily     = 0  /// published daily
  case weekly    = 1  /// published every week
  case monthly   = 2  /// published every month
  case quarterly = 3  /// published every quarter
  case yearly    = 4  /// published once a year
  case unknown   = 5  /// unknown publication cycle
  
  public func toString() -> String {
    switch self {
    case .daily:     return "daily"
    case .weekly:    return "weekly"
    case .monthly:   return "monthly"
    case .quarterly: return "quarterly"
    case .yearly:    return "yearly"
    case .unknown:   return "unknown"
    }
  }
  
  public init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "daily"     : self = .daily
    case "weekly"    : self = .weekly
    case "monthly"   : self = .monthly
    case "quarterly" : self = .quarterly
    case "yearly"    : self = .yearly
    default          : self = .unknown
    }
  }
} // PublicationCycle

/// Type of a Feed
@objc public enum FeedType: Int16, Decodable, ToString {  
  case publication = 0  /// regular publication
  case bookmarks   = 1  /// a feed of bookmarks
  case info        = 2  /// info and help texts
  case unknown     = -1
  public func toString() -> String {
    switch self {
    case .publication:  return "daily"
    case .bookmarks:    return "bookmarks"
    case .info:         return "info"
    case .unknown:      return "unknown"
    }
  }
  
  public init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "publication" : self = .publication
    case "bookmarks"   : self = .bookmarks
    case "info"        : self = .info
    default            : self = .unknown
    }
  }
} // FeedType

/**
 A Feed is a somewhat abstract form of a publication
 */
public protocol Feed: ToString {
  /// Name of Feed
  var name: String { get }
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
  /// Issues availaible in this Feed
  var issues: [Issue]? { get }
} // Feed

public extension Feed {  
  var type: FeedType { .unknown }
  var lastIssueRead: Date? { nil }
  var lastUpdated: Date? { nil }
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
  /// The resources directory
  public var resourcesDir: Dir { return Dir(dir: baseDir.path, fname: "resources") }
  /// The global directory
  public var globalDir: Dir { return Dir(dir: baseDir.path, fname: "global") }
  /// The resources version file
  public var resVersionFile: File { return File(dir: resourcesDir.path, 
                                                fname: "ResourceVersion") }
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
    return issueDir(feed: issue.feed.name, issue: date2a(issue.date))
  }
  
  /// Returns the "Moment" Image file name as Gif-Animation or in highest resolution
  public func momentImageName(issue: Issue, isCredited: Bool = false) 
    -> String? {
    var file = issue.moment.animatedGif
    if isCredited, let highres = issue.moment.creditedHighres {       
      file = highres 
    }
    if file == nil { file = issue.moment.highres }
    if let img = file {
      return "\(issueDir(issue: issue).path)/\(img.fileName)"
    }
    return nil
  }

  /// Returns the "Moment" Image as Gif-Animation or in highest resolution
  public func momentImage(issue: Issue, isCredited: Bool = false) 
    -> UIImage? {
    if let fn = momentImageName(issue: issue, isCredited: isCredited) {
      if File.extname(fn) == "gif" {
        return UIImage.animatedGif(File(fn).data)
      }
      else { return UIImage(contentsOfFile: fn) }
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
@objc public enum NotificationType: Int16, Decodable, ToString {  
  case subscription   = 0    /// new subscription info available
  case newIssue       = 1    /// new issue available
  case unknown        = 1000 /// unknown subscription type
  
  public func toString() -> String {
    switch self {
    case .subscription:    return "subscription"
    case .newIssue:        return "newIssue"
    case .unknown:         return "unknown"
    }
  }
  
  public var encoded: String {
    switch self {
    case .subscription:    return "subscriptionPoll"
    case .newIssue:        return "aboPoll"
    case .unknown:         return "unknown"
    }
  }
  
  public init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "subscriptionPoll": self = .subscription
    case "aboPoll":          self = .newIssue
    default:                 self = .unknown
    }
  }  
  
} // FileStorageType
