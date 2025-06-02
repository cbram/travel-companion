//
//  CLLocationExtensions.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import Foundation
import CoreLocation

extension CLLocation {
    
    /// Formatierte Koordinaten für Debug-Ausgabe
    var formattedCoordinates: String {
        return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
    
    /// Kurze Koordinaten-Darstellung
    var shortCoordinates: String {
        return String(format: "%.3f, %.3f", coordinate.latitude, coordinate.longitude)
    }
    
    /// Prüft ob Location aktuell/valide ist
    var isRecent: Bool {
        return abs(timestamp.timeIntervalSinceNow) < 300 // 5 Minuten
    }
    
    /// Prüft ob Genauigkeit akzeptabel ist
    var hasAcceptableAccuracy: Bool {
        return horizontalAccuracy >= 0 && horizontalAccuracy <= 100 // Bis 100m Genauigkeit
    }
    
    /// Formatierte Genauigkeits-Information
    var accuracyDescription: String {
        // SICHERE NaN-Behandlung für UI
        guard horizontalAccuracy.isFinite else {
            return "Unbekannt"
        }
        
        if horizontalAccuracy < 0 {
            return "Unbekannt"
        } else if horizontalAccuracy <= 5 {
            return "Sehr genau (±\(Int(horizontalAccuracy))m)"
        } else if horizontalAccuracy <= 20 {
            return "Genau (±\(Int(horizontalAccuracy))m)"
        } else if horizontalAccuracy <= 100 {
            return "Mäßig (±\(Int(horizontalAccuracy))m)"
        } else {
            return "Ungenau (±\(Int(horizontalAccuracy))m)"
        }
    }
    
    /// Berechnet Entfernung zu anderem Punkt mit formatierter Ausgabe
    func formattedDistance(to location: CLLocation) -> String {
        let distance = self.distance(from: location)
        
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    /// Prüft ob Location signifikant von anderer abweicht
    func isSignificantlyDifferent(from location: CLLocation, threshold: CLLocationDistance = 50) -> Bool {
        return self.distance(from: location) > threshold
    }
    
    /// NEUE EIGENSCHAFT: Sichere formatierte Koordinaten für UI
    var safeFormattedCoordinates: String {
        guard coordinate.latitude.isFinite && coordinate.longitude.isFinite else {
            return "Ungültige Koordinaten"
        }
        
        return LocationValidator.formatCoordinates(
            latitude: coordinate.latitude, 
            longitude: coordinate.longitude, 
            precision: 6
        )
    }
    
    /// NEUE EIGENSCHAFT: Sichere kurze Koordinaten für UI  
    var safeShortCoordinates: String {
        guard coordinate.latitude.isFinite && coordinate.longitude.isFinite else {
            return "N/A"
        }
        
        return LocationValidator.formatCoordinates(
            latitude: coordinate.latitude, 
            longitude: coordinate.longitude, 
            precision: 3
        )
    }
} 