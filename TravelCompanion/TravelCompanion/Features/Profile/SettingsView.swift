import SwiftUI
import CoreLocation

/// Basis Settings View für die TravelCompanion App
/// Zeigt App-Informationen und grundlegende Einstellungen
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var tripManager: TripManager
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var authenticationState: AuthenticationState
    @State private var showingUserProfile = false
    @State private var showingUserSelection = false
    
    var body: some View {
        NavigationView {
            List {
                // User Profile Section - Enhanced
                Section("Benutzer") {
                    Button(action: {
                        showingUserProfile = true
                    }) {
                        HStack {
                            // User Avatar
                            AsyncImage(url: URL(string: userManager.currentUser?.avatarURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userManager.currentUser?.formattedDisplayName ?? "Unbekannt")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(userManager.currentUser?.email ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let stats = userManager.currentUser {
                                    Text("\(stats.tripsCount) Reisen • \(stats.memoriesCount) Erinnerungen")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Benutzer wechseln Button
                    Button(action: {
                        showingUserSelection = true
                    }) {
                        HStack {
                            Image(systemName: "person.2.circle")
                                .foregroundColor(.orange)
                            Text("Benutzer wechseln")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
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
            .sheet(isPresented: $showingUserProfile) {
                UserProfileView()
            }
            .sheet(isPresented: $showingUserSelection) {
                UserSelectionView()
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
        Task {
            // 1. UserDefaults leeren
            let domain = Bundle.main.bundleIdentifier!
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            
            // 2. URL Cache leeren
            URLCache.shared.removeAllCachedResponses()
            
            // 3. Photo File Manager Cache leeren (aber nicht alle Dateien)
            await PhotoFileManager.shared.optimizeFileSystem()
            
            // 4. System Caches
            if let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                do {
                    let cacheContents = try FileManager.default.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil)
                    for itemURL in cacheContents {
                        // Nur temporäre Cache-Dateien löschen, keine App-Daten
                        if itemURL.lastPathComponent.contains("Cache") || 
                           itemURL.lastPathComponent.contains("tmp") ||
                           itemURL.pathExtension == "tmp" {
                            try FileManager.default.removeItem(at: itemURL)
                        }
                    }
                } catch {
                    print("Cache cleanup error: \(error)")
                }
            }
            
            await MainActor.run {
                showInfo("Cache wurde geleert - App-Daten bleiben erhalten")
            }
        }
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
        
        // Sicheres Handling des Enumerators
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: resourceKeys) else {
            throw NSError(domain: "FileManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create directory enumerator"])
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                if resourceValues.isRegularFile == true {
                    size += UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
                }
            } catch {
                // Einzelne Dateifehler ignorieren, aber weiter iterieren
                continue
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