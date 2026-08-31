//
//  ArticleDB.swift
//
//  Created by Norbert Thies on 04.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import CoreData
import NorthLib

/// A quite simple Database derivation
public class ArticleDB: Database {
  
  /// There is only one article DB in the app
  public static var singleton: ArticleDB!
  
  let dbQueue = DispatchQueue(label: "database-queue")
  
  /// Initialize with name of database, open it and call the passed closure
  @discardableResult
  public init(name: String, closure: @escaping (Error?)->()) {
    super.init(name: name, model: "ArticleDB")
    onVersionChange { [weak self] _ in
      self?.mergeVersions()
    }
    ArticleDB.singleton = self
    self.open { err in closure(err) }
  }
  
  /// The managed object context
  public static var context: NSManagedObjectContext { return singleton.context! }
  
  var isShowingDbErrorInfo: Bool = false
  
  //public static func save() {...isMoved to ArticleDB+SaveErrorHandling
} // ArticleDB

/// A Protocol to extend CoreData objects
public protocol PersistentObject: NSManagedObject, DoesLog {}

public extension PersistentObject {
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
  /// Delete the object from the persistent store
  func delete() { ArticleDB.context.delete(self) }
} // PersistentObject

/// A StoredObject is in essence a PersistentObject Wrapper
public protocol StoredObject: DoesLog {
  
  associatedtype PO: PersistentObject
  associatedtype Object
  var pr: PO { get }                      // persistent record
  var id: String { get }                  // ID of persistent record
  init(persistent: PO)                    // create stored record from persistent one
  /// Update from passed Object
  func update(from: Object)
  /// Get from passed Object
  static func get(object: Object) -> Self?
  static func persist(object: Object) -> Self
  static var entity: String { get }       // name of persistent entity
  static var fetchRequest: NSFetchRequest<PO> { get } // fetch request for persistent record
  
} // StoredObject

public extension StoredObject {
  
  var id: String { pr.objectID.uriRepresentation().absoluteString }// ID of persistent record
  static var fetchRequest: NSFetchRequest<PO> { NSFetchRequest<PO>(entityName: entity) }
  
  /// Delete the object from the persistent store
  func deletePersistent() { pr.delete() }
  func delete() {
    Notification.send("issueProgress", content: "deleted", sender: self)
    if let issue = self as? Issue {
      Notification.send("issueDelete", content: issue.date)
    }
    deletePersistent()
  }
  
  /// Create a new persistent record
  static func newPersistent() -> PO {
    NSEntityDescription.insertNewObject(forEntityName: entity,
                                        into: ArticleDB.context) as! PO
  }
  
  /// Create a new stored and persistent record
  static func new() -> Self {
    Self(persistent: newPersistent())
  }
  
  /// Create new StoredObject and initialize from Object
  @discardableResult
  static func persist(object: Object) -> Self {
    var storedRecord: Self
    if let tmp = get(object: object) { storedRecord = tmp }
    else { storedRecord = new() }
    storedRecord.update(from: object)
    return storedRecord
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
  
  func save() { ArticleDB.save() }
  
} // StoredObject

extension PersistentFileEntry: PersistentObject {
  
  // Remove file if record is deleted and no other records point to this file
  public override func prepareForDeletion() {
    if let fn = name, let sd = subdir {
      let path = "\(Database.appDir)/\(sd)/\(fn)"
      File(path).remove()
      if name?.contains("bundestalk") == true {
        debug("Deleted File at \(path)")
      }
    }
  }
  var isGlobal: Bool { storageType == FileStorageType.global.rawValue  }
}

/// A stored FileEntry
public final class StoredFileEntry: FileEntry, StoredObject {
  
  public static var entity = "FileEntry"
  public var pr: PersistentFileEntry // persistent record
  public var name: String {
    get { pr.name! }
    set { pr.name = newValue }
  }
  /// Sub directory relative to Database.appDir where the file is stored
  public var subdir: String? {
    get { pr.subdir }
    set { pr.subdir = newValue }
  }
  /// Absolute directory where the file is stored
  public var dir: String? {
    get {
      guard let sd = subdir else { return nil }
      return Database.appDir + "/" + sd
    }
    set (str) {
      guard let d = str else { return }
      subdir = String(d.dropFirst(Database.appDir.count + 1))
    }
  }
  /// Pathname of file (absolute path)
  public var path: String? {
    get {
      guard let d = dir else { return nil }
      return d + "/" + name
    }
    set {
      guard let fn = newValue else { return }
      let file = File(fn)
      dir = file.dirname
      name = file.basename
    }
  }
  public var storageType: FileStorageType {
    get { FileStorageType(pr.storageType!)! }
    set { pr.storageType = newValue.rawValue }
  }
  public var moTime: Date {
    ///optional unwrap fixed crash occoured everytime on open an issue which had corupt data
    ///Crash Count in Debug: 2
    ///last Time: Logout, open PDF, (was not loaded, App data was loaded)
    //    get { pr.moTime ?? Date(timeIntervalSince1970: 0) }
    get { pr.moTime! }
    set { pr.moTime = newValue }
  }
  public var size: Int64 {
    get { pr.size }
    set { pr.size = newValue }
  }
  public var storedSize: Int64 {
    get {
      if let p = path, pr.storedSize <= 0 {
        let file = File(p)
        if file.exists { pr.storedSize = file.size }
      }
      return pr.storedSize
    }
    set { pr.storedSize = newValue }
  }
  public var sha256: String {
    get { pr.sha256! }
    set { pr.sha256 = newValue }
  }
  public var payloads: [StoredPayload] {
    var pls: [StoredPayload] = []
    for plpr in pr.payloads! {
      pls += StoredPayload(persistent: plpr as! PersistentPayload)
    }
    return pls
  }
  public var image: StoredImageEntry? {
    if let img = pr.image { return StoredImageEntry(persistent: img) }
    else { return nil }
  }
  
  public required init(persistent: PersistentFileEntry) { self.pr = persistent }
  
  /// Initialize from existing file
  public static func new(path: String, storageType: FileStorageType = .issue) -> Self? {
    var ret: Self? = nil
    let file = File(path)
    if file.exists {
      let fe = Self.new()
      fe.path = path
      fe.moTime = file.mTime
      fe.storageType = storageType
      fe.size = file.size
      fe.storedSize = fe.size
      fe.sha256 = file.sha256
      ret = fe
    }
    return ret
  }
  
  /// Overwrite the persistent values
  public func update(from: FileEntry) {
    pr.name = from.name
    pr.storageType = from.storageType.representation
    pr.moTime = from.moTime
    pr.size = from.size
    pr.sha256 = from.sha256
  }
  
  /// Return stored record with given name
  public static func get(name: String) -> [StoredFileEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "name = %@", name)
    return get(request: request)
  }
  
  /// Return stored record with given SHA256
  public static func get(sha256: String) -> [StoredFileEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "sha256 = %@", sha256)
    return get(request: request)
  }
  
  /// Return stored record that matches the SHA256 of the passed object
  public static func get(object: FileEntry) -> StoredFileEntry? {
    let res = get(name: object.name)
    if res.count > 0 { return res[0] }
    else { return nil }
  }
  
  /// Return all records of a payload
  public static func filesInPayload(payload: StoredPayload) -> [StoredFileEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "%@ IN payloads", payload.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
  /// Return all animation files of a Moment
  public static func animationInMoment(moment: StoredMoment) -> [StoredFileEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "momentAnimated = %@", moment.pr)
    return get(request: request)
  }
  
} // StoredFileEntry

extension PersistentImageEntry: PersistentObject {}

/// A stored ImageEntry
public final class StoredImageEntry: ImageEntry, StoredObject {
  
  public static var entity = "ImageEntry"
  public var pr: PersistentImageEntry // persistent record
  public var pf: PersistentFileEntry!
  public var name: String { pf.name! }
  public var path: String? { StoredFileEntry(persistent: pf).path }
  public var storageType: FileStorageType { FileStorageType(pf.storageType!)! }
  public var moTime: Date { pf.moTime! }
  public var size: Int64 { pf.size }
  public var sha256: String { pf.sha256! }
  public var resolution: ImageResolution { ImageResolution(pr.resolution!)! }
  public var type: ImageType { ImageType(pr.type!)! }
  public var alpha: Float? { pr.alpha }
  public var sharable: Bool { pr.sharable }
  public var author: StoredAuthor? {
    if let au = pr.author { return StoredAuthor(persistent: au) }
    else { return nil }
  }
  public var moment: StoredMoment? {
    (pr.moment != nil) ? StoredMoment(persistent: pr.moment!) : nil
  }
  
  public required init(persistent: PersistentImageEntry) {
    self.pr = persistent
    if let pf = persistent.file { self.pf = pf }
  }
  
  /// Initialize with image in existing file
  public static func new(path: String, resolution: ImageResolution = .normal,
                         type: ImageType = .facsimile,
                         storageType: FileStorageType = .issue) -> StoredImageEntry? {
    if let fe = StoredFileEntry.new(path: path, storageType: storageType) {
      let ie = StoredImageEntry.new()
      ie.pf = fe.pr
      ie.pr.file = ie.pf
      ie.pr.resolution = resolution.rawValue
      ie.pr.type = "facsimile"
      ie.pr.alpha = 1.0
      ie.pr.sharable = true
      return ie
    }
    return nil
  }
  
  /// Overwrite the persistent values
  public func update(from: ImageEntry) {
    var file: StoredFileEntry
    if pf == nil { file = StoredFileEntry.get(object: from) ?? StoredFileEntry.new() }
    else { file = StoredFileEntry(persistent: pf) }
    file.update(from: from)
    pf = file.pr
    pr.resolution = from.resolution.rawValue
    pr.type = from.type.rawValue
    pr.alpha = from.alpha ?? 1.0
    pr.sharable = from.sharable
    pr.file = pf
    pf.image = pr
  }
  
  /// Return stored record with given name
  public static func get(name: String) -> [StoredImageEntry] {
    let files = StoredFileEntry.get(name: name)
    if files.count > 0 {
      if let img = files[0].image {
        return [img]
      }
      else {
        let sr = new()
        ///changed to fix 'Author Image CoreData validation crash' @see: TODO.md
        ///alternative: 'return []'
        sr.pr.file = files[0].pr
        return [sr]
      }
    }
    return []
  }
  
  /// Return stored record with given SHA256
  public static func get(sha256: String) -> [StoredImageEntry] {
    let files = StoredFileEntry.get(sha256: sha256)
    if files.count > 0 {
      if let img = files[0].image {
        return [img]
      }
    }
    return []
  }
  
  /// Return stored record that matches the name of the passed object
  public static func get(object: ImageEntry) -> StoredImageEntry? {
    let res = get(name: object.name)
    if res.count > 0 { return res[0] }
    else { return nil }
  }
  
