//
//  Trip+CoreDataProperties.swift
//  
//
//  Created by Christian Bram on 30.05.25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Trip {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Trip> {
        return NSFetchRequest<Trip>(entityName: "Trip")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var tripDescription: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var owner: User?
    @NSManaged public var participants: NSSet?
    @NSManaged public var memories: NSSet?

}

// MARK: Generated accessors for participants
extension Trip {

    @objc(addParticipantsObject:)
    @NSManaged public func addToParticipants(_ value: User)

    @objc(removeParticipantsObject:)
    @NSManaged public func removeFromParticipants(_ value: User)

    @objc(addParticipants:)
    @NSManaged public func addToParticipants(_ values: NSSet)

    @objc(removeParticipants:)
    @NSManaged public func removeFromParticipants(_ values: NSSet)

}

// MARK: Generated accessors for memories
extension Trip {

    @objc(addMemoriesObject:)
    @NSManaged public func addToMemories(_ value: Memory)

    @objc(removeMemoriesObject:)
    @NSManaged public func removeFromMemories(_ value: Memory)

    @objc(addMemories:)
    @NSManaged public func addToMemories(_ values: NSSet)

    @objc(removeMemories:)
    @NSManaged public func removeFromMemories(_ values: NSSet)

}

extension Trip : Identifiable {

}
