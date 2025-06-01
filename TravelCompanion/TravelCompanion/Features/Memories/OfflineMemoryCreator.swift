//
//  OfflineMemoryCreator.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import Foundation
import UIKit
import CoreData
import CoreLocation

/// Offline-first Memory Creation Workflow Manager
@MainActor
class OfflineMemoryCreator: ObservableObject {
    
    // MARK: - Singleton
    static let shared = OfflineMemoryCreator()
    
    // MARK: - Published Properties
    @Published var isCreatingMemory = false
    @Published var pendingMemoriesCount = 0
    @Published var lastCreatedMemory: Memory?
    
    // MARK: - Private Properties
    private let persistenceController = PersistenceController.shared
    private let photoFileManager = PhotoFileManager.shared
    private let locationManager = LocationManager.shared
    
    // MARK: - Memory Creation Data
    struct MemoryCreationData {
        let title: String
        let content: String?
        let photos: [UIImage]
        let location: CLLocation?
        let tripID: UUID
        let userID: UUID
        let timestamp: Date
        
        init(title: String, content: String? = nil, photos: [UIImage] = [], location: CLLocation? = nil, tripID: UUID, userID: UUID, timestamp: Date = Date()) {
            self.title = title
            self.content = content
            self.photos = photos
            self.location = location
            self.tripID = tripID
            self.userID = userID
            self.timestamp = timestamp
        }
    }
    
    // MARK: - Creation Result
    enum MemoryCreationResult {
        case success(Memory)
        case offline(UUID) // Memory ID für später sync
        case failure(Error)
    }
    
    // MARK: - Initialization
    private init() {
        updatePendingCount()
        DebugLogger.shared.log("📝 OfflineMemoryCreator initialisiert")
    }
    
    // MARK: - Memory Creation
    
    /// Erstellt eine Memory mit vollständigem Offline-Support
    func createMemory(data: MemoryCreationData) async -> MemoryCreationResult {
        DebugLogger.shared.log("📝 Erstelle Memory: \(data.title)")
        
        await MainActor.run {
            isCreatingMemory = true
        }
        
        defer {
            Task { @MainActor in
                isCreatingMemory = false
            }
        }
        
        do {
            // Memory in Core Data erstellen
            let memory = try await createMemoryEntity(data: data)
            
            // Photos verarbeiten und speichern
            let photoSaveResults = await savePhotosOffline(photos: data.photos, memoryID: memory.id!)
            
            // Photo Results zu Memory hinzufügen
            await updateMemoryWithPhotos(memory: memory, photoResults: photoSaveResults)
            
            await MainActor.run {
                lastCreatedMemory = memory
            }
            
            DebugLogger.shared.log("✅ Memory erfolgreich erstellt: \(data.title)")
            return .success(memory)
            
        } catch {
            DebugLogger.shared.log("❌ Memory Creation Fehler: \(error.localizedDescription)")
            
            // Bei Fehler: Offline Memory erstellen
            let offlineMemoryID = await createOfflineMemory(data: data)
            return .offline(offlineMemoryID)
        }
    }
    
    /// Erstellt eine Memory mit aktueller Location
    func createMemoryAtCurrentLocation(title: String, content: String? = nil, photos: [UIImage] = [], for trip: Trip, by user: User) async -> MemoryCreationResult {
        
        let location = locationManager.currentLocation
        
        let data = MemoryCreationData(
            title: title,
            content: content,
            photos: photos,
            location: location,
            tripID: trip.id!,
            userID: user.id!
        )
        
        return await createMemory(data: data)
    }
    
    /// Schnelle Memory-Erstellung ohne Photos
    func createQuickMemory(title: String, for trip: Trip, by user: User) async -> MemoryCreationResult {
        let data = MemoryCreationData(
            title: title,
            content: nil,
            photos: [],
            location: locationManager.currentLocation,
            tripID: trip.id!,
            userID: user.id!
        )
        
        return await createMemory(data: data)
    }
    
    // MARK: - Core Data Operations
    
