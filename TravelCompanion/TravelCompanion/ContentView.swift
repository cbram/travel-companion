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
    
    private func initializeServices() async {
        print("🚀 ContentView: App-Start Setup")
        
        // Immediate UI-safe operations first
        await MainActor.run {
            locationManager.restoreLastKnownLocation()
        }
        
        // File System Validation (non-blocking)
        await PhotoFileManager.shared.validateFileSystem()
        
        // Offline Queue Processing (falls vorhanden) - im Hintergrund
        Task.detached(priority: .background) {
            // Sichere Überprüfung der Queue-Größen mit await
            let offlineQueueSize = await PhotoFileManager.shared.offlineQueueSize
            let pendingMemoriesCount = await OfflineMemoryCreator.shared.pendingMemoriesCount
            
            if offlineQueueSize > 0 || pendingMemoriesCount > 0 {
                print("🔄 Processing Offline Queue from previous session")
                
                await PhotoFileManager.shared.processOfflineQueue()
                await OfflineMemoryCreator.shared.syncOfflineMemories()
            }
        }
    }
    
    private func setupAppStart() {
        Task {
            // Initialisiere Services
            await initializeServices()
            
            // NEUE: Validiere und bereinige Koordinaten beim App-Start
            CoreDataManager.shared.validateAndFixMemoryCoordinates()
            
            #if DEBUG
            // Zeige Datenbankstatus in Debug-Builds
            CoreDataManager.shared.validateDatabaseIntegrity()
            
            // Validiere TripManager-Status
            TripManager.shared.validateState()
            #endif
            
            // Performance check
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 Sekunden
            
            await MainActor.run {
                print("✅ ContentView: App-Setup abgeschlossen")
            }
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
