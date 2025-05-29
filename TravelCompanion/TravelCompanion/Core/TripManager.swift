import Foundation
import CoreData
import Combine

/// Zentrale Service-Klasse für Trip-Management
/// Verwaltet aktive Reise, erstellt neue Reisen und stellt Trip-Daten für die gesamte App bereit
class TripManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = TripManager()
    
    // MARK: - Published Properties
    @Published var currentTrip: Trip? = nil
    @Published var allTrips: [Trip] = []
    @Published var isLoading = false
    
    // MARK: - Private Properties
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupNotifications()
        loadInitialData()
    }
    
    // MARK: - Setup Methods
    private func setupNotifications() {
        // Beobachte Core Data Änderungen
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshTrips()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        isLoading = true
        
        DispatchQueue.main.async {
            self.refreshTrips()
            self.loadCurrentTrip()
            
            // Falls keine aktive Reise vorhanden, erstelle Default Trip
            if self.currentTrip == nil {
                self.createDefaultTripIfNeeded()
            }
            
            self.isLoading = false
        }
    }
    
    // MARK: - Public Trip Management Methods
    
    /// Erstellt eine neue Reise
    func createTrip(title: String, description: String? = nil, startDate: Date = Date()) -> Trip? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ TripManager: Trip-Titel darf nicht leer sein")
            return nil
        }
        
        let trip = coreDataManager.createTrip(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            owner: getCurrentUser()
        )
        
        guard coreDataManager.save() else {
            print("❌ TripManager: Fehler beim Speichern der neuen Reise")
            return nil
        }
        
        print("✅ TripManager: Neue Reise erstellt: \(title)")
        refreshTrips()
        
        return trip
    }
    
    /// Setzt die aktive Reise
    func setActiveTrip(_ trip: Trip) {
        // Alle anderen Trips deaktivieren
        allTrips.forEach { $0.isActive = false }
        
        // Neue aktive Reise setzen
        trip.isActive = true
        currentTrip = trip
        
        guard coreDataManager.save() else {
            print("❌ TripManager: Fehler beim Setzen der aktiven Reise")
            return
        }
        
        print("✅ TripManager: Aktive Reise geändert zu: \(trip.title ?? "Unbekannt")")
        
        // LocationManager über Änderung informieren
        let user = getCurrentUser()
        LocationManager.shared.startTracking(for: trip, user: user)
    }
    
    /// Holt alle Reisen des aktuellen Users
    func getAllTrips() -> [Trip] {
        return allTrips
    }
    
    /// Löscht eine Reise
    func deleteTrip(_ trip: Trip) {
        // Wenn es die aktive Reise ist, setze eine andere als aktiv
        if trip == currentTrip {
            let remainingTrips = allTrips.filter { $0 != trip }
            if let newActiveTrip = remainingTrips.first {
                setActiveTrip(newActiveTrip)
            } else {
                currentTrip = nil
            }
        }
        
        coreDataManager.viewContext.delete(trip)
        
        guard coreDataManager.save() else {
            print("❌ TripManager: Fehler beim Löschen der Reise")
            return
        }
        
        print("✅ TripManager: Reise gelöscht: \(trip.title ?? "Unbekannt")")
        refreshTrips()
    }
    
    /// Beendet die aktuelle Reise
    func endCurrentTrip() {
        guard let trip = currentTrip else { return }
        
        trip.endDate = Date()
        trip.isActive = false
        
        guard coreDataManager.save() else {
            print("❌ TripManager: Fehler beim Beenden der Reise")
            return
        }
        
        print("✅ TripManager: Reise beendet: \(trip.title ?? "Unbekannt")")
        
        // Tracking stoppen
        LocationManager.shared.stopTracking()
        
        currentTrip = nil
        refreshTrips()
    }
    
    // MARK: - Private Helper Methods
    
    private func refreshTrips() {
        let user = getCurrentUser()
        allTrips = coreDataManager.fetchTrips(for: user)
            .sorted { $0.createdAt ?? Date.distantPast > $1.createdAt ?? Date.distantPast }
    }
    
    private func loadCurrentTrip() {
        let user = getCurrentUser()
        currentTrip = coreDataManager.fetchActiveTrip(for: user)
    }
    
    private func getCurrentUser() -> User {
        // Holt oder erstellt den aktuellen User
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let users = try coreDataManager.viewContext.fetch(request)
            if let user = users.first {
                return user
            }
        } catch {
            print("❌ TripManager: Fehler beim Laden des Users: \(error)")
        }
        
        // Erstelle neuen Default User
        return createDefaultUser()
    }
    
    private func createDefaultUser() -> User {
        let user = coreDataManager.createUser(
            email: "user@travelcompanion.app",
            displayName: "Reisender"
        )
        
        guard coreDataManager.save() else {
            fatalError("Konnte Default User nicht erstellen")
        }
        
        return user
    }
    
    private func createDefaultTripIfNeeded() {
        if allTrips.isEmpty {
            if let defaultTrip = createTrip(
                title: "Meine erste Reise",
                description: "Willkommen bei TravelCompanion! Hier können Sie Ihre Reise-Erinnerungen sammeln.",
                startDate: Date()
            ) {
                setActiveTrip(defaultTrip)
                print("✅ TripManager: Default Trip erstellt und aktiviert")
            }
        }
    }
}

// MARK: - Trip Statistics Extension
extension TripManager {
    
    /// Holt Statistiken für eine Reise
    func getStatistics(for trip: Trip) -> TripStatistics {
        let footsteps = coreDataManager.fetchFootsteps(for: trip)
        let photoCount = footsteps.compactMap { $0.photos }.flatMap { $0 }.count
        
        // Berechne Dauer basierend auf Start- und Enddatum
        let startDate = trip.startDate ?? Date()
        let endDate = trip.endDate ?? Date()
        let duration = endDate.timeIntervalSince(startDate)
        
        return TripStatistics(
            footstepCount: footsteps.count,
            photoCount: photoCount,
            duration: duration,
            startDate: startDate,
            endDate: trip.endDate
        )
    }
}

// MARK: - Trip Statistics Model
struct TripStatistics {
    let footstepCount: Int
    let photoCount: Int
    let duration: TimeInterval
    let startDate: Date
    let endDate: Date?
    
    var isActive: Bool {
        return endDate == nil
    }
    
    var formattedDuration: String {
        let days = Int(duration) / (24 * 3600)
        if days > 0 {
            return "\(days) Tag\(days == 1 ? "" : "e")"
        } else {
            let hours = Int(duration) / 3600
            return "\(hours) Stunde\(hours == 1 ? "" : "n")"
        }
    }
} 