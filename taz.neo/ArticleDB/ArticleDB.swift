//
//  ArticleDB.swift
//
//  Created by Norbert Thies on 04.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import CoreData
import NorthLib

/// A quite simple Database derivation
class ArticleDB: Database {  
  
  /// There is only one article DB in the app
  static var singleton: ArticleDB!
  
  /// Initialize with name of database, open it and call the passed closure
  @discardableResult
  public init(name: String, closure: @escaping (Error?)->()) { 
    super.init(name: name, model: "ArticleDB") 
    ArticleDB.singleton = self
    self.open { err in closure(err) }
  }    
  
  /// The managed object context
  static var context: NSManagedObjectContext { return singleton.context! } 
  
} // ArticleDB

/// A Protocol to extend CoreData objects
protocol PersistentObject: NSManagedObject, DoesLog {}

extension PersistentObject {
  /// The unique ID of every CoredData entity as String
  var id: String { objectID.uriRepresentation().absoluteString }
  /// Get object using its ID
  static func get(id: String) -> Self? { 
    let uri = URL(string: id)
    let coordinator = ArticleDB.singleton.coordinator
    if let uri = uri,
       let oid = coordinator.managedObjectID(forURIRepresentation: uri) {
      return ArticleDB.context.object(with: oid) as? Self
    }
    return nil
  }
} // PersistentObject

/// A StoredObject is in essence a PersistentObject Wrapper
protocol StoredObject: DoesLog {
  associatedtype PO: PersistentObject
  var pr: PO { get }                      // persistent record
  var id: String { get }                  // ID of persistent record
  init(persistent: PO)                    // create stored record from persistent one
  static var entity: String { get }       // name of persistent entity
  static var fetchRequest: NSFetchRequest<PO> { get } // fetch request for persistent record
}

extension StoredObject {  
  
  var id: String { pr.id } // ID of persistent record
  static var fetchRequest: NSFetchRequest<PO> { NSFetchRequest<PO>(entityName: entity) }

  /// Delete the object from the persistent store
  func delete() { ArticleDB.context.delete(pr) }
  
  /// Create a new persistent record 
  static func new() -> Self {
    let pr = NSEntityDescription.insertNewObject(forEntityName: entity,
               into: ArticleDB.context) as! PO
    let sr = Self(persistent: pr)
    return sr
  }
  
  /// Get record using its ID
  static func get(id: String) -> Self? { 
    if let rec = PO.get(id: id) { 
      return Self(persistent: rec) 
    }
    return nil
  }

  /// Execute fetch request and return persistent records
  static func getPersistent(request: NSFetchRequest<PO>) -> [PO] {
    do {
      let res = try ArticleDB.context.fetch(request)
      return res
    }
    catch let err { Log.error(err) }
    return []
  }

  /// Execute fetch request and return stored records
  static func get(request: NSFetchRequest<PO>) -> [Self] {
    return getPersistent(request: request).map { Self(persistent: $0) }
  }
  
  /// Return all stored records
  static func all() -> [Self] {
    let request = fetchRequest
    return get(request: request)
  }

}

extension PersistentFileEntry: PersistentObject {
  // Remove file if record is deleted
  public override func prepareForDeletion() {
    if let fn = name { File(fn).remove() }
  }
}

/// A stored FileEntry
class StoredFileEntry: FileEntry, StoredObject {
  
  static var entity = "FileEntry"
  var pr: PersistentFileEntry // persistent record
  var name: String { pr.name! }
  var storageType: FileStorageType { FileStorageType(rawValue: pr.storageType)! }
  var moTime: Date { pr.moTime! }
  var size: Int64 { pr.size }
  var storedSize: Int64 { 
    get { pr.storedSize }
    set { pr.storedSize = newValue }
  }
  var sha256: String { pr.sha256! }
  var payload: StoredPayload { StoredPayload(persistent: pr.payload!) }
  var image: StoredImageEntry? {
    if let img = pr.image { return StoredImageEntry(persistent: img) }
    else { return nil }
  }
  
  required init(persistent: PersistentFileEntry) { self.pr = persistent }

