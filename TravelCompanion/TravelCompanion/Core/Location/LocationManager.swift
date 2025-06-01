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
        locationManager.distanceFilter = 10
        authorizationStatus = locationManager.authorizationStatus
        
        // Request initial location if authorized
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation() // Sofortiger Location-Abruf
        }
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
        
        // Background Location Updates für kontinuierliches Tracking
        if UIApplication.shared.backgroundRefreshStatus == .available {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            print("✅ LocationManager: Background Location Updates aktiviert")
        } else {
            print("⚠️ LocationManager: Background App Refresh nicht verfügbar")
        }
        
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
        
        // Background Location Updates deaktivieren
        if locationManager.allowsBackgroundLocationUpdates {
            locationManager.allowsBackgroundLocationUpdates = false
            print("✅ LocationManager: Background Location Updates deaktiviert")
        }
        
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
        let batteryLevel = UIDevice.current.batteryLevel
        
        if batteryLevel < 0.2 && batteryOptimizationEnabled {
            // Bei niedriger Batterie auf Energiesparmodus umschalten
            setTrackingAccuracy(.low)
            DebugLogger.shared.log("🔋 Niedrige Batterie - Energiesparmodus aktiviert")
        } else if batteryLevel > 0.5 && trackingAccuracy == .low {
            // Bei ausreichender Batterie wieder normale Genauigkeit
            setTrackingAccuracy(.balanced)
            DebugLogger.shared.log("🔋 Batterie ausreichend - normale Genauigkeit wiederhergestellt")
        }
    }
    
    @objc private func batteryStateChanged() {
        let batteryState = UIDevice.current.batteryState
        
        switch batteryState {
        case .charging, .full:
            // Bei Laden kann höhere Genauigkeit verwendet werden
            if trackingAccuracy == .low {
                setTrackingAccuracy(.balanced)
                DebugLogger.shared.log("🔌 Gerät lädt - höhere Tracking-Genauigkeit aktiviert")
            }
        case .unplugged:
            // Beim Trennen vom Ladegerät Energiesparmodus prüfen
            if UIDevice.current.batteryLevel < 0.3 {
                setTrackingAccuracy(.low)
                DebugLogger.shared.log("🔋 Ladegerät getrennt + niedrige Batterie - Energiesparmodus")
            }
        default:
            break
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
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                print("❌ LocationManager: Konnte kein Window für Alert finden")
                return
            }
            
            let alert = UIAlertController(
                title: "Standort-Berechtigung erforderlich",
                message: "TravelCompanion benötigt Zugriff auf Ihren Standort für GPS-Tracking. Bitte aktivieren Sie die Berechtigung in den Einstellungen.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Einstellungen", style: .default) { _ in
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            })
            
            alert.addAction(UIAlertAction(title: "Abbrechen", style: .cancel))
            
            window.rootViewController?.present(alert, animated: true)
        }
        
        print("⚠️ LocationManager: Benutzer sollte zu den Einstellungen weitergeleitet werden")
    }
    
    // MARK: - Deinitializer
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        pauseTimer?.invalidate()
    }
    
    // MARK: - Location Request Helper
    
    /// Fordert eine einmalige Standortabfrage an
    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        
        locationManager.requestLocation()
        print("📍 LocationManager: Standort-Abfrage gestartet")
    }
    
    // MARK: - Background Processing Methods
    
    /// Verarbeitet Location Updates im Background
    func processBackgroundLocationUpdates() async {
        DebugLogger.shared.log("🔄 Background Location Updates werden verarbeitet")
        
        guard isTracking, let currentLocation = currentLocation else {
            DebugLogger.shared.log("⚠️ Kein aktives Tracking oder keine Location für Background Processing")
            return
        }
        
        // Prüfe ob neue Location signifikant ist
        if let lastLocation = lastSignificantLocation {
            let distance = currentLocation.distance(from: lastLocation)
            if distance < minimumDistanceForUpdate {
                DebugLogger.shared.log("📍 Location Change zu gering für Update: \(distance)m")
                return
            }
        }
        
        // Speichere aktuelle Location als letzte signifikante Location
        lastSignificantLocation = currentLocation
        
        // Update Location in Context von aktivem Trip
        await updateTripLocation(currentLocation)
        
        DebugLogger.shared.log("✅ Background Location Update verarbeitet")
    }
    
    /// Erstellt automatisch Memories bei signifikanten Location Changes
    func createPendingMemories() async {
        DebugLogger.shared.log("🔄 Erstelle Pending Memories")
        
        guard isTracking,
              let currentLocation = currentLocation,
              let activeTrip = activeTrip,
              let currentUser = currentUser else {
            return
        }
        
        // Prüfe ob Location alt genug ist für automatische Memory-Erstellung
        let locationAge = Date().timeIntervalSince(currentLocation.timestamp)
        guard locationAge < maximumLocationAge else {
            DebugLogger.shared.log("⚠️ Location zu alt für Memory-Erstellung: \(locationAge)s")
            return
        }
        
        // Erstelle automatische Memory für signifikante Location
        let pendingMemory = PendingMemory(
            title: "Standort Update",
            content: "Automatisch erfasster Standort während der Reise",
            latitude: currentLocation.coordinate.latitude,
            longitude: currentLocation.coordinate.longitude,
            timestamp: currentLocation.timestamp,
            tripID: activeTrip.id!,
            userID: currentUser.id!
        )
        
        // Zur Queue hinzufügen
        await MainActor.run {
            pendingMemories.append(pendingMemory)
            savePendingMemories()
        }
        
        DebugLogger.shared.log("✅ Pending Memory erstellt")
    }
    
    /// Aktualisiert Trip Location im Background
    private func updateTripLocation(_ location: CLLocation) async {
        let context = coreDataManager.persistentContainer.newBackgroundContext()
        
        await context.perform {
            do {
                guard let activeTrip = self.activeTrip else { return }
                
                // Trip im Background Context finden
                let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
                tripRequest.predicate = NSPredicate(format: "id == %@", activeTrip.id! as CVarArg)
                
                guard try context.fetch(tripRequest).first != nil else {
                    DebugLogger.shared.log("⚠️ Aktiver Trip nicht im Background Context gefunden")
                    return
                }
                
                // Aktualisiere Trip mit neuer Location (falls ein lastLocation Feld existiert)
                // trip.lastLatitude = location.coordinate.latitude
                // trip.lastLongitude = location.coordinate.longitude
                // trip.lastLocationUpdate = location.timestamp
                
                try context.save()
                DebugLogger.shared.log("✅ Trip Location im Background aktualisiert")
                
            } catch {
                DebugLogger.shared.log("❌ Background Trip Location Update Fehler: \(error.localizedDescription)")
            }
        }
    }
    
    /// Überprüft den aktuellen Permission Status
    func checkPermissionStatus() {
        let currentStatus = locationManager.authorizationStatus
        
        if currentStatus != authorizationStatus {
            DispatchQueue.main.async {
                self.authorizationStatus = currentStatus
            }
        }
        
        DebugLogger.shared.log("📍 Permission Status Check: \(currentStatus.description)")
        
        // Warnungen für problematische Zustände
        switch currentStatus {
        case .denied, .restricted:
            DebugLogger.shared.log("⚠️ Location Permission Problem - Tracking nicht möglich")
            if isTracking {
                stopTracking()
            }
        case .authorizedWhenInUse:
            if isTracking {
                DebugLogger.shared.log("⚠️ Nur Foreground Location Permission - Background Tracking limitiert")
            }
        default:
            break
        }
    }
    
    // MARK: - App State Change Handlers
    
    func handleAppStateChange(_ state: AppStateManager.AppState) {
        switch state {
        case .inactive:
            // Location Updates pausieren wenn möglich
            if !isTracking { return }
            DebugLogger.shared.log("📱 App inaktiv - Location Updates fortsetzen")
            
        case .background:
            // Auf significant location changes umschalten für Batterie-Optimierung
            enableBackgroundLocationOptimization()
            
        case .active:
            // Normale Location Updates aktivieren
            disableBackgroundLocationOptimization()
            
        case .terminating:
            // Final location save
            saveFinalLocation()
            
        default:
            break
        }
    }
    
    private func enableBackgroundLocationOptimization() {
        guard isTracking else { return }
        
        // Auf significant location changes umschalten
        locationManager.stopUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        DebugLogger.shared.log("🔋 Background Location Optimization aktiviert")
    }
    
    private func disableBackgroundLocationOptimization() {
        guard isTracking else { return }
        
        // Normale Location Updates wieder aktivieren
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
        
        DebugLogger.shared.log("📍 Normale Location Updates aktiviert")
    }
    
    private func saveFinalLocation() {
        guard let currentLocation = currentLocation else { return }
        
        // Finale Location in UserDefaults speichern für nächsten App-Start
        let locationData = [
            "latitude": currentLocation.coordinate.latitude,
            "longitude": currentLocation.coordinate.longitude,
            "timestamp": currentLocation.timestamp.timeIntervalSince1970
        ]
        
        UserDefaults.standard.set(locationData, forKey: "lastKnownLocation")
        DebugLogger.shared.log("📍 Finale Location gespeichert")
    }
    
    func prepareForMemoryWarning() {
        // Location Cache leeren
        lastSignificantLocation = nil
        
        // Nur die neuesten pending memories behalten
        if pendingMemories.count > 10 {
            pendingMemories = Array(pendingMemories.suffix(10))
            savePendingMemories()
        }
        
        DebugLogger.shared.log("🧹 LocationManager Memory Warning Cleanup")
    }
    
    // MARK: - Location Restoration
    
    /// Lädt die letzte bekannte Location beim App-Start
    func restoreLastKnownLocation() {
        guard let locationData = UserDefaults.standard.dictionary(forKey: "lastKnownLocation"),
              let latitude = locationData["latitude"] as? Double,
              let longitude = locationData["longitude"] as? Double,
              let timestamp = locationData["timestamp"] as? TimeInterval else {
            DebugLogger.shared.log("📍 Keine gespeicherte Location zum Wiederherstellen gefunden")
            return
        }
        
        let restoredLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: 1000, // Große Unsicherheit da gespeicherte Location
            verticalAccuracy: -1,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )
        
        DispatchQueue.main.async {
            self.currentLocation = restoredLocation
        }
        
        DebugLogger.shared.log("📍 Letzte bekannte Location wiederhergestellt")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update current location immediately
        DispatchQueue.main.async {
            self.currentLocation = location
            print("✅ LocationManager: Location aktualisiert - \(location.formattedCoordinates), Genauigkeit: \(location.horizontalAccuracy)m")
        }
        
        // Handle location for tracking if enabled
        if isTracking {
            handleLocationUpdate(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager: Location update failed - \(error.localizedDescription)")
        
        // Bei kritischen Fehlern Tracking stoppen
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("❌ LocationManager: Location access denied")
                if isTracking {
                    stopTracking()
                }
            case .locationUnknown:
                print("⚠️ LocationManager: Location unknown - will continue trying...")
            case .network:
                print("⚠️ LocationManager: Network error - will retry...")
            default:
                print("⚠️ LocationManager: Other location error (\(clError.code.rawValue)) - continuing...")
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
        
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
            // Request initial location when permission granted
            locationManager.requestLocation()
        case .authorizedAlways:
            print("✅ LocationManager: Full location access granted")
            // Request initial location when permission granted
            locationManager.requestLocation()
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