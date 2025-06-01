//
//  ContentView.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import SwiftUI
import CoreData
import QuartzCore

/// Haupt-Content View mit TabView Navigation für die TravelCompanion App
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var locationManager: LocationManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Timeline Tab - Zeigt Memories der aktiven Reise
            TimelineView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "clock.fill" : "clock")
                    Text("Timeline")
                }
                .tag(0)
            
            // Trips Tab - Verwaltung aller Reisen
            TripsListView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "suitcase.fill" : "suitcase")
                    Text("Reisen")
                }
                .tag(1)
            
            // Settings Tab - App-Einstellungen
            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "gearshape.fill" : "gearshape")
                    Text("Einstellungen")
                }
                .tag(2)
            
            #if DEBUG
            // Developer Settings Tab - Nur im Debug Build
            DeveloperSettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver")
                    Text("Debug")
                }
                .tag(3)
            #endif
        }
        .accentColor(.blue)
        .onAppear {
            setupTabBarAppearance()
            setupSampleDataIfNeeded()
            setupAppStart()
            setupPerformanceMonitoring()
        }
    }
    
    // MARK: - Setup Methods
    private func setupTabBarAppearance() {
        // TabBar Appearance konfigurieren
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Shadow für moderne Optik
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        appearance.shadowImage = UIImage()
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Keyboard Assistant View Constraints Fix
        setupKeyboardAssistantConfiguration()
        
        // Fix für AutoLayout Warnings bei Toolbars
        setupToolbarConfiguration()
    }
    
    private func setupKeyboardAssistantConfiguration() {
        // Reduziert AutoLayout-Konflikte mit der Keyboard Assistant View
        if #available(iOS 16.0, *) {
            // iOS 16+ automatische Keyboard-Konfiguration
            UITextView.appearance().keyboardDismissMode = .onDrag
        } else {
            // iOS 15 fallback
            UIScrollView.appearance().keyboardDismissMode = .onDrag
        }
        
        // Zusätzliche Keyboard-Konfiguration für bessere UX
        UITextField.appearance().clearButtonMode = .whileEditing
        UITextView.appearance().keyboardDismissMode = .onDrag
    }
    
    private func setupToolbarConfiguration() {
        // Fix für Toolbar AutoLayout Warnings
        if #available(iOS 15.0, *) {
            // UIToolbar Appearance für iOS 15+
            let toolbarAppearance = UIToolbarAppearance()
            toolbarAppearance.configureWithOpaqueBackground()
            toolbarAppearance.backgroundColor = UIColor.systemBackground
            
            UIToolbar.appearance().standardAppearance = toolbarAppearance
            UIToolbar.appearance().compactAppearance = toolbarAppearance
            UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance
        }
        
        // Reduziere AutoLayout Konflikte
        UIView.appearance(whenContainedInInstancesOf: [UIToolbar.self]).translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupSampleDataIfNeeded() {
        // Prüfe ob bereits Daten vorhanden sind
        let tripRequest = Trip.fetchRequest()
        tripRequest.fetchLimit = 1
        
        do {
            let existingTrips = try viewContext.fetch(tripRequest)
            if existingTrips.isEmpty {
                DebugLogger.shared.info("📝 ContentView: Keine Trips gefunden, erstelle Sample Data")
                SampleDataCreator.createSampleData(in: viewContext)
                try viewContext.save()
                DebugLogger.shared.info("✅ ContentView: Sample Data erfolgreich erstellt")
            }
        } catch {
            DebugLogger.shared.error("❌ ContentView: Fehler beim Prüfen/Erstellen von Sample Data: \(error)")
        }
    }
    
    private func setupAppStart() {
        DebugLogger.shared.info("🚀 ContentView: App-Start Setup")
        
        // Immediate UI-safe operations first
        locationManager.restoreLastKnownLocation()
        
        // Heavy operations asynchronously
        Task { @MainActor in
            // File System Validation (non-blocking)
            await PhotoFileManager.shared.validateFileSystem()
            
            // Kleine Verzögerung für UI Stabilität
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 Sekunden
            
            // Offline Queue Processing (falls vorhanden) - im Hintergrund
            Task.detached(priority: .background) {
                // Sichere Überprüfung der Queue-Größen mit await
                let offlineQueueSize = await PhotoFileManager.shared.offlineQueueSize
                let pendingMemoriesCount = await OfflineMemoryCreator.shared.pendingMemoriesCount
                
                if offlineQueueSize > 0 || pendingMemoriesCount > 0 {
                    DebugLogger.shared.info("🔄 Processing Offline Queue from previous session")
                    
                    await PhotoFileManager.shared.processOfflineQueue()
                    await OfflineMemoryCreator.shared.syncOfflineMemories()
                }
            }
            
            DebugLogger.shared.info("✅ App-Start Setup abgeschlossen")
        }
    }
    
    private func setupPerformanceMonitoring() {
        DebugLogger.shared.info("🔄 Performance Monitoring Setup")
        
        // Vereinfachtes Performance Monitoring ohne CADisplayLink
        // Performance Warning Check Timer
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            DebugLogger.shared.checkPerformanceWarnings()
        }
        
        // Memory Monitoring
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            DebugLogger.shared.logMemoryUsage()
        }
        
        DebugLogger.shared.info("✅ Performance Monitoring aktiv")
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocationManager.shared)
            .environmentObject(TripManager.shared)
            .environmentObject(UserManager.shared)
    }
}