  /// Overwrite the persistent values
  func update(file: FileEntry) {
    pr.name = file.name
    pr.storageType = file.storageType.rawValue
    pr.moTime = file.moTime
    pr.size = file.size
    pr.sha256 = file.sha256      
  }
  
  /// Return stored record with given name  
  static func get(name: String) -> [StoredFileEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "name = %@", name)
    return get(request: request)
  }
  
  /// Create a new persistent record if not available and store the passed FileEntry into it
  static func persist(file: FileEntry) -> StoredFileEntry {
    let sfes = get(name: file.name)
    var sr: StoredFileEntry
    if sfes.count == 0 { sr = new() }
    else { sr = sfes[0] }
    sr.update(file: file)
    return sr
  }
  
  /// Return stored record with given SHA256  
  static func get(sha256: String) -> [StoredFileEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "sha256 = %@", sha256)
    return get(request: request)
  }
  
  /// Return all records of a payload
  static func filesInPayload(payload: StoredPayload) -> [StoredFileEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "payload = %@", payload.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
  /// Return all animation files of a Moment
  static func animationInMoment(moment: StoredMoment) -> [StoredFileEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "momentAnimated = %@", moment.pr)
    return get(request: request)
  }
  
} // StoredFileEntry

extension PersistentImageEntry: PersistentObject {}

/// A stored FileEntry
class StoredImageEntry: ImageEntry, StoredObject {  
  
  static var entity = "ImageEntry"
  var pr: PersistentImageEntry // persistent record
  var pf: PersistentFileEntry!
  var name: String { pf.name! }
  var storageType: FileStorageType { FileStorageType(rawValue: pf.storageType)! }
  var moTime: Date { pf.moTime! }
  var size: Int64 { pf.size }
  var sha256: String { pf.sha256! }
  var resolution: ImageResolution { ImageResolution(rawValue: pr.resolution)! }
  var type: ImageType { ImageType(rawValue: pr.type)! }
  var alpha: Float? { pr.alpha }
  var sharable: Bool { pr.sharable }
  var author: StoredAuthor? { 
    if let au = pr.author { return StoredAuthor(persistent: au) }
    else { return nil }
  }
  
  required init(persistent: PersistentImageEntry) { 
    self.pr = persistent 
    if let pf = persistent.file { self.pf = pf }
  }

  /// Overwrite the persistent values
  func update(file: ImageEntry) {
    if pf == nil { pf = StoredFileEntry.new().pr }
    pf.name = file.name
    pf.storageType = file.storageType.rawValue
    pf.moTime = file.moTime
    pf.size = file.size
    pf.sha256 = file.sha256
    pr.resolution = file.resolution.rawValue
    pr.type = file.type.rawValue
    pr.alpha = file.alpha ?? 1.0
    pr.sharable = file.sharable
    pf.image = pr
  }
  
  /// Return stored record with given name  
  static func get(name: String) -> [StoredImageEntry] {
    let files = StoredFileEntry.get(name: name)
    if files.count > 0 {
      if let img = files[0].image {
        return [img]
      }
    }
    return []
  }
  
  /// Create a new persistent record if not available and store the passed FileEntry into it
  static func persist(file: ImageEntry) -> StoredImageEntry {
    let sies = get(name: file.name)
    var sr: StoredImageEntry
    if sies.count == 0 { sr = new() }
    else { sr = sies[0] }
    sr.update(file: file)
    return sr
  }
  
  /// Return stored record with given SHA256  
  static func get(sha256: String) -> [StoredImageEntry] {
    let files = StoredFileEntry.get(sha256: sha256)
    if files.count > 0 {
      if let img = files[0].image {
        return [img]
      }
    }
    return []
  }
  
