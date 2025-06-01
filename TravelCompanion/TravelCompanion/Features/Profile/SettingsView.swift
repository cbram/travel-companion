import SwiftUI
import CoreLocation

/// Basis Settings View für die TravelCompanion App
/// Zeigt App-Informationen und grundlegende Einstellungen
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var tripManager: TripManager
    @EnvironmentObject private var userManager: UserManager
    
    var body: some View {
        NavigationView {
            List {
                // User Info Section
                Section("Benutzer") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userManager.currentUser?.formattedDisplayName ?? "Unbekannt")
                                .font(.headline)
                            Text(userManager.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                
                // Trip Statistics Section
                Section("Reise-Statistiken") {
                    HStack {
                        Image(systemName: "suitcase.fill")
                            .foregroundColor(.green)
                        Text("Reisen")
                        Spacer()
                        Text("\(tripManager.allTrips.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.red)
                        Text("Memories")
                        Spacer()
                        Text("\(viewModel.totalMemoriesCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let currentTrip = tripManager.currentTrip {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Aktive Reise")
                            Spacer()
                            Text(currentTrip.title ?? "Unbekannt")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
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
                            Text("Reisen, Memories und Fotos")
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
                        viewModel.showDataSummary(trips: tripManager.allTrips)
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
                viewModel.refreshData(trips: tripManager.allTrips)
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
            viewModel.refreshData(trips: tripManager.allTrips)
        }
    }
}

/// ViewModel für SettingsView
class SettingsViewModel: ObservableObject {
    @Published var showClearCacheAlert = false
    @Published var showInfoAlert = false
    @Published var infoMessage = ""
    @Published var totalMemoriesCount = 0
    
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
    
    // MARK: - Data Properties
    var dataSize: String {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let size = try? FileManager.default.allocatedSizeOfDirectory(at: url)
        return ByteCountFormatter.string(fromByteCount: Int64(size ?? 0), countStyle: .file)
    }
    
    // MARK: - Actions
    func refreshData(trips: [Trip]) {
        // Calculate total memories count from all trips
        totalMemoriesCount = trips.reduce(0) { $0 + $1.memoriesCount }
    }
    
    func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    func clearCache() {
        // Clear UserDefaults
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        showInfo("Cache wurde geleert")
    }
    
    func createSampleData() {
        SampleDataCreator.createSampleData(in: CoreDataManager.shared.viewContext)
        showInfo("Sample Data wurde erstellt")
    }
    
    func showDataSummary(trips: [Trip]) {
        let tripsCount = trips.count
        let memoriesCount = totalMemoriesCount
        let message = "Trips: \(tripsCount)\nMemories: \(memoriesCount)"
        showInfo(message)
    }
    
    func testLocationServices() {
        LocationManager.shared.requestPermission()
        showInfo("GPS Test gestartet - siehe Console für Details")
    }
    
    func sendFeedback() {
        if let url = URL(string: "mailto:feedback@travelcompanion.app") {
            UIApplication.shared.open(url)
        }
    }
    
    func rateApp() {
        // In Production würde hier der App Store Link verwendet
        showInfo("App Store Rating würde geöffnet")
    }
    
    private func showInfo(_ message: String) {
        infoMessage = message
        showInfoAlert = true
    }
}

// MARK: - FileManager Extension
extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> UInt64 {
        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]
        
        var size: UInt64 = 0
        let enumerator = enumerator(at: url, includingPropertiesForKeys: resourceKeys)!
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if resourceValues.isRegularFile == true {
                size += UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
            }
        }
        
        return size
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(TripManager.shared)
            .environmentObject(UserManager.shared)
    }
} 