import Foundation
import CoreData

extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var id: UUID
    @NSManaged public var filename: String
    @NSManaged public var localURL: String?
    @NSManaged public var cloudURL: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var footstep: Footstep?

}

extension Photo : Identifiable {

} 