  /// Return all images of a Moment
  static func imagesInMoment(moment: StoredMoment) -> [StoredImageEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "moment = %@", moment.pr)
    return get(request: request)
  }
  
  /// Return all images of an Article
  static func imagesInArticle(article: StoredArticle) -> [StoredImageEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "imageContent = %@", article.pr)
    return get(request: request)
  }
  
  /// Return all images of a Section
  static func imagesInSection(section: StoredSection) -> [StoredImageEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "imageContent = %@", section.pr)
    return get(request: request)
  }
  
  /// Return all credited images of a Moment
  static func creditedImagesInMoment(moment: StoredMoment) -> [StoredImageEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "momentCredit = %@", moment.pr)
    return get(request: request)
  }
  
} // StoredImageEntry

extension PersistentMoment: PersistentObject {}

/// A stored FileEntry
class StoredMoment: Moment, StoredObject {

  static var entity = "Moment"
  var pr: PersistentMoment // persistent record
  var data: Data? {
    get { pr.data }
    set { pr.data = newValue }
  }
  var image: UIImage? { (data == nil) ? nil : UIImage(data: data!) }
  var images: [ImageEntry] { StoredImageEntry.imagesInMoment(moment: self) }
  var creditedImages: [ImageEntry] 
    { StoredImageEntry.creditedImagesInMoment(moment: self) }
  var animation: [FileEntry] { StoredFileEntry.animationInMoment(moment: self) }
  
  required init(persistent: PersistentMoment) { 
    self.pr = persistent 
  }
  
  /// Store all data as a new entry
  static func persist(obj: Moment) -> StoredMoment {
    let sr = new()
    for img in obj.images {
      let se = StoredImageEntry.persist(file: img)
      se.pr.moment = sr.pr
      sr.pr.addToImages(se.pr)
    }
    for img in obj.creditedImages {
      let se = StoredImageEntry.persist(file: img)
      se.pr.momentCredit = sr.pr
      sr.pr.addToCreditedImages(se.pr)
    }
    for f in obj.animation {
      let fe = StoredFileEntry.persist(file: f)
      fe.pr.momentAnimated = sr.pr
      sr.pr.addToAnimation(fe.pr)
    }
    ArticleDB.singleton.save()
    return sr
  }
  
  /// Read Image data from file and store it in persistent record
  func storeData(from file: String) {
    self.data = File(file).data
  }
  
} // Stored Moment

extension PersistentPayload: PersistentObject {}

/// A stored Payload
class StoredPayload: StoredObject {
  
  static var entity = "Payload"  
  var pr: PersistentPayload // persistent record
  var bytesLoaded: Int64 {
    get { return pr.bytesLoaded }
    set { pr.bytesLoaded = newValue }
  }
  var bytesTotal: Int64 {
    get { return pr.bytesTotal }
    set { pr.bytesTotal = newValue }
  }
  var downloadStarted: Date? {
    get { return pr.downloadStarted }
    set { pr.downloadStarted = newValue }
  }
  var downloadStopped: Date? {
    get { return pr.downloadStopped }
    set { pr.downloadStopped = newValue }
  }
  var localDir: String {
    get { return pr.localDir! }
    set { pr.localDir = newValue }
  }
  var remoteBaseUrl: String? {
    get { return pr.remoteBaseUrl }
    set { pr.remoteBaseUrl = newValue }
  }
  var remoteZipName: String? {
    get { return pr.remoteZipName }
    set { pr.remoteZipName = newValue }
  }

  lazy var files: [StoredFileEntry] = { 
    StoredFileEntry.filesInPayload(payload: self) 
  }()
  
  var isComplete: Bool { bytesTotal <= bytesLoaded }


  required init(persistent: PersistentPayload) { self.pr = persistent }
  
  /// Store all FileEntries as one new Payload
  static func persist(files: [FileEntry], localDir: String, 
                      remoteBaseUrl: String? = nil,
                      remoteZipName: String? = nil) -> StoredPayload {
    let sr = new()
    var bytesTotal: Int64 = 0
    var order: Int64 = 0
    for f in files {
      let fe = StoredFileEntry.persist(file: f)
      fe.pr.order = order
      order += 1
      sr.pr.addToFiles(fe.pr)
      bytesTotal += f.size
    }
    sr.bytesTotal = bytesTotal
    sr.bytesLoaded = 0
    sr.localDir = localDir
    sr.remoteBaseUrl = remoteBaseUrl
    sr.remoteZipName = remoteZipName
    ArticleDB.singleton.save()
    return sr
  }

} // StoredPayload