  /// Return all images of a Moment
  public static func imagesInMoment(moment: StoredMoment) -> [StoredImageEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "moment = %@", moment.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
  /// Return all images of an Article
  public static func imagesInArticle(article: StoredArticle) -> [StoredImageEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "%@ IN imageContent", article.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
  /// Return all images of a Section
  public static func imagesInSection(section: StoredSection) -> [StoredImageEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "%@ IN imageContent", section.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
  /// Return all credited images of a Moment
  public static func creditedImagesInMoment(moment: StoredMoment) -> [StoredImageEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "momentCredit = %@", moment.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
} // StoredImageEntry

extension PersistentMoment: PersistentObject {}

/// A stored Moment image
public final class StoredMoment: Moment, StoredObject {
  
  public static var entity = "Moment"
  public var pr: PersistentMoment // persistent record
  public var data: Data? {
    get { pr.data }
    set { pr.data = newValue }
  }
  public var image: UIImage? { (data == nil) ? nil : UIImage(data: data!) }
  public var images: [ImageEntry] { StoredImageEntry.imagesInMoment(moment: self) }
  public var creditedImages: [ImageEntry]
  { StoredImageEntry.creditedImagesInMoment(moment: self) }
  public var animation: [FileEntry] { StoredFileEntry.animationInMoment(moment: self) }
  public var firstPage: StoredPage? {
    get {
      guard let pg = pr.firstPage else { return nil }
      return StoredPage(persistent: pg)
    }
    set {
      guard let spg = newValue else { return }
      pr.firstPage = spg.pr
      pr.firstPage?.moment = pr
    }
  }
  
  public var issue: StoredIssue? {
    get {
      guard let pIssue = pr.issue else { return nil }
      return StoredIssue(persistent: pIssue)
    }
    set {
      guard let sIssue = newValue else { return }
      pr.issue = sIssue.pr
      pr.issue?.moment = pr
    }
  }
  
  public var facsimile: ImageEntry? { firstPage?.facsimile }
  
  public required init(persistent: PersistentMoment) {
    self.pr = persistent
  }
  
  /// Overwrite the persistent values
  public func update(from: Moment) {
    if let new = from as? StoredMoment { data = new.data }
    // Add new images
    for img in from.images {
      let se = StoredImageEntry.persist(object: img)
      se.pr.moment = pr
      pr.addToImages(se.pr)
    }
    // Remove unneeded images
    for img in images as! [StoredImageEntry] {
      if !from.images.contains(where: { $0.name == img.name }) {
        pr.removeFromImages(img.pr)
      }
    }
    // Add new credited images
    for img in from.creditedImages {
      let se = StoredImageEntry.persist(object: img)
      se.pr.momentCredit = pr
      pr.addToCreditedImages(se.pr)
    }
    // Remove unneeded credited images
    for img in creditedImages as! [StoredImageEntry] {
      if !from.creditedImages.contains(where: { $0.name == img.name }) {
        pr.removeFromCreditedImages(img.pr)
      }
    }
    // Add new animation files
    for f in from.animation {
      let fe = StoredFileEntry.persist(object: f)
      fe.pr.momentAnimated = pr
      pr.addToAnimation(fe.pr)
    }
    // Remove unneeded animation files
    for file in animation as! [StoredFileEntry] {
      if !from.animation.contains(where: { $0.name == file.name }) {
        pr.removeFromAnimation(file.pr)
      }
    }
  } // update
  
  /// Return stored record that matches the name of the passed object
  public static func get(object: Moment) -> StoredMoment? {
    let imgs = object.images
    if imgs.count > 0, let img = StoredImageEntry.get(object: imgs[0]) {
      return img.moment
    }
    else { return nil }
  }
  
  /// Read Image data from file and store it in persistent record
  public func storeData(from file: String) {
    self.data = File(file).data
  }
  
} // Stored Moment

extension PersistentPayload: PersistentObject {}

/// A stored Payload
public final class StoredPayload: StoredObject, Payload {
  
  public static var entity = "Payload"
  public var pr: PersistentPayload // persistent record
  public var bytesLoaded: Int64 {
    get { return pr.bytesLoaded }
    set { pr.bytesLoaded = newValue }
  }
  public var bytesTotal: Int64 {
    get { return pr.bytesTotal }
    set { pr.bytesTotal = newValue }
  }
  public var downloadStarted: Date? {
    get { return pr.downloadStarted }
    set { pr.downloadStarted = newValue }
  }
  public var downloadStopped: Date? {
    get { return pr.downloadStopped }
    set { pr.downloadStopped = newValue }
  }
  /// Relative path to destination directory
  public var subdir: String {
    get { return pr.localDir! }
    set { pr.localDir = newValue }
  }
  /// Absolute path to destination directory
  public var localDir: String {
    get { "\(Database.appDir)/\(subdir)" }
    set (ldir) {
      subdir = String(ldir.dropFirst(Database.appDir.count + 1))
    }
  }
  public var remoteBaseUrl: String {
    get { return pr.remoteBaseUrl! }
    set { pr.remoteBaseUrl = newValue }
  }
  public var remoteZipName: String? {
    get { return pr.remoteZipName }
    set { pr.remoteZipName = newValue }
  }
  public var issue: Issue? {
    if let pissue = pr.issue { return StoredIssue(persistent: pissue) }
    else { return nil }
  }
  public var resources: Resources? {
    if let pres = pr.resources { return StoredResources(persistent: pres) }
    else { return nil }
  }
  
  public lazy var storedFiles: [StoredFileEntry] = {
    var fls: [StoredFileEntry] = []
    if let files = pr.files {
      for f in files {
        fls += StoredFileEntry(persistent: f as! PersistentFileEntry)
      }
    }
    return fls
  }()

  func updateGlobalFiles(subdir: String) {
    for case let pfe as PersistentFileEntry in pr.files ?? [] {
      guard pfe.isGlobal else { continue }
      pfe.subdir = subdir
    }
  }
  
  public var files: [FileEntry] { return storedFiles }
  
  public required init(persistent: PersistentPayload) { self.pr = persistent }
  
  func delete() {
    // Delete file entries that don't belong to another payload
    for f in storedFiles {
      if f.payloads.count == 1 { f.delete() }
    }
    self.deletePersistent()
  }
  
  public func update(from: Payload) {
    var bytesTotal: Int64 = 0
    var bytesLoaded: Int64 = 0
    var order: Int64 = 0
    self.localDir = from.localDir
    for f in from.files {
      let fe = StoredFileEntry.persist(object: f)
      fe.pr.order = order
      fe.pr.addToPayloads(pr)
      ///Warning: this is maybe wrong for f.storageType == .global //!.issue
      ///seen after bg zip download; problem in file delete
      ///solved in StoredIssue.update(from issue..) with storedPayload.updateGlobalFiles(subdir: globalsSubPath)
      fe.pr.subdir = subdir
      order += 1
      pr.addToFiles(fe.pr)
      bytesTotal += f.size
      bytesLoaded += fe.storedSize
    }
    // Delete unneeded files
    var toDelete: [StoredFileEntry] = []
    for file in files as! [StoredFileEntry] {
      if !from.files.contains(where: { $0.name == file.name }) {
        pr.removeFromFiles(file.pr)
        file.pr.removeFromPayloads(pr)
        toDelete += file
      }
    }
    for f in toDelete {
      if f.payloads.count == 1 { f.delete() }
    }
    self.bytesTotal = bytesTotal
    self.bytesLoaded = 0
    self.remoteBaseUrl = from.remoteBaseUrl
    self.remoteZipName = from.remoteZipName
  }
  
  public static func get(object: Payload) -> StoredPayload? {
    if let issue = object.issue {
      return StoredIssue.get(object: issue)?.storedPayload
    }
    if let res = object.resources {
      return StoredResources.get(object: res)?.storedPayload
    }
    return nil
  }
  
} // StoredPayload

extension PersistentResources: PersistentObject {}


/// A stored list of resource files
public final class BundledResources : DoesLog {
  lazy var bundledFiles : [URL] = {
    return Bundle.main.urls(forResourcesWithExtension: "", subdirectory: "files")
  }() ?? []
  
  //  lazy var bundledFilesDir : String? = {
  //    return Bundle.main.resourceURL?.appendingPathComponent("files").absoluteString
  //  }()...finally unused
  
  lazy var resourcesPayload : Result<[String:GqlResources],Error> = {
    guard let resourcesJsonFileUrl
            = Bundle.main.url(forResource: "resources",
                              withExtension: "json") else {
      return .failure(self.fatal("Bundled resources.json Not found"))
    }
    let bundledResources = File(resourcesJsonFileUrl)
    
    if bundledResources.exists == false {
      return .failure(self.fatal("Bundled resources.json File Not exist!"))
    }
    
    do {
      let dec = JSONDecoder()
      
      //        self.debug("Try to decode: \"\(String(decoding: bundledResources.data, as: UTF8.self)[0..<2000])\"")
      
      let dict = try dec.decode([String:[String:GqlResources]].self,
                                from: bundledResources.data)
      guard let data = dict["data"] else {
        return .failure(self.fatal("No data in resources.json"))
      }
      return .success(data)
    }
    catch let error {
      return .failure(self.fatal("JSON decoding error: \(error)"))
    }
  }()
}

/// A stored list of resource files
public final class StoredResources: Resources, StoredObject {
  
  public static var entity = "Resources"
  public var pr: PersistentResources // persistent record
  public var storedPayload: StoredPayload? {
    if let ppl = pr.payload { return StoredPayload(persistent: ppl) }
    else { return nil }
  }
  public var payload: Payload { storedPayload! }
  public var resourceBaseUrl: String { payload.remoteBaseUrl }
  public var resourceZipName: String { payload.remoteZipName! }
  public var resourceVersion: Int {
    get { return Int(pr.resourceVersion) }
    set { pr.resourceVersion = Int32(newValue) }
  }
  public var localDir: String { payload.localDir }
  public var resourceFiles: [FileEntry] { payload.files }
  public var isDownloading: Bool = false
  public var isComplete: Bool {
    get { return payload.isComplete }
    set {}
  }
  
  public required init(persistent: PersistentResources) { self.pr = persistent }
  
  /// Return stored record with given resourceVersion
  public static func get(version: Int) -> [StoredResources] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "resourceVersion = %d", version)
    return get(request: request)
  }
  
  /// Return stored record with latest (largest) resourceVersion
  public static func latest() -> StoredResources? {
    let request = fetchRequest
    request.fetchLimit = 1
    request.sortDescriptors = [
      NSSortDescriptor(key: "resourceVersion", ascending: false)
    ]
    let res = get(request: request)
    if res.count > 0 { return res[0] }
    else { return nil }
  }
  
  public func update(from: Resources) {
    pr.payload = StoredPayload.persist(object: from.payload).pr
    pr.payload?.resources = pr
    resourceVersion = from.resourceVersion
  }
  
  /// Return Resources matching the resource version of the passed object
  public static func get(object: Resources) -> StoredResources? {
    let tmp = get(version: object.resourceVersion)
    if tmp.count > 0 { return tmp[0] }
    else { return nil }
  }
  
} // StoredResources

extension PersistentAudio: PersistentObject {}

/// A stored Author
public final class StoredAudio: Audio, StoredObject {
  public static var entity = "Audio"
  public var pr: PersistentAudio // persistent record
  
  public var file: FileEntry? {
    get {
      guard let file = pr.file else { return nil }
      return StoredFileEntry(persistent: file) }
    set {
      if let fe = newValue {
        pr.file = StoredFileEntry.persist(object: fe).pr
        pr.file?.audio = pr
      }
      else { pr.file = nil }
    }
  }
  
  public var duration: Float?{
    get { return pr.duration }
    set { pr.duration = newValue ?? 0.0 }
  }
  
  public var speaker: AudioSpeaker? {
    get {
      guard let s = pr.speaker else { return nil }
      return AudioSpeaker(s)
    }
    set {
      pr.speaker = newValue?.rawValue
    }
  }
  
  public var breaks: [Float]?{
    get { return pr.breaks as? [Float] }
    set { pr.breaks = newValue as NSArray? }
  }
  
  public var content: [Content]?{
    var ret:[Content] = []
    for pArticle in pr.content?.allObjects as? [PersistentArticle] ?? [] {
      ret.append(StoredArticle(persistent: pArticle))
    }
    for pSection in pr.content?.allObjects as? [PersistentSection] ?? [] {
      ret.append(StoredSection(persistent: pSection))
    }
    return ret
  }
  
  public var page: [Page]?{
    var ret:[Page] = []
    for pPage in pr.page?.allObjects as? [PersistentPage] ?? [] {
      ret.append(StoredPage(persistent: pPage))
    }
    return ret
  }
  
  public required init(persistent: PersistentAudio) {
    self.pr = persistent
  }
  
  /// Overwrite the persistent values
  public func update(from object: Audio) {
    self.file = object.file
    self.duration = object.duration
    self.speaker = object.speaker
    self.breaks = object.breaks
  }
  
  /// Return stored record with given name
  public static func get(file: String) -> [StoredAudio] {
    let request = fetchRequest
    #warning("Test if relation correct")
    request.predicate = NSPredicate(format: "file.name = %@", file)
    return get(request: request)
  }
  
  public static func get(object: Audio) -> StoredAudio? {
    guard let audioFileName = object.file?.name else { return nil }
    let tmp = get(file: audioFileName)
    if tmp.count > 0 { return tmp[0] }
    else { return nil }
  }
  
} // StoredAudio


extension PersistentAuthor: PersistentObject {}

/// A stored Author
public final class StoredAuthor: Author, StoredObject {
  
  public static var entity = "Author"
  public var pr: PersistentAuthor // persistent record
  public var name: String? { pr.name }
  
  public var serverId: Int? {
    get { return pr.serverId != 0 ? Int(pr.serverId) : nil }
    set {
      if let id = newValue {
        pr.serverId = Int64(id)
      }
      else { pr.serverId = 0 }
    }
  }
  
  public var photo: ImageEntry? {
    if let p = pr.photo { return StoredImageEntry(persistent: p) }
    else { return nil }
  }
  
  public required init(persistent: PersistentAuthor) { self.pr = persistent }
  
  /// Overwrite the persistent values
  public func update(from object: Author) {
    pr.name = object.name
    self.serverId = object.serverId
    if let photo = object.photo {
      let imageEntry = StoredImageEntry.persist(object: photo)
      pr.photo = imageEntry.pr
      imageEntry.pr.author = pr
    }
    else { pr.photo = nil }
  }
  
  /// Return stored record with given name
  public static func get(name: String) -> [StoredAuthor] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "name = %@", name)
    return get(request: request)
  }
  