    private func createMemoryEntity(data: MemoryCreationData) async throws -> Memory {
        let context = persistenceController.container.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Trip und User finden
                    let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
                    tripRequest.predicate = NSPredicate(format: "id == %@", data.tripID as CVarArg)
                    
                    let userRequest: NSFetchRequest<User> = User.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "id == %@", data.userID as CVarArg)
                    
                    guard let trip = try context.fetch(tripRequest).first,
                          let user = try context.fetch(userRequest).first else {
                        throw MemoryCreationError.invalidTripOrUser
                    }
                    
                    // Memory Entity erstellen
                    let memory = Memory(context: context)
                    memory.id = UUID()
                    memory.title = data.title
                    memory.content = data.content
                    memory.timestamp = data.timestamp
                    memory.createdAt = Date()
                    memory.author = user
                    memory.trip = trip
                    
                    // Location setzen falls vorhanden
                    if let location = data.location {
                        memory.latitude = location.coordinate.latitude
                        memory.longitude = location.coordinate.longitude
                    }
                    
                    try context.save()
                    
                    DebugLogger.shared.logCoreDataOperation("CREATE", entityName: "Memory", result: .success(()))
                    continuation.resume(returning: memory)
                    
                } catch {
                    DebugLogger.shared.logCoreDataOperation("CREATE", entityName: "Memory", result: .failure(error))
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Photo Management
    
    private func savePhotosOffline(photos: [UIImage], memoryID: UUID) async -> [PhotoFileManager.PhotoSaveResult] {
        var results: [PhotoFileManager.PhotoSaveResult] = []
        
        for (index, photo) in photos.enumerated() {
            let filename = "memory_\(memoryID.uuidString)_\(index + 1).jpg"
            let result = await photoFileManager.savePhoto(photo, for: memoryID, originalFilename: filename)
            results.append(result)
            
            // Kurze Pause zwischen Photos für Performance
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 Sekunden
        }
        
        return results
    }
    
    private func updateMemoryWithPhotos(memory: Memory, photoResults: [PhotoFileManager.PhotoSaveResult]) async {
        let context = persistenceController.container.newBackgroundContext()
        
        await context.perform {
            do {
                // Memory im Background Context finden
                let memoryRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
                memoryRequest.predicate = NSPredicate(format: "id == %@", memory.id! as CVarArg)
                
                guard let backgroundMemory = try context.fetch(memoryRequest).first else {
                    DebugLogger.shared.log("⚠️ Memory nicht im Background Context gefunden")
                    return
                }
                
                // Photo Entities für erfolgreiche Saves erstellen
                for result in photoResults {
                    switch result {
                    case .success(let localURL, _, _):
                        let photo = Photo(context: context)
                        photo.id = UUID()
                        
                        // Dateinamen aus URL extrahieren
                        let filename = URL(fileURLWithPath: localURL).lastPathComponent
                        photo.filename = filename
                        
                        photo.localURL = localURL
                        photo.createdAt = Date()
                        photo.memory = backgroundMemory
                        
                    case .failure(let error):
                        DebugLogger.shared.log("❌ Photo Save Fehler: \(error.localizedDescription)")
                    }
                }
                
                try context.save()
                DebugLogger.shared.log("✅ Photos zu Memory hinzugefügt")
                
            } catch {
                DebugLogger.shared.log("❌ Memory Photo Update Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Offline Memory Management
    
    private func createOfflineMemory(data: MemoryCreationData) async -> UUID {
        let offlineMemoryID = UUID()
        
        // Photos offline speichern
        let photoResults = await savePhotosOffline(photos: data.photos, memoryID: offlineMemoryID)
        
        // Offline Memory Data zusammenstellen
        let offlineMemory = OfflineMemoryData(
            id: offlineMemoryID,
            title: data.title,
            content: data.content,
            latitude: data.location?.coordinate.latitude,
            longitude: data.location?.coordinate.longitude,
            timestamp: data.timestamp,
            tripID: data.tripID,
            userID: data.userID,
            photoURLs: extractSuccessfulPhotoURLs(from: photoResults),
            createdAt: Date()
        )
        
        // In UserDefaults speichern
        saveOfflineMemory(offlineMemory)
        
        await MainActor.run {
            pendingMemoriesCount += 1
        }
        
        DebugLogger.shared.log("📦 Offline Memory erstellt: \(data.title)")
        return offlineMemoryID
    }
    
    private func extractSuccessfulPhotoURLs(from results: [PhotoFileManager.PhotoSaveResult]) -> [String] {
        return results.compactMap { result in
            switch result {
            case .success(let localURL, _, _):
                return localURL
            case .failure:
                return nil
            }
        }
    }
    
    // MARK: - Offline Data Persistence
    
    struct OfflineMemoryData: Codable {
        let id: UUID
        let title: String
        let content: String?
        let latitude: Double?
        let longitude: Double?
        let timestamp: Date
        let tripID: UUID
        let userID: UUID
        let photoURLs: [String]
        let createdAt: Date
    }
    
    private func saveOfflineMemory(_ offlineMemory: OfflineMemoryData) {
        let key = "offlineMemory_\(offlineMemory.id.uuidString)"
        
        do {
            let data = try JSONEncoder().encode(offlineMemory)
            UserDefaults.standard.set(data, forKey: key)
            
            // Zur Liste der offline memories hinzufügen
            var offlineMemoryIDs = UserDefaults.standard.stringArray(forKey: "offlineMemoryIDs") ?? []
            offlineMemoryIDs.append(offlineMemory.id.uuidString)
            UserDefaults.standard.set(offlineMemoryIDs, forKey: "offlineMemoryIDs")
            
            DebugLogger.shared.log("💾 Offline Memory gespeichert: \(offlineMemory.title)")
        } catch {
            DebugLogger.shared.log("❌ Offline Memory Save Fehler: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Offline Sync
    
    func syncOfflineMemories() async {
        DebugLogger.shared.log("🔄 Sync Offline Memories gestartet")
        
        let offlineMemoryIDs = UserDefaults.standard.stringArray(forKey: "offlineMemoryIDs") ?? []
        
        for memoryIDString in offlineMemoryIDs {
            await syncOfflineMemory(id: memoryIDString)
        }
        
        // IDs-Liste leeren nach erfolgreichem Sync
        UserDefaults.standard.removeObject(forKey: "offlineMemoryIDs")
        
        await MainActor.run {
            updatePendingCount()
        }
        
        DebugLogger.shared.log("✅ Offline Memory Sync abgeschlossen")
    }
    
    private func syncOfflineMemory(id: String) async {
        let key = "offlineMemory_\(id)"
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            DebugLogger.shared.log("⚠️ Offline Memory nicht gefunden: \(id)")
            return
        }
        
        do {
            let offlineMemory = try JSONDecoder().decode(OfflineMemoryData.self, from: data)
            
            // Memory in Core Data erstellen
            let memoryData = MemoryCreationData(
                title: offlineMemory.title,
                content: offlineMemory.content,
                photos: [], // Photos bereits gespeichert
                location: createLocationFromCoordinates(
                    latitude: offlineMemory.latitude,
                    longitude: offlineMemory.longitude
                ),
                tripID: offlineMemory.tripID,
                userID: offlineMemory.userID,
                timestamp: offlineMemory.timestamp
            )
            
            let memory = try await createMemoryEntity(data: memoryData)
            
            // Vorhandene Photos mit Memory verknüpfen
            await linkExistingPhotosToMemory(memory: memory, photoURLs: offlineMemory.photoURLs)
            
            // Offline Data löschen
            UserDefaults.standard.removeObject(forKey: key)
            
            DebugLogger.shared.log("✅ Offline Memory synced: \(offlineMemory.title)")
            
        } catch {
            DebugLogger.shared.log("❌ Offline Memory Sync Fehler: \(error.localizedDescription)")
        }
    }
    
    private func createLocationFromCoordinates(latitude: Double?, longitude: Double?) -> CLLocation? {
        guard let latitude = latitude, let longitude = longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    private func linkExistingPhotosToMemory(memory: Memory, photoURLs: [String]) async {
        let context = persistenceController.container.newBackgroundContext()
        
        await context.perform {
            do {
                // Memory im Background Context finden
                let memoryRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
                memoryRequest.predicate = NSPredicate(format: "id == %@", memory.id! as CVarArg)
                
                guard let backgroundMemory = try context.fetch(memoryRequest).first else {
                    return
                }
                
                // Photo Entities für vorhandene URLs erstellen
                for photoURL in photoURLs {
                    let photo = Photo(context: context)
                    photo.id = UUID()
                    
                    // Dateinamen aus URL extrahieren
                    let filename = URL(fileURLWithPath: photoURL).lastPathComponent
                    photo.filename = filename
                    
                    photo.localURL = photoURL
                    photo.createdAt = Date()
                    photo.memory = backgroundMemory
                }
                
                try context.save()
                DebugLogger.shared.log("🔗 Bestehende Photos mit Memory verknüpft")
                
            } catch {
                DebugLogger.shared.log("❌ Photo Linking Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updatePendingCount() {
        let offlineMemoryIDs = UserDefaults.standard.stringArray(forKey: "offlineMemoryIDs") ?? []
        pendingMemoriesCount = offlineMemoryIDs.count
    }
    
    func getPendingMemoriesCount() -> Int {
        return UserDefaults.standard.stringArray(forKey: "offlineMemoryIDs")?.count ?? 0
    }
    
    func clearOfflineMemories() {
        let offlineMemoryIDs = UserDefaults.standard.stringArray(forKey: "offlineMemoryIDs") ?? []
        
        for memoryID in offlineMemoryIDs {
            UserDefaults.standard.removeObject(forKey: "offlineMemory_\(memoryID)")
        }
        
        UserDefaults.standard.removeObject(forKey: "offlineMemoryIDs")
        
        DispatchQueue.main.async {
            self.pendingMemoriesCount = 0
        }
        
        DebugLogger.shared.log("🧹 Offline Memories geleert")
    }
    
    // MARK: - Auto-Memory Creation
    
    /// Erstellt automatisch eine Memory bei signifikanten Location Changes
    func createAutoMemoryIfNeeded(for trip: Trip, by user: User) async {
        guard let currentLocation = locationManager.currentLocation else { return }
        
        // Prüfe ob bereits kürzlich eine Auto-Memory erstellt wurde
        let lastAutoMemoryKey = "lastAutoMemory_\(trip.id!.uuidString)"
        let lastAutoMemoryTime = UserDefaults.standard.double(forKey: lastAutoMemoryKey)
        let timeSinceLastAuto = Date().timeIntervalSince1970 - lastAutoMemoryTime
        
        // Mindestens 30 Minuten zwischen Auto-Memories
        guard timeSinceLastAuto > 30 * 60 else { return }
        
        let autoMemoryTitle = "Automatische Standort-Erinnerung"
        let autoMemoryContent = "Automatisch erstellt um \(DateFormatter.timeFormatter.string(from: Date()))"
        
        let data = MemoryCreationData(
            title: autoMemoryTitle,
            content: autoMemoryContent,
            photos: [],
            location: currentLocation,
            tripID: trip.id!,
            userID: user.id!
        )
        
        let result = await createMemory(data: data)
        
        switch result {
        case .success, .offline:
            // Zeitstempel für nächste Auto-Memory speichern
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastAutoMemoryKey)
            DebugLogger.shared.log("✅ Auto-Memory erstellt")
            
        case .failure:
            DebugLogger.shared.log("❌ Auto-Memory Creation fehlgeschlagen")
        }
    }
}

// MARK: - Memory Creation Errors

enum MemoryCreationError: LocalizedError {
    case invalidTripOrUser
    case photoSaveFailed
    case coreDataError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidTripOrUser:
            return "Invalid trip or user for memory creation"
        case .photoSaveFailed:
            return "Failed to save photos for memory"
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        }
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
} 