extension PersistentResources: PersistentObject {}

/// A stored list of resource files
class StoredResources: Resources, StoredObject {
    
  static var entity = "Resources"
  var pr: PersistentResources // persistent record
  lazy var payload = StoredPayload(persistent: pr.payload!)
  var resourceBaseUrl: String { payload.remoteBaseUrl! }
  var resourceZipName: String { payload.remoteZipName! }
  var resourceVersion: Int { Int(pr.resourceVersion) }
  var localDir: String { payload.localDir }
  var resourceFiles: [FileEntry] { payload.files }
  var isDownloading: Bool = false
  var isComplete: Bool { 
    get { return payload.isComplete }
    set {}
  }

  required init(persistent: PersistentResources) { self.pr = persistent }

  /// Return stored record with given resourceVersion  
  static func get(version: Int) -> [StoredResources] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "resourceVersion = %d", version)
    return get(request: request)
  }
  
  /// Return stored record with latest (largest) resourceVersion
  static func latest() -> StoredResources? {
    let request = fetchRequest
    request.fetchLimit = 1
    request.sortDescriptors = [
      NSSortDescriptor(key: "resourceVersion", ascending: false)
    ]
    let res = get(request: request)
    if res.count > 0 { return res[0] }
    else { return nil }
  }
  
  /// Create a new persistent record if not available and store the passed 
  /// Resources into it
  static func persist(res: Resources, localDir: String) -> StoredResources {
    let sfes = get(version: res.resourceVersion)
    var sr: StoredResources
    if sfes.count == 0 { sr = new() }
    else { return sfes[0] }
    let spl = StoredPayload.persist(files: res.resourceFiles, localDir: localDir, 
      remoteBaseUrl: res.resourceBaseUrl, remoteZipName: res.resourceZipName)
    sr.pr.payload = spl.pr
    sr.pr.resourceVersion = Int32(res.resourceVersion)
    ArticleDB.singleton.save()
    return sr
  }

} // StoredResources

extension PersistentAuthor: PersistentObject {}

/// A stored Author
class StoredAuthor: Author, StoredObject {
  
  static var entity = "Author"
  var pr: PersistentAuthor // persistent record
  var name: String? { pr.name }
  var photo: ImageEntry? { 
    if let p = pr.photo { return StoredImageEntry(persistent: p) }
    else { return nil }
  }
  
  required init(persistent: PersistentAuthor) { self.pr = persistent }

  /// Overwrite the persistent values
  func update(object: Author) {
    pr.name = object.name
    if let photo = object.photo {
      let imageEntry = StoredImageEntry.persist(file: photo)
      pr.photo = imageEntry.pr
      imageEntry.pr.author = pr
    }
    else { pr.photo = nil }
  }
  
  /// Return stored record with given name  
  static func get(name: String) -> [StoredAuthor] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "name = %@", name)
    return get(request: request)
  }
  
  /// Return stored record with given photo  
  static func get(photo: ImageEntry) -> [StoredAuthor] {
    let imgs = StoredImageEntry.get(name: photo.name) 
    if imgs.count > 0 {
      if let au = imgs[0].author {
        return [au]
      }
    }
    return []
  }
  
  /// Create a new persistent record if not available and store the passed Author into it
  static func persist(object: Author) -> StoredAuthor {
    var pers: [StoredAuthor] = []
    if let n = object.name { pers = get(name: n) }
    else { pers = get(photo: object.photo!) }
    if pers.count == 0 { pers = [new()] }
    pers[0].update(object: object)
    return pers[0]
  }
  
  /// Return all Authors of an Article
  static func authorsOfArticle(article: StoredArticle) -> [StoredAuthor] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "articles = %@", article.pr)
    return get(request: request)
  }
  
} // StoredAuthor

extension PersistentArticle: PersistentObject {}

/// A stored Article
class StoredArticle: Article, StoredObject {
  
