import Foundation
import CoreData
import Combine

// MARK: - Trip Creation Result
enum TripCreationResult {
    case success(Trip)
    case noUserAvailable
    case userValidationFailed
    case saveFailed(String)
    case validationFailed(String)
}

/// Zentrale Service-Klasse für Trip-Management
/// Verwaltet aktive Reise, erstellt neue Reisen und stellt Trip-Daten für die gesamte App bereit
@MainActor
class TripManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = TripManager()
    
    // MARK: - Published Properties
    @Published var currentTrip: Trip? = nil
    @Published var allTrips: [Trip] = []
    @Published var isLoading = false
    
    // MARK: - Private Properties
    private let coreDataManager = CoreDataManager.shared
    private let userManager = UserManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var viewContext: NSManagedObjectContext {
        return coreDataManager.viewContext
    }
    
    // MARK: - Initialization
    private init() {
        setupNotifications()
        
        // Warte bis UserManager initialisiert ist
        userManager.$currentUser
            .sink { [weak self] user in
                if user != nil {
                    Task {
                        await self?.loadInitialData()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Setup Methods
    private func setupNotifications() {
        // Beobachte Core Data Änderungen
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshTripsInternal()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() async {
        guard !isLoading else { return }
        isLoading = true
        
        await refreshTripsInternal()
        await loadCurrentTrip()
        
        // Keine automatische Default-Trip-Erstellung mehr
        
        self.isLoading = false
    }
    
    // MARK: - Public Trip Management Methods
    
    /// Erstellt eine neue Reise mit verbesserter Fehlerbehandlung
    func createTripWithResult(title: String, description: String? = nil, startDate: Date = Date()) async -> TripCreationResult {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .validationFailed("Trip-Titel darf nicht leer sein")
        }
        
        // Prüfe ob ein User vorhanden ist
        guard userManager.currentUser != nil else {
            print("📝 TripManager: Kein User vorhanden - informative Meldung wird angezeigt")
            return .noUserAvailable
        }
        
        // Validiere und bereite User für Context-Operationen vor
        guard let userInContext = await validateAndPrepareUser() else {
            print("❌ TripManager: User-Validierung fehlgeschlagen")
            return .userValidationFailed
        }
        
        print("🔄 TripManager: Erstelle Trip '\(title)' für User '\(userInContext.displayName ?? "Unknown")'")
        
        // SYNCHRONOUS Trip-Erstellung im Main Context für bessere Stabilität
        let trip = coreDataManager.createTrip(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            owner: userInContext
        )
        
        // ROBUSTE Save-Operation mit Retry-Mechanismus
        var saveAttempts = 0
        let maxSaveAttempts = 3
        var lastSaveError: Error?
        
        while saveAttempts < maxSaveAttempts {
            saveAttempts += 1
            
            if coreDataManager.save() {
                print("✅ TripManager: Trip erfolgreich gespeichert (Versuch \(saveAttempts))")
                lastSaveError = nil
                break
            } else {
                lastSaveError = coreDataManager.lastSaveError
                print("❌ TripManager: Save-Versuch \(saveAttempts) fehlgeschlagen: \(lastSaveError?.localizedDescription ?? "Unknown error")")
                
                if saveAttempts < maxSaveAttempts {
                    // Kurze Pause vor erneutem Versuch
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        }
        
        // Prüfe ob alle Save-Versuche fehlgeschlagen sind
        guard saveAttempts <= maxSaveAttempts && lastSaveError == nil else {
            let errorMessage = "Alle Save-Versuche fehlgeschlagen nach \(maxSaveAttempts) Versuchen: \(lastSaveError?.localizedDescription ?? "Unbekannter Fehler")"
            print("❌ TripManager: \(errorMessage)")
            await refreshTripsInternal()
            return .saveFailed(errorMessage)
        }
        
        // VEREINFACHTE VALIDIERUNG: Prüfe nur ObjectID und grundlegende Eigenschaften
        guard !trip.objectID.isTemporaryID,
              !trip.isDeleted,
              trip.managedObjectContext == viewContext,
              trip.owner != nil else {
            let errorMessage = "Trip-Validierung fehlgeschlagen - Permanent ID: \(!trip.objectID.isTemporaryID), Not deleted: \(!trip.isDeleted), Correct context: \(trip.managedObjectContext == viewContext), Has owner: \(trip.owner != nil)"
            print("❌ TripManager: \(errorMessage)")
            await refreshTripsInternal()
            return .validationFailed(errorMessage)
        }
        
        print("✅ TripManager: Trip erfolgreich gespeichert und validiert: \(title)")
        print("   - ObjectID: \(trip.objectID)")
        print("   - Permanent ID: \(!trip.objectID.isTemporaryID)")
        print("   - Owner: \(trip.owner?.displayName ?? "Unknown")")
        
        // SICHERE Trip-Liste-Aktualisierung
        await refreshTripsInternal()
        
        // Rückgabe des erfolgreichen Ergebnisses
        return .success(trip)
    }
    
    /// Erstellt eine neue Reise (Legacy-Methode für Kompatibilität)
    func createTrip(title: String, description: String? = nil, startDate: Date = Date()) async -> Trip? {
        let result = await createTripWithResult(title: title, description: description, startDate: startDate)
        switch result {
        case .success(let trip):
        return trip
        default:
            return nil
        }
    }
    
    /// Setzt die aktive Reise
    func setActiveTrip(_ trip: Trip) async {
        print("🔄 TripManager: Setze Trip '\(trip.title ?? "Unknown")' als aktiv")
        
        // ERWEITERTE Validierung: Multi-Level Object-Check
        guard !trip.isDeleted,
              let tripContext = trip.managedObjectContext,
              tripContext == viewContext || tripContext.parent == viewContext,
              coreDataManager.isValidObject(trip) else {
            print("❌ TripManager: Trip ungültig oder in falschem Context")
            await refreshTripsInternal()
            return
        }
        
        // Sicherstellen, dass der Trip im korrekten Context ist
        guard let tripInContext = await ensureObjectInViewContext(trip) else {
            print("❌ TripManager: Fehler beim Laden des Trips in den korrekten Context")
            await refreshTripsInternal()
            return
        }
        
        // KRITISCHE Validierung nach Context-Transfer
        guard coreDataManager.isValidObject(tripInContext),
              !tripInContext.isDeleted else {
            print("❌ TripManager: Trip nach Context-Transfer ungültig")
            await refreshTripsInternal()
            return
        }
        
        // Sichere Referenz auf Trip-Eigenschaften für Logging
        let tripTitle = tripInContext.title ?? "Unbekannt"
        let tripObjectID = tripInContext.objectID
        
        // BATCH-UPDATE: Alle Trips in einer Operation deaktivieren für Atomicity
        do {
            // Fetch alle Trips des aktuellen Users
            let request = Trip.fetchRequest()
            if let currentUser = getCurrentUser() {
                request.predicate = NSPredicate(format: "owner == %@", currentUser)
            }
            request.returnsObjectsAsFaults = false
            
            let userTrips = try viewContext.fetch(request)
            
            // Batch-Deaktivierung aller anderen Trips
            for tripToUpdate in userTrips {
                if coreDataManager.isValidObject(tripToUpdate) &&
                   tripToUpdate.objectID != tripObjectID {
                    tripToUpdate.isActive = false
                }
            }
            
            // Neue aktive Reise setzen
            tripInContext.isActive = true
            
        } catch {
            print("❌ TripManager: Fehler beim Batch-Update der Trip-Status: \(error)")
            await refreshTripsInternal()
            return
        }
        
        // ATOMARER Save-Vorgang
        guard coreDataManager.save() else {
            print("❌ TripManager: Fehler beim Setzen der aktiven Reise")
            // ROLLBACK: Bei Fehler Zustand zurücksetzen
            viewContext.rollback()
            await refreshTripsInternal()
            return
        }
        
        // FINAL VALIDATION: Prüfe dass Trip nach Save noch aktiv und gültig ist
        do {
            let finalTrip = try viewContext.existingObject(with: tripObjectID) as? Trip
            guard let validatedTrip = finalTrip,
                  validatedTrip.isActive,
                  coreDataManager.isValidObject(validatedTrip) else {
                print("❌ TripManager: Trip nach Save-Validierung fehlgeschlagen")
                await refreshTripsInternal()
                return
            }
            
            // ERFOLG: Setze currentTrip nur nach vollständiger Validierung
            currentTrip = validatedTrip
            print("✅ TripManager: Aktive Reise erfolgreich geändert zu: \(tripTitle)")
            
        } catch {
            print("❌ TripManager: Final Trip-Validierung fehlgeschlagen: \(error)")
            await refreshTripsInternal()
            return
        }
    }
    
    /// Holt alle Reisen des aktuellen Users
    func getAllTrips() -> [Trip] {
        return allTrips
    }
    
    /// Löscht eine Reise
    func deleteTrip(_ trip: Trip) async {
        // Validierung: Prüfe ob Trip noch im Context existiert
        guard !trip.isDeleted && trip.managedObjectContext != nil else {
            print("⚠️ TripManager: Trip bereits gelöscht oder nicht im Context")
            await refreshTripsInternal()
            return
        }
        
        // Sicherstellen, dass der Trip im korrekten Context ist
        guard let tripInContext = await ensureObjectInViewContext(trip) else {
            print("❌ TripManager: Fehler beim Laden des Trips in den korrekten Context für Löschung")
            await refreshTripsInternal()
            return
        }
        
        // Temporäre Referenz auf Trip-Eigenschaften vor dem Löschen
        let tripTitle = tripInContext.title ?? "Unbekannt"
        let wasActiveTrip = tripInContext == currentTrip
        let tripObjectID = tripInContext.objectID
        
        // WICHTIG: Trip aus lokaler Liste entfernen BEVOR es gelöscht wird
        if let index = allTrips.firstIndex(where: { $0.objectID == tripObjectID }) {
            allTrips.remove(at: index)
        }
        
        // Wenn es die aktive Reise ist, currentTrip sofort zurücksetzen
        if wasActiveTrip {
            currentTrip = nil
        }
        
        // Trip aus CoreData löschen
        coreDataManager.deleteObject(tripInContext)
        
        // Speichern mit Fehlerbehandlung
        guard coreDataManager.save() else {
            print("❌ TripManager: Fehler beim Löschen der Reise")
            // Bei Fehler: Liste neu laden um Konsistenz zu gewährleisten
            await refreshTripsInternal()
            return
        }
        
        // NACH erfolgreichem Löschen: Neue aktive Reise setzen falls nötig
        if wasActiveTrip && !allTrips.isEmpty {
            if let newActiveTrip = allTrips.first {
                // Sichere Aktivierung ohne Mutation des gelöschten Objects
                newActiveTrip.isActive = true
                if coreDataManager.save() {
                    currentTrip = newActiveTrip
                    print("✅ TripManager: Neue aktive Reise gesetzt: \(newActiveTrip.title ?? "Unbekannt")")
                }
            }
        }
        
        print("✅ TripManager: Reise gelöscht: \(tripTitle)")
        
        // Abschließende Synchronisation
        await refreshTripsInternal()
    }
    
    /// Beendet die aktuelle Reise
    func endCurrentTrip() async {
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
        await refreshTripsInternal()
    }
    
    /// Aktualisiert die Trip-Liste manuell
    func refreshTrips() async {
        await refreshTripsInternal()
    }
    
    // MARK: - Private Helper Methods
    
    private func refreshTripsInternal() async {
        guard let user = getCurrentUser() else {
            allTrips = []
            return
        }
        
        allTrips = Trip.fetchAllTrips(for: user, in: viewContext)
    }
    
    private func loadCurrentTrip() async {
        guard let user = getCurrentUser() else {
            currentTrip = nil
            return
        }
        
        let activeTrips = Trip.fetchActiveTrips(in: viewContext)
        // Filter active trips for current user since fetchActiveTrips doesn't take user parameter
        let userActiveTrips = activeTrips.filter { $0.owner == user }
        currentTrip = userActiveTrips.first
    }
    
    private func getCurrentUser() -> User? {
        return userManager.currentUser
    }
    
    // MARK: - Context Management Helper
    
    /// Stellt sicher, dass ein Core Data Object im ViewContext verfügbar ist
    private func ensureObjectInViewContext<T: NSManagedObject>(_ object: T) async -> T? {
        // FAST PATH: Object bereits im viewContext
        if object.managedObjectContext == viewContext {
            return object
        }
        
        // SAFETY CHECK: Object-Validierung vor Transfer
        guard !object.isDeleted,
              object.managedObjectContext != nil else {
            print("❌ TripManager: Object ungültig für Context-Transfer")
            return nil
        }
        
        do {
            // VERBESSERTE Context-Transfer-Logik
            let objectInViewContext = try viewContext.existingObject(with: object.objectID) as? T
            
            // VALIDIERUNG nach Transfer
            guard let transferredObject = objectInViewContext,
                  !transferredObject.isDeleted,
                  transferredObject.managedObjectContext == viewContext else {
                print("❌ TripManager: Object-Transfer fehlgeschlagen oder ungültig")
                return nil
            }
            
            return transferredObject
            
        } catch {
            print("❌ TripManager: Fehler beim Laden des Objects in viewContext: \(error)")
            
            // SPEZIELLE User-Recovery
            if object is User {
                print("🔄 TripManager: Versuche User-Reload aus UserManager...")
                self.userManager.loadOrCreateDefaultUser()
                
                // Warte kurz und versuche erneut (non-blocking)
                try? await Task.sleep(for: .milliseconds(100))
                
                if self.userManager.currentUser != nil {
                    print("✅ TripManager: User erfolgreich neu geladen nach Fehler")
                }
            }
            
            return nil
        }
    }
    
    /// Validiert und bereitet User für Context-Operationen vor
    private func validateAndPrepareUser() async -> User? {
        guard let currentUser = userManager.currentUser else {
            print("❌ TripManager: Kein aktueller User verfügbar")
            return nil
        }
        
        // KRITISCH: Prüfe ob User im korrekten Context ist
        if currentUser.managedObjectContext != viewContext {
            print("⚠️ TripManager: User nicht im ViewContext - lade neu...")
            
            // User im korrekten Context finden
            let request = User.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", currentUser.id! as CVarArg)
            request.fetchLimit = 1
            
            do {
                if let userInContext = try viewContext.fetch(request).first {
                    print("✅ TripManager: User erfolgreich in ViewContext geladen")
                    return userInContext
                } else {
                    print("❌ TripManager: User nicht im ViewContext gefunden")
                    return nil
                }
            } catch {
                print("❌ TripManager: Fehler beim Laden des Users: \(error)")
                return nil
            }
        }
        
        // ZUSÄTZLICHE Validierung: Prüfe Object-Gültigkeit
        guard !currentUser.isDeleted,
              coreDataManager.isValidObject(currentUser) else {
            print("❌ TripManager: User-Validierung fehlgeschlagen")
            return nil
        }
        
        return currentUser
    }
    
    // MARK: - Debugging and Validation
    
    /// Validiert den aktuellen Zustand des TripManagers
    func validateState() {
        print("\n🔍 TripManager State Validation")
        print("===============================")
        print("Current Trip: \(currentTrip?.title ?? "nil")")
        print("All Trips Count: \(allTrips.count)")
        
        var activeTripsCount = 0
        for trip in allTrips {
            if trip.isActive {
                activeTripsCount += 1
                print("  ✅ Active Trip: \(trip.title ?? "Unknown") (ID: \(trip.objectID))")
            } else {
                print("  ⚪ Inactive Trip: \(trip.title ?? "Unknown")")
            }
            
            // Validiere CoreData Context
            if !coreDataManager.isValidObject(trip) {
                print("  ⚠️ Invalid Trip Object: \(trip.title ?? "Unknown")")
            }
        }
        
        if activeTripsCount > 1 {
            print("❌ FEHLER: Mehrere aktive Trips gefunden! (\(activeTripsCount))")
        } else if activeTripsCount == 0 && !allTrips.isEmpty {
            print("⚠️ WARNUNG: Trips vorhanden aber keine aktiv")
        } else {
            print("✅ Trip-Status OK")
        }
        
        print("===============================\n")
    }
    
    /// NEUE FUNKTION: Test Trip-Erstellung mit vollständiger Validierung
    func debugCreateTrip() async {
        print("\n🧪 TripManager Debug: Test-Trip-Erstellung")
        print("==========================================")
        
        // UserManager Status prüfen
        print("👤 User Status:")
        print("   - Current User: \(self.userManager.currentUser?.displayName ?? "nil")")
        print("   - User Valid: \(self.userManager.validateCurrentUser())")
        
        // Context Status prüfen
        print("📊 Context Status:")
        print("   - View Context: \(viewContext)")
        print("   - Has Changes: \(viewContext.hasChanges)")
        
        // Test-Trip erstellen
        let testTitle = "Debug Test Reise \(Date().timeIntervalSince1970)"
        print("🔨 Erstelle Test-Trip: '\(testTitle)'")
        
        if let trip = await createTrip(title: testTitle, description: "Debug Test Beschreibung") {
            print("✅ Test-Trip erfolgreich erstellt:")
            print("   - Titel: \(trip.title ?? "nil")")
            print("   - ID: \(trip.objectID)")
            print("   - Owner: \(trip.owner?.displayName ?? "nil")")
            print("   - In allTrips: \(allTrips.contains(where: { $0.objectID == trip.objectID }))")
            
            // Trip wieder löschen
            print("🗑️ Lösche Test-Trip...")
            await deleteTrip(trip)
            print("✅ Test-Trip gelöscht")
        } else {
            print("❌ Test-Trip-Erstellung fehlgeschlagen")
        }
        
        print("==========================================\n")
    }
    
    /// NEUE FUNKTION: Automatische Diagnose und Problem-Behebung
    func diagnoseAndFix() async {
        print("\n🩺 TripManager: Starte automatische Diagnose...")
        print("================================================")
        
        // 1. Validiere aktuellen State
        validateState()
        
        // 2. Prüfe UserManager
        print("👤 UserManager-Diagnose:")
        let userValid = userManager.validateCurrentUser()
        print("   - User Valid: \(userValid)")
        if !userValid {
            print("🔧 Lade User neu...")
            userManager.loadOrCreateDefaultUser()
        }
        
        // 3. Prüfe CoreData Integrität
        print("📊 CoreData-Diagnose:")
        coreDataManager.validateDatabaseIntegrity()
        
        // 4. Automatische Problem-Behebung
        print("🔧 Starte automatische Reparaturen...")
        coreDataManager.fixDatabaseIssues()
        
        // 5. Aktualisiere lokale Trip-Liste
        print("🔄 Aktualisiere Trip-Liste...")
        await refreshTripsInternal()
        
        // 6. Final-Validierung
        print("✅ Final-Validierung:")
        validateState()
        
        print("================================================")
        print("🏁 Diagnose und Reparatur abgeschlossen\n")
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
