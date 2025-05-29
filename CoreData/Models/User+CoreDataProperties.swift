import Foundation
import CoreData

extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var id: UUID
    @NSManaged public var email: String
    @NSManaged public var displayName: String
    @NSManaged public var avatarURL: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var isActive: Bool
    @NSManaged public var ownedTrips: NSSet?
    @NSManaged public var participatedTrips: NSSet?
    @NSManaged public var footsteps: NSSet?

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

// MARK: Generated accessors for footsteps
extension User {

    @objc(addFootstepsObject:)
    @NSManaged public func addToFootsteps(_ value: Footstep)

    @objc(removeFootstepsObject:)
    @NSManaged public func removeFromFootsteps(_ value: Footstep)

    @objc(addFootsteps:)
    @NSManaged public func addToFootsteps(_ values: NSSet)

    @objc(removeFootsteps:)
    @NSManaged public func removeFromFootsteps(_ values: NSSet)

}

extension User : Identifiable {

} 