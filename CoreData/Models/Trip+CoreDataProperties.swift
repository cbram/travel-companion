import Foundation
import CoreData

extension Trip {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Trip> {
        return NSFetchRequest<Trip>(entityName: "Trip")
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var tripDescription: String?
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var owner: User?
    @NSManaged public var participants: NSSet?
    @NSManaged public var footsteps: NSSet?

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

// MARK: Generated accessors for footsteps
extension Trip {

    @objc(addFootstepsObject:)
    @NSManaged public func addToFootsteps(_ value: Footstep)

    @objc(removeFootstepsObject:)
    @NSManaged public func removeFromFootsteps(_ value: Footstep)

    @objc(addFootsteps:)
    @NSManaged public func addToFootsteps(_ values: NSSet)

    @objc(removeFootsteps:)
    @NSManaged public func removeFromFootsteps(_ values: NSSet)

}

extension Trip : Identifiable {

} 