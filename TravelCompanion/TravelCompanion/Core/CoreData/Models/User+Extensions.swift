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
    
    /// ROBUSTE Erstelle oder holt den Default User - ENHANCED VERSION
    static func fetchOrCreateDefaultUser(in context: NSManagedObjectContext) -> User {
        // SCHRITT 1: Versuche existierenden aktiven User zu finden
        let request = User.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true AND email == %@", "default@travelcompanion.com")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \User.createdAt, ascending: true)]
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false // Eager loading für bessere Performance
        
        do {
            let users = try context.fetch(request)
            if let existingUser = users.first {
                // ERWEITERTE Validierung des existierenden Users
                guard !existingUser.isDeleted,
                      let userContext = existingUser.managedObjectContext,
                      userContext == context else {
                    print("⚠️ User: Existierender User ist ungültig oder in falschem Context, erstelle neuen...")
                    // Bereinige ungültigen User
                    if !existingUser.isDeleted {
                        context.delete(existingUser)
                    }
                    return createNewDefaultUser(in: context)
                }
                
                // STORE-VALIDIERUNG für existierenden User
                do {
                    _ = try context.existingObject(with: existingUser.objectID)
                    print("✅ User: Existierender Default User erfolgreich validiert: \(existingUser.formattedDisplayName)")
                    return existingUser
                } catch {
                    print("⚠️ User: Existierender User nicht im Store validierbar: \(error)")
                    return createNewDefaultUser(in: context)
                }
            }
        } catch {
            print("❌ User: Fehler beim Suchen des Default Users: \(error)")
        }
        
        // SCHRITT 2: Kein gültiger User gefunden - erstelle neuen
        return createNewDefaultUser(in: context)
    }
    
    /// NEUE Helper-Methode: Erstellt einen neuen Default User mit vollständiger Validierung
    private static func createNewDefaultUser(in context: NSManagedObjectContext) -> User {
        print("🔄 User: Erstelle neuen Default User...")
        
        // Bereinige alle alten Default-User vor der Neuerstellung
        let cleanupRequest = User.fetchRequest()
        cleanupRequest.predicate = NSPredicate(format: "email == %@", "default@travelcompanion.com")
        
        do {
            let oldUsers = try context.fetch(cleanupRequest)
            for oldUser in oldUsers {
                print("🗑️ User: Entferne alten Default User: \(oldUser.formattedDisplayName)")
                context.delete(oldUser)
            }
        } catch {
            print("⚠️ User: Fehler beim Bereinigen alter Default Users: \(error)")
        }
        
        // Erstelle neuen Default User
        let newUser = User(context: context)
        newUser.id = UUID()
        newUser.email = "default@travelcompanion.com"
        newUser.displayName = "Travel Explorer"
        newUser.createdAt = Date()
        newUser.isActive = true
        
        // KRITISCHER PUNKT: SOFORT speichern mit mehrfacher Validierung
        do {
            // Erst Context-Validierung
            guard context.insertedObjects.contains(newUser) else {
                throw NSError(domain: "UserCreation", code: 1, userInfo: [NSLocalizedDescriptionKey: "User nicht im Context eingefügt"])
            }
            
            // Context-Save
            try context.save()
            
            // POST-SAVE Validierung: Prüfe dass User wirklich im Store ist
            let verifyRequest = User.fetchRequest()
            verifyRequest.predicate = NSPredicate(format: "id == %@", newUser.id! as CVarArg)
            verifyRequest.fetchLimit = 1
            
            let verifyUsers = try context.fetch(verifyRequest)
            guard let verifiedUser = verifyUsers.first,
                  verifiedUser.objectID == newUser.objectID else {
                throw NSError(domain: "UserCreation", code: 2, userInfo: [NSLocalizedDescriptionKey: "User nach Save nicht im Store gefunden"])
            }
            
            print("✅ User: Neuer Default User erfolgreich erstellt und validiert: \(newUser.formattedDisplayName)")
            return newUser
            
        } catch {
            print("❌ User: KRITISCHER FEHLER beim Erstellen des Default Users: \(error)")
            
            // FALLBACK: Versuche minimalen User zu erstellen
            let fallbackUser = User(context: context)
            fallbackUser.id = UUID()
            fallbackUser.email = "fallback@travelcompanion.com"
            fallbackUser.displayName = "Emergency User"
            fallbackUser.createdAt = Date()
            fallbackUser.isActive = true
            
            // Versuche Fallback-Save (ohne weitere Validierung um Endlos-Loop zu vermeiden)
            do {
                try context.save()
                print("⚠️ User: Fallback User erstellt")
                return fallbackUser
            } catch {
                print("❌ User: FATALER FEHLER - Auch Fallback User konnte nicht erstellt werden: \(error)")
                // Rückgabe des nicht-gespeicherten Users als letzte Option
                return fallbackUser
            }
        }
    }
} 