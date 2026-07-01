//
//  PersistentIssue+CoreDataProperties.swift
//  taz.neo
//
//  Created by Ringo Müller on 01.07.26.
//  Copyright © 2026 taz. All rights reserved.
//
//

public import Foundation
public import CoreData


public typealias PersistentIssueCoreDataPropertiesSet = NSSet

extension PersistentIssue {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersistentIssue> {
        return NSFetchRequest<PersistentIssue>(entityName: "Issue")
    }

    @NSManaged public var baseUrl: String?
    @NSManaged public var date: Date?
    @NSManaged public var fullDownloadedDate: Date?
    @NSManaged public var isAudioComplete: Bool
    @NSManaged public var isAutodownloading: Bool
    @NSManaged public var isComplete: Bool
    @NSManaged public var isOvwComplete: Bool
    @NSManaged public var isWeekend: Bool
    @NSManaged public var key: String?
    @NSManaged public var lastArticle: Int32
    @NSManaged public var lastArticleScrollPos: Float
    @NSManaged public var lastPage: Int32
    @NSManaged public var lastReadWasPage: Bool
    @NSManaged public var lastSection: Int32
    @NSManaged public var minResourceVersion: Int32
    @NSManaged public var moTime: Date?
    @NSManaged public var needUpdateAudio: Bool
    @NSManaged public var status: String?
    @NSManaged public var validityDate: Date?
    @NSManaged public var versionLocal: Int32
    @NSManaged public var versionRemote: Int32
    @NSManaged public var zipAudioName: String?
    @NSManaged public var zipName: String?
    @NSManaged public var zipNamePdf: String?
    @NSManaged public var articles: NSSet?
    @NSManaged public var feed: PersistentFeed?
    @NSManaged public var imprint: PersistentArticle?
    @NSManaged public var lastContent: PersistentContent?
    @NSManaged public var moment: PersistentMoment?
    @NSManaged public var pages: NSSet?
    @NSManaged public var payload: PersistentPayload?
    @NSManaged public var resource: PersistentResources?
    @NSManaged public var sections: NSSet?

}

// MARK: Generated accessors for articles
extension PersistentIssue {

    @objc(addArticlesObject:)
    @NSManaged public func addToArticles(_ value: PersistentArticle)

    @objc(removeArticlesObject:)
    @NSManaged public func removeFromArticles(_ value: PersistentArticle)

    @objc(addArticles:)
    @NSManaged public func addToArticles(_ values: NSSet)

    @objc(removeArticles:)
    @NSManaged public func removeFromArticles(_ values: NSSet)

}

// MARK: Generated accessors for pages
extension PersistentIssue {

    @objc(addPagesObject:)
    @NSManaged public func addToPages(_ value: PersistentPage)

    @objc(removePagesObject:)
    @NSManaged public func removeFromPages(_ value: PersistentPage)

    @objc(addPages:)
    @NSManaged public func addToPages(_ values: NSSet)

    @objc(removePages:)
    @NSManaged public func removeFromPages(_ values: NSSet)

}

// MARK: Generated accessors for sections
extension PersistentIssue {

    @objc(addSectionsObject:)
    @NSManaged public func addToSections(_ value: PersistentSection)

    @objc(removeSectionsObject:)
    @NSManaged public func removeFromSections(_ value: PersistentSection)

    @objc(addSections:)
    @NSManaged public func addToSections(_ values: NSSet)

    @objc(removeSections:)
    @NSManaged public func removeFromSections(_ values: NSSet)

}

extension PersistentIssue : Identifiable {

}