  static var entity = "Article"
  var pr: PersistentArticle // persistent record
  var text: String? {
    get { return pr.text }
    set { pr.text = newValue }
  }
  var title: String? {
    get { return pr.title }
    set { pr.title = newValue }
  }
  var html: FileEntry {
    get { return StoredFileEntry(persistent: pr.html!) }
    set { 
      pr.html = StoredFileEntry.persist(file: newValue).pr 
      pr.html!.content = pr
    }
  }
  var audio: FileEntry? {
    get { 
      if let pau = pr.audio { return StoredFileEntry(persistent: pau) }
      else { return nil } 
    }
    set { 
      if let au = newValue { 
        pr.audio = StoredFileEntry.persist(file: au).pr
        pr.audio?.articleAudio = pr
      }
      else { pr.audio = nil }      
    }
  }
  var lastArticlePosition: Int {
    get { return Int(pr.lastArticlePosition) }
    set { pr.lastArticlePosition = Int64(newValue) }
  }
  var onlineLink: String? {
    get { return pr.onlineLink }
    set { pr.onlineLink = newValue }
  }
  var teaser: String? {
    get { return pr.teaser }
    set { pr.teaser = newValue }
  }
  var images: [ImageEntry]? { StoredImageEntry.imagesInArticle(article: self) }
  var authors: [Author]? { StoredAuthor.authorsOfArticle(article: self) }
  var pageNames: [String]? { nil }
  
  required init(persistent: PersistentArticle) { self.pr = persistent }

  /// Overwrite the persistent values
  func update(object: Article) {
    if let sobject = object as? StoredArticle {
      self.text = sobject.text
      self.lastArticlePosition = sobject.lastArticlePosition
    }
    self.title = object.title
    self.html = object.html
    self.audio = object.audio
    self.onlineLink = object.onlineLink
    self.teaser = object.teaser
    if let imgs = object.images {
      for img in imgs {
        let imageEntry = StoredImageEntry.persist(file: img)
        imageEntry.pr.addToImageContent(pr)
      }
    }
    if let aus = object.authors {
      for au in aus {
        let sau = StoredAuthor.persist(object: au)
        sau.pr.addToArticles(pr)
      }
    }
  }
  
  /// Return stored record with given name  
  static func get(file: String) -> [StoredArticle] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "html.name = %@", file)
    return get(request: request)
  }
  
  /// Create a new persistent record if not available and store the passed 
  /// Article into it
  static func persist(object: Article) -> StoredArticle {
    let tmp = get(file: object.html.name)
    var sart: StoredArticle
    if tmp.count == 0 { sart = new() }
    else { sart = tmp[0] }
    sart.update(object: object)
    return sart
  }
  
  /// Return all Articles in a Section
  static func articlesInSection(section: StoredSection) -> [StoredArticle] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "sections = %@", section.pr)
    return get(request: request)
  }
  
  /// Return all Articles in an Issue
  static func articlesInIssue(issue: StoredIssue) -> [StoredArticle] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "issues = %@", issue.pr)
    return get(request: request)
  }

} // StoredArticle

extension PersistentSection: PersistentObject {}

/// A stored Section
class StoredSection: Section, StoredObject {
  
  static var entity = "Section"
  var pr: PersistentSection // persistent record
  var text: String? {
    get { return pr.text }
    set { pr.text = newValue }
  }
  var name: String {
    get { return pr.name! }
    set { pr.name = newValue }
  }
  var extendedTitle: String? {
    get { return pr.extendedTitle }
    set { pr.extendedTitle = newValue }
  }
  var type: SectionType {
    get { return SectionType(rawValue: pr.type)! }
    set { pr.type = newValue.rawValue }
  }
  var html: FileEntry {
    get { return StoredFileEntry(persistent: pr.html!) }
    set { 
      pr.html = StoredFileEntry.persist(file: newValue).pr 
      pr.html!.content = pr
    }
  }
  var navButton: ImageEntry? {
    get { 
      if let pbutton = pr.navButton { return StoredImageEntry(persistent: pbutton) }
      else { return nil } 
    }
    set { 
      if let button = newValue { 
        pr.navButton = StoredImageEntry.persist(file: button).pr
        pr.navButton?.addToNavSection(pr)
      }
      else { pr.navButton = nil }      
    }
  }

