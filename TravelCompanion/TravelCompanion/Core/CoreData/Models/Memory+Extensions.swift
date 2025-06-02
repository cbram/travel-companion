//
//  Memory+Extensions.swift
//  TravelCompanion
//
//  Created on 2024.
//

import Foundation
import CoreData
import CoreLocation

// MARK: - Memory Extensions
extension Memory {
    
    // MARK: - Computed Properties
    
    /// Formatierter Memory Titel
    var formattedTitle: String {
        return title?.isEmpty == false ? title! : "Unbenannte Erinnerung"
    }
    
    /// Formatiertes Timestamp
    var formattedTimestamp: String {
        guard let timestamp = timestamp else { return "Unbekannt" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Formatiertes Datum (ohne Zeit)
    var formattedDate: String {
        guard let timestamp = timestamp else { return "Unbekannt" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }
    
    /// Formatierte Zeit
    var formattedTime: String {
        guard let timestamp = timestamp else { return "Unbekannt" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Location als CLLocation - SICHER vor NaN-Werten
    var location: CLLocation {
        // Validiere Koordinaten bevor CLLocation erstellt wird
        let lat = latitude.isFinite ? latitude : 0.0
        let lon = longitude.isFinite ? longitude : 0.0
        
        // Zusätzliche Validierung für gültige Koordinatenbereiche
        let validLat = max(-90.0, min(90.0, lat))
        let validLon = max(-180.0, min(180.0, lon))
        
        return CLLocation(latitude: validLat, longitude: validLon)
    }
    
    /// Koordinaten als String - KANN NaN enthalten für Debug-Zwecke
    var coordinatesString: String {
        return String(format: "%.6f, %.6f", latitude, longitude)
    }
    
    /// Formatierte Location für Display - SICHER vor NaN-Werten
    var formattedLocation: String {
        // Sichere Formatierung der Koordinaten für UI
        let safeLat = latitude.isFinite ? latitude : 0.0
        let safeLon = longitude.isFinite ? longitude : 0.0
        return String(format: "%.4f°, %.4f°", safeLat, safeLon)
    }
    
    /// NEUE EIGENSCHAFT: Sichere formatierte Location die NaN-Werte abfängt
    var safeFormattedLocation: String {
        // Verwende LocationValidator für sichere Formatierung
        guard LocationValidator.isValidCoordinate(latitude: latitude, longitude: longitude) else {
            return "Standort unbekannt"
        }
        
        return LocationValidator.formatCoordinates(latitude: latitude, longitude: longitude, precision: 4)
    }
    
    /// Anzahl der Fotos
    var photosCount: Int {
        return photos?.count ?? 0
    }
    
    /// Alle Fotos als Array
    var photosArray: [Photo] {
        let photos = photos?.allObjects as? [Photo] ?? []
        return photos.sorted { $0.createdAt ?? Date.distantPast < $1.createdAt ?? Date.distantPast }
    }
    
    /// Erstes Foto des Memory
    func firstPhoto() -> Photo? {
        guard let photos = photos, photos.count > 0 else { return nil }
        return photos.allObjects.first as? Photo
    }
    
    /// Content Vorschau (erste 100 Zeichen)
    var contentPreview: String {
        guard let content = content, !content.isEmpty else { return "Keine Beschreibung" }
        return content.count > 100 ? String(content.prefix(100)) + "..." : content
    }
    
    // MARK: - Convenience Methods
    
    /// Holt Memories für einen Trip
    static func fetchMemories(for trip: Trip, in context: NSManagedObjectContext) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", trip)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Memory: Fehler beim Laden der Memories für Trip: \(error)")
            return []
        }
    }
    
    /// Holt Memories für einen User
    static func fetchMemories(for user: User, in context: NSManagedObjectContext) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "author == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Memory: Fehler beim Laden der Memories für User: \(error)")
            return []
        }
    }
    
    /// Holt Memories in der Nähe einer Location
    static func fetchMemories(near latitude: Double, longitude: Double, radius: Double, in context: NSManagedObjectContext) -> [Memory] {
        let request = Memory.fetchRequest()
        
        // Berechne bounding box für Radius
        let latitudeDelta = radius / 111000 // ~111km pro Grad
        let longitudeDelta = radius / (111000 * cos(latitude * .pi / 180))
        
        let minLat = latitude - latitudeDelta
        let maxLat = latitude + latitudeDelta
        let minLon = longitude - longitudeDelta
        let maxLon = longitude + longitudeDelta
        
        request.predicate = NSPredicate(format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f", minLat, maxLat, minLon, maxLon)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            let memories = try context.fetch(request)
            // Filtere nach genauer Distanz
            let targetLocation = CLLocation(latitude: latitude, longitude: longitude)
            return memories.filter { memory in
                memory.location.distance(from: targetLocation) <= radius
            }
        } catch {
            print("❌ Memory: Fehler beim Laden der Memories in der Nähe: \(error)")
            return []
        }
    }
    
    /// Holt Memories in einem Zeitraum
    static func fetchMemories(from startDate: Date, to endDate: Date, in context: NSManagedObjectContext) -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Memory: Fehler beim Laden der Memories im Zeitraum: \(error)")
            return []
        }
    }
    
    /// Berechnet Distanz zu einer anderen Memory
    func distance(to other: Memory) -> Double {
        return location.distance(from: other.location)
    }
    
    /// Berechnet Distanz zu einer Location
    func distance(to location: CLLocation) -> Double {
        return self.location.distance(from: location)
    }
    
    /// Fügt ein Photo hinzu
    func addPhoto(_ photo: Photo) {
        addToPhotos(photo)
    }
    
    /// Entfernt ein Photo
    func removePhoto(_ photo: Photo) {
        removeFromPhotos(photo)
    }
} 