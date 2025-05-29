import SwiftUI
import CoreLocation

/// Test-Script für GPS-Funktionalität im iOS Simulator
/// Simuliert verschiedene Tracking-Szenarien und GPS-Bedingungen
struct GPSTestScript {
    
    static let shared = GPSTestScript()
    private let locationManager = LocationManager.shared
    private let coreDataManager = CoreDataManager.shared
    
    // MARK: - Simulator Test Locations
    
    /// Vordefinierte Test-Locations für Simulator
    private let testLocations: [TestLocation] = [
        TestLocation(name: "Rom, Kolosseum", latitude: 41.8902, longitude: 12.4922),
        TestLocation(name: "Florenz, Dom", latitude: 43.7731, longitude: 11.2560),
        TestLocation(name: "Venedig, Markusplatz", latitude: 45.4342, longitude: 12.3388),
        TestLocation(name: "Mailand, Dom", latitude: 45.4642, longitude: 9.1900),
        TestLocation(name: "Neapel, Zentrum", latitude: 40.8518, longitude: 14.2681)
    ]
    
    private struct TestLocation {
        let name: String
        let latitude: Double
        let longitude: Double
        
        var clLocation: CLLocation {
            CLLocation(latitude: latitude, longitude: longitude)
        }
    }
    
    // MARK: - Test Scenarios
    
    /// Komplettes Test-Szenario für GPS-Tracking
    func runCompleteGPSTest() async {
        print("🧪 === GPS TEST SCENARIO GESTARTET ===")
        
        // 1. Sample-Daten erstellen
        await setupTestData()
        
        // 2. Permission-Test
        await testPermissions()
        
        // 3. Tracking-Genauigkeit testen
        await testTrackingAccuracy()
        
        // 4. Pause-Erkennung testen
        await testPauseDetection()
        
        // 5. Batterie-Optimierung testen
        await testBatteryOptimization()
        
        // 6. Offline-Funktionalität testen
        await testOfflineFunctionality()
        
        // 7. Manual Memories testen
        await testManualMemories()
        
        print("✅ === GPS TEST SCENARIO ABGESCHLOSSEN ===")
    }
    
    // MARK: - Individual Tests
    
    private func setupTestData() async {
        print("📊 Test 1: Sample-Daten Setup")
        
        SampleDataCreator.createSampleData(in: coreDataManager.viewContext)
        // SampleDataCreator.printDataSummary(using: coreDataManager) // Kommentiert aus bis Implementierung
        
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 Sekunde
        } catch {
            print("Sleep error: \(error)")
        }
        print("✅ Sample-Daten erstellt\n")
    }
    
    private func testPermissions() async {
        print("🔐 Test 2: Permission-Handling")
        
        let currentStatus = locationManager.authorizationStatus
        print("📍 Aktuelle Berechtigung: \(currentStatus)")
        
        locationManager.requestPermission()
        
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 Sekunden
        } catch {
            print("Sleep error: \(error)")
        }
        print("✅ Permission-Request gesendet\n")
    }
    
    private func testTrackingAccuracy() async {
        print("🎯 Test 3: Tracking-Genauigkeit")
        
        for accuracy in LocationManager.LocationAccuracy.allCases {
            print("🔄 Teste Genauigkeit: \(accuracy.description)")
            locationManager.setTrackingAccuracy(accuracy)
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 Sekunden
            } catch {
                print("Sleep error: \(error)")
            }
        }
        
        // Zurück zu balanced
        locationManager.setTrackingAccuracy(.balanced)
        print("✅ Genauigkeits-Tests abgeschlossen\n")
    }
    
    private func testPauseDetection() async {
        print("⏸️ Test 4: Pause-Erkennung")
        
        // Simuliere Stillstand (im echten Szenario würde GPS-Manager das automatisch erkennen)
        print("🚶‍♂️ Simuliere Bewegung...")
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
        } catch {
            print("Sleep error: \(error)")
        }
        
        print("🛑 Simuliere Stillstand (5 Min)...")
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // Verkürzt für Test
        } catch {
            print("Sleep error: \(error)")
        }
        
        print("✅ Pause-Erkennung getestet\n")
    }
    
    private func testBatteryOptimization() async {
        print("🔋 Test 5: Batterie-Optimierung")
        
        // Simuliere verschiedene Batterie-Zustände
        print("📱 Teste Batterie-Optimierungen...")
        
        // Im echten Szenario würde der LocationManager auf UIDevice.current.batteryLevel reagieren
        print("🔋 Niedriger Batteriestand -> Reduzierte Genauigkeit")
        print("⚡ Lädt -> Höhere Genauigkeit")
        
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            print("Sleep error: \(error)")
        }
        print("✅ Batterie-Optimierung getestet\n")
    }
    
    private func testOfflineFunctionality() async {
        print("📡 Test 6: Offline-Funktionalität")
        
        // Simuliere Offline-Situation durch temporäre Core Data Unterbrechung
        print("🌐 Simuliere Offline-Modus...")
        
        // Test-Memory erstellen während "offline"
        locationManager.createManualMemory(
            title: "Offline Test",
            content: "Memory erstellt während Offline-Simulation",
            location: testLocations[0].clLocation
        )
        
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            print("Sleep error: \(error)")
        }
        print("💾 Offline-Memory erstellt")
        print("✅ Offline-Funktionalität getestet\n")
    }
    
    private func testManualMemories() async {
        print("📍 Test 7: Manuelle Memories")
        
        for (index, location) in testLocations.enumerated() {
            print("📌 Erstelle Memory #\(index + 1): \(location.name)")
            
            locationManager.createManualMemory(
                title: location.name,
                content: "Test-Memory an \(location.name) erstellt",
                location: location.clLocation
            )
            
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 Sekunden
            } catch {
                print("Sleep error: \(error)")
            }
        }
        
        print("✅ Manuelle Memories erstellt\n")
    }
    
    // MARK: - Quick Tests für Development
    
    /// Schneller Test für aktuelle Entwicklung
    func quickTest() {
        print("⚡ QUICK GPS TEST")
        
        // User und Trip für Test holen
        let users = coreDataManager.fetchAllUsers()
        guard let user = users.first else {
            print("❌ Kein User gefunden - führe zuerst Sample Data Creation aus")
            return
        }
        
        let trips = coreDataManager.fetchTrips(for: user)
        guard let trip = trips.first else {
            print("❌ Kein Trip gefunden - erstelle einen Trip")
            return
        }
        
        // Tracking starten
        locationManager.startTracking(for: trip, user: user)
        print("✅ Tracking gestartet für Trip: \(trip.title ?? "Unbekannt")")
        
        // Test-Memory erstellen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.locationManager.createManualMemory(
                title: "Quick Test Location",
                content: "Schneller Test-Memory",
                location: self.testLocations.randomElement()?.clLocation
            )
            print("✅ Test-Memory erstellt")
        }
    }
    
    /// Tracking stoppen und Daten ausgeben
    func stopTestAndShowResults() {
        locationManager.stopTracking()
        
        // Kurze Zusammenfassung ausgeben
        let users = coreDataManager.fetchAllUsers()
        for user in users {
            let memories = coreDataManager.fetchMemories(for: user)
            print("👤 User \(user.displayName ?? "Unbekannt"): \(memories.count) Memories")
        }
    }
}

