import Foundation
import CoreData

@objc(User)
public class User: NSManagedObject {
    
    // MARK: - Computed Properties
    
    var allTrips: [Trip] {
        var trips: [Trip] = []
        if let ownedTrips = ownedTrips?.allObjects as? [Trip] {
            trips.append(contentsOf: ownedTrips)
        }
        if let participatedTrips = participatedTrips?.allObjects as? [Trip] {
            trips.append(contentsOf: participatedTrips.filter { !trips.contains($0) })
        }
        return trips.sorted { $0.startDate > $1.startDate }
    }
    
    var currentTrips: [Trip] {
        return allTrips.filter { $0.isActive }
    }
    
    var pastTrips: [Trip] {
        return allTrips.filter { !$0.isActive && ($0.endDate ?? Date()) < Date() }
    }
    
    var upcomingTrips: [Trip] {
        return allTrips.filter { !$0.isActive && $0.startDate > Date() }
    }
    
    var totalFootsteps: Int {
        return footsteps?.count ?? 0
    }
    
    var initials: String {
        let components = displayName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first?.uppercased() }
        return initials.prefix(2).joined()
    }
    
    // MARK: - Convenience Methods
    
    func addTrip(_ trip: Trip) {
        addToOwnedTrips(trip)
    }
    
    func removeTrip(_ trip: Trip) {
        removeFromOwnedTrips(trip)
    }
    
    func joinTrip(_ trip: Trip) {
        trip.addToParticipants(self)
    }
    
    func leaveTrip(_ trip: Trip) {
        trip.removeFromParticipants(self)
    }
    
    func isOwner(of trip: Trip) -> Bool {
        return trip.owner == self
    }
    
    func isParticipant(in trip: Trip) -> Bool {
        return trip.participants?.contains(self) ?? false
    }
} 