  /// Return stored record with given photo
  public static func get(photo: ImageEntry) -> [StoredAuthor] {
    let imgs = StoredImageEntry.get(name: photo.name)
    if imgs.count > 0 {
      if let au = imgs[0].author {
        return [au]
      }
    }
    return []
  }
  
  public static func get(object: Author) -> StoredAuthor? {
    var tmp: [StoredAuthor] = []
    if let name = object.name { tmp = get(name: name) }
    if tmp.count == 0, let photo = object.photo { tmp = get(photo: photo) }
    if tmp.count < 1 { return nil }
    else { return tmp[0] }
  }
} // StoredAuthor

/// also: PersistentSection, PersistentArticle
extension PersistentContent: PersistentObject {
  public override func prepareForDeletion() {
    super.prepareForDeletion()
    ///Do not itterate over org set while changing it; this causes errors!
    let imagesCopy = (self.images as? Set<PersistentImageEntry>) ?? []
    for img in imagesCopy {
      img.removeFromImageContent(self)
      if (img.imageContent?.count ?? 0) == 0 { img.delete() }
    }
    let iconsCopy = (self.icons as? Set<PersistentImageEntry>) ?? []
    for img in iconsCopy {
      img.removeFromIconContent(self)
      if (img.imageContent?.count ?? 0) == 0 { img.delete() }
    }
    if audioItem?.file?.name?.contains("bundestalk") == true {
      #warning("ToDo 1.6.0: Bundestalk is not deleted at the last reference, but  during a later cleanup-folders!")
      ///Maybe this is the better behavior for users who manually delete issues after read,
      ///then bundestalk maybe will be downloaded multiple times
      ///Solution: Check if related issue is older than 10 days && RefCount is 0 => DELETE
      debug("Try to Delete AutioItem \(audioItem?.file?.name ?? "-") in \(self.title ?? "-") with Reference count \(audioItem?.referencesCount ?? 0)")
    }
    if audioItem?.referencesCount ?? 0 <= 1 {///Section or Article
      debug("Delete AutioItem \(audioItem?.file?.name ?? "-") due last Reference")
      audioItem?.delete()
    }
    else {
      debug("do not Delete AutioItem Reference count \(audioItem?.referencesCount ?? 0)")
    }
  }
}

extension PersistentSection {
  public override func prepareForDeletion() {
    super.prepareForDeletion()
    ///Do not itterate over org set while changing it; this causes errors!
    let articlesCopy = (self.articles as? Set<PersistentArticle>) ?? []
    for art in articlesCopy {
        art.removeFromSections(self)
      if (art.sections?.count ?? 0) == 0 { art.delete() }
      /// else if art.sectionTitle == nil {  art.sectionTitle = self.title }
      /// NOTE: Accessing `self.title` here does not work.
      /// By the time `prepareForDeletion()` runs, Core Data has already marked
      /// this object as deleted and may have invalidated or cleared simple properties.
      /// As a result, values like `title` can already be nil.
    }
  }
}

extension PersistentArticle {
  public override func prepareForDeletion() {
    super.prepareForDeletion()
//    debug("Try to Delete Article: \(title ?? "-") HTML Filename: \(self.html?.name ?? "-")")
    ///array is still a copy so we can itterate directly over it
    for author in (self.authors?.array as? [PersistentAuthor]) ?? [] {
      author.removeFromArticles(self)
      if (author.articles?.count ?? 0) == 0 {
        author.delete()
      }
    }
  }
}

extension PersistentPage: PersistentObject {
  public override func prepareForDeletion() {
    super.prepareForDeletion()
    if audioItem?.file?.name?.contains("bundestalk") == true {
      debug("Try to Delete AutioItem \(audioItem?.file?.name ?? "-") in \(self.title ?? "-") with Reference count \(audioItem?.referencesCount ?? 0)")
    }
    if audioItem?.referencesCount ?? 0 <= 1 {
      debug("Delete AutioItem \(audioItem?.file?.name ?? "-") due last Reference")
      audioItem?.delete()
    }
    else {
      debug("do not Delete AutioItem Reference count \(audioItem?.referencesCount ?? 0)")
    }
  }
}

extension PersistentAudio {
  var referencesCount:Int {
    return content?.count ?? 0 + (page?.count ?? 0)
  }
}

/// A stored Article
public final class StoredArticle: Article, StoredObject {
  public static var entity = "Article"
  public var pr: PersistentArticle // persistent record
  public var audioItem: Audio? {
    get {
      guard let audio = pr.audioItem else { return nil }
      return StoredAudio(persistent: audio)
    }
    set {
      guard let newValue = newValue else {
        pr.audioItem = nil
        return
      }
      pr.audioItem = StoredAudio.persist(object: newValue).pr
      pr.audioItem?.addToContent(self.pr)
    }
  }
  
  public var baseURL: String? {
    /// When downloading missing files, it's possible that the issue is still in demo/preview mode while 
    /// the bookmarked article have already been updated.
    /// Therefore, prioritize the persisted and updated base URL, 
    /// particularly in ContentVC's `setContents()`... `contents.map`
    /// Former: the base URL from the issues was used as default, since this field is not populated in the mapping
    get { return pr.baseURL?.length ?? 0 > 10 ? pr.baseURL ?? primaryIssue?.baseUrl : primaryIssue?.baseUrl }
    set { pr.baseURL = newValue }
  }
  
  public var text: String? {
    get { return pr.text }
    set { pr.text = newValue }
  }
  public var title: String? {
    get { return pr.title }
    set { pr.title = newValue }
  }

  public var bookmarkedDate: Date? {
    get { return pr.bookmarkedDate }
    set { pr.bookmarkedDate = newValue }
  }
  
  public var html: FileEntry? {
    get {
      guard let html = pr.html else { return nil }
      return StoredFileEntry(persistent: html) }
    set {
      guard let newValue = newValue else {
        pr.html = nil
        return
      }
      pr.html = StoredFileEntry.persist(object: newValue).pr
      pr.html!.content = pr
    }
  }
  public var pdf: FileEntry? {
    get {
      guard let pdf = pr.pdf else { return nil }
      return StoredFileEntry(persistent: pdf) }
    set {
      guard let newValue = newValue else {
        pr.pdf = nil
        return
      }
      pr.pdf = StoredFileEntry.persist(object: newValue).pr
      pr.pdf!.article = pr
    }
  }
  public var lastArticlePosition: Int {
    get { return Int(pr.lastArticlePosition) }
    set { pr.lastArticlePosition = Int64(newValue) }
  }
  public var onlineLink: String? {
    get { return pr.onlineLink }
    set { pr.onlineLink = newValue }
  }
  public var articleType: ArticleType? {
    get {
      guard let type = pr.articleType else { return nil }
      return ArticleType(type)
    }
    set {
      pr.articleType = newValue?.rawValue
    }
  }
  public var teaser: String? {
    get { return pr.teaser }
    set { pr.teaser = newValue }
  }
  
  public var serverId: Int64? {
      get { pr.serverId != 0 ? pr.serverId : nil }
      set { pr.serverId = newValue ?? 0 }
  }
  public var contentId: Int64? {
    get { pr.contentId != 0 ? pr.contentId : nil }
    set { pr.contentId = newValue ?? 0 }
  }
  public var readingDuration: Int? {
    get { return pr.readingDuration != 0 ? Int(pr.readingDuration) : nil }
    set {
      if let id = newValue {
        pr.readingDuration = Int64(id)
      }
      else { pr.readingDuration = 0 }
    }
  }
  
  public var icons: [ImageEntry]? {
      guard let icons = pr.icons else { return nil }
      return icons.compactMap {
          guard let persistent = $0 as? PersistentImageEntry else { return nil }
          return StoredImageEntry(persistent: persistent)
      }
  }

  public var images: [ImageEntry]? { StoredImageEntry.imagesInArticle(article: self) }
  public var authors: [Author]? {
    return (pr.authors?.array as? [PersistentAuthor])?
      .map{StoredAuthor(persistent: $0)}
  }
  public var pageNames: [String]? {
    get { return pr.pageNames as? [String] }
    set { pr.pageNames = newValue as? NSArray }
  }
  
  public var nonBookmarkSections: [StoredSection] {
    var ret: [StoredSection] = []
    for case let s as PersistentSection in pr.sections ?? [] {
      if s.issue?.isBookmarkIssue == true { continue }
      ret += StoredSection(persistent: s)
    }
    return ret
  }
  
  public var issues: [StoredIssue] {
    var ret: [StoredIssue] = []
    if let issues = pr.issues {
      for issue in issues {
        if let issue = issue as? PersistentIssue {
          ret += StoredIssue(persistent: issue)
        }
      }
    }
    return ret
  }
  /// the primary Issue is assumed to be the first none Bookmark Issue stored
  /// if there is only the bookmark issue, primary issue is nil
  /// Former: -For now the primary Issue is assumed to be the first one stored-
  public var primaryIssue: Issue? {
    for issue in issues {
      if issue.isBookmarkIssue == false { return issue }
    }
    return nil
  }
  
