//
//  GPSDebugView.swift
//  TravelCompanion
//
//  Created on 2024.
//

import SwiftUI
import CoreLocation

struct GPSDebugView: View {
    @StateObject private var locationManager = LocationManager.shared
    @State private var debugOutput: [String] = []
    @State private var isTestRunning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Status Section
                statusSection
                
                // Actions Section  
                actionsSection
                
                // Debug Log
                debugLogSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("GPS Debug")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GPS Status")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(locationManager.currentLocation != nil ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(locationManager.currentLocation != nil ? "GPS Aktiv" : "Keine Position")
                    .foregroundColor(locationManager.currentLocation != nil ? .green : .red)
            }
            
            if let location = locationManager.currentLocation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📍 \(location.formattedCoordinates)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Genauigkeit: \(location.formattedAccuracy)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Zeitstempel: \(location.timestamp.formatted(.dateTime.hour().minute().second()))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            
            // Authorization Status
            HStack {
                Image(systemName: authorizationIcon)
                    .foregroundColor(authorizationColor)
                
                Text("Berechtigung: \(authorizationDescription)")
                    .font(.caption)
                    .foregroundColor(authorizationColor)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Text("GPS Aktionen")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button("Position abrufen") {
                    requestLocation()
                }
                .buttonStyle(.bordered)
                .disabled(isTestRunning)
                
                Button("Berechtigung anfragen") {
                    locationManager.requestPermission()
                }
                .buttonStyle(.bordered)
            }
            
            Button(isTestRunning ? "Test läuft..." : "GPS Test starten") {
                startGPSTest()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isTestRunning)
            
            if isTestRunning {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var debugLogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Log")
                    .font(.headline)
                
                Spacer()
                
                Button("Löschen") {
                    debugOutput.removeAll()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(debugOutput.indices, id: \.self) { index in
                        Text(debugOutput[index])
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var authorizationIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var authorizationColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .orange
        }
    }
    
    private var authorizationDescription: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "Immer erlaubt"
        case .authorizedWhenInUse:
            return "Bei App-Nutzung"
        case .denied:
            return "Verweigert"
        case .restricted:
            return "Eingeschränkt"
        case .notDetermined:
            return "Nicht bestimmt"
        @unknown default:
            return "Unbekannt"
        }
    }
    
    // MARK: - Actions
    
    private func requestLocation() {
        addDebugMessage("🔄 Position wird abgerufen...")
        locationManager.requestCurrentLocation()
        
        // Überprüfe nach 3 Sekunden den Status
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if let location = locationManager.currentLocation {
                addDebugMessage("✅ Position erhalten: \(location.shortCoordinates)")
            } else {
                addDebugMessage("❌ Keine Position erhalten")
            }
        }
    }
    
    private func startGPSTest() {
        isTestRunning = true
        addDebugMessage("🚀 GPS Test gestartet")
        
        Task {
            // Test 1: Berechtigung prüfen
            addDebugMessage("1️⃣ Prüfe Berechtigung...")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            addDebugMessage("   Status: \(authorizationDescription)")
            
            // Test 2: Position anfordern
            addDebugMessage("2️⃣ Fordere Position an...")
            locationManager.requestCurrentLocation()
            
            // Test 3: Warte auf Position
            addDebugMessage("3️⃣ Warte auf GPS-Signal...")
            var attempts = 0
            let maxAttempts = 10
            
            while attempts < maxAttempts {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                attempts += 1
                
                if let location = locationManager.currentLocation {
                    addDebugMessage("✅ Position nach \(attempts)s: \(location.formattedCoordinates)")
                    addDebugMessage("   Genauigkeit: \(location.formattedAccuracy)")
                    addDebugMessage("   Alter: \(Int(-location.timestamp.timeIntervalSinceNow))s")
                    break
                } else {
                    addDebugMessage("   Versuch \(attempts)/\(maxAttempts)...")
                }
            }
            
            if locationManager.currentLocation == nil {
                addDebugMessage("❌ Keine Position nach \(maxAttempts) Versuchen")
            }
            
            addDebugMessage("🏁 GPS Test beendet")
            
            await MainActor.run {
                isTestRunning = false
            }
        }
    }
    
    private func addDebugMessage(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = Date().formatted(.dateTime.hour().minute().second())
            debugOutput.append("[\(timestamp)] \(message)")
            
            // Begrenze auf die letzten 50 Nachrichten
            if debugOutput.count > 50 {
                debugOutput.removeFirst()
            }
        }
    }
}

#Preview {
    GPSDebugView()
} 