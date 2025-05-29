import SwiftUI
import CoreLocation

/// Basis Settings View für die TravelCompanion App
/// Zeigt App-Informationen und grundlegende Einstellungen
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                // App Info Section
                Section("App Information") {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                        Text("Build")
                        Spacer()
                        Text(viewModel.buildNumber)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Berechtigungen Section
                Section("Berechtigungen") {
                    HStack {
                        Image(systemName: viewModel.locationIcon)
                            .foregroundColor(viewModel.locationIconColor)
                        Text("Standort")
                        Spacer()
                        Text(viewModel.locationStatus)
                            .foregroundColor(viewModel.locationStatusColor)
                    }
                    .onTapGesture {
                        viewModel.openLocationSettings()
                    }
                }
                
                // Daten Section
                Section("Daten") {
                    HStack {
                        Image(systemName: "internaldrive.fill")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lokale Daten")
                            Text("Reisen, Footsteps und Fotos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(viewModel.dataSize)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        viewModel.showClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Cache leeren")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Debug Section (nur in Development)
                #if DEBUG
                Section("Development") {
                    Button(action: {
                        viewModel.createSampleData()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Sample Data erstellen")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button(action: {
                        viewModel.showDataSummary()
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                            Text("Daten-Zusammenfassung")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {
                        viewModel.testLocationServices()
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.orange)
                            Text("GPS Test starten")
                                .foregroundColor(.orange)
                        }
                    }
                }
                #endif
                
                // Support Section
                Section("Support") {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text("Feedback senden")
                    }
                    .onTapGesture {
                        viewModel.sendFeedback()
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("App bewerten")
                    }
                    .onTapGesture {
                        viewModel.rateApp()
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.refreshData()
            }
            .alert("Cache leeren", isPresented: $viewModel.showClearCacheAlert) {
                Button("Löschen", role: .destructive) {
                    viewModel.clearCache()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Möchten Sie den App-Cache wirklich leeren? Dies kann die Leistung vorübergehend beeinträchtigen.")
            }
            .alert("Information", isPresented: $viewModel.showInfoAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.infoMessage)
            }
        }
        .onAppear {
            viewModel.refreshData()
        }
    }
}

/// ViewModel für SettingsView
class SettingsViewModel: ObservableObject {
    @Published var showClearCacheAlert = false
    @Published var showInfoAlert = false
    @Published var infoMessage = ""
    
    // MARK: - App Info Properties
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - Location Properties
    var locationStatus: String {
        switch CLLocationManager().authorizationStatus {
        case .notDetermined:
            return "Nicht festgelegt"
        case .denied:
            return "Verweigert"
        case .restricted:
            return "Eingeschränkt"
        case .authorizedWhenInUse:
            return "Bei Nutzung"
        case .authorizedAlways:
            return "Immer"
        @unknown default:
            return "Unbekannt"
        }
    }
    
    var locationIcon: String {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "location.fill"
        case .denied, .restricted:
            return "location.slash.fill"
        default:
            return "location.circle.fill"
        }
    }
    
    var locationIconColor: Color {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }
    
    var locationStatusColor: Color {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }
    
    var dataSize: String {
        // Einfache Schätzung der Datengröße
        let trips = TripManager.shared.getAllTrips()
        let totalFootsteps = trips.reduce(0) { total, trip in
            let footsteps = CoreDataManager.shared.fetchFootsteps(for: trip)
            return total + footsteps.count
        }
        
        if totalFootsteps == 0 {
            return "Keine Daten"
        } else if totalFootsteps < 10 {
            return "< 1 MB"
        } else {
            let estimatedMB = totalFootsteps / 10
            return "≈ \(estimatedMB) MB"
        }
    }
    
    // MARK: - Actions
    func refreshData() {
        // Aktualisiert die angezeigten Daten
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func openLocationSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    func clearCache() {
        // Cache leeren (in Production würde hier UserDefaults und temporäre Dateien gelöscht)
        UserDefaults.standard.removeObject(forKey: "cached_locations")
        
        showInfo(message: "Cache wurde erfolgreich geleert.")
        print("✅ SettingsView: Cache geleert")
    }
    
    func sendFeedback() {
        // Feedback E-Mail öffnen
        let email = "feedback@travelcompanion.app"
        let subject = "TravelCompanion Feedback"
        let body = "Hallo TravelCompanion Team,\n\n"
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
    
    func rateApp() {
        // App Store Bewertung öffnen (Placeholder)
        showInfo(message: "App Store Bewertung ist in der Vollversion verfügbar.")
    }
    
    // MARK: - Development Actions
    #if DEBUG
    func createSampleData() {
        SampleDataCreator.createSampleData(in: CoreDataManager.shared.viewContext)
        showInfo(message: "Sample Data wurde erstellt.")
        print("✅ SettingsView: Sample Data erstellt")
    }
    
    func showDataSummary() {
        let trips = TripManager.shared.getAllTrips()
        let totalFootsteps = trips.reduce(0) { total, trip in
            let footsteps = CoreDataManager.shared.fetchFootsteps(for: trip)
            return total + footsteps.count
        }
        showInfo(message: "Daten-Zusammenfassung: \(trips.count) Reisen, \(totalFootsteps) Footsteps")
    }
    
    func testLocationServices() {
        LocationManager.shared.requestPermission()
        showInfo(message: "GPS Test gestartet. Prüfen Sie die Konsole für Details.")
        print("🧪 SettingsView: GPS Test gestartet")
    }
    #endif
    
    // MARK: - Helper Methods
    private func showInfo(message: String) {
        infoMessage = message
        showInfoAlert = true
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 