  public var dir: Dir {
    guard let sdir = (html as? StoredFileEntry)?.dir
    else { fatalError("FileEntry.dir is undefined") }
    return Dir(sdir)
  }
  
  public var path: String {
    guard let path = (html as? StoredFileEntry)?.path
    else { fatalError("FileEntry.path is undefined") }
    return path
  }
  
  public var issueDate: Date? {
    pr.issueDate ?? primaryIssue?.date
  }
  
  public var sectionTitle: String? {
    get {
      if let s = pr.sectionTitle { return s }
      for s in nonBookmarkSections {
        if let t = s.title { return t }
      }
      return nil
    }
    set { pr.sectionTitle = newValue }
  }
  
  public required init(persistent: PersistentArticle) { self.pr = persistent }
  
  /// Overwrite the persistent values
  public func update(from object: Article) {
    if let sobject = object as? StoredArticle {
      self.text = sobject.text
      self.lastArticlePosition = sobject.lastArticlePosition
    }
    self.title = object.title
    self.html = object.html
    self.pdf = object.pdf
    self.audioItem = object.audioItem
    self.onlineLink = object.onlineLink
    self.articleType = object.articleType
    self.pageNames = object.pageNames
    self.teaser = object.teaser
    self.serverId = object.serverId
    self.contentId = object.contentId
    self.readingDuration = object.readingDuration
    if let imgs = object.images {
      var order: Int32 = 0
      for img in imgs {
        let imageEntry = StoredImageEntry.persist(object: img)
        imageEntry.pr.addToImageContent(pr)
        imageEntry.pr.order = order
        /// duplicate of: imageEntry.pr.addToImageContent(pr)
        /// only set one relation is required the other will be established automatically
        /// pr.addToImages(imageEntry.pr)
        order += 1
      }
      // Remove unneeded images
      for img in images as! [StoredImageEntry] {
        if !imgs.contains(where: { $0.name == img.name }) {
          pr.removeFromImages(img.pr)
        }
      }
    }
    else { pr.images = nil }
    ///Icons
    if let _icons = object.icons {
      var order: Int32 = 0
      for ico in _icons {
        let icoEntry = StoredImageEntry.persist(object: ico)
        icoEntry.pr.addToIconContent(pr)
        icoEntry.pr.order = order
        order += 1
      }
      // Remove unneeded images
      for ico in icons as! [StoredImageEntry] {
        if !_icons.contains(where: { $0.name == ico.name }) {
          pr.removeFromImages(ico.pr)
        }
      }
    }
    else { pr.icons = nil }
    if let aus = object.authors {
      for au in aus {
        let sau = StoredAuthor.persist(object: au)
        sau.pr.addToArticles(pr)
        pr.addToAuthors(sau.pr)
      }
      // Remove unneeded authors
      for au in authors as? [StoredAuthor] ?? [] {
        if !aus.contains(where: { $0.name == au.name }) {
          pr.removeFromAuthors(au.pr)
        }
      }
    }
    else { pr.authors = nil }
  }
  
  /// Return stored record with given name
  public static func get(file: String) -> [StoredArticle] {
    let request = fetchRequest
    let fileNameWithoutExtension = file.replacingOccurrences(of: ".html", with: "")
    let publicFileName = "\(fileNameWithoutExtension).public.html"
    let nonPublicFileName = "\(fileNameWithoutExtension).html"
    request.predicate = NSPredicate(format: "html.name IN %@", [publicFileName, nonPublicFileName])
    return get(request: request)
  }
  
  public static func get(byMediaSyncId mediaSyncId: Int64) -> StoredArticle? {
      let request = fetchRequest
      request.predicate = NSPredicate(format: "serverId == %lld", mediaSyncId)
    return get(request: request).first
  }
  
  public static func get(object: Article) -> StoredArticle? {
    guard let name =  object.html?.name else { return nil }
    let tmp = get(file:name)
    if tmp.count > 0 { return tmp[0] }
    else { return nil }
  }
  
  /// Return all Articles in a Section
  public static func articlesInSection(section: StoredSection) -> [StoredArticle] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "%@ IN sections", section.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  

/// **currently unused!**
//  /// Return all Articles in an Issue
//  public static func articlesInIssue(issue: StoredIssue) -> [StoredArticle] {
//    let request = fetchRequest
//    request.predicate = NSPredicate(format: "%@ IN issues", issue.pr)
//    request.sortDescriptors = [
//      NSSortDescriptor(key: "order", ascending: true)
//    ]
//    return get(request: request)
//  }
} // StoredArticle

extension PersistentFrame: PersistentObject {}

/// A stored Frame
public final class StoredFrame: Frame, StoredObject {
  
  @discardableResult
  public static func persist(object: Frame, relatedPage: StoredPage) -> StoredFrame {
    var storedRecord: StoredFrame
    if let tmp = get(object: object, relatedPage: relatedPage) { storedRecord = tmp }
    else { storedRecord = new() }
    storedRecord.update(from: object)
    return storedRecord
  }
  
  public static var entity = "Frame"
  public var pr: PersistentFrame // persistent record
  public var link: String? {
    get { return pr.link }
    set { pr.link = newValue }
  }
  public var x1: Float {
    get { return pr.x1 }
    set { pr.x1 = newValue }
  }
  public var x2: Float {
    get { return pr.x2 }
    set { pr.x2 = newValue }
  }
  public var y1: Float {
    get { return pr.y1 }
    set { pr.y1 = newValue }
  }
  public var y2: Float {
    get { return pr.y2 }
    set { pr.y2 = newValue }
  }
  
  public required init(persistent: PersistentFrame) { self.pr = persistent }
  
  public static func get(object: Frame) -> Self? {
    let epsilon: Float = 0.0001
    let request = fetchRequest
    let p1 = NSPredicate(format: "abs(x1 - %f) < %f", object.x1, epsilon)
    let p2 = NSPredicate(format: "abs(x2 - %f) < %f", object.x2, epsilon)
    let p3 = NSPredicate(format: "abs(y1 - %f) < %f", object.y1, epsilon)
    let p4 = NSPredicate(format: "abs(y2 - %f) < %f", object.y2, epsilon)
    request.predicate = NSCompoundPredicate(type: .and,
                                            subpredicates: [p1, p2, p3, p4])
    let res = get(request: request)
    if res.count > 0 { return res[0] }
    return nil
  }
  
  public static func get(object: Frame, relatedPage: StoredPage) -> StoredFrame? {
    
    let epsilon: Float = 0.0001
    
    for storedFrame in relatedPage.frames ?? [] {
      if abs(storedFrame.x1 - object.x1) > epsilon { continue }
      if abs(storedFrame.x2 - object.x2) > epsilon { continue }
      if abs(storedFrame.y1 - object.y1) > epsilon { continue }
      if abs(storedFrame.y2 - object.y2) > epsilon { continue }
      if (storedFrame as? StoredFrame)?.pr.page != relatedPage.pr {
        Log.log("Warning unexpected found frame on another page")
        continue
      }
      return storedFrame as? StoredFrame
    }
    return nil
  }
  
  /// Overwrite the persistent values
  public func update(from object: Frame) {
    self.link = object.link
    self.x1 = object.x1
    self.x2 = object.x2
    self.y1 = object.y1
    self.y2 = object.y2
  }
  
  /// Return all Frames in a Page
  public static func framesInPage(page: StoredPage) -> [StoredFrame] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "page = %@", page.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
} // StoredFrame

/// A stored Page
public final class StoredPage: Page, StoredObject {
  
  public static var entity = "Page"
  public var pr: PersistentPage // persistent record
  public var title: String? {
    get { return pr.title }
    set { pr.title = newValue }
  }
  public var pagina: String? {
    get { return pr.pagina }
    set { pr.pagina = newValue }
  }
  public var pdf: FileEntry? {
    ///Debug Crash nil while unwrapping optional!
    ///no solution: return StoredFileEntry.new() ...crash on next place
    get {
      guard let pdf = pr.pdf else { return nil }
      return StoredFileEntry(persistent: pdf) }
    set {
      if let old = pr.pdf, old.name != newValue?.name { old.delete() }
      guard let newValue = newValue else { return }
      let persistedRecord = StoredFileEntry.persist(object: newValue).pr
      pr.pdf = persistedRecord
      persistedRecord.page = pr
    }
  }
  
  public var facsimile: ImageEntry? {
    get {
      createFacsimile()
      guard let pf = pr.facsimile else { return nil }
      return StoredImageEntry(persistent: pf)
    }
    set {
      if let img = newValue {
        pr.facsimile = StoredImageEntry.persist(object: img).pr
        pr.facsimile!.page = pr
      }
      else { pr.facsimile = nil }
    }
  }
  
  public var audioItem: Audio? {
    get {
      guard let audio = pr.audioItem else { return nil }
      return StoredAudio(persistent: audio)
    }
    set {
      guard let newValue = newValue else {
        pr.audioItem = nil
        #warning("ToDO Check deleted Issue with page if PageToAudio Reference TAble had 1 page:audio entry and after save page:nil")
        return
      }
      pr.audioItem = StoredAudio.persist(object: newValue).pr
      pr.audioItem?.addToPage(self.pr)
    }
  }
  
  public var type: PageType {
    get { return PageType(pr.type ?? "") ?? .unknown }
    set { pr.type = newValue.representation }
  }
  
  public var adIdList: [String]? {
    get { return pr.adIdList as? [String] }
    set { pr.adIdList = newValue as? NSArray }
  }
  
  public var frames: [Frame]? { StoredFrame.framesInPage(page: self) }
  
  public required init(persistent: PersistentPage) { self.pr = persistent }
  
  /// Create facsimile image (if not available)
  private func createFacsimileImage() -> Bool {
    if let pdfPath = StoredFileEntry(persistent: pr.pdf!).path {
      let jpgPath = File.prefname(pdfPath) + ".jpg"
      if File(pdfPath).exists {
        if !File(jpgPath).exists {
          ///ensure facsimile images for home are not bigger than the images from Backend
          ///saved storage before: Image was 700-900KB now: 200-400KB
          let img = UIImage.pdf(File(pdfPath).data, width: 660, useHeight: false)
          img?.save(to: jpgPath)
          return true
        }
        else { return true }
      }
    }
    return false
  }
  
  /// Create facsimile image from pdf, if not already available
  private func createFacsimile() {
    if pr.facsimile == nil,
       createFacsimileImage(),
       let pdfPath = StoredFileEntry(persistent: pr.pdf!).path {
      let jpgPath = File.prefname(pdfPath) + ".jpg"
      if let sie = StoredImageEntry.new(path: jpgPath) {
        pr.facsimile = sie.pr
        pr.facsimile!.page = pr
      }
    }
  }
  
  /// Overwrite the persistent values
  public func update(from object: Page) {
    if !(object is GqlPage) {
      log("Not expecting: \(Swift.type(of:object)) on update Page", logLevel: .Fatal)
    }
    self.title = object.title
    self.pdf = object.pdf
    self.facsimile = object.facsimile
    self.audioItem = object.audioItem
    self.type = object.type
    self.pagina = object.pagina
    self.adIdList = object.adIdList
    self.pr.frames = nil
    var order: Int32 = 0
    if let frames = object.frames {
      if let oldFrames = frames as? [StoredFrame] {
        for f in oldFrames { f.delete() }
      }
      for frame in frames {
        let sf = StoredFrame.persist(object: frame, relatedPage: self)
        sf.pr.page = self.pr
        sf.pr.order = order
        order += 1
        self.pr.addToFrames(sf.pr)
        sf.pr.article = nil
        if let link = sf.link {
          let arts = StoredArticle.get(file: link)
          if arts.count > 0 {
            let art = arts[0]
            sf.pr.article = art.pr
            art.pr.addToFrames(sf.pr)
          }
        }
      }
    }
    //    if let sourceCount = object.frames?.count,
    //       let selfCount = self.frames?.count,
    //       sourceCount != selfCount {
    //      log("Wrong count of Frames saved. Source: \(sourceCount) != \(selfCount) saved.")
    //    }
  }
  
