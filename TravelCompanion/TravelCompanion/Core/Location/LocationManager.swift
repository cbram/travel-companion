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
        
        // ENTFERNT: Sofortiger Location-Abruf verhindert Performance-Probleme
        // Nur bei expliziter Anfrage Location anfordern
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
        
        // PERFORMANCE-OPTIMIERUNG: Reduziere excessive Updates mit intelligenter Filterung
        if let lastLocation = currentLocation {
            let timeSinceLastUpdate = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            let distance = location.distance(from: lastLocation)
            
            // ANGEPASSTE Filter-Logik: Weniger aggressive Updates
            let minTimeInterval: TimeInterval = isTracking ? 30.0 : 60.0  // 30s beim Tracking, 60s normal
            let minDistance: CLLocationDistance = isTracking ? 10.0 : 25.0  // 10m beim Tracking, 25m normal
            
            // Ignoriere zu häufige Updates mit vernünftigen Schwellwerten
            if timeSinceLastUpdate < minTimeInterval && distance < minDistance {
                // AUSNAHME: Bei sehr schlechter Genauigkeit (>100m) weniger strikt filtern
                guard lastLocation.horizontalAccuracy > 100 || location.horizontalAccuracy > 100 else {
                    return // Filtere Update aus
                }
            }
            
            // BATTERIE-OPTIMIERUNG: Bei niedrigem Batteriestand noch strikter filtern
            if UIDevice.current.batteryLevel < 0.3 && UIDevice.current.batteryState != .charging {
                if timeSinceLastUpdate < 60.0 && distance < 50.0 {
                    return
                }
            }
        }
        
        currentLocation = location
        lastLocationUpdate = Date()
        
        // Pause-Erkennung zurücksetzen nur bei signifikanten Bewegungen
        if let lastLocation = lastSignificantLocation {
            let distance = location.distance(from: lastLocation)
            if distance >= minimumDistanceForUpdate {
                resetPauseDetection()
            }
        } else {
            resetPauseDetection()
        }
        
        // Automatische Memory-Erstellung nur bei wirklich signifikanten Bewegungen
        if shouldCreateAutomaticMemory(for: location) {
            createAutomaticMemory(at: location)
        }
        
        // Update lastSignificantLocation nur bei größeren Bewegungen
        if let lastLocation = lastSignificantLocation {
            let distance = location.distance(from: lastLocation)
            if distance >= minimumDistanceForUpdate {
                lastSignificantLocation = location
            }
        } else {
            lastSignificantLocation = location
        }
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
        guard let lastLocation = lastSignificantLocation else { 
            // Erste Location - nur bei Tracking automatisch speichern
            return isTracking
        }
        
        let distance = location.distance(from: lastLocation)
        let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
        
        // REDUZIERTE Häufigkeit für automatische Memories
        let minimumDistance: CLLocationDistance = 100 // 100m statt 5m
        let minimumTime: TimeInterval = 600 // 10 Minuten statt 5 Minuten
        
        // BATTERIESTAND-ABHÄNGIGE Anpassung
        let batteryLevel = UIDevice.current.batteryLevel
        if batteryLevel < 0.3 && UIDevice.current.batteryState != .charging {
            // Bei niedrigem Batteriestand sehr restriktiv
            return distance >= 500 || timeInterval >= 1800 // 500m oder 30 Minuten
        } else if batteryLevel < 0.6 {
            // Bei mittlerem Batteriestand moderat restriktiv
            return distance >= 200 || timeInterval >= 900 // 200m oder 15 Minuten
        }
        
        // Normale Bedingungen
        return distance >= minimumDistance || timeInterval >= minimumTime
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
        // PERFORMANCE-OPTIMIERUNG: Background Context verwenden
        let backgroundContext = coreDataManager.backgroundContext
        
        backgroundContext.perform { [weak self] in
            guard self != nil else { return }
            
            // Trip und User im Background Context finden
            let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            tripRequest.predicate = NSPredicate(format: "id == %@", trip.id! as CVarArg)
            tripRequest.fetchLimit = 1
            
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            userRequest.predicate = NSPredicate(format: "id == %@", user.id! as CVarArg)
            userRequest.fetchLimit = 1
            
            do {
                guard let backgroundTrip = try backgroundContext.fetch(tripRequest).first,
                      let backgroundUser = try backgroundContext.fetch(userRequest).first else {
                    print("❌ LocationManager: Trip oder User nicht im Background Context gefunden")
                    return
                }
                
                let memory = Memory(context: backgroundContext)
                memory.id = UUID()
                memory.title = title
                memory.content = content
                memory.latitude = location.coordinate.latitude
                memory.longitude = location.coordinate.longitude
                memory.timestamp = location.timestamp
                memory.createdAt = Date()
                memory.author = backgroundUser
                memory.trip = backgroundTrip
                
                try backgroundContext.save()
                print("✅ LocationManager: Automatische Memory erstellt: '\(title)'")
                
            } catch {
                print("❌ LocationManager: Fehler beim Erstellen der Memory: \(error)")
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
    
    /// Fordert eine einmalige Standortabfrage an - PERFORMANCE OPTIMIZED
    func requestLocationUpdate() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        
        // PERFORMANCE: Prüfe ob bereits aktuelle Location verfügbar ist
        if let currentLocation = currentLocation {
            let locationAge = Date().timeIntervalSince(currentLocation.timestamp)
            
            // Location ist frisch genug (unter 30 Sekunden)
            if locationAge < 30.0 {
                print("✅ LocationManager: Verwende aktuelle Location (Alter: \(Int(locationAge))s)")
                return
            }
        }
        
        // Fordere neue Location nur bei Bedarf an
        locationManager.requestLocation()
        print("📍 LocationManager: Neue Standort-Abfrage gestartet")
    }
    
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
    
    /// PERFORMANCE-OPTIMIERT: Background Location Processing ohne Timer
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
        
        // VEREINFACHT: Nur bei signifikanten Änderungen Background-Updates
        await updateTripLocationIfNeeded(currentLocation)
        
        DebugLogger.shared.log("✅ Background Location Update verarbeitet")
    }
    
    /// OPTIMIERT: Erstellt Pending Memories nur bei Bedarf
    func createPendingMemories() async {
        DebugLogger.shared.log("🔄 Erstelle Pending Memories")
        
        guard isTracking,
              let currentLocation = currentLocation,
              let activeTrip = activeTrip,
              let currentUser = currentUser else {
            return
        }
        
        // PERFORMANCE: Prüfe ob Location alt genug ist
        let locationAge = Date().timeIntervalSince(currentLocation.timestamp)
        guard locationAge < maximumLocationAge else {
            DebugLogger.shared.log("⚠️ Location zu alt für Memory-Erstellung: \(locationAge)s")
            return
        }
        
        // PERFORMANCE: Begrenze Anzahl Pending Memories
        guard pendingMemories.count < 50 else {
            DebugLogger.shared.log("⚠️ Zu viele Pending Memories - überspringe neue Erstellung")
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
    
    /// OPTIMIERT: Trip Location Update nur bei Bedarf
    private func updateTripLocationIfNeeded(_ location: CLLocation) async {
        // Prüfe ob Update nötig ist
        guard let lastUpdate = lastLocationUpdate,
              Date().timeIntervalSince(lastUpdate) > 60.0 else { // Max alle 60 Sekunden
            return
        }
        
        await updateTripLocation(location)
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
                tripRequest.fetchLimit = 1
                
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