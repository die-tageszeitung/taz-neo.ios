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
  private init() { super.init("ArticleDB") }    
  /// There is only one article DB in the app
  static var singleton: ArticleDB = ArticleDB()  
  /// The managed object context
  static var context: NSManagedObjectContext { return singleton.context! }  
} // ArticleDB

/// A Protocol to extend CoreData objects
private protocol PersistentObject: NSManagedObject, DoesLog {}

extension PersistentObject {
  /// The object ID as String
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

/// A Protocol to extent StoredObjects (ie. PersistentObject Wrappers)
private protocol StoredObject: DoesLog {
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
  
  /// Execute fetch request and return stored record
  static func get(request: NSFetchRequest<PO>) -> [Self] {
    do {
      let res = try ArticleDB.context.fetch(request)
      return res.map { Self(persistent: $0) }
    }
    catch let err { Log.error(err) }
    return []
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
  var sha256: String { pr.sha256! }
  
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
  static func payload(payload: StoredPayload) -> [StoredFileEntry] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "payload = %@", payload.pr)
    request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
    return get(request: request)
  }
  
} // StoredFileEntry


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

  lazy var files: [StoredFileEntry] = { StoredFileEntry.payload(payload: self) }()

  required init(persistent: PersistentPayload) { self.pr = persistent }
  
  /// Store all FileEntries as one new Payload
  static func persist(files: [FileEntry], localDir: String, remoteBaseUrl: String? = nil,
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

class StoredResources: Resources, StoredObject {
    
  static var entity = "Resources"
  var pr: PersistentResources // persistent record
  lazy var payload = StoredPayload(persistent: pr.payload!)
  var resourceBaseUrl: String { payload.remoteBaseUrl! }
  var resourceZipName: String { payload.remoteZipName! }
  var resourceVersion: Int { Int(pr.resourceVersion) }
  var localDir: String { payload.localDir }
  var resourceFiles: [FileEntry] { payload.files }

  required init(persistent: PersistentResources) { self.pr = persistent }

  /// Return stored record with given resourceVersion  
  static func get(version: Int) -> [StoredResources] {
    let request = fetchRequest
    request.predicate = NSPredicate(format: "resourceVersion = %d", version)
    return get(request: request)
  }
  
  /// Create a new persistent record if not available and store the passed Resources into it
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

}