  /// Return stored record with given name
  public static func get(file: String) -> [StoredPage] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "pdf.name = %@", file)
    return get(request: request)
  }
  
  public static func get(object: Page) -> StoredPage? {
    guard let pdfName = object.pdf?.name else { return nil }
    let tmp = get(file: pdfName)
    if tmp.count > 0 { return tmp[0] }
    else { return nil }
  }
  
  /// Return all Pages in an Issue
  public static func pagesInIssue(issue: StoredIssue) -> [StoredPage] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "issue = %@", issue.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
  /// Return first of an Issue
  public static func pageOne(issue: StoredIssue) -> StoredPage? {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "issue = %@", issue.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    request.fetchLimit = 1
    let res = get(request: request)
    if res.count > 0 { return res[0] }
    else { return nil }
  }
  
} // StoredPage

/// A stored Section
public final class StoredSection: Section, StoredObject {
  public static var entity = "Section"
  public var pr: PersistentSection // persistent record
  public var audioItem: Audio? {
    get {
      guard let audio = pr.audioItem else { return nil }
      return StoredAudio(persistent: audio)
    }
    set {
      guard let newValue = newValue else {
        pr.audioItem = nil
        return
      }
      pr.audioItem = StoredAudio.persist(object: newValue).pr
      pr.audioItem?.addToContent(self.pr)
    }
  }
  public var text: String? {
    get { return pr.text }
    set { pr.text = newValue }
  }
  public var name: String {
    get { return pr.name! }
    set { pr.name = newValue }
  }
  public var contentId: Int64? {
    get { pr.contentId != 0 ? pr.contentId : nil }
    set { pr.contentId = newValue ?? 0 }
  }
  public var extendedTitle: String? {
    get { return pr.extendedTitle }
    set { pr.extendedTitle = newValue }
  }
  public var type: SectionType {
    get { return SectionType(pr.type!)! }
    set { pr.type = newValue.representation }
  }
  public var html: FileEntry? {
    get {
      guard let html = pr.html else { return nil }
      return StoredFileEntry(persistent: html)
    }
    set {
      guard let newValue = newValue else {
        pr.html?.delete()
        pr.html = nil
        return
      }
      if pr.html?.name != newValue.name { pr.html?.delete() }
      pr.html = StoredFileEntry.persist(object: newValue).pr
      pr.html?.content = pr
    }
  }
  
  public var navButton: ImageEntry? {
    get {
      if let pbutton = pr.navButton { return StoredImageEntry(persistent: pbutton) }
      else { return nil }
    }
    set {
      if let button = newValue {
        if let old = navButton as? StoredImageEntry, old.name != button.name {
          old.delete()
        }
        pr.navButton = StoredImageEntry.persist(object: button).pr
        pr.navButton?.addToNavSection(pr)
      }
      else { pr.navButton = nil }
    }
  }
  public var primaryIssue: Issue? {
    guard let pIssue = pr.issue else { return nil }
    return StoredIssue(persistent: pIssue)
  }
  
  public var dir: Dir {
    guard let sdir = (html as? StoredFileEntry)?.dir
    else { fatalError("FileEntry.dir is undefined") }
    return Dir(sdir)
  }
  
  public var path: String {
#warning("DoDo 1.0.0 Crash Cnt#: 1")
    guard let path = (html as? StoredFileEntry)?.path
    else { fatalError("FileEntry.path is undefined") }
    ///empty on start see frame in carousell, open issue login ...slider opened, but why?
    return path
  }
  
  public var baseURL: String? {
    /// For backward compatibility and because this field is not filled in the mapping, use the base URL from issues as the default.
    get { return primaryIssue?.baseUrl ?? pr.baseURL }
    set { pr.baseURL = newValue }
  }
  
  public var sectionTitle: String? { return pr.sectionTitle }
  
  public var images: [ImageEntry]? { StoredImageEntry.imagesInSection(section: self) }
  public var authors: [Author]? { nil }
  public var articles: [Article]? {
    var ret: [StoredArticle] = []
    for case let art as PersistentArticle in self.pr.articles ?? [] {
      ret.append(StoredArticle(persistent: art))
    }
    return ret.sorted(by: { $0.pr.order < $1.pr.order })
  }
  
  public required init(persistent: PersistentSection) { self.pr = persistent }
  
  /// Overwrite the persistent values
  public func update(from object: Section) {
    if let sobject = object as? StoredSection {
      self.text = sobject.text
    }
    self.name = object.name
    self.extendedTitle = object.extendedTitle
    self.type = object.type
    self.html = object.html
    self.contentId = object.contentId
    self.audioItem = object.audioItem
    self.navButton = object.navButton
    if let imgs = object.images {
      var order: Int32 = 0
      for img in imgs {
        let imageEntry = StoredImageEntry.persist(object: img)
        imageEntry.pr.addToImageContent(pr)
        imageEntry.pr.order = order
        pr.addToImages(imageEntry.pr)
        order += 1
      }
      // Remove unneeded images
      for img in images as! [StoredImageEntry] {
        if !imgs.contains(where: { $0.name == img.name }) {
          pr.removeFromImages(img.pr)
        }
      }
    }
    else { pr.images = nil }
    if let arts = object.articles {
      var order: Int32 = 0
      for art in arts {
        let newArt = StoredArticle.persist(object: art)
        newArt.pr.addToSections(self.pr)
        newArt.pr.order = order
        pr.addToArticles(newArt.pr)
        order += 1
      }
      // Remove unneeded articles
      for case let art as StoredArticle in articles ?? [] {
        if !arts.contains(where: { $0.html?.name == art.html?.name }) {
          if art.hasBookmark {
            art.pr.removeFromSections(self.pr)
            debug(">>> remove \(art)")
          }
          else {
            debug(">>> deleting \(art)")
            art.delete()
          }
        }
      }
    }
    else { pr.articles = nil }
  }
  
  /// Return stored record with given name
  public static func get(file: String) -> [StoredSection] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "html.name = %@", file)
    return get(request: request)
  }
  
  public static func get(object: Section) -> StoredSection? {
    guard let name = object.html?.name else { return nil }
    let tmp = get(file: name)
    if tmp.count > 0 { return tmp[0] }
    else { return nil }
  }
  
  /// Return all Sections in an Issue
  public static func sectionsInIssue(issue: StoredIssue) -> [StoredSection] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "issue = %@", issue.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
} // StoredSection

extension PersistentPublicationDate: PersistentObject {}

extension StoredPublicationDate: Equatable {
  static public func ==(lhs: StoredPublicationDate, rhs: StoredPublicationDate) -> Bool {
    return lhs.date == rhs.date
  }
}

/// A stored PublicationDate
public final class StoredPublicationDate: PublicationDate, StoredObject {
  
  public static var entity = "PublicationDate"
  public var pr: PersistentPublicationDate // persistent record
  
  public var feed: (any Feed)? {
    get {
      guard let pFeed = pr.feed else { return nil }
      return StoredFeed(persistent: pFeed)
    }
    set {/*not allowed due circular/endless loop on startup*/}
  }
  
  public var date: Date {
    get { return pr.date! }
    set { pr.date = newValue }
  }
  public var validityDate: Date? {
    get { return pr.validityDate }
    set { pr.validityDate = newValue }
  }
  
  /// Persists an array of `PublicationDate` objects into the Core Data store for the specified feed.
  ///
  /// This method inserts all provided `publicationDates` into the persistent store using a high-performance
  /// batch insert. It intentionally avoids filtering out duplicates in Swift prior to insertion due to
  /// the performance cost of comparing thousands of entries in memory (e.g., using `Set` or `filter` operations).
  ///
  /// Instead, this method relies on a **Core Data Unique Constraint** defined on the `date` attribute
  /// of the `PublicationDate` entity to ensure that no duplicates are inserted.
  ///
  /// - Important:
  ///   - The `PublicationDate` entity must define a **Unique Constraint on `date`** in the Core Data model.
  ///   - This allows the underlying SQLite engine to automatically discard duplicates efficiently during insert.
  ///   - As a result, no Swift-side filtering or deduplication logic is needed, resulting in significantly better performance,
  ///     especially when inserting thousands of items.
  ///
  /// - Performance:
  ///   - On a test device (iPad Air 2 running iOS 15.8), the previous Swift-based filtering implementation
  ///     took approximately **9 seconds** to process ~4,000 items.
  ///   - With the current approach that delegates duplicate handling to Core Data via unique constraints,
  ///     the same insert takes only around **2 seconds**, including fetch and batch insert.
  ///
  /// - Parameters:
  ///   - publicationDates: An array of `PublicationDate` instances to be persisted.
  ///   - feed: The `StoredFeed` entity to which the publication dates belong.
  public static func persist(publicationDates: [PublicationDate],
                             inFeed feed: StoredFeed) {
    let start = Date()
    
    let objectsArray: [[String: Any]] = publicationDates.map {
      [
        "date": $0.date,
        "validityDate": $0.validityDate ?? NSNull()
      ]
    }
    
    guard let entD = NSEntityDescription.entity(forEntityName: StoredPublicationDate.entity, in: ArticleDB.context) else {
      Log.log("Could not get entity for \(StoredPublicationDate.entity)")
      return
    }
    
    let request = NSBatchInsertRequest(entity: entD, objects: objectsArray)
    
    if let insertResult = try? ArticleDB.context.execute(request) as? NSBatchInsertResult,
       let objectIDs = insertResult.result as? [NSManagedObjectID] {
      // Importent: for later fetch
      let changes = [NSInsertedObjectsKey: objectIDs]
      NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [ArticleDB.context])
    }
    
    // new objects are now in context, so we can fetch them
    let pds = StoredPublicationDate.getAllWithoutFeed()
    for pd in pds { feed.pr.addToPublicationDates(pd.pr) }
    
    Log.log("Persisting \(publicationDates.count) took \(Date().timeIntervalSince(start))s")
  }
  
  /// Return stored record with given name
  public static func get(date: Date, inFeed feed: StoredFeed) -> [StoredPublicationDate] {
    let nsdate = NSDate(timeIntervalSinceReferenceDate:
                          date.timeIntervalSinceReferenceDate)
    let request = fetchRequest
    request.predicate = NSPredicate(format: "(date = %@) AND (feed = %@)",
                                    nsdate, feed.pr)
    return get(request: request)
  }
  
  /// Return stored record with given name
  public static func getAll(inFeed feed: StoredFeed) -> [StoredPublicationDate] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "(feed = %@)", feed.pr)
    return get(request: request)
  }
    
  private static func getAllWithoutFeed() -> [StoredPublicationDate] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "feed == nil")
    return get(request: request)
  }
  
  public static func get(object: PublicationDate, inFeed feed: StoredFeed) -> StoredPublicationDate? {
    return get(date: object.date, inFeed: feed).first
  }
  
  public static func get(object: PublicationDate) -> StoredPublicationDate? {
    if let feed = object.feed,
       let sfeed = StoredFeed.get(object: feed) {
      return get(object: object, inFeed: sfeed)
    }
    else { return nil }
  }
  
  /// Return an array of Issues in a Feed
  public static func publicationDatesInFeed(feed: StoredFeed, count: Int = -1)
  -> [StoredPublicationDate] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "feed = %@", feed.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
    if count > 0 { request.fetchLimit = count }
    return get(request: request)
  }
  
  public required init(persistent: PersistentPublicationDate) { self.pr = persistent }
  
  /// Overwrite the persistent values
  public func update(from object: PublicationDate) {
    self.feed = object.feed ///in or out?
    self.date = object.date
    self.validityDate = object.validityDate
  }
  
} //StoredPublicationDate