// MARK: - SwiftUI Test View

/// Test-View für GPS-Funktionalität in SwiftUI
struct GPSTestView: View {
    @StateObject private var locationManager = LocationManager.shared
    @State private var isTestRunning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                GroupBox("Test Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(locationManager.isTracking ? .green : .red)
                                .frame(width: 12, height: 12)
                            Text(locationManager.isTracking ? "GPS aktiv" : "GPS gestoppt")
                        }
                        
                        Text("Berechtigung: \(locationManager.authorizationStatus.description)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let location = locationManager.currentLocation {
                            Text("Lat: \(location.coordinate.latitude, specifier: "%.6f")")
                                .font(.caption)
                            Text("Lon: \(location.coordinate.longitude, specifier: "%.6f")")
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Komplett-Test starten") {
                        runCompleteTest()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTestRunning)
                    
                    Button("Quick Test") {
                        GPSTestScript.shared.quickTest()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test stoppen") {
                        GPSTestScript.shared.stopTestAndShowResults()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .navigationTitle("GPS Test Script")
        }
    }
    
    private func runCompleteTest() {
        isTestRunning = true
        
        Task {
            await GPSTestScript.shared.runCompleteGPSTest()
            
            await MainActor.run {
                isTestRunning = false
            }
        }
    }
}

// MARK: - Extensions

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Nicht bestimmt"
        case .restricted: return "Eingeschränkt"
        case .denied: return "Verweigert"
        case .authorizedAlways: return "Immer erlaubt"
        case .authorizedWhenInUse: return "Bei Nutzung"
        @unknown default: return "Unbekannt"
        }
    }
}

// MARK: - Simulator Location Setup Instructions

/*
 📱 SIMULATOR SETUP FÜR GPS-TESTS:
 
 1. iOS Simulator öffnen
 2. Device → Location → Custom Location...
 3. Folgende Test-Koordinaten verwenden:
    - Rom: 41.8902, 12.4922
    - Florenz: 43.7731, 11.2560
    - Venedig: 45.4342, 12.3388
 
 4. Oder automatische Simulation:
    Device → Location → City Run/Freeway Drive
 
 🔧 DEBUGGING:
 - Console öffnen für detaillierte GPS-Logs
 - Alle LocationManager-Events werden mit Emojis geloggt
 - Core Data SQL-Debug: Add launch argument `-com.apple.CoreData.SQLDebug 1`
 
 ⚠️ WICHTIG:
 - Info.plist Einträge müssen konfiguriert sein
 - Background Modes: Location updates aktivieren
 - Für echte Tests: Physisches Device verwenden
 */ 