  var images: [ImageEntry]? { StoredImageEntry.imagesInSection(section: self) }
  var authors: [Author]? { nil }
  var articles: [Article]? { StoredArticle.articlesInSection(section: self) }
  
  required init(persistent: PersistentSection) { self.pr = persistent }

  /// Overwrite the persistent values
  func update(object: Section) {
    if let sobject = object as? StoredSection {
      self.text = sobject.text
    }
    self.name = object.name
    self.extendedTitle = object.extendedTitle
    self.type = object.type
    self.html = object.html
    self.navButton = object.navButton
    if let imgs = object.images {
      for img in imgs {
        let imageEntry = StoredImageEntry.persist(file: img)
        imageEntry.pr.addToImageContent(pr)
      }
    }
    if let arts = object.articles {
      for art in arts {
        let newArt = StoredArticle.persist(object: art)
        newArt.pr.addToSections(self.pr)
      }
    }
  }
  
  /// Return stored record with given name  
  static func get(file: String) -> [StoredSection] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "html.name = %@", file)
    return get(request: request)
  }
  
  /// Create a new persistent record if not available and store the passed 
  /// Section into it
  static func persist(object: Section) -> StoredSection {
    let tmp = get(file: object.html.name)
    var ssec: StoredSection
    if tmp.count == 0 { ssec = new() }
    else { ssec = tmp[0] }
    ssec.update(object: object)
    return ssec
  }
  
  /// Return all Sections in an Issue
  static func sectionsInIssue(issue: StoredIssue) -> [StoredSection] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "issue = %@", issue.pr)
    return get(request: request)
  }

} // StoredSection

extension PersistentIssue: PersistentObject {}

/// A stored Issue
class StoredIssue: Issue, StoredObject {
  
  static var entity = "Issue"
  var pr: PersistentIssue // persistent record
  var feed: Feed { 
    get { StoredFeed(persistent: pr.feed!) }
    set { 
      if let sfeed = newValue as? StoredFeed {
        pr.feed = sfeed.pr
        pr.feed?.addToIssues(self.pr)
      }
    }
  }
  var date: Date {
    get { return pr.date! }
    set { pr.date = newValue }
  }
  var moTime: Date {
    get { return pr.moTime! }
    set { pr.moTime = newValue }
  }
  var isWeekend: Bool {
    get { return pr.isWeekend }
    set { pr.isWeekend = newValue }
  }
  var moment: Moment { 
    get { StoredMoment(persistent: pr.moment!) }
    set { 
      pr.moment = StoredMoment.persist(obj: newValue).pr
      pr.moment?.issue = self.pr
    }
  }
  var key: String? {
    get { return pr.key }
    set { pr.key = newValue }
  }
  var baseUrl: String {
    get { return pr.baseUrl! }
    set { pr.baseUrl = newValue }
  }
  var status: IssueStatus {
    get { return IssueStatus(rawValue: pr.status)! }
    set { pr.status = newValue.rawValue }
  }
  var minResourceVersion: Int {
    get { return Int(pr.minResourceVersion) }
    set { pr.minResourceVersion = Int32(newValue) }
  }
  var zipName: String? {
    get { return pr.zipName }
    set { pr.zipName = newValue }
  }
  var zipNamePdf: String? {
    get { return pr.zipNamePdf }
    set { pr.zipNamePdf = newValue }
  }
  var fileList: [String]? { nil }
  var fileListPdf: [String]? { nil }
  var imprint: Article? {
    get {
      if let pim = pr.imprint { return StoredArticle(persistent: pim) }
      else { return nil }
    }
    set {
      if let sim = newValue {
        pr.imprint = StoredArticle.persist(object: sim).pr
        pr.imprint?.issueImprint = self.pr
      }
      else { pr.imprint = nil }
    }
  }
  var sections: [Section]? { StoredSection.sectionsInIssue(issue: self) }
  var pages: [Page]? { nil }
  var isDownloading: Bool = false
  var isComplete: Bool = false