extension Date {
    var dayKey: Int {
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: self)
        return comps.year! * 10000 + comps.month! * 100 + comps.day!
    }
}

extension StoredIssue: Equatable {
  static public func ==(lhs: StoredIssue, rhs: StoredIssue) -> Bool {
    ///cannot ensure they are the same, usually the are not due one is deleted or prepared sor deletion
    if lhs.safeDate == nil { return false }
    return lhs.safeDate == rhs.safeDate
  }
}

/// A stored Issue
public final class StoredIssue: Issue, StoredObject {
  public static var entity = "Issue"
  public var pr: PersistentIssue // persistent record
  public var feed: Feed {
    get { StoredFeed(persistent: pr.feed!) }
    set {
      if let sfeed = StoredFeed.get(object: newValue) {
        pr.feed = sfeed.pr
        pr.feed?.addToIssues(self.pr)
      }
    }
  }
  public var safeDate: Date? { pr.date }
  public var date: Date {
    get { return pr.date! }
    ///In case of multiple crashes in different situations may use the following or refactor all to use optional date
    ///crash seeams to appeared on DemoIssue > FullIssue after login, also after app-restart in new home
    /*
     get {
     if let d = pr.date { return d }
     error("Prevent Crash Bug!")
     return Date(timeIntervalSince1970: 0)
     }*/
    set { pr.date = newValue }
  }
  public var validityDate: Date? {
    get { return pr.validityDate }
    set { pr.validityDate = newValue }
  }
  
  public var fullDownloadedDate: Date? {
    get { return pr.fullDownloadedDate }
    set { pr.fullDownloadedDate = newValue }
  }
  public var moTime: Date {
    get { return pr.moTime! }
    set { pr.moTime = newValue }
  }
  public var isWeekend: Bool {
    get { return pr.isWeekend }
    set { pr.isWeekend = newValue }
  }
  public var moment: Moment {
    get { StoredMoment(persistent: pr.moment!) }///CrashCount: 1
    set {
      pr.moment = StoredMoment.persist(object: newValue).pr
      pr.moment?.issue = self.pr
    }
  }
  public var key: String? {
    get { return pr.key }
    set { pr.key = newValue }
  }
  public var baseUrl: String {
    get { return pr.baseUrl! }
    set { pr.baseUrl = newValue }
  }
  public var status: IssueStatus {
    get { return IssueStatus(pr.status ?? "unknown") ?? IssueStatus.unknown }
    set { pr.status = newValue.representation }
  }
  public var minResourceVersion: Int {
    get { return Int(pr.minResourceVersion) }
    set { pr.minResourceVersion = Int32(newValue) }
  }
  public var versionLocal: Int? {
    get { return (pr.versionLocal < 0) ? nil : Int(pr.versionLocal) }
    set(val) { pr.versionLocal = Int32((val==nil) ? -1 : val!) }
  }
  public var versionRemote: Int? {
    get { return (pr.versionRemote < 0) ? nil : Int(pr.versionRemote) }
    set(val) { pr.versionRemote = Int32((val==nil) ? -1 : val!) }
  }
  public var zipName: String? {
    get { return pr.zipName }
    set { pr.zipName = newValue }
  }
  public var zipNamePdf: String? {
    get { return pr.zipNamePdf }
    set { pr.zipNamePdf = newValue }
  }
  public var zipAudioName: String? {
    get { return pr.zipAudioName }
    set { pr.zipAudioName = newValue }
  }
  public var fileList: [String]? { nil }
  public var fileListPdf: [String]? { nil }
  public var imprint: Article? {
    get {
      if let pim = pr.imprint { return StoredArticle(persistent: pim) }
      else { return nil }
    }
    set {
      if let sim = newValue {
        if let old = pr.imprint, old.html?.name != sim.html?.name {
          old.delete()
        }
        pr.imprint = StoredArticle.persist(object: sim).pr
        pr.imprint?.issueImprint = self.pr
      }
      else { pr.imprint = nil }
    }
  }
  
  public var lastContent: Content? {
    get {
      if let pArt = pr.lastContent as? PersistentArticle {
        return StoredArticle(persistent: pArt)
      }
      else if let pSect = pr.lastContent as? PersistentSection {
        return StoredSection(persistent: pSect)
      }
      return nil
    }
    set {
      if let sArt = newValue as? StoredArticle {
        pr.lastContent = sArt.pr
      }
      else if let sSect = newValue as? StoredSection {
        pr.lastContent = sSect.pr
      }
      else {
        pr.lastContent = nil
      }
    }
  }
  public var lastArticle: Int? {
    get { return (pr.lastArticle < 0) ? nil : Int(pr.lastArticle) }
    set(val) { pr.lastArticle = Int32((val==nil) ? -1 : val!) }
  }
  public var lastArticleScrollPos: CGFloat? {
    get { return (pr.lastArticleScrollPos < 0) ? nil : CGFloat(pr.lastArticleScrollPos) }
    set(val) { pr.lastArticleScrollPos = (val == nil ? -1.0 : Float(val!))}
  }
  public var lastSection: Int? {
    get { return (pr.lastSection < 0) ? nil : Int(pr.lastSection) }
    set(val) { pr.lastSection = Int32((val==nil) ? -1 : val!) }
  }
  public var lastPage: Int? {
    get { return (pr.lastPage < 0) ? nil : Int(pr.lastPage) }
    set(val) { pr.lastPage = Int32((val==nil) ? -1 : val!) }
  }
  public var lastReadWasPage: Bool {
    get { return pr.lastReadWasPage }
    set(val) { pr.lastReadWasPage = val }
  }
  public var isComplete: Bool {
    get { return pr.isComplete }
    set {
      pr.isComplete = newValue
      if newValue == true {
        pr.isOvwComplete = newValue
        pr.fullDownloadedDate = Date()
      } else {
        pr.fullDownloadedDate = nil
      }
    }
  }
  public var isAutodownloading: Bool {
    get { return pr.isAutodownloading }
    set { pr.isAutodownloading = newValue }
  }
  public var isOvwComplete: Bool {
    get { return pr.isOvwComplete }
    set { pr.isOvwComplete = newValue }
  }
  public var isAudioComplete: Bool {
    get { return pr.isAudioComplete }
    set { pr.isAudioComplete = newValue }
  }
  public var needUpdateAudio: Bool {
    get { return pr.needUpdateAudio }
    set { pr.needUpdateAudio = newValue }
  }
  public var storedPayload: StoredPayload? {
    if let ppl = pr.payload { return StoredPayload(persistent: ppl) }
    else { return nil }
  }
  public var payload: Payload { storedPayload! }
  
  public var sections: [Section]? { StoredSection.sectionsInIssue(issue: self) }
  public var pages: [Page]? { StoredPage.pagesInIssue(issue: self) }
  public var isDownloading: Bool = false
  
  public required init(persistent: PersistentIssue) { self.pr = persistent }
  
  /// Overwrite the persistent values
  public func update(from object: Issue) {
    let sendUpdatedDemoIssueNotification = self.status == .reduced && object.status != .reduced
    var sendUpdateBookmarksNotification: Bool = false
    self.feed = object.feed
    self.date = object.date
    self.fullDownloadedDate = object.fullDownloadedDate
    self.validityDate = object.validityDate
    self.isAutodownloading = object.isAutodownloading
    self.isDownloading = object.isDownloading
    self.moTime = object.moTime
    ///Set **only** remote version here and **localVersion after Download!**
    self.versionRemote = object.versionRemote
    self.isWeekend = object.isWeekend
    self.moment = object.moment
    self.key = object.key
    self.baseUrl = object.baseUrl
    self.minResourceVersion = object.minResourceVersion
    self.zipName = object.zipName
    self.zipNamePdf = object.zipNamePdf
    self.imprint = object.imprint
    if let art = self.imprint as? StoredArticle {
      art.pr.addToIssues(self.pr)
      art.pr.issueImprint = self.pr
    }
    self.status = object.status
    let oldSections = sections
    let oldPages = pages
    
    if let secs = object.sections {
      var order: Int32 = 0
      for section in secs {
        let ssection = StoredSection.persist(object: section)
        ssection.pr.issue = self.pr
        ssection.pr.order = order
        pr.addToSections(ssection.pr)
        order += 1
        if let arts = ssection.articles {
          for case let art as StoredArticle in arts {
            art.pr.addToIssues(self.pr)
            if Bookmarks.shared.has(article: art){
              sendUpdateBookmarksNotification = true
            }
          }
        }
      }
    }
    if let pages = object.pages {
      var order: Int32 = 0
      for page in pages {
        let spage = StoredPage.persist(object: page)
        spage.pr.issue = self.pr
        spage.pr.order = order
        pr.addToPages(spage.pr)
        order += 1
      }
    }
    // Remove sections no longer needed
    if let osecs = oldSections as? [StoredSection] {
      if let secs = object.sections {
        for s in osecs {
          if !secs.contains(where: { $0.html?.name == s.html?.name }) {
            s.delete()
          }
        }
      }
      else {
        for s in osecs { s.delete() }
      }
    }
    
    // Remove pages no longer needed
    if let opgs = oldPages as? [StoredPage] {
      if let pages = object.pages {
        for p in opgs {
          if !pages.contains(where: { $0.pdf?.name == p.pdf?.name && $0.pdf != nil }) {
            p.delete()
          }
        }
      }
      else {
        for p in opgs { p.delete() }
      }
    }
    ///Warining in Persist the wrong subdir is set due Payload did not know the globals dir; solution @see below
    let storedPayload = StoredPayload.persist(object: object.payload)
    pr.payload = storedPayload.pr
    pr.payload?.issue = pr
    let globalsPath = feed.feeder.globalDir.path
    var globalsSubPath = String(globalsPath.dropFirst(Database.appDir.count + 1))
    globalsSubPath = globalsSubPath.hasSuffix("/") ? String(globalsSubPath.dropLast()) : globalsSubPath
    log("storedPayload.updateGlobalFiles(subdir: \(globalsSubPath)")
    storedPayload.updateGlobalFiles(subdir: globalsSubPath)///fix globals subdir!
    if let p1 = StoredPage.pageOne(issue: self) {
      let mom = StoredMoment(persistent: pr.moment!)
      mom.firstPage = p1
    }
    if sendUpdatedDemoIssueNotification { Notification.send("updatedDemoIssue") }
    if sendUpdateBookmarksNotification { Notification.send(Const.NotificationNames.bookmarkChanged) }
  }
  
  /// Return stored record with given name
  public static func get(date: Date, inFeed feed: StoredFeed) -> [StoredIssue] {
    let nsdate = NSDate(timeIntervalSinceReferenceDate:
                          date.timeIntervalSinceReferenceDate)
    let request = fetchRequest
    request.predicate = NSPredicate(format: "(date = %@) AND (feed = %@)",
                                    nsdate, feed.pr)
    return get(request: request)
  }
  
