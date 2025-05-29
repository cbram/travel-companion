import Foundation
import CoreData
import CoreLocation

@objc(Footstep)
public class Footstep: NSManagedObject {
    
    // MARK: - Computed Properties
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    var photosArray: [Photo] {
        guard let photos = photos?.allObjects as? [Photo] else { return [] }
        return photos.sorted { $0.createdAt < $1.createdAt }
    }
    
    var photoCount: Int {
        return photos?.count ?? 0
    }
    
    var hasPhotos: Bool {
        return photoCount > 0
    }
    
    var hasContent: Bool {
        return content?.isEmpty == false
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(timestamp)
        
        if interval < 60 {
            return "Gerade eben"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "vor \(minutes) Min"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "vor \(hours) Std"
        } else {
            let days = Int(interval / 86400)
            return "vor \(days) Tag\(days == 1 ? "" : "en")"
        }
    }
    
    var shortDescription: String {
        if let content = content, !content.isEmpty {
            return String(content.prefix(100)) + (content.count > 100 ? "..." : "")
        }
        return "Keine Beschreibung"
    }
    
    // MARK: - Location Methods
    
    func distance(from location: CLLocation) -> CLLocationDistance {
        return self.location.distance(from: location)
    }
    
    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let otherLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return distance(from: otherLocation)
    }
    
    func formattedDistance(from location: CLLocation) -> String {
        let distance = self.distance(from: location)
        
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    // MARK: - Photo Management
    
    func addPhoto(_ photo: Photo) {
        addToPhotos(photo)
    }
    
    func removePhoto(_ photo: Photo) {
        removeFromPhotos(photo)
    }
    
    func firstPhoto() -> Photo? {
        return photosArray.first
    }
    
    func canEdit(by user: User) -> Bool {
        return author == user || trip?.owner == user
    }
    
    func canDelete(by user: User) -> Bool {
        return author == user || trip?.owner == user
    }
} 