//
//  LocationValidator.swift
//  TravelCompanion
//
//  Created on 2024.
//

import Foundation
import CoreLocation

/// Utilities für sichere Location- und Koordinaten-Validierung
struct LocationValidator {
    
    /// Validiert ob Koordinaten gültig sind
    static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        return latitude.isFinite && longitude.isFinite &&
               latitude >= -90.0 && latitude <= 90.0 &&
               longitude >= -180.0 && longitude <= 180.0
    }
    
    /// Validiert ob eine CLLocation gültig ist
    static func isValidLocation(_ location: CLLocation?) -> Bool {
        guard let location = location else { return false }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        return isValidCoordinate(latitude: lat, longitude: lon) &&
               location.horizontalAccuracy >= 0 &&
               location.horizontalAccuracy.isFinite
    }
    
    /// Bereinigt Koordinaten und stellt sicher, dass sie gültig sind
    static func sanitizeCoordinates(latitude: Double, longitude: Double) -> (lat: Double, lon: Double) {
        let safeLat = latitude.isFinite ? max(-90.0, min(90.0, latitude)) : 0.0
        let safeLon = longitude.isFinite ? max(-180.0, min(180.0, longitude)) : 0.0
        
        return (lat: safeLat, lon: safeLon)
    }
    
    /// Erstellt eine sichere CLLocation mit validierten Koordinaten
    static func createSafeLocation(latitude: Double, longitude: Double, accuracy: Double? = nil) -> CLLocation {
        let sanitized = sanitizeCoordinates(latitude: latitude, longitude: longitude)
        
        if let accuracy = accuracy, accuracy >= 0 && accuracy.isFinite {
            return CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: sanitized.lat, longitude: sanitized.lon),
                altitude: 0,
                horizontalAccuracy: accuracy,
                verticalAccuracy: -1,
                timestamp: Date()
            )
        } else {
            return CLLocation(latitude: sanitized.lat, longitude: sanitized.lon)
        }
    }
    
    /// Formatiert horizontalAccuracy sicher für UI-Anzeige
    static func formatAccuracy(_ accuracy: Double) -> String {
        if accuracy >= 0 && accuracy.isFinite {
            return "±\(Int(accuracy))m"
        } else {
            return "Unbekannt"
        }
    }
    
    /// Formatiert Koordinaten sicher für UI-Anzeige
    static func formatCoordinates(latitude: Double, longitude: Double, precision: Int = 6) -> String {
        let sanitized = sanitizeCoordinates(latitude: latitude, longitude: longitude)
        return String(format: "%.\(precision)f, %.\(precision)f", sanitized.lat, sanitized.lon)
    }
    
    /// Prüft ob zwei Locations ähnlich sind (für Duplikat-Erkennung)
    static func areLocationsSimilar(_ location1: CLLocation, _ location2: CLLocation, threshold: Double = 10.0) -> Bool {
        guard isValidLocation(location1) && isValidLocation(location2) else {
            return false
        }
        
        return location1.distance(from: location2) <= threshold
    }
}

// MARK: - CLLocation Extensions für sichere Verwendung

extension CLLocation {
    
    /// Gibt true zurück wenn die Location valide ist
    var isValid: Bool {
        return LocationValidator.isValidLocation(self)
    }
    
    /// Formatierte Genauigkeit für UI
    var formattedAccuracy: String {
        return LocationValidator.formatAccuracy(horizontalAccuracy)
    }
    
    /// Bereinigte Version dieser Location
    var sanitized: CLLocation {
        return LocationValidator.createSafeLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            accuracy: horizontalAccuracy >= 0 ? horizontalAccuracy : nil
        )
    }
} 