  /// Return stored record with given params or nil
  public static func get(baseUrl: String, inFeed feed: StoredFeed) -> StoredIssue? {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "baseUrl = %@", baseUrl, feed.pr)
    return get(request: request).first
  }
  
  public static func get(object: Issue, inFeed feed: StoredFeed) -> StoredIssue? {
    let issues = get(date: object.date, inFeed: feed)
    if issues.count > 0 { return issues[0] }
    else { return nil }
  }
  
  public static func get(object: Issue) -> StoredIssue? {
    if let sfeed = StoredFeed.get(object: object.feed) {
      return get(object: object, inFeed: sfeed)
    }
    else { return nil }
  }
  
  /// Return an array of Issues in a Feed
  public static func lastComplete(feed: StoredFeed, isPages: Bool, withAudio: Bool) -> StoredIssue? {
      let request = fetchRequest
      var predicates: [NSPredicate] = [
          NSPredicate(format: "feed = %@", feed.pr),
          NSPredicate(format: "isComplete = true")
      ]
      if isPages { predicates.append(NSPredicate(format: "zipNamePdf != nil"))  }
      if withAudio { predicates.append(NSPredicate(format: "zipAudioName != nil")) }
      // combine all predicates with AND
      request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
      request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
      request.fetchLimit = 1
      return get(request: request).first
  }
  
  public static func lastComplete(feed: StoredFeed)
  -> StoredIssue? {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "feed = %@ AND isComplete = true", feed.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
    request.fetchLimit = 1
    return get(request: request).first
  }
  
  /// Return an array of Issues in a Feed
  public static func issuesInFeed(feed: StoredFeed, count: Int = -1, fromDate: Date? = nil)
  -> [StoredIssue] {
    let request = fetchRequest
    if let fromDate = fromDate {
      let nsdate = NSDate(timeIntervalSinceReferenceDate: fromDate.timeIntervalSinceReferenceDate)
      request.predicate = NSPredicate(format: "feed = %@ AND date <= %@", feed.pr, nsdate)
    }
    else { request.predicate = NSPredicate(format: "feed = %@", feed.pr) }
    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
    if count > 0 { request.fetchLimit = count }
    return get(request: request)
  }
  
  /// Return an array of Issues ordered by load date, ie. the oldest (by
  /// load date) comes first
  public static func firstLoaded(feed: StoredFeed, count: Int = -1) -> [StoredIssue] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "feed = %@ AND isComplete = true", feed.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "payload.downloadStarted",
                                                ascending: true)]
    if count > 0 { request.fetchLimit = count }
    return get(request: request)
  }
  
  /// fetch helper for issue sorting
  public enum IssueSorting {
    case issueDate, fullDownloadedDate
    var key: String {
      get {
        switch self {
          case .issueDate:
            return "date"
          case .fullDownloadedDate:
            return "fullDownloadedDate"
        }
      }
    }
    
    /// Helper usage e.g.: .issueDate..sortDescriptor(ascending:true)
    func sortDescriptor(ascending:Bool) -> NSSortDescriptor {
      return NSSortDescriptor(key: self.key, ascending: ascending)
    }
  }
  
  /// Fetch and return array of Issues, by given params
  /// - Parameters:
  ///   - feed: feed to use
  ///   - count: max count
  ///   - onlyComplete: only fetch compleetly downloaded issues
  ///   - sortedBy: used sorting
  ///   - ascending: descending if false
  /// - Returns: array of Issues
  public static func issues(feed: StoredFeed,
                            count: Int = -1,
                            onlyComplete: Bool,
                            onlyWithoutCompleteDate: Bool = false,
                            sortedBy: IssueSorting = .issueDate,
                            ascending:Bool = true) -> [StoredIssue] {
    let request = fetchRequest
    
    var predicates: [NSPredicate] = [
        NSPredicate(format: "feed = %@", feed.pr)
    ]

    if onlyComplete {
        predicates.append(NSPredicate(format: "isComplete = true"))
    }

    if onlyWithoutCompleteDate {
        predicates.append(NSPredicate(format: "fullDownloadedDate = nil"))
    }

    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    
    request.sortDescriptors = [sortedBy.sortDescriptor(ascending:ascending)]
    if count > 0 { request.fetchLimit = count }
    return get(request: request)
  }
  
  /// Returns the latest (ie. most current) issue stored
  public static func latest(feed: StoredFeed) -> StoredIssue? {
    let issues = issuesInFeed(feed: feed, count: 1)
    if issues.count >= 1 { return issues[0] }
    return nil
  }
  
  /// delete all issues in feed
  /// - Parameters:
  ///   - feed: feed for Issues
  ///   - deleteBookmarkIssues: if true, bookmark issues will also be deleted
  public static func deleteAllIssues(feed: StoredFeed, deleteBookmarkIssues: Bool = false) {
    let allIssues
    = issues(feed: feed, onlyComplete: false, sortedBy: .issueDate, ascending: false)
    
    for issue in allIssues {
      if issue.isBookmarkIssue && !deleteBookmarkIssues {
        Log.log("not deleting \(issue.date.short) due its a bookmark issue")
        continue
      }
      if issue.isDownloading == true {
        Log.log("not deleting \(issue.date.short) due its currently downloading")
        continue
      }
      Log.log("delete issue: \(issue.date.short)")
      issue.delete()
    }
  }
   
  /// Cleans up old issues while keeping recent full and preview issues.
  ///
  /// Removes old issues of a feed while retaining the most recent ones.
  ///
  /// - Workflow:
  ///   1. Keep a configurable number of the most recent fully downloaded issues.
  ///   2. Additionally keep a number of preview issues (reduced via `reduceToOverview`).
  ///   3. Delete older issues completely if `deleteOlder == true`,
  ///      otherwise reduce them to Overview only.
  ///   4. Always keep the bookmark issue and the currently opened issue.
  ///   5. Optionally remove orphaned issue folders from the filesystem.
  ///
  /// - Parameters:
  ///   - feed: The feed whose issues should be cleaned up.
  ///   - keepDownloaded: Number of fully downloaded issues to retain.
  ///     `0` means keep all issues (no deletion).
  ///   - keepPreviews: Number of preview issues to retain in addition to full ones.
  ///   - deleteOlder: Whether to fully delete preview issues beyond `keepPreviews`.
  ///     ⚠️ WARNING: deleted issues may still be referenced in `IssueOverviewService`.
  ///     Starting a download in that state will crash the app.
  ///   - deleteOrphanFolders: Whether to also remove orphaned issue folders
  ///     from the filesystem.
  public static func removeOldest(feed: StoredFeed,
                                  keepDownloaded: Int,
                                  keepPreviews: Int = 20,
                                  deleteOlder: Bool = false,
                                  deleteOrphanFolders: Bool = false) {
    // User-Setting keepDownloaded:
    // 0 = means keep all issues
    // otherwise user setting, at least 3
    let completeFetchCount: Int = keepDownloaded == 0 ? -1 : max(3, keepDownloaded)
    
    Log.debug("keepDownloaded: \(keepDownloaded), keepPreviews: \(keepPreviews), deleteOrphanFolders: \(deleteOrphanFolders)")
    
    // all issues which should not be deleted
    var lastCompleteIssues: [StoredIssue] = issues(feed: feed,
                                                   count: completeFetchCount,
                                                   onlyComplete: true,
                                                   sortedBy: .fullDownloadedDate,
                                                   ascending: false)
    
    if let latestComplete = lastComplete(feed: feed),
       !lastCompleteIssues.contains(latestComplete) {
      lastCompleteIssues.insert(latestComplete, at: 0)
      if lastCompleteIssues.count > max(3, keepDownloaded){
        _ = lastCompleteIssues.popLast()
      }
    }
    
    let allIssues = issues(feed: feed, onlyComplete: false, sortedBy: .issueDate, ascending: false)
    guard !allIssues.isEmpty else {
      Log.log("No Issues > cancel")
      return
    }
    
    var knownDirs: [String] = []
    var deletedIssueDates: [String] = []
    var previewCount = 0
    
    let lastCompleteDates = Set(lastCompleteIssues.compactMap { $0.safeDate?.ISO8601 })
    
    var bookmarkIssue: StoredIssue?
    
    for issue in allIssues {
      let dir = feed.feeder.issueDir(issue: issue)
      let path = dir.exists ? dir.path : nil
      
      // 1. do not delete bookmark issue or its folder
      if issue.isBookmarkIssue {
        bookmarkIssue = issue ///there is only one Bookmark Issue
        knownDirs.appendIfPresent(path)
        for art in bookmarkIssue?.allArticles ?? [] {
          knownDirs.appendIfPresent(art.path.urlByDeleetingLastPathComponent)
        }
        continue
      }
      
      // 2. do not delete a issue if keepDownloaded == 0: "Alle behalten"
      if keepDownloaded == 0 {
        knownDirs.appendIfPresent(path)
        continue
      }
      
      previewCount += 1
      
      // 3. compleete issue: do not delete
      if let sd = issue.safeDate?.ISO8601, lastCompleteDates.contains(sd) {
        knownDirs.appendIfPresent(path)
        continue
      }
      
      // 4. currently opened issue: do not delete; probably also in lastCompleteDates/lastCompleteIssues
      if let opened = TazAppEnvironment.sharedInstance.feederContext?.openedIssue as? StoredIssue,
         issue.safeDate?.ISO8601 == opened.safeDate?.ISO8601 {
        knownDirs.appendIfPresent(path)
        continue
      }
            
      // 5. delete or reduceToOverview
      if deleteOlder && previewCount > keepPreviews {
        deletedIssueDates.append("\(issue.date.ISO8601) \(issue.isComplete ? "complete" :"overview")")
        ///Notification.send("issueProgress", content: "deleted", sender: issue)...automatically send
        issue.delete()
      } else if issue.reduceToOverview() {
        Notification.send("issueProgress", content: "deleted", sender: issue)
        knownDirs.appendIfPresent(path)
      } else {///not deleted (may active download), do not send notification to show issue as deleted
        knownDirs.appendIfPresent(path)
      }
    }
    guard deleteOrphanFolders else { return }
    
    // scan subdirs
    let allSubdirs = feed.feeder.feedDir(feed.name).scan()
    var deletedFolders: [String] = []
    var skippedFolders: [String] = []

    //do not delete Bookmark Articles original folders
    for art in bookmarkIssue?.allArticles ?? [] {
      knownDirs.appendIfPresent(art.path.urlByDeleetingLastPathComponent)
    }
    ///remove duplicates and percent encoding
    knownDirs = Array(Set(knownDirs.map { $0.removingPercentEncoding ?? $0 }))
    
    ///remove duplicates and percent encoding
    knownDirs = Array(Set(knownDirs.map { $0.removingPercentEncoding ?? $0 }))

    
    for path in allSubdirs {
      let decodedPath = path.removingPercentEncoding ?? path
      if knownDirs.contains(decodedPath) ||
          File("\(path)/\(BackgroundDownloadService.jsonDataFilename)").exists {
        skippedFolders.append(path.lastPathComponents(4))
        continue
      }
      deletedFolders.append(path.lastPathComponents(4))
      Dir(path).remove()
    }
    
    if !deletedIssueDates.isEmpty {
      Log.log("...deleted issues:\n  \(deletedIssueDates.sorted().joined(separator: "\n  "))")
    }
    if !deletedFolders.isEmpty {
      Log.log("...deleted folders:\n  \(deletedFolders.sorted().joined(separator: "\n  "))")
    }
    if !skippedFolders.isEmpty {
      Log.log("skipped folders:\n  \(skippedFolders.sorted().joined(separator: "\n  "))")
    }
  }
  
  @discardableResult
  /// Deletes data that is not needed for overview
  /// - Parameter force: delete also issues with bookmarks
  /// - Returns: true if content deletes, false if already overview version OR currently downloading
  public func reduceToOverview() -> Bool {
    if isDownloading {
      ///WARNING May not catch all states, due isDownloading is set if Downloader.downloading files;
      ///not in first Step: get Structure Data @REFACTORING
      Log.log("Delete Issue: \(self.date.short) prevented while downloading")
      return false
    }
    else {
      Log.log("Delete Issue: \(self.date.short) Status compleete: \(isComplete) isOvwComplete: \(isOvwComplete) autoDownloading: \(isAutodownloading) downloaded: \(fullDownloadedDate?.dateAndTime ?? "-")")
    }
    // Remove files not needed for overview
    // Remove sections and cascading all data referenced by them
    var hasChanges = false
    for section in self.sections as? [StoredSection] ?? [] {
      section.delete()
      hasChanges = true
    }
    
    let facsimileFileName = pageOneFacsimile?.fileName
    for case let p as StoredPage in pages ?? [] {
      if facsimileFileName != nil && p.pdf?.fileName == facsimileFileName { continue }
      p.delete()
      hasChanges = true
    }
    
    (imprint as? StoredArticle)?.delete()
    if isComplete {
      isComplete = false
      isOvwComplete = true
    }
    self.isAudioComplete = false
    self.lastPage = nil
    self.lastContent = nil
    self.lastArticle = nil
    self.lastSection = nil
    //lastPage = nil //May delete also last Page?
    //Cannot be restored in current UI Flow and DataModel settup
    ArticleDB.save()
    return hasChanges
  }
  
} // StoredIssue

