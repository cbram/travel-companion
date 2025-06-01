//
//  User+CoreDataProperties.swift
//  
//
//  Created by Christian Bram on 30.05.25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var email: String?
    @NSManaged public var displayName: String?
    @NSManaged public var avatarURL: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var ownedTrips: NSSet?
    @NSManaged public var participatedTrips: NSSet?
    @NSManaged public var memories: NSSet?

}

// MARK: Generated accessors for ownedTrips
extension User {

    @objc(addOwnedTripsObject:)
    @NSManaged public func addToOwnedTrips(_ value: Trip)

    @objc(removeOwnedTripsObject:)
    @NSManaged public func removeFromOwnedTrips(_ value: Trip)

    @objc(addOwnedTrips:)
    @NSManaged public func addToOwnedTrips(_ values: NSSet)

    @objc(removeOwnedTrips:)
    @NSManaged public func removeFromOwnedTrips(_ values: NSSet)

}

// MARK: Generated accessors for participatedTrips
extension User {

    @objc(addParticipatedTripsObject:)
    @NSManaged public func addToParticipatedTrips(_ value: Trip)

    @objc(removeParticipatedTripsObject:)
    @NSManaged public func removeFromParticipatedTrips(_ value: Trip)

    @objc(addParticipatedTrips:)
    @NSManaged public func addToParticipatedTrips(_ values: NSSet)

    @objc(removeParticipatedTrips:)
    @NSManaged public func removeFromParticipatedTrips(_ values: NSSet)

}

// MARK: Generated accessors for memories
extension User {

    @objc(addMemoriesObject:)
    @NSManaged public func addToMemories(_ value: Memory)

    @objc(removeMemoriesObject:)
    @NSManaged public func removeFromMemories(_ value: Memory)

    @objc(addMemories:)
    @NSManaged public func addToMemories(_ values: NSSet)

    @objc(removeMemories:)
    @NSManaged public func removeFromMemories(_ values: NSSet)

}

extension User : Identifiable {

}