  required init(persistent: PersistentIssue) { self.pr = persistent }

  /// Overwrite the persistent values
  func update(object: Issue) {
    self.feed = object.feed
    self.date = object.date
    self.moTime = object.moTime
    self.isWeekend = object.isWeekend
    self.moment = object.moment
    self.key = object.key
    self.baseUrl = object.baseUrl
    self.minResourceVersion = object.minResourceVersion
    self.zipName = object.zipName
    self.zipNamePdf = object.zipNamePdf
    self.imprint = object.imprint
    self.status = object.status
    if let secs = object.sections {
      for section in secs {
        let ssection = StoredSection.persist(object: section)
        ssection.pr.issue = self.pr
      }
    }
  }
  
  /// Return stored record with given name  
  static func get(date: Date, inFeed feed: StoredFeed) -> [StoredIssue] {
    let nsdate = NSDate(timeIntervalSinceReferenceDate:
                        date.timeIntervalSinceReferenceDate)
    let request = fetchRequest
    request.predicate = NSPredicate(format: "(date = %@) AND (feed = %@)", 
                                    nsdate, feed.pr)
    return get(request: request)
  }
  
  /// Create a new persistent record if not available and store the passed 
  /// Article into it
  static func persist(object: Issue, inFeed feed: StoredFeed) -> StoredIssue {
    let tmp = get(date: object.date, inFeed: feed)
    var sissue: StoredIssue
    if tmp.count == 0 { sissue = new() }
    else { sissue = tmp[0] }
    sissue.update(object: object)
    return sissue
  }
  
  /// Return all Issues in a Feed
  static func issuesInFeed(feed: StoredFeed) -> [StoredIssue] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "feed = %@", feed.pr)
    return get(request: request)
  }
  
} // StoredIssue

extension PersistentFeed: PersistentObject {}

/// A stored Feed
class StoredFeed: Feed, StoredObject {
  
  static var entity = "Feed"
  var pr: PersistentFeed // persistent record
  var name: String {
    get { return pr.name! }
    set { pr.name = newValue }
  }
  var cycle: PublicationCycle {
    get { return PublicationCycle(rawValue: pr.cycle)! }
    set { pr.cycle = newValue.rawValue }
  }
  var type: FeedType {
    get { return FeedType(rawValue: pr.type)! }
    set { pr.type = newValue.rawValue }
  }
  var momentRatio: Float {
    get { return pr.momentRatio }
    set { pr.momentRatio = newValue }
  }
  var issueCnt: Int {
    get { return Int(pr.issueCnt) }
    set { pr.issueCnt = Int64(newValue) }
  }
  var firstIssue: Date {
    get { return pr.firstIssue! }
    set { pr.firstIssue = newValue }
  }
  var lastIssue: Date {
    get { return pr.lastIssue! }
    set { pr.lastIssue = newValue }
  }
  var lastIssueRead: Date? {
    get { return pr.lastIssueRead }
    set { pr.lastIssueRead = newValue }
  }
  var lastUpdated: Date? {
    get { return pr.lastUpdated }
    set { pr.lastUpdated = newValue }
  }

  var issues: [Issue]? { StoredIssue.issuesInFeed(feed: self) }
  
  required init(persistent: PersistentFeed) { self.pr = persistent }

  /// Overwrite the persistent values
  func update(object: Feed) {
    self.name = object.name
    self.cycle = object.cycle
    self.type = object.type
    self.issueCnt = object.issueCnt
    self.momentRatio = object.momentRatio
    self.firstIssue = object.firstIssue
    self.lastIssue = object.lastIssue
    self.lastIssueRead = object.lastIssueRead
    self.lastUpdated = object.lastUpdated
    if let iss = object.issues {
      for issue in iss {
        let sissue = StoredIssue.persist(object: issue, inFeed: self)
        sissue.pr.feed = pr
      }
    }
  }
  