extension PersistentFeed: PersistentObject {}

/// A stored Feed
public final class StoredFeed: Feed, StoredObject {
  
  public static var entity = "Feed"
  public var pr: PersistentFeed // persistent record
  public var name: String {
    get { return pr.name! }
    set { pr.name = newValue }
  }
  public var cycle: PublicationCycle {
    get { return PublicationCycle(pr.cycle!)! }
    set { pr.cycle = newValue.representation }
  }
  public var type: FeedType {
    get { return FeedType(pr.type!)! }
    set { pr.type = newValue.representation }
  }
  public var momentRatio: Float {
    get { return pr.momentRatio }
    set { pr.momentRatio = newValue }
  }
  public var issueCnt: Int {
    get { return Int(pr.issueCnt) }
    set { pr.issueCnt = Int64(newValue) }
  }
  public var firstIssue: Date {
    get { return pr.firstIssue! }
    set { pr.firstIssue = newValue }
  }
  public var firstSearchableIssue: Date? {
    get { return pr.firstSearchableIssue }
    set { pr.firstSearchableIssue = newValue }
  }
  public var lastIssue: Date {
    get { 
      if pr.isFault {
        log("Core Data Fault \(pr) \(pr.isFault)")
        pr.managedObjectContext?.refresh(pr, mergeChanges: true)
        log("Is loaded now? \(pr) \(pr.isFault) moc:\(String(describing: pr.managedObjectContext))")
      }
      return pr.lastIssue! }
    set { pr.lastIssue = newValue }
  }
  public var lastIssueRead: Date? {
    get { return pr.lastIssueRead }
    set { pr.lastIssueRead = newValue }
  }
  public var lastUpdated: Date? {
    get { return pr.lastUpdated }
    set { pr.lastUpdated = newValue }
  }
  public var feeder: Feeder {
    get { return StoredFeeder(persistent: pr.feeder!) }
    set {
      if let sfeeder = StoredFeeder.get(object: newValue) {
        pr.feeder = sfeeder.pr
        pr.feeder?.addToFeeds(self.pr)
      }
    }
  }
  
  public var storedIssues: [StoredIssue] { StoredIssue.issuesInFeed(feed: self) }
  public var issues: [Issue]? { storedIssues }
  
  public var issueVersions: [IssueVersion]? { nil }
  
  public var storedPublicationDates: [StoredPublicationDate] {
    let dates = StoredPublicationDate.publicationDatesInFeed(feed: self)
    if !dates.isEmpty { return dates }
    createPublicationDatesFromStoredIssues()
    return StoredPublicationDate.publicationDatesInFeed(feed: self)
  }
  
  ///Helper for migation from 1.1? to newer version
  private func createPublicationDatesFromStoredIssues(){
    var dates: [PublicationDate] = []
    for issue in storedIssues {
      let date = GqlPublicationDate(from: issue.date.dbIssueRepresentation, feed: self)
      date.validityDate = issue.validityDate
      dates.append(date)
    }
    guard (issues?.first) != nil else { return }
    StoredPublicationDate.persist(publicationDates: dates, inFeed: self)
    ArticleDB.save()
  }
  
  public var publicationDates: [PublicationDate]? { storedPublicationDates }
  
  public required init(persistent: PersistentFeed) { self.pr = persistent }
  
  /// Overwrite the persistent values
  public func update(from object: Feed) {
    log("update Feed: \(object.name)")
    self.name = object.name
    self.feeder = object.feeder
    self.cycle = object.cycle
    self.type = object.type
    self.issueCnt = object.issueCnt
    self.momentRatio = object.momentRatio
    self.firstIssue = object.firstIssue
    self.firstSearchableIssue = object.firstSearchableIssue
    self.lastIssue = object.lastIssue
    self.lastIssueRead = object.lastIssueRead
    self.lastUpdated = object.lastUpdated
    if let issueVersions = object.issueVersions {
      for version in issueVersions {
        guard let si = StoredIssue.get(date: version.date, inFeed: self).first else { continue }
        if si.versionRemote == version.versionRemote { continue }
        debug("update Issue \(version.date.short) remote from>to: \(si.versionRemote ?? -1)>\(version.versionRemote)")
        si.versionRemote = version.versionRemote
      }
    }
    /// CR-Feeds: Warning: what should we do? only add issues to primary feed?
    /// CR-Feeds: Warning Issue>Feed Relation is currently **to one** need to be changed or add just issues to master feed?
    /// wochentaz login => default filter to wochentaz > no more db reset required > no more time consuming qa...legacy code...
    if let iss = object.issues {
      for issue in iss {
        let sissue = StoredIssue.persist(object: issue)
        ///CR-Feeds: adding multiple feeds?
        sissue.pr.feed = pr
        pr.addToIssues(sissue.pr)
      }
      // Remove Issues no longer needed
      for issue in self.issues as! [StoredIssue] {
        if !iss.contains(where: { $0.date == issue.date }) {
          pr.removeFromIssues(issue.pr)
        }
      }
    }
    if let pubDates = object.publicationDates {
      let start = Date()
      StoredPublicationDate.persist(publicationDates: pubDates, inFeed: self)
#warning("not removing wrong publicationDates!")
      /// Remove publicationDates no longer needed e.g. wrongly delivered by temporary api error
      /// **is not possible due we request only the newest ones
      //      for pd in self.publicationDates as! [StoredPublicationDate] {
      //        if !pubDates.contains(where: { $0.date == pd.date }) {
      //          pr.removeFromPublicationDates(pd.pr)
      //        }
      //      }
      ///Saving 3770 PublicationDates took 13.26183307170868s on iPhone 7 initially in Debugging!
      ///  Saving 3770 PublicationDates took 5.203890919685364s on iPhone 7 initially in Debugging! after StoredPublicationDate.feed removed db requests
      ///    Saving 3770 PublicationDates took 5.487667918205261s
      log("Saving \(pubDates.count) PublicationDates took \(abs(start.timeIntervalSinceNow))s")
    }
  }
  
  /// Return stored Issue with given name in Feeder
  public static func get(name: String, inFeeder feeder: StoredFeeder) -> [StoredFeed] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "(name = %@) AND (feeder = %@)",
                                    name, feeder.pr)
    return get(request: request)
  }
  
  public static func get(object: Feed, inFeeder feeder: StoredFeeder) -> StoredFeed? {
    let feeds = get(name: object.name, inFeeder: feeder)
    if feeds.count > 1 {///Problematisch? Es sollte keine 2 Feeds mit gleichem Namen geben.
      Usage.track(Usage.event.errorEvent.UnexpectedFeedCountInDatabase,
                  name: "expected: 1, found: \(feeds.count) for feedName: \(object.name)")
      Log.log("ERROR:: Unexpected Feed Count In Database: expected: 1, found: \(feeds.count) for feedName: \(object.name)", logLevel: Log.LogLevel.Error)
    }
    return feeds.first
  }
  
  public static func get(object: Feed) -> StoredFeed? {
    if let sfeeder = StoredFeeder.get(object: object.feeder) {
      return get(object: object, inFeeder: sfeeder)
    }
    else { return nil }
  }
  
  /// Return all Feeds of a Feeder
  public static func feedsOfFeeder(feeder: StoredFeeder) -> [StoredFeed] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "feeder = %@", feeder.pr)
    return get(request: request)
  }
  
} // StoredFeed

extension StoredFeed {
  public var lastPublicationDate: Date? {
    guard let publicationDates = pr.publicationDates as? Set<PersistentPublicationDate> else {
      return nil
    }
    return publicationDates.max { a, b in
      guard let apd = a.date,
            let bpd = b.date else { return false }
      return apd < bpd
    }?.date
  }
}

extension PersistentFeeder: PersistentObject {}

/// A stored Feeder
public final class StoredFeeder: Feeder, StoredObject {
  
  public static var entity = "Feeder"
  public var pr: PersistentFeeder // persistent record
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
  public var resourceBaseUrl: String {
    get { return pr.resourceBaseUrl! }
    set { pr.resourceBaseUrl = newValue }
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
  public var storedResources: StoredResources? {
    let res = StoredResources.get(version: resourceVersion)
    if res.count > 0 { return res[0] }
    else { return nil }
  }
  public var resourceFiles: [StoredFileEntry]
  { storedResources?.storedPayload?.storedFiles ?? [] }
  public var storedFeeds: [StoredFeed] { StoredFeed.feedsOfFeeder(feeder: self) }
  public var feeds: [Feed] { storedFeeds }
  
  public required init(persistent: PersistentFeeder) { self.pr = persistent }
  
  /// Overwrite the persistent values
  public func update(from object: Feeder) {
    log("update feeder, persist feeds")
    self.title = object.title
    self.timeZone = object.timeZone
    self.baseUrl = object.baseUrl
    self.globalBaseUrl = object.globalBaseUrl
    self.resourceBaseUrl = object.resourceBaseUrl
    self.authToken = object.authToken
    self.resourceVersion = object.resourceVersion
    self.lastUpdated = object.lastUpdated
    for feed in object.feeds {
      let sfeed = StoredFeed.persist(object: feed)
      sfeed.pr.feeder = pr
      pr.addToFeeds(sfeed.pr)
    }
    // Do not remove Feeds no longer on server
  }
  
  /// Return stored record with given name/title
  public static func get(name: String) -> [StoredFeeder] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "title = %@", name)
    return get(request: request)
  }
  
  public static func get(object: Feeder) -> StoredFeeder? {
    let feeders = get(name: object.title)
    if feeders.count > 0 { return feeders[0] }
    else { return nil }
  }
  
  public static func all() -> [StoredFeeder] {
    let request = fetchRequest
    return get(request: request)
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
  
  public func resources(closure: @escaping(Result<Resources,Error>, Data?)->()) {
    closure(.failure(error("Currently no resources available")), nil)
  }
  
} // StoredFeeder
