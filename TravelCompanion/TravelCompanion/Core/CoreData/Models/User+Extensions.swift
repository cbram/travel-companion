//
//  User+Extensions.swift
//  TravelCompanion
//
//  Created on 2024.
//

import Foundation
import CoreData

// MARK: - User Extensions
extension User {
    
    // MARK: - Computed Properties
    
    /// Formatierter Display Name mit Fallback
    var formattedDisplayName: String {
        return displayName?.isEmpty == false ? displayName! : "Unbekannter Benutzer"
    }
    
    /// Initiale des Benutzernamens für Avatars
    var initials: String {
        guard let displayName = displayName, !displayName.isEmpty else { return "?" }
        let components = displayName.components(separatedBy: " ")
        return components.compactMap { $0.first }
            .prefix(2)
            .map { String($0).uppercased() }
            .joined()
    }
    
    /// Anzahl der eigenen Trips
    var tripsCount: Int {
        return ownedTrips?.count ?? 0
    }
    
    /// Anzahl der Memories
    var memoriesCount: Int {
        return memories?.count ?? 0
    }
    
    /// Formatiertes Erstellungsdatum
    var formattedCreatedAt: String {
        guard let createdAt = createdAt else { return "Unbekannt" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
    
    /// Aktive Trips des Users
    var activeTrips: [Trip] {
        return ownedTripsArray.filter { $0.isActive }
    }
    
    /// Alle eigenen Trips als Array
    var ownedTripsArray: [Trip] {
        let trips = ownedTrips?.allObjects as? [Trip] ?? []
        return trips.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
    }
    
    /// Alle teilgenommenen Trips als Array
    var participatedTripsArray: [Trip] {
        let trips = participatedTrips?.allObjects as? [Trip] ?? []
        return trips.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
    }
    
    /// Alle Memories als Array
    var memoriesArray: [Memory] {
        let memories = memories?.allObjects as? [Memory] ?? []
        return memories.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    /// Alle Trips (owned + participated) als Array
    var allTripsArray: [Trip] {
        let owned = ownedTripsArray
        let participated = participatedTripsArray
        let combined = Set(owned + participated)
        return Array(combined).sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
    }
    
    // MARK: - Convenience Methods
    
    /// Holt alle Users
    static func fetchAllUsers(in context: NSManagedObjectContext) -> [User] {
        let request = User.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \User.displayName, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ User: Fehler beim Laden aller Users: \(error)")
            return []
        }
    }
    
    /// Holt User nach Email
    static func fetchUser(by email: String, in context: NSManagedObjectContext) -> User? {
        let request = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("❌ User: Fehler beim Laden des Users mit Email \(email): \(error)")
            return nil
        }
    }
    
    /// Holt alle aktiven Users
    static func fetchActiveUsers(in context: NSManagedObjectContext) -> [User] {
        let request = User.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \User.displayName, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ User: Fehler beim Laden aktiver Users: \(error)")
            return []
        }
    }
    
    /// Prüft ob User Trips hat
    var hasTrips: Bool {
        return tripsCount > 0
    }
    
    /// Prüft ob User Memories hat
    var hasMemories: Bool {
        return memoriesCount > 0
    }
    
    /// Holt die letzten Memories des Users
    func recentMemories(limit: Int = 10) -> [Memory] {
        return Array(memoriesArray.prefix(limit))
    }
    
    /// Erstellt oder holt den Default User
    static func fetchOrCreateDefaultUser(in context: NSManagedObjectContext) -> User {
        let request = User.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \User.createdAt, ascending: true)]
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            if let existingUser = users.first {
                return existingUser
            }
        } catch {
            print("❌ User: Fehler beim Laden des Default Users: \(error)")
        }
        
        // Erstelle neuen Default User
        let newUser = User(context: context)
        newUser.id = UUID()
        newUser.email = "default@travelcompanion.com"
        newUser.displayName = "Travel Explorer"
        newUser.createdAt = Date()
        newUser.isActive = true
        
        return newUser
    }
} 