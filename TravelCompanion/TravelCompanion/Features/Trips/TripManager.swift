import SwiftUI
import CoreData
import Foundation

/// Manager für Trip-Management in der App
@MainActor
class TripManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = TripManager()
    
    // MARK: - Published Properties
    @Published var currentTrip: Trip?
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Private Properties
    private let coreDataManager = CoreDataManager.shared
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Lädt den aktuell aktiven Trip für einen User
    func loadActiveTrip(for user: User) {
        isLoading = true
        currentTrip = coreDataManager.fetchActiveTrip(for: user)
        isLoading = false
    }
    
    /// Startet einen neuen Trip
    func startTrip(_ trip: Trip) {
        // Alle anderen Trips als inaktiv markieren
        let user = trip.owner!
        let allTrips = coreDataManager.fetchTrips(for: user)
        
        for existingTrip in allTrips {
            existingTrip.isActive = false
        }
        
        // Neuen Trip als aktiv markieren
        trip.isActive = true
        currentTrip = trip
        
        // Speichern
        coreDataManager.save()
    }
    
    /// Beendet den aktuellen Trip
    func endCurrentTrip() {
        currentTrip?.isActive = false
        currentTrip?.endDate = Date()
        currentTrip = nil
        
        // Speichern
        coreDataManager.save()
    }
    
    /// Prüft ob aktuell ein Trip aktiv ist
    var hasActiveTrip: Bool {
        currentTrip != nil
    }
} 