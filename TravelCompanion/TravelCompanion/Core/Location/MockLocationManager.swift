import Foundation
import CoreLocation
import Combine

/// Mock LocationManager für SwiftUI Previews und Tests
/// Simuliert GPS-Funktionen ohne echte Hardware-Abhängigkeiten
class MockLocationManager: LocationManager {
    
    // MARK: - Mock Data
    private let mockLocations: [CLLocation] = [
        CLLocation(latitude: 48.1351, longitude: 11.5820), // München
        CLLocation(latitude: 52.5200, longitude: 13.4050), // Berlin
        CLLocation(latitude: 53.5511, longitude: 9.9937),  // Hamburg
        CLLocation(latitude: 50.1109, longitude: 8.6821),  // Frankfurt
        CLLocation(latitude: 51.2277, longitude: 6.7735)   // Düsseldorf
    ]
    
    private var mockLocationIndex = 0
    private var mockTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupMockLocation()
    }
    
    // MARK: - Mock Setup
    private func setupMockLocation() {
        // Setze initiale Mock-Location
        currentLocation = mockLocations[0]
        authorizationStatus = .authorizedAlways
        
        print("🎭 MockLocationManager: Initialisiert mit Mock-Daten")
    }
    
    // MARK: - Override Methods
    override func requestPermission() {
        // Simuliere Permission Grant
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.authorizationStatus = .authorizedAlways
            print("🎭 MockLocationManager: Permission gewährt (simuliert)")
        }
    }
    
    override func startTracking(for trip: Trip, user: User) {
        isTracking = true
        isPaused = false
        
        // Starte Mock-Location Updates
        startMockLocationUpdates()
        
        print("🎭 MockLocationManager: Mock-Tracking gestartet für '\(trip.title ?? "Unbekannt")'")
    }
    
    override func stopTracking() {
        isTracking = false
        isPaused = false
        
        // Stoppe Mock-Location Updates
        stopMockLocationUpdates()
        
        print("🎭 MockLocationManager: Mock-Tracking gestoppt")
    }
    
    override func createManualMemory(title: String, content: String?, location: CLLocation?) {
        let usedLocation = location ?? currentLocation ?? mockLocations[0]
        
        print("🎭 MockLocationManager: Mock Memory erstellt: '\(title)' bei \(usedLocation.coordinate)")
        
        // In echtem LocationManager würde hier Core Data verwendet
        // Für Mock geben wir nur eine Bestätigung aus
    }
    
    // MARK: - Mock Location Updates
    private func startMockLocationUpdates() {
        mockTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMockLocation()
            }
        }
    }
    
    private func stopMockLocationUpdates() {
        mockTimer?.invalidate()
        mockTimer = nil
    }
    
    private func updateMockLocation() {
        // Gehe zur nächsten Mock-Location
        mockLocationIndex = (mockLocationIndex + 1) % mockLocations.count
        currentLocation = mockLocations[mockLocationIndex]
        
        print("🎭 MockLocationManager: Mock-Location aktualisiert zu \(currentLocation?.coordinate.latitude ?? 0), \(currentLocation?.coordinate.longitude ?? 0)")
    }
    
    // MARK: - Mock Helper Methods
    
    /// Setze eine spezifische Mock-Location
    func setMockLocation(_ location: CLLocation) {
        currentLocation = location
        print("🎭 MockLocationManager: Mock-Location manuell gesetzt")
    }
    
    /// Simuliere eine Location-Änderung
    func simulateLocationChange() {
        updateMockLocation()
    }
    
    /// Simuliere Permission-Verweigerung
    func simulatePermissionDenied() {
        authorizationStatus = .denied
        print("🎭 MockLocationManager: Permission verweigert (simuliert)")
    }
    
    /// Simuliere Low-Accuracy Location
    func simulateLowAccuracy() {
        if let current = currentLocation {
            let lowAccuracyLocation = CLLocation(
                coordinate: current.coordinate,
                altitude: current.altitude,
                horizontalAccuracy: 500.0, // Niedrige Genauigkeit
                verticalAccuracy: -1,
                timestamp: Date()
            )
            currentLocation = lowAccuracyLocation
            print("🎭 MockLocationManager: Niedrige Genauigkeit simuliert")
        }
    }
    
    deinit {
        mockTimer?.invalidate()
    }
}

// MARK: - Preview Helper
extension LocationManager {
    static var preview: LocationManager {
        return MockLocationManager()
    }
} 