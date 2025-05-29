import Foundation
import CoreLocation
import CoreData
import UserNotifications
import UIKit

/// LocationManager für GPS-Tracking mit intelligenter Batterie-Optimierung
/// und automatischer Pause-Erkennung
class LocationManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = LocationManager()
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var isPaused = false
    @Published var trackingAccuracy: LocationAccuracy = .balanced
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let coreDataManager = CoreDataManager.shared
    
    // Tracking State
    private var activeTrip: Trip?
    private var currentUser: User?
    private var lastLocationUpdate: Date?
    private var lastSignificantLocation: CLLocation?
    private var pauseTimer: Timer?
    private var batteryOptimizationEnabled = true
    
    // Configuration
    private let pauseDetectionInterval: TimeInterval = 300 // 5 Minuten
    private let minimumDistanceForUpdate: CLLocationDistance = 5 // 5 Meter
    private let maximumLocationAge: TimeInterval = 60 // 1 Minute
    
    // Offline Storage
    private var pendingMemories: [PendingMemory] = []
    
    // MARK: - Location Accuracy Levels
    enum LocationAccuracy: CaseIterable {
        case low, balanced, high, navigation
        
        var description: String {
            switch self {
            case .low: return "Energiesparend"
            case .balanced: return "Ausgewogen"
            case .high: return "Hoch"
            case .navigation: return "Navigation"
            }
        }
        
        var coreLocationAccuracy: CLLocationAccuracy {
            switch self {
            case .low: return kCLLocationAccuracyKilometer
            case .balanced: return kCLLocationAccuracyHundredMeters
            case .high: return kCLLocationAccuracyNearestTenMeters
            case .navigation: return kCLLocationAccuracyBest
            }
        }
        
        var distanceFilter: CLLocationDistance {
            switch self {
            case .low: return 100
            case .balanced: return 50
            case .high: return 10
            case .navigation: return 5
            }
        }
    }
    
    // MARK: - Pending Memory für Offline-Speicherung
    struct PendingMemory {
        let title: String
        let content: String?
        let latitude: Double
        let longitude: Double
        let timestamp: Date
        let tripID: UUID
        let userID: UUID
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        setupBatteryMonitoring()
        loadPendingMemories()
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = false
        authorizationStatus = locationManager.authorizationStatus
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Permission Management
    
    func requestPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showLocationSettingsAlert()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Tracking Control
    
    /// GPS-Tracking für einen Trip starten
    func startTracking(for trip: Trip, user: User) {
        guard authorizationStatus == .authorizedAlways else {
            print("❌ LocationManager: Keine Berechtigung für Background-Tracking")
            requestPermission()
            return
        }
        
        activeTrip = trip
        currentUser = user
        isTracking = true
        isPaused = false
        
        updateLocationManagerSettings()
        locationManager.startUpdatingLocation()
        
        // Significant Location Changes für Batterie-Optimierung
        locationManager.startMonitoringSignificantLocationChanges()
        
        print("✅ LocationManager: Tracking gestartet für Trip '\(trip.title ?? "Unbekannt")'")
        
        // Local Notification
        scheduleTrackingNotification(isStarting: true)
    }
    
    /// GPS-Tracking stoppen
    func stopTracking() {
        isTracking = false
        isPaused = false
        
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        pauseTimer?.invalidate()
        pauseTimer = nil
        
        // Pending Memories verarbeiten
        processPendingMemories()
        
        print("⏹️ LocationManager: Tracking gestoppt")
        
        // Local Notification
        scheduleTrackingNotification(isStarting: false)
        
        activeTrip = nil
        currentUser = nil
    }
    
    /// Tracking-Genauigkeit ändern
    func setTrackingAccuracy(_ accuracy: LocationAccuracy) {
        trackingAccuracy = accuracy
        updateLocationManagerSettings()
        
        print("🎯 LocationManager: Genauigkeit geändert zu \(accuracy.description)")
    }
    
    /// Manuell ein Memory erstellen
    func createManualMemory(title: String, content: String? = nil, location: CLLocation? = nil) {
        guard let trip = activeTrip, let user = currentUser else {
            print("❌ LocationManager: Kein aktiver Trip oder User")
            return
        }
        
        let useLocation = location ?? currentLocation
        guard let finalLocation = useLocation else {
            print("❌ LocationManager: Keine Location verfügbar")
            return
        }
        
        createMemory(
            title: title,
            content: content,
            location: finalLocation,
            trip: trip,
            user: user
        )
    }
    
    // MARK: - Private Methods
    
    private func updateLocationManagerSettings() {
        locationManager.desiredAccuracy = trackingAccuracy.coreLocationAccuracy
        locationManager.distanceFilter = trackingAccuracy.distanceFilter
        
        // Batterie-Optimierung anwenden
        if batteryOptimizationEnabled {
            applyBatteryOptimization()
        }
    }
    
    private func applyBatteryOptimization() {
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        // Bei niedrigem Batteriestand automatisch reduzierte Genauigkeit
        if batteryLevel < 0.2 && batteryState != .charging {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 100
            print("🔋 LocationManager: Batterie-Optimierung aktiviert (Niedriger Ladestand)")
        } else if batteryLevel < 0.5 && batteryState != .charging {
            locationManager.desiredAccuracy = max(trackingAccuracy.coreLocationAccuracy, kCLLocationAccuracyNearestTenMeters)
            locationManager.distanceFilter = max(trackingAccuracy.distanceFilter, 25)
            print("🔋 LocationManager: Mittlere Batterie-Optimierung aktiviert")
        }
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        // Location-Validierung
        guard isLocationValid(location) else { return }
        
        currentLocation = location
        lastLocationUpdate = Date()
        
        // Pause-Erkennung zurücksetzen
        resetPauseDetection()
        
        // Automatische Memory-Erstellung bei signifikanten Bewegungen
        if shouldCreateAutomaticMemory(for: location) {
            createAutomaticMemory(at: location)
        }
        
        lastSignificantLocation = location
    }
    
    private func isLocationValid(_ location: CLLocation) -> Bool {
        // Zu alte Locations ignorieren
        if location.timestamp.timeIntervalSinceNow < -maximumLocationAge {
            return false
        }
        
        // Ungenaue Locations ignorieren
        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 100 {
            return false
        }
        
        return true
    }
    
    private func shouldCreateAutomaticMemory(for location: CLLocation) -> Bool {
        guard let lastLocation = lastSignificantLocation else { return true }
        
        let distance = location.distance(from: lastLocation)
        let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
        
        // Mindestdistanz oder Mindestzeit erreicht
        return distance >= minimumDistanceForUpdate || timeInterval >= 300 // 5 Minuten
    }
    
    private func createAutomaticMemory(at location: CLLocation) {
        guard let trip = activeTrip, let user = currentUser else { return }
        
        let title = generateAutomaticMemoryTitle(for: location)
        
        createMemory(
            title: title,
            content: nil,
            location: location,
            trip: trip,
            user: user
        )
    }
    
    private func generateAutomaticMemoryTitle(for location: CLLocation) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Standort um \(formatter.string(from: location.timestamp))"
    }
    
    private func createMemory(title: String, content: String?, location: CLLocation, trip: Trip, user: User) {
        // Offline-Speicherung wenn keine Core Data Verbindung
        if !isConnectedToCoreData() {
            storePendingMemory(
                title: title,
                content: content,
                location: location,
                trip: trip,
                user: user
            )
            return
        }
        
        // Background Context für Performance
        coreDataManager.performBackgroundTask { context in
            // Objektreferenzen im Background Context holen
            guard let bgTrip = context.object(with: trip.objectID) as? Trip,
                  let bgUser = context.object(with: user.objectID) as? User else {
                print("❌ LocationManager: Fehler beim Abrufen der Objektreferenzen")
                return
            }
            
            let memory = Memory(context: context)
            memory.id = UUID()
            memory.title = title
            memory.content = content
            memory.latitude = location.coordinate.latitude
            memory.longitude = location.coordinate.longitude
            memory.timestamp = location.timestamp
            memory.createdAt = Date()
            memory.author = bgUser
            memory.trip = bgTrip
            
            self.coreDataManager.saveContext(context: context)
            
            Task { @MainActor in
                print("📍 LocationManager: Memory '\(title)' erstellt")
            }
        }
    }
    
    private func isConnectedToCoreData() -> Bool {
        // Einfache Verbindungsprüfung
        return coreDataManager.persistentContainer.viewContext.persistentStoreCoordinator != nil
    }
    
    private func storePendingMemory(title: String, content: String?, location: CLLocation, trip: Trip, user: User) {
        let pendingMemory = PendingMemory(
            title: title,
            content: content,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            tripID: trip.id!,
            userID: user.id!
        )
        
        pendingMemories.append(pendingMemory)
        savePendingMemories()
        
        print("💾 LocationManager: Memory offline gespeichert")
    }
    
    // MARK: - Pause Detection
    
    private func resetPauseDetection() {
        if isPaused {
            isPaused = false
            print("▶️ LocationManager: Bewegung erkannt - Tracking fortgesetzt")
        }
        
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: pauseDetectionInterval, repeats: false) { [weak self] _ in
            self?.detectPause()
        }
    }
    
    private func detectPause() {
        guard isTracking else { return }
        
        isPaused = true
        
        // Energie sparen während der Pause
        locationManager.stopUpdatingLocation()
        
        // Nur auf signifikante Location Changes hören
        locationManager.startMonitoringSignificantLocationChanges()
        
        print("⏸️ LocationManager: Pause erkannt - Energiesparmodus aktiviert")
    }
    
    // MARK: - Battery Monitoring
    
    @objc private func batteryLevelChanged() {
        if batteryOptimizationEnabled && isTracking {
            applyBatteryOptimization()
        }
    }
    
    @objc private func batteryStateChanged() {
        if batteryOptimizationEnabled && isTracking {
            applyBatteryOptimization()
        }
    }
    
    // MARK: - Offline Storage
    
    private func savePendingMemories() {
        if let data = try? JSONEncoder().encode(pendingMemories) {
            UserDefaults.standard.set(data, forKey: "PendingMemories")
        }
    }
    
    private func loadPendingMemories() {
        guard let data = UserDefaults.standard.data(forKey: "PendingMemories"),
              let memories = try? JSONDecoder().decode([PendingMemory].self, from: data) else {
            return
        }
        
        pendingMemories = memories
        print("📂 LocationManager: \(memories.count) pending Memories geladen")
    }
    
    func clearOfflineData() {
        pendingMemories.removeAll()
        UserDefaults.standard.removeObject(forKey: "PendingMemories")
        print("🧹 LocationManager: Offline-Daten gelöscht")
    }
    
    private func processPendingMemories() {
        guard !pendingMemories.isEmpty else { return }
        
        print("🔄 LocationManager: Verarbeite \(pendingMemories.count) pending Memories")
        
        coreDataManager.performBackgroundTask { context in
            for pendingMemory in self.pendingMemories {
                // Trip und User anhand der IDs finden
                let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
                tripRequest.predicate = NSPredicate(format: "id == %@", pendingMemory.tripID as CVarArg)
                
                let userRequest: NSFetchRequest<User> = User.fetchRequest()
                userRequest.predicate = NSPredicate(format: "id == %@", pendingMemory.userID as CVarArg)
                
                do {
                    guard let trip = try context.fetch(tripRequest).first,
                          let user = try context.fetch(userRequest).first else {
                        continue
                    }
                    
                    let memory = Memory(context: context)
                    memory.id = UUID()
                    memory.title = pendingMemory.title
                    memory.content = pendingMemory.content
                    memory.latitude = pendingMemory.latitude
                    memory.longitude = pendingMemory.longitude
                    memory.timestamp = pendingMemory.timestamp
                    memory.createdAt = Date()
                    memory.author = user
                    memory.trip = trip
                    
                } catch {
                    print("❌ LocationManager: Fehler beim Verarbeiten von pending Memory: \(error)")
                }
            }
            
            self.coreDataManager.saveContext(context: context)
            
            Task { @MainActor in
                self.pendingMemories.removeAll()
                self.savePendingMemories()
                print("✅ LocationManager: Alle pending Memories verarbeitet")
            }
        }
    }
    
    // MARK: - Notifications
    
    private func scheduleTrackingNotification(isStarting: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "TravelCompanion"
        content.body = isStarting ? "GPS-Tracking gestartet" : "GPS-Tracking gestoppt"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "tracking_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showLocationSettingsAlert() {
        // Diese Methode sollte in der UI-Schicht implementiert werden
        print("⚠️ LocationManager: Benutzer sollte zu den Einstellungen weitergeleitet werden")
    }
    
    // MARK: - Deinitializer
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        pauseTimer?.invalidate()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        handleLocationUpdate(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager: Location update failed - \(error.localizedDescription)")
        
        // Bei kritischen Fehlern Tracking stoppen
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("❌ LocationManager: Location access denied")
                stopTracking()
            case .locationUnknown:
                print("⚠️ LocationManager: Location unknown - continuing...")
            case .network:
                print("⚠️ LocationManager: Network error - continuing...")
            default:
                print("⚠️ LocationManager: Other location error - continuing...")
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .notDetermined:
            print("📍 LocationManager: Authorization not determined")
        case .denied, .restricted:
            print("❌ LocationManager: Location access denied or restricted")
            if isTracking {
                stopTracking()
            }
        case .authorizedWhenInUse:
            print("⚠️ LocationManager: Only foreground location access - request always authorization for tracking")
        case .authorizedAlways:
            print("✅ LocationManager: Full location access granted")
        @unknown default:
            print("❓ LocationManager: Unknown authorization status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("📍 LocationManager: Region betreten: \(region.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("📍 LocationManager: Region verlassen: \(region.identifier)")
    }
}

// MARK: - Codable Support für PendingMemory

extension LocationManager.PendingMemory: Codable {} 