  /// Return stored Issue with given name in Feeder
  static func get(name: String, inFeeder feeder: StoredFeeder) -> [StoredFeed] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "(name = %@) AND (feeder = %@)", 
                                    name, feeder.pr)
    return get(request: request)
  }
  
  /// Create a new persistent record if not available and store the passed 
  /// Article into it
  static func persist(object: Feed, inFeeder: StoredFeeder) -> StoredFeed {
    let tmp = get(name: object.name, inFeeder: inFeeder)
    var sfeed: StoredFeed
    if tmp.count == 0 { sfeed = new() }
    else { sfeed = tmp[0] }
    sfeed.update(object: object)
    return sfeed
  }
  
  /// Return all Feeds of a Feeder
  static func feedsOfFeeder(feeder: StoredFeeder) -> [StoredFeed] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "feeder = %@", feeder.pr)
    return get(request: request)
  }

} // StoredFeed

extension PersistentFeeder: PersistentObject {}

/// A stored Feeder
public class StoredFeeder: Feeder, StoredObject {

  static var entity = "Feeder"
  var pr: PersistentFeeder // persistent record
  public var title: String {
    get { return pr.title! }
    set { pr.title = newValue }
  }
  public var timeZone: String {
    get { return pr.timeZone! }
    set { pr.timeZone = newValue }
  }
  public var baseUrl: String {
    get { return pr.baseUrl! }
    set { pr.baseUrl = newValue }
  }
  public var globalBaseUrl: String {
    get { return pr.globalBaseUrl! }
    set { pr.globalBaseUrl = newValue }
  }
  public var authToken: String? {
    get { return pr.authToken }
    set { pr.authToken = newValue }
  }
  public var lastUpdated: Date? {
    get { return pr.lastUpdated }
    set { pr.lastUpdated = newValue }
  }
  public var resourceVersion: Int {
    get { return Int(pr.resourceVersion) }
    set { pr.resourceVersion = Int32(newValue) }
  }
  public var feeds: [Feed] { StoredFeed.feedsOfFeeder(feeder: self) }
  
  public required init(persistent: PersistentFeeder) { self.pr = persistent }

  /// Overwrite the persistent values
  public func update(object: Feeder) {
    self.title = object.title
    self.timeZone = object.timeZone
    self.baseUrl = object.baseUrl
    self.globalBaseUrl = object.globalBaseUrl
    self.authToken = object.authToken
    self.resourceVersion = object.resourceVersion
    self.lastUpdated = object.lastUpdated
    for feed in object.feeds {
      let sfeed = StoredFeed.persist(object: feed, inFeeder: self)
      sfeed.pr.feeder = pr
    }
  }
  
  /// Return stored record with given name/title 
  public static func get(name: String) -> [StoredFeeder] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "title = %@", name)
    return get(request: request)
  }
  
  /// Create a new persistent record if not available and store the passed 
  /// Article into it
  public static func persist(object: Feeder) -> StoredFeeder {
    let tmp = get(name: object.title)
    var sfeeder: StoredFeeder
    if tmp.count == 0 { sfeeder = new() }
    else { sfeeder = tmp[0] }
    sfeeder.update(object: object)
    return sfeeder
  }
  
  public required init(title: String, url: String, closure:
    @escaping(Result<Feeder,Error>)->()) {
    let request = StoredFeeder.fetchRequest
    request.predicate = NSPredicate(format: "title = %@", title)
    let pfeeders = StoredFeeder.getPersistent(request: request)
    if pfeeders.count > 0 {
      self.pr = pfeeders[0]
      closure(.success(self))
    }
    else {
      pr = PersistentFeeder()
      closure(.failure(Log.error("No Feeder with name '\(title)' found"))) 
    }
  }

  public func authenticate(account: String, password: String, closure: 
    @escaping (Result<String, Error>) -> ()) {
    closure(.failure(error("Can't authenticate at DB Feeder")))
  }
  
  public func resources(closure: @escaping(Result<Resources,Error>)->()) {
    closure(.failure(error("Currently no resources available")))
  }
  
} // StoredFeeder
