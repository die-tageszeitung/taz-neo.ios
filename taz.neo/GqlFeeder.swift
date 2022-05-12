//
//  GqlFeeder.swift
//
//  Created by Norbert Thies on 12.09.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A protocol defining methods to use by GraphQL objects
protocol GQLObject: Decodable, ToString {
  /// A String listing the GraphQL field names of an GraphQL object
  static var fields: String { get }
}

/// Authentication status
enum GqlAuthStatus: String, CodableEnum {  
  /// valid authentication token provided
  case valid = "valid"      
  /// invalid (or no) token
  case invalid = "invalid(notValid)" 
  /// account provided by token is expired (ISO-Date in message)
  case expired = "expired(elapsed)"      
  /// ID not linked to subscription
  case unlinked = "unlinked(tazIdNotLinked)"  
  // AboId exists but PW is wrong 
  case notValidMail = "notValidMail" 
  /// AboId already linked to tazId
  case alreadyLinked = "alreadyLinked" 
  case unknown   = "unknown"   /// decoded from unknown string
} // GqlAuthStatus

/// A GqlAuthInfo describes an GqlAuthStatus with an optional message
struct GqlAuthInfo: GQLObject {  
  /// Authentication status
  var status:  GqlAuthStatus
  /// Optional message in case of !valid
  var message: String?
  
  static var fields = "status message"
  
  func toString() -> String {
    var ret = status.toString()
    if let msg = message { ret += ": (\(msg))" }
    return ret
  }  
} // GqlAuthInfo

/// A GqlAuthToken is returned upon an Authentication request
struct GqlAuthToken: GQLObject {  
  /// Authentication token (to use for further authentication)  
  var token: String?
  /// Authentication info
  var authInfo: GqlAuthInfo
  
  static var fields = "token authInfo{\(GqlAuthInfo.fields)}"
  
  func toString() -> String {
    var ret: String
    if let str = token { 
      ret = authInfo.toString() + ": \(str.prefix(20))..." 
    }
    else { ret = authInfo.toString() }
    return ret
  }  
} // GqlAuthToken


/// GqlFile as defined by server
class GqlFile: FileEntry, GQLObject {
  /// name of file relative to base URL
  var name: String
  /// Storage type of file
  var storageType: FileStorageType
  /// Modification time as String of seconds since 1970-01-01 00:00:00 UTC
  var sMoTime: String
  /// SHA256 of files' contents
  var sha256: String
  /// File size in bytes
  var sSize: String
  
  /// Modification time as Date
  var moTime: Date { return UsTime(sMoTime).date }
  
  /// Size as Int64
  var size: Int64 { return Int64(sSize)! }
  
  static var fields =  "name storageType sMoTime:moTime sha256 sSize:size"
} // GqlFile

/// A file storing an Image
class GqlImage: ImageEntry, GQLObject {
  /// Resolution of Image
  var resolution: ImageResolution  
  /// Type of Image
  var type: ImageType
  /// Tranparency
  var alpha: Float?
  /// Name of file relative to base URL
  var name: String
  /// Storage type of file
  var storageType: FileStorageType
  /// Modification time as String of seconds since 1970-01-01 00:00:00 UTC
  var sMoTime: String
  /// SHA256 of files' contents
  var sha256: String
  /// File size in bytes
  var sSize: String
  /// Optional sharable
  var oSharable: Bool?
  /// Is the image sharable
  var sharable: Bool { oSharable ?? false }
  
  /// Modification time as Date
  var moTime: Date { return UsTime(sMoTime).date }
  
  /// Size as Int64
  var size: Int64 { return Int64(sSize)! }
  
  //static var fields = "resolution type alpha \(GqlFile.fields)"
  static var fields = "resolution type alpha oSharable:sharable \(GqlFile.fields)"  
} // GqlImage

/// The Payload of files from the download server
class GqlPayload: Payload {
  var localDir: String
  var remoteBaseUrl: String
  var remoteZipName: String?
  var files: [FileEntry]
  var issue: Issue? 
  var resources: Resources?
  
  /// Initialize Payload from Resources
  init(feeder: GqlFeeder, resources: GqlResources) {
    localDir = feeder.resourcesDir.path
    remoteBaseUrl = resources.resourceBaseUrl
    remoteZipName = resources.resourceZipName
    files = resources.files
    self.resources = resources
  }
  
