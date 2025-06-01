//
//  Trip+Extensions.swift
//  TravelCompanion
//
//  Created on 2024.
//

import Foundation
import CoreData

// MARK: - Trip Extensions
extension Trip {
    
    // MARK: - Computed Properties
    
    /// Formatierter Trip Titel
    var formattedTitle: String {
        return title?.isEmpty == false ? title! : "Unbenannte Reise"
    }
    
    /// Trip Dauer in Tagen
    var durationInDays: Int {
        guard let startDate = startDate else { return 0 }
        
        guard let endDate = endDate else {
            // Laufende Trips: Dauer bis heute
            return Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        }
        return Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
    
    /// Formatiertes Start-Datum
    var formattedStartDate: String {
        guard let startDate = startDate else { return "Unbekannt" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate)
    }
    
    /// Formatiertes End-Datum
    var formattedEndDate: String {
        guard let endDate = endDate else { return "Laufend" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: endDate)
    }
    
    /// Formatierte Trip-Dauer
    var formattedDuration: String {
        let days = durationInDays
        if days == 0 {
            return "Heute gestartet"
        } else if days == 1 {
            return "1 Tag"
        } else {
            return "\(days) Tage"
        }
    }
    
    /// Trip Status
    var status: TripStatus {
        if isActive {
            return .active
        } else if let endDate = endDate, endDate < Date() {
            return .completed
        } else {
            return .planned
        }
    }
    
    /// Anzahl der Memories
    var memoriesCount: Int {
        return memories?.count ?? 0
    }
    
    /// Anzahl der Teilnehmer
    var participantsCount: Int {
        return participants?.count ?? 0
    }
    
    /// Alle Memories als Array
    var memoriesArray: [Memory] {
        let memories = memories?.allObjects as? [Memory] ?? []
        return memories.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    /// Alle Teilnehmer als Array
    var participantsArray: [User] {
        let participants = participants?.allObjects as? [User] ?? []
        return participants.sorted { ($0.displayName ?? "") < ($1.displayName ?? "") }
    }
    
    /// Aktuelle Memories (chronologisch sortiert)
    var sortedMemories: [Memory] {
        return memoriesArray.sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
    }
    
    // MARK: - Convenience Methods
    
    /// Holt alle aktiven Trips
    static func fetchActiveTrips(in context: NSManagedObjectContext) -> [Trip] {
        let request = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Trip: Fehler beim Laden aktiver Trips: \(error)")
            return []
        }
    }
    
    /// Holt alle Trips
    static func fetchAllTrips(for user: User, in context: NSManagedObjectContext) -> [Trip] {
        let request = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Trip: Fehler beim Laden aller Trips für User: \(error)")
            return []
        }
    }
    
    /// Holt Trips eines Users
    static func fetchTrips(for user: User, in context: NSManagedObjectContext) -> [Trip] {
        return fetchAllTrips(for: user, in: context)
    }
    
    /// Prüft ob Trip Memories hat
    var hasMemories: Bool {
        return memoriesCount > 0
    }
    
    /// Holt die neuesten Memories
    func recentMemories(limit: Int = 5) -> [Memory] {
        return Array(sortedMemories.prefix(limit))
    }
    
    /// Fügt einen Teilnehmer hinzu
    func addParticipant(_ user: User) {
        addToParticipants(user)
    }
    
    /// Entfernt einen Teilnehmer
    func removeParticipant(_ user: User) {
        removeFromParticipants(user)
    }
}

// MARK: - Trip Status Enum
enum TripStatus: String, CaseIterable {
    case planned = "Geplant"
    case active = "Aktiv"
    case completed = "Abgeschlossen"
    
    var color: String {
        switch self {
        case .planned: return "blue"
        case .active: return "green"
        case .completed: return "gray"
        }
    }
    
    var systemImage: String {
        switch self {
        case .planned: return "calendar"
        case .active: return "location.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
} 