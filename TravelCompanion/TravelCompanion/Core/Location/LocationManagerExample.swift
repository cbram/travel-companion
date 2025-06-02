import SwiftUI
import CoreLocation

/// Beispiel für die Verwendung des LocationManagers in einer SwiftUI-App
struct LocationManagerExample: View {
    @StateObject private var locationManager = LocationManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    
    // Beispiel-Daten
    @State private var currentUser: User?
    @State private var activeTrip: Trip?
    @State private var showingPermissionAlert = false
    @State private var showingAccuracySheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Status-Anzeige
                GroupBox("GPS Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 12, height: 12)
                            Text(statusText)
                        }
                        
                        if let location = locationManager.currentLocation {
                            Text("Koordinaten: \(location.coordinate.latitude, specifier: "%.6f"), \(location.coordinate.longitude, specifier: "%.6f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if locationManager.isPaused {
                            Label("Pausiert (keine Bewegung)", systemImage: "pause.circle")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }
                
                // Genauigkeits-Einstellung
                GroupBox("Tracking-Genauigkeit") {
                    Button(action: { showingAccuracySheet = true }) {
                        HStack {
                            Text("Aktuell: \(locationManager.trackingAccuracy.description)")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                
                // Aktiver Trip
                if let trip = activeTrip {
                    GroupBox("Aktiver Trip") {
                        VStack(alignment: .leading) {
                            Text(trip.title ?? "Unbekannte Reise")
                                .font(.headline)
                            if let description = trip.tripDescription {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Haupt-Buttons
                VStack(spacing: 12) {
                    if locationManager.authorizationStatus != .authorizedAlways {
                        Button("GPS-Berechtigung anfordern") {
                            locationManager.requestPermission()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    
                    if locationManager.isTracking {
                        Button("Tracking stoppen") {
                            stopTracking()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else if canStartTracking {
                        Button("Tracking starten") {
                            startTracking()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    
                    Button("Manuelles Memory erstellen") {
                        createManualMemory()
                    }
                    .buttonStyle(TertiaryButtonStyle())
                    .disabled(!locationManager.isTracking)
                }
            }
            .padding()
            .navigationTitle("GPS Tracking")
            .onAppear {
                setupExampleData()
            }
            .sheet(isPresented: $showingAccuracySheet) {
                AccuracySelectionView(selectedAccuracy: $locationManager.trackingAccuracy)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return locationManager.isTracking ? .green : .yellow
        case .authorizedWhenInUse:
            return .orange
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    private var statusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return locationManager.isTracking ? "Tracking aktiv" : "Bereit zum Tracking"
        case .authorizedWhenInUse:
            return "Nur Vordergrund-Berechtigung"
        case .denied, .restricted:
            return "Berechtigung verweigert"
        case .notDetermined:
            return "Berechtigung nicht erteilt"
        @unknown default:
            return "Unbekannter Status"
        }
    }
    
    private var canStartTracking: Bool {
        return locationManager.authorizationStatus == .authorizedAlways &&
               currentUser != nil &&
               activeTrip != nil
    }
    
    // MARK: - Methods
    
    private func setupExampleData() {
        // Prüfe ob bereits User vorhanden sind - keine automatische Erstellung
        let users = CoreDataManager.shared.fetchAllUsers()
        if let existingUser = users.first {
            currentUser = existingUser
            // Aktiven Trip laden falls vorhanden
            activeTrip = CoreDataManager.shared.fetchActiveTrip(for: existingUser)
        }
        // Wenn keine Daten vorhanden sind, bleibt alles nil - User muss manuell Daten erstellen
    }
    
    private func startTracking() {
        guard let trip = activeTrip, let user = currentUser else { return }
        locationManager.startTracking(for: trip, user: user)
    }
    
    private func stopTracking() {
        locationManager.stopTracking()
    }
    
    private func createManualMemory() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        locationManager.createManualMemory(
            title: "Manueller Punkt um \(formatter.string(from: Date()))",
            content: "Manuell hinzugefügter Memory für Testzwecke"
        )
    }
}

// MARK: - Accuracy Selection View

struct AccuracySelectionView: View {
    @Binding var selectedAccuracy: LocationManager.LocationAccuracy
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(LocationManager.LocationAccuracy.allCases, id: \.self) { accuracy in
                Button(action: {
                    selectedAccuracy = accuracy
                    LocationManager.shared.setTrackingAccuracy(accuracy)
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(accuracy.description)
                                .font(.headline)
                            Text(accuracyDescription(for: accuracy))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedAccuracy == accuracy {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Tracking-Genauigkeit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func accuracyDescription(for accuracy: LocationManager.LocationAccuracy) -> String {
        switch accuracy {
        case .low:
            return "Geringster Batterieverbrauch, ~1km Genauigkeit"
        case .balanced:
            return "Ausgewogen zwischen Batterie und Genauigkeit, ~100m"
        case .high:
            return "Hohe Genauigkeit, ~10m, höherer Batterieverbrauch"
        case .navigation:
            return "Höchste Genauigkeit für Navigation, ~5m"
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct TertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Preview

struct LocationManagerExample_Previews: PreviewProvider {
    static var previews: some View {
        LocationManagerExample()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 