  /// Initialize Payload from Issue
  init(feeder: GqlFeeder, issue: GqlIssue, isPages: Bool = false) {
    localDir = feeder.issueDir(issue: issue).path
    remoteBaseUrl = issue.baseUrl
    remoteZipName = issue.zipName
    files = issue.files(isPages: isPages)
    self.issue = issue
  }
  
} // GqlPayload

/// A list of resource files
class GqlResources: Resources, GQLObject {  
  /// Current resource version
  var resourceVersion: Int
  /// Base URL of resource files
  var resourceBaseUrl: String
  /// name of resource zip file (under resourceBaseUrl)
  var resourceZipName: String  
  /// List of files
  var files: [GqlFile]
  var resourceFiles: [FileEntry] { return files }
  var _isDownloading: Bool? = nil
  var isDownloading: Bool {
    get { if _isDownloading != nil { return _isDownloading! } else { return false } }
    set { _isDownloading = newValue }
  }
  var _isComplete: Bool? = nil
  var isComplete: Bool {
    get { if _isComplete != nil { return _isComplete! } else { return false } }
    set { _isComplete = newValue }
  }
  var gqlPayload: GqlPayload?
  var payload: Payload { return gqlPayload! }
  
  static var fields = """
  resourceVersion 
  resourceBaseUrl 
  resourceZipName: resourceZip
  files: resourceList { \(GqlFile.fields) }
  """   
    
  enum CodingKeys: String, CodingKey {
    case resourceVersion
    case resourceBaseUrl
    case resourceZipName
    case files
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    resourceVersion = try container.decode(Int.self, forKey: .resourceVersion)
    resourceBaseUrl = try container.decode(String.self, forKey: .resourceBaseUrl)
    resourceZipName = try container.decode(String.self, forKey: .resourceZipName)
    files = try container.decode([GqlFile].self, forKey: .files)
  }
  
  func setPayload(feeder: GqlFeeder) {
    self.gqlPayload = GqlPayload(feeder: feeder, resources: self)
  }
  
} //  GqlResources

/// The author of an article
class GqlAuthor: Author, GQLObject {
  /// Name of author
  var name: String?
  /// Photo (if any)
  var image: GqlImage?
  var photo: ImageEntry? { return image }
  
  static var fields = "name image: imageAuthor { \(GqlImage.fields) }"
}

/// One Article of an Issue
class GqlArticle: Article, GQLObject {
  var realPrimaryIssue: GqlIssue?
  /// Issue where this Article is stored
  var primaryIssue: Issue { 
    get { realPrimaryIssue! } 
    set { realPrimaryIssue = (newValue as! GqlIssue) }
  }
  /// File storing article HTML
  var articleHtml: GqlFile
  var html: FileEntry { return articleHtml }
  /// File storing article MP3 (if any)
  var audioFile: GqlFile?
  var audio: FileEntry? { return audioFile }
  /// Article title
  var title: String?
  /// Article teaser
  var teaser: String?
  /// Link to online version of this article
  var onlineLink: String?
  /// List of PDF page (-file) names containing this article
  var pageNames: [String]?
  /// List of Images (photos)
  var imageList: [GqlImage]?
  var images: [ImageEntry]? { return imageList }
  /// List of authors
  var authorList: [GqlAuthor]?
  var authors: [Author]? { return authorList }

  static var fields = """
  articleHtml { \(GqlFile.fields) }
  audioFile { \(GqlFile.fields) }
  title
  teaser
  onlineLink
  pageNames: pageNameList
  imageList { \(GqlImage.fields) }
  authorList { \(GqlAuthor.fields) }
  """  
}

/// A Section of an Issue
class GqlSection: Section, GQLObject {
  var realPrimaryIssue: GqlIssue?
  /// Issue where this Section is stored
  var primaryIssue: Issue { 
    get { realPrimaryIssue! } 
    set { realPrimaryIssue = (newValue as! GqlIssue) }
  }
  /// File storing section HTML
  var sectionHtml: GqlFile
  var html: FileEntry { return sectionHtml }
  /// Name of section
  var name: String
  /// Optional title (not to display in table of contents)
  var extendedTitle: String?
  /// Type of section
  var type: SectionType
  /// List of articles
  var articleList: [GqlArticle]?
  var articles: [Article]? { return articleList }
  /// List of Images
  var imageList: [GqlImage]?
  var images: [ImageEntry]? { return imageList }
  /// Optional list of Authors in this section (currently empty)
  var authors: [Author]? { return nil }
  /// Navigation button
  var sectionNavButton: GqlImage?
  var navButton: ImageEntry? { return sectionNavButton }
  
