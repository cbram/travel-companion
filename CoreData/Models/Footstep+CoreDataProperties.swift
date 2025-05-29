import Foundation
import CoreData

extension Footstep {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Footstep> {
        return NSFetchRequest<Footstep>(entityName: "Footstep")
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var content: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var timestamp: Date
    @NSManaged public var createdAt: Date
    @NSManaged public var author: User?
    @NSManaged public var trip: Trip?
    @NSManaged public var photos: NSSet?

}

// MARK: Generated accessors for photos
extension Footstep {

    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: Photo)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: Photo)

    @objc(addPhotos:)
    @NSManaged public func addToPhotos(_ values: NSSet)

    @objc(removePhotos:)
    @NSManaged public func removeFromPhotos(_ values: NSSet)

}

extension Footstep : Identifiable {

} 