import Foundation
import CoreData

@objc(Trip)
public class Trip: NSManagedObject {
    
    // MARK: - Computed Properties
    
    var duration: TimeInterval? {
        guard let endDate = endDate else { return nil }
        return endDate.timeIntervalSince(startDate)
    }
    
    var durationInDays: Int? {
        guard let duration = duration else { return nil }
        return Int(duration / (24 * 60 * 60))
    }
    
    var isOngoing: Bool {
        let now = Date()
        if let endDate = endDate {
            return startDate <= now && now <= endDate
        }
        return startDate <= now && isActive
    }
    
    var isPast: Bool {
        if let endDate = endDate {
            return endDate < Date()
        }
        return false
    }
    
    var isFuture: Bool {
        return startDate > Date()
    }
    
    var allParticipants: [User] {
        var participants: [User] = []
        if let owner = owner {
            participants.append(owner)
        }
        if let otherParticipants = self.participants?.allObjects as? [User] {
            participants.append(contentsOf: otherParticipants.filter { $0 != owner })
        }
        return participants.sorted { $0.displayName < $1.displayName }
    }
    
    var footstepsArray: [Footstep] {
        guard let footsteps = footsteps?.allObjects as? [Footstep] else { return [] }
        return footsteps.sorted { $0.timestamp < $1.timestamp }
    }
    
    var totalFootsteps: Int {
        return footsteps?.count ?? 0
    }
    
    var totalPhotos: Int {
        return footstepsArray.reduce(0) { $0 + ($1.photos?.count ?? 0) }
    }
    
    var participantCount: Int {
        return allParticipants.count
    }
    
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if let endDate = endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            return "Ab \(formatter.string(from: startDate))"
        }
    }
    
    // MARK: - Convenience Methods
    
    func addParticipant(_ user: User) {
        addToParticipants(user)
    }
    
    func removeParticipant(_ user: User) {
        removeFromParticipants(user)
    }
    
    func addFootstep(_ footstep: Footstep) {
        addToFootsteps(footstep)
    }
    
    func removeFootstep(_ footstep: Footstep) {
        removeFromFootsteps(footstep)
    }
    
    func isParticipant(_ user: User) -> Bool {
        return allParticipants.contains(user)
    }
    
    func canEdit(by user: User) -> Bool {
        return owner == user
    }
    
    func start() {
        isActive = true
    }
    
    func end() {
        isActive = false
        if endDate == nil {
            endDate = Date()
        }
    }
    
    func footsteps(by user: User) -> [Footstep] {
        return footstepsArray.filter { $0.author == user }
    }
} 