  static var fields = """
  sectionHtml { \(GqlFile.fields) }
  name: title
  extendedTitle
  type
  sectionNavButton: navButton { \(GqlImage.fields) }
  articleList { \(GqlArticle.fields) }
  imageList { \(GqlImage.fields) }
  """
} // GqlSection

/// A Frame represents one frame of an article or other
/// box on a PDF page
class GqlFrame: Frame, GQLObject {
  /// Coordinates of frame
  var x1: Float
  var y1: Float
  var x2: Float
  var y2: Float
  /// Link to either local file (eg. Article) or to remote object
  var link: String?
  
  static var fields = "x1 y1 x2 y2 link"
} // Frame

/// A PDF page of an Issue
class GqlPage: Page, GQLObject {
  /// File storing PDF
  var pagePdf: GqlFile
  var pdf: FileEntry? { return pagePdf }
  /// Facsimile if first page
  var gqlFacsimile: GqlImage?
  var facsimile: ImageEntry? { return gqlFacsimile }
  /// Page title (if any)
  var title: String?
  /// Page number (or some String numbering the page in some way)
  var pagina: String?
  /// Type of page
  var type: PageType
  /// Frames in page
  var frameList: [GqlFrame]?
  var frames: [Frame]? { return frameList }
  
  static var fields = """
  pagePdf { \(GqlFile.fields) }
  gqlFacsimile: facsimile { \(GqlImage.fields) }
  title
  pagina
  type
  frameList { \(GqlFrame.fields) }
  """
} // GqlPage

/// The Moment is a list of Images identifying an Issue
class GqlMoment: Moment, GQLObject {
  /// The images in different resolutions
  public var imageList: [GqlImage]
  public var creditList: [GqlImage]?  
  public var momentList: [GqlFile]?
  public var images: [ImageEntry] { return imageList }
  public var creditedImages: [ImageEntry] { return creditList ?? [] }
  public var animation: [FileEntry] { return momentList ?? [] }

  static var fields = """
    imageList { \(GqlImage.fields) }
    creditList { \(GqlImage.fields) }
    momentList { \(GqlFile.fields) }
  """
} // GqlMoment

/// One Issue of a Feed
class GqlIssue: Issue, GQLObject {
  var realFeed: Feed?
  /// The Feed containing this Issue
  var feed: Feed { get { realFeed! } set { realFeed = newValue } }
  /// Issue date
  var sDate: String 
  var date: Date { return UsTime(iso: sDate, tz: GqlFeeder.tz).date }
  /// Modification time as String of seconds since 1970-01-01 00:00:00 UTC
  var sMoTime: String?
  /// Modification time as Date
  var moTime: Date { 
    guard let mtime = sMoTime else { return date }
    return UsTime(mtime).date 
  }
  /// Is this Issue a week end edition?
  var isWeekend: Bool { return sIsWeekend ?? false }
  var sIsWeekend: Bool?
  /// Issue defining images
  var gqlMoment: GqlMoment
  var moment: Moment { return gqlMoment }
  /// persistent Issue key
  var key: String?
  /// Base URL of all files of this Issue
  var baseUrl: String
  /// Issue status
  var status: IssueStatus
  /// Minimal resource version for this issue
  var minResourceVersion: Int
  /// Name of zip file with all data minus PDF
  var zipName: String?
  /// Name of zip file with all data plus PDF
  var zipNamePdf: String?
  /// Issue imprint
  var gqlImprint: GqlArticle?
  var imprint: Article? { return gqlImprint }
  /// List of sections in this Issue
  var sectionList: [GqlSection]?
  var sections: [Section]? { return sectionList }
  /// List of PDF pages (if any)
  var pageList : [GqlPage]?
  var pages: [Page]? { return pageList }
  var _isDownloading: Bool? = nil
  var isDownloading: Bool {
    get { if _isDownloading != nil { return _isDownloading! } else { return false } }
    set { _isDownloading = newValue }
  }
  var _isComplete: Bool? = nil
  var isComplete: Bool {
    get { if _isComplete != nil { return _isComplete! } else { return false } }
    set { _isComplete = newValue }
  }
  /// Not used in GqlIssue
  var lastSection: Int? { get { return nil } set {} }
  /// Not used in GqlIssue
  var lastArticle: Int? { get { return nil } set {} }
  /// Not used in GqlIssue
  var lastPage: Int?  { get { return nil } set {} }
  var gqlPayload: GqlPayload? = nil
  var payload: Payload { return gqlPayload! }
  
  enum CodingKeys: String, CodingKey {
    case sDate
    case sMoTime
    case sIsWeekend
    case gqlMoment
    case key
    case baseUrl
    case status
    case minResourceVersion
    case zipName
    case zipNamePdf
    case gqlImprint
    case sectionList
    case pageList
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    sDate = try container.decode(String.self, forKey: .sDate)
    sMoTime = try container.decodeIfPresent(String.self, forKey: .sMoTime)
    sIsWeekend = try container.decodeIfPresent(Bool.self, forKey: .sIsWeekend)
    gqlMoment = try container.decode(GqlMoment.self, forKey: .gqlMoment)
    key = try container.decodeIfPresent(String.self, forKey: .key)
    baseUrl = try container.decode(String.self, forKey: .baseUrl)
    status = try container.decode(IssueStatus.self, forKey: .status)
    minResourceVersion = try container.decode(Int.self, forKey: .minResourceVersion)
    zipName = try container.decodeIfPresent(String.self, forKey: .zipName)
    zipNamePdf = try container.decodeIfPresent(String.self, forKey: .zipNamePdf)
    gqlImprint = try container.decodeIfPresent(GqlArticle.self, forKey: .gqlImprint)
    sectionList = try container.decodeIfPresent([GqlSection].self, 
                                                forKey: .sectionList)
    pageList = try container.decodeIfPresent([GqlPage].self, forKey: .pageList)
  }
  
  func setPayload(feeder: GqlFeeder, isPages: Bool = false) {
    self.gqlPayload = GqlPayload(feeder: feeder, issue: self, isPages: isPages)
  }

  static var ovwFields = """
  sDate: date 
  sMoTime: moTime
  sIsWeekend: isWeekend
  gqlMoment: moment { \(GqlMoment.fields) } 
  baseUrl 
  status
  minResourceVersion
  pageList { \(GqlPage.fields) }
  """
  
  static var fields = """
  \(ovwFields)
  key 
  zipName
  zipNamePdf: zipPdfName
  gqlImprint: imprint { \(GqlArticle.fields) }
  sectionList { \(GqlSection.fields) }
  """
} // GqlIssue

/// A Feed of publication issues and articles
class GqlFeed: Feed, GQLObject {  
  var gqlFeeder: GqlFeeder!
  /// The Feeder offering this Feed
  var feeder: Feeder { gqlFeeder }
  /// Name of Feed
  var name: String
  /// Publication cycle
  var cycle: PublicationCycle
  /// width/height of "Moment"-Image
  var momentRatio: Float
  /// Number of issues available
  var issueCnt: Int
  /// Date of last issue available (newest)
  var sLastIssue: String
  var lastIssue: Date { return UsTime(iso: sLastIssue, tz: GqlFeeder.tz).date }
  /// Date of first issue available (oldest)
  var sFirstIssue: String  
  var firstIssue: Date { return UsTime(iso: sFirstIssue, tz: GqlFeeder.tz).date }
  /// The Issues requested of this Feed
  var gqlIssues: [GqlIssue]?
  var issues: [Issue]? { return gqlIssues }
  
  enum CodingKeys: String, CodingKey {
    case name, cycle, momentRatio, issueCnt, sLastIssue, sFirstIssue,
         gqlIssues
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    cycle = try container.decode(PublicationCycle.self, forKey: .cycle)
    momentRatio = try container.decode(Float.self, forKey: .momentRatio)
    issueCnt = try container.decode(Int.self, forKey: .issueCnt)
    sLastIssue = try container.decode(String.self, forKey: .sLastIssue)
    sFirstIssue = try container.decode(String.self, forKey: .sFirstIssue)
    gqlIssues = try container.decodeIfPresent([GqlIssue].self, forKey: .gqlIssues)
  }
  
  static var fields = """
      name cycle momentRatio issueCnt
      sLastIssue: issueMaxDate
      sFirstIssue: issueMinDate
    """
} // class GqlFeed

/// GqlFeederStatus stores some Feeder specific data
class GqlFeederStatus: GQLObject {  
  /// Authentication Info
  var authInfo: GqlAuthInfo
  /// Current resource version
  var resourceVersion: Int
  /// Base URL of resource files
  var resourceBaseUrl: String
  /// Base URL of global files
  var globalBaseUrl: String
  /// Feeds this Feeder provides
  var feeds: [GqlFeed]
  
  static var fields = """
  authInfo{\(GqlAuthInfo.fields)}
  resourceVersion
  resourceBaseUrl
  globalBaseUrl
  feeds: feedList { \(GqlFeed.fields) }
  """
  
  func toString() -> String {
    var ret = """
      authentication:  \(authInfo.toString())
      resourceVersion: \(resourceVersion)
      resourceBaseUrl: \(resourceBaseUrl)
      globalBaseUrl:   \(globalBaseUrl)
      Feeds:
    """
    for f in feeds {
      ret += "\n\(f.toString().indent(by: 4))"
    }
    return ret
  }  
} // GqlFeederStatus

/**
 The GqlFeeder implements the Feeder protocol to manage the communication
 with a Feeder providing data feeds (publications).
 
 This class provides the necessary functionality to handle all data transfer 
 operations with the taz/lmd GraphQL server.
 */
open class GqlFeeder: Feeder, DoesLog {

  /// Time zone Feeder lives in ;-(
  public static var tz = "Europe/Berlin"
  public var timeZone: String { return GqlFeeder.tz }

  /// URL of GraphQL server
  public var baseUrl: String
  /// Authentication token got from server
  public var authToken: String? { didSet { gqlSession?.authToken = authToken } }
  /// title/name of Feeder
  public var title: String
  /// The last time feeds have been requested
  public var lastUpdated: Date?
  /// Current resource version
  public var resourceVersion: Int {
    guard let st = status else { return -1 }
    return st.resourceVersion
  }
  /// base URL of global files
  public var globalBaseUrl: String {
    guard let st = status else { return "" }
    return st.globalBaseUrl
  }
  /// base URL of resource files
  public var resourceBaseUrl: String {
    guard let st = status else { return "" }
    return st.resourceBaseUrl
  }
  /// The Feeds this Feeder is providing
  public var feeds: [Feed] {
    guard let st = status else { return [] }
    return st.feeds
  }
  /// The GraphQL server delivering the Feeds
  public var gqlSession: GraphQlSession?
  
  let deviceType = "apple"
  lazy var deviceInfoString : String = {
    var deviceFormat = ""
    switch Device.singleton {
      case .iPad :  deviceFormat = "tablet"
      case .iPhone: deviceFormat = "mobile"
      default:deviceFormat = "desktop"
    }
    
    //Taz App (de.taz.taz.2) Version 0.4.9 (#2020090951)
    let appVersion = "\(App.name) (\(App.bundleIdentifier)) Ver.:\(App.bundleVersion) #\(App.buildNumber)"
    return ""
      + "deviceType: \(deviceType), "   //apple Default
      + "deviceName: \"\(UIDevice().model)\", " // e.g.: iPhone iPad iPod touch (Ringos iPhone)
      //e.g. iPhone12,3 (modelName) for iPhone 11 Pro (modelNameReadable)
      + "deviceVersion: \"\(Utsname.machineModel)\", "//e.g. iPhone 11 Pro
      + "deviceFormat: \(deviceFormat), " //e.g.: mobile, tablet
      + "appVersion: \"\(appVersion)\", " //e.g.: Taz App (de.taz.taz.2) Version 0.4.9 (#2020090951)
      + "deviceOS: \"iOS \(UIDevice.current.systemVersion)\""
  }()
  
  
  // The FeederStatus
  var status: GqlFeederStatus?
  
  public func toString() -> String {
    guard let st = status else { return "Error: No Feeder status available" }
    return "Feeder (\(lastUpdated?.isoTime() ?? "unknown time")):\n" + 
      "  title:           \(title)\n" +
      "  baseUrl:         \(baseUrl)\n" +
      "  token:           \((authToken ?? "undefined").prefix(20))...\n" +
      st.toString()
  }
  
  /// Initilialize with name/title and URL of GraphQL server
  required public init(title: String, url: String,
    closure: @escaping(Result<Feeder,Error>)->()) {
    self.baseUrl = url
    self.title = title
    self.gqlSession = GraphQlSession(url)
    self.feederStatus { [weak self] (res) in
      guard let self = self else { return }
      var ret: Result<Feeder,Error>
      switch res {
      case .success(let st):   
        ret = .success(self)
        self.status = st
        self.lastUpdated = Date()
      case .failure(let err):  
        ret = .failure(err)
      }
      self.lastUpdated = UsTime.now.date
      closure(ret)
    }
  }
  
  /**
   Authenticate with server.
   
   If the authentication was successful, the provided authentication token
   is written to self.authToken and passed to 'closure' as Result.success.
   If an error was encountered, the closure is called with Result.failure and
   an Error is passed along. If this Error is of type FeederError, then
   a GqlAuthInfo object is written to self.status.authInfo and may be interpreted
   for further information.
   
   - parameters:
     - account:  tazId or AboId
     - password: account password
     - closure:  is called when the communication with the server has been
                 finished
     - result:   Either auth token or Error
  */
  public func authenticate(account: String, password: String,
    closure: @escaping(_ result: Result<String,Error>)->()) {
    guard let gqlSession = self.gqlSession else {
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      authToken: authentificationToken(\(self.deviceInfoString), 
    user: \(account.quote()), password: \(password.quote())) {
        \(GqlAuthToken.fields)
      }
    """
    gqlSession.query(graphql: request, type: [String:GqlAuthToken].self) { [weak self] (res) in
      var ret: Result<String,Error>
      switch res {
        case .success(let auth):
          let atoken = auth["authToken"]!
          self?.status?.authInfo = atoken.authInfo
          switch atoken.authInfo.status {
            case .expired, .unlinked, .invalid, .alreadyLinked, .notValidMail, .unknown:
              ret = .failure(AuthStatusError(status: atoken.authInfo.status, message: atoken.authInfo.message))
            case .valid:
              self?.authToken = atoken.token!
              ret = .success(atoken.token!)
        }
        case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  
  /// Send server notification/device/user infos after successful authentication
  public func notification(pushToken: String?, oldToken: String?, 
    isTextNotification: Bool, closure: @escaping(Result<Bool,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    
    if pushToken == nil && oldToken == nil {
      closure(.failure(error("one token must not be nil either oldToken or (new) pushToken")))
      return
    }
    
    let pToken = (pushToken == nil) ? "" : "pushToken: \"\(pushToken!)\","
    let oToken = (oldToken == nil) ? "" : "oldToken: \"\(oldToken!)\","
    let request = """
      notification(\(pToken), \(oToken) 
                   textNotification: \(isTextNotification ? "true" : "false"),
                   \(deviceInfoString)
                  )
    """
    gqlSession.mutation(graphql: request, type: [String:Bool].self) { (res) in
      var ret: Result<Bool,Error>
      switch res {
      case .success(let dict):   
        let status = dict["notification"]!
        ret = .success(status)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
    
  /// Request push notification from server (test purpose).
  public func testNotification(pushToken: String?, request: NotificationType, 
                               closure: @escaping(Result<Bool,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    guard let pushToken = pushToken else { 
      closure(.failure(error("Notification not allowed"))); return
    }
    let request = """
      testNotification(
        pushToken: "\(pushToken)",
        sendRequest: \(request.external),
        \(deviceInfoString),
        isSilent: true
      )
    """
    gqlSession.mutation(graphql: request, type: [String:Bool].self) { (res) in
      var ret: Result<Bool,Error>
      switch res {
      case .success(let dict):   
        let status = dict["testNotification"]!
        ret = .success(status)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }

  /// Requests a ResourceList object from the server
  public func resources(fromData: Data? = nil, closure: @escaping(Result<Resources,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      resources: product {
        \(GqlResources.fields)
      }
    """
    gqlSession.query(graphql: request, type: [String:GqlResources].self,
                     fromData: fromData) { (res) in
      var ret: Result<Resources,Error>
      switch res {
      case .success(let str): 
        let resources = str["resources"]!
        resources.setPayload(feeder: self)
        ret = .success(resources)
      case .failure(let err):   ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  public func resources(closure: @escaping (Result<Resources, Error>) -> ()) {
    resources(fromData: nil, closure: closure)
  }

  // Get GqlFeederStatus
  func feederStatus(closure: @escaping(Result<GqlFeederStatus,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      feederStatus: product {
        \(GqlFeederStatus.fields)
      }
    """
    gqlSession.query(graphql: request, type: [String:GqlFeederStatus].self) { (res) in
      var ret: Result<GqlFeederStatus,Error>
      switch res {
      case .success(let fs):   
        let fst = fs["feederStatus"]!
        for feed in fst.feeds { feed.gqlFeeder = self }
        ret = .success(fst)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
 
  // Get Issues
  public func issues(feed: Feed, date: Date? = nil, key: String? = nil,
    count: Int = 20, isOverview: Bool = false, isPages: Bool = false,
    closure: @escaping(Result<[Issue],Error>)->()) { 
    struct FeedRequest: Decodable {
      var authInfo: GqlAuthInfo
      var feeds: [GqlFeed]
      static func request(feedName: String, date: Date?, key: String?,
                          count: Int, isOverview: Bool) -> String {
        var dateArg = ""
        if let date = date {
          dateArg = ",issueDate:\"\(date.isoDate(tz: GqlFeeder.tz))\""
        }
        var keyArg = ""
        if let key = key {
          keyArg = ",key:\"\(key)\""
        }
        return """
        feedRequest: product {
          authInfo { \(GqlAuthInfo.fields) }
          feeds: feedList(name:"\(feedName)") {
            \(GqlFeed.fields)
            gqlIssues: issueList(limit:\(count)\(dateArg)\(keyArg)) {
              \(isOverview ? GqlIssue.ovwFields : GqlIssue.fields)
            }
          }
        }
        """
      }
    }
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let wasAuthenticated: Bool = authToken != nil
    let request = FeedRequest.request(feedName: feed.name, date: date, key: key,
                                      count: count, isOverview: isOverview)
    gqlSession.query(graphql: request,
      type: [String:FeedRequest].self) {[weak self]  (res) in
      guard let self = self else { return }
      var ret: Result<[Issue],Error>? = nil
      switch res {
      case .success(let frq):  
        let req = frq["feedRequest"]!
        if wasAuthenticated {
          if req.authInfo.status == .valid
             && Defaults.expiredAccountDate != nil { //account not expired anymore
              MainNC.singleton.expiredAccountInfoShown = false
              Alert.message(message: "Ihr Abo ist wieder aktiv!")
              Defaults.expiredAccountDate = nil
          }
          else if req.authInfo.status == .expired
                  && MainNC.singleton.expiredAccountInfoShown == false {
            ret = .failure(FeederError.expiredAccount(req.authInfo.message))
            MainNC.singleton.expiredAccountInfoShown = true
          }
          else if req.authInfo.status != .expired
                    && req.authInfo.status != .valid {
            self.log("Invalid Auth Status: \(req.authInfo.status) for FeedRequest. WasAuth:\(wasAuthenticated) SessionAuth: \(gqlSession.authToken?.length ?? 0 > 10)")
            ret = .failure(FeederError.changedAccount(req.authInfo.message))
          }
        }
        if ret == nil { 
          if let issues = req.feeds[0].issues, issues.count > 0 {
            for issue in issues { 
              issue.feed = feed 
              (issue as? GqlIssue)?.setPayload(feeder: self, isPages: isPages)
              if let sections = issue.sections as? [GqlSection] {
                for section in sections {
                  section.primaryIssue = issue
                  if let articles = section.articles as? [GqlArticle] { 
                    for article in articles {
                      article.primaryIssue = issue
                    }
                  }
                }
              }
            }
            ret = .success(issues) 
          }
          else {
            ret = .failure(FeederError.unexpectedResponse(
              "Server didn't return issues"))
          }
        }
      case .failure(let err):
        ret = .failure(err)
      }
      closure(ret!)
    }
  }
  
//  // Get Issue
//  public func issue(feed: Feed, date: Date? = nil, key: String? = nil,
//                    isPages: Bool = false,
//                    closure: @escaping(Result<Issue,Error>)->()) { 
//    issues(feed: feed, date: date, key: key, count: 1, isOverview: false,
//           isPages: isPages) { res in
//      if let issues = res.value() {
//        if issues.count > 0 { closure(.success(issues[0])) }
//        else { 
//          closure(.failure(FeederError.unexpectedResponse(
//            "Server didn't return issues")))
//        }
//      }
//      else { closure(.failure(res.error()!)) }
//    }
//  }
//    
  /// Signal server that download has been started
  public func startDownload(feed: Feed, issue: Issue, isPush: Bool,
                            pushToken: String?, isAutomatically: Bool,
                            closure: @escaping(Result<String,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    
    var pToken = ""
    if let t = pushToken { pToken = "pushToken: \"\(t)\"," }
    
    let isTextNotification = Defaults.isTextNotification
    
    let request = """
    downloadStart(
      feedName: "\(feed.name)", 
      issueDate: "\(self.date2a(issue.date))",
      isPush: \(isPush ? "true" : "false"),
      \(pToken)
      isAutomatically: \(isAutomatically ? "true" : "false"),
      textNotification: \(isTextNotification ? "true" : "false"),
      installationId: "\(App.installationId)",
       \(deviceInfoString)
    )
    """
    gqlSession.mutation(graphql: request, type: [String:String].self) { (res) in
      var ret: Result<String,Error>
      switch res {
      case .success(let dict):   
        let status = dict["downloadStart"]!
        ret = .success(status)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }

  /// Signal server that download has been finished
  public func stopDownload(dlId: String, seconds: Double, 
                    closure: @escaping(Result<Bool,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      downloadStop(\(deviceInfoString), downloadId: "\(dlId)", downloadTime: \(seconds))
    """
    gqlSession.mutation(graphql: request, type: [String:Bool].self) { (res) in
      var ret: Result<Bool,Error>
      switch res {
      case .success(let dict):   
        let status = dict["downloadStop"]!
        ret = .success(status)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  /// send error report to server
  public func errorReport(
    message:String?,
    lastAction:String?,
    conditions:String?,
    deviceData:DeviceData?,
    errorProtocol:String?,
    eMail:String?,//comes from Server
    screenshotName:String?,
    screenshot:String?,
    finished: @escaping(Result<Bool,Error>)->()) {
    
    guard let gqlSession = self.gqlSession else {
      finished(.failure(fatal("Not connected"))); return
    }
    
    var fields:[String:Any] = [:]


    fields["deviceOS"] = "iOS \(UIDevice.current.systemVersion)"
    fields["deviceName"] = UIDevice().model
    fields["eMail"] = eMail
    //    fields["deviceVersion"] = deviceVersion
    fields["appVersion"] = "\(App.name) (\(App.bundleIdentifier)) Ver.:\(App.bundleVersion) #\(App.buildNumber)"
    fields["installationId"] = App.installationId
    fields["storageAvailable"] = deviceData?.storageAvailable
    fields["storageUsed"] = deviceData?.storageUsed
    fields["ramAvailable"] = deviceData?.ramAvailable
    fields["ramUsed"] = deviceData?.ramUsed
    fields["pushToken"] = Defaults.singleton["pushToken"]
    fields["architecture"] = Utsname.machine
    fields["screenshotName"] = screenshotName
    fields["screenshot"] = screenshot
    
    // Data as Array = Dict     remove nil values     map key: value
    var arrayData = fields.compactMapValues{$0}.map{"\($0.key): \"\($0.value)\""}
    
    arrayData += "deviceType: \(Device.deviceType)"
    arrayData += "deviceFormat: \(Device.deviceFormat)"
    if let errorProt = errorProtocol {
      arrayData += "errorProtocol: \(errorProt.quote())"
    }
    
    if let msg = message {
        arrayData += "message: \(msg.quote())"
    }
    
    if let la = lastAction {
         arrayData += "lastAction: \(la.quote())"
    }
    
    if let cond = conditions {
        arrayData += "conditions: \(cond.quote())"
    } 
    
    let request = "errorReport(\(arrayData.joined(separator: ", ")))"
    
    gqlSession.mutation(graphql: request, type: [String:Bool].self) { (res) in
      var ret: Result<Bool,Error>
      switch res {
        case .success(let dict):
          //        let status = dict["whatever"]!
          print("success_ \(dict)")
          ret = .success(true)
        case .failure(let err):  ret = .failure(err)
      }
      finished(ret)
    }
  }
  
  /// send error report to server
  public func requestAccountDeletion(finished: @escaping(Result<Bool,Error>)->()) {
    
    guard let gqlSession = self.gqlSession else {
      finished(.failure(fatal("Not connected"))); return
    }
    
    var fields:[String:Any] = [:]
    fields["message"] = "Ringo: Test Vorbereitung für Account löschen Request, Bitte ignorieren!"
    fields["appVersion"] = "\(App.name) (\(App.bundleIdentifier)) Ver.:\(App.bundleVersion) #\(App.buildNumber)"
    fields["deviceName"] = UIDevice().model
    fields["eMail"] = "ringo.mueller@taz.de"
    fields["installationId"] = App.installationId

    // Data as Array = Dict     remove nil values     map key: value
    var arrayData = fields.compactMapValues{$0}.map{"\($0.key): \"\($0.value)\""}
    arrayData += "deviceType: \(Device.deviceType)"
    arrayData += "deviceFormat: \(Device.deviceFormat)"
    let request = "errorReport(\(arrayData.joined(separator: ", ")))"
    
    gqlSession.mutation(graphql: request, type: [String:Bool].self) { (res) in
      var ret: Result<Bool,Error>
      switch res {
        case .success(let dict):
          print("success_ \(dict)")
          ret = .success(true)
        case .failure(let err):  ret = .failure(err)
      }
      finished(ret)
    }
  }
  
} // GqlFeeder
