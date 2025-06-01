//
//  TravelCompanionApp.swift
//  TravelCompanion
//
//  Created by Christian Bram on 29.05.25.
//

import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct TravelCompanionApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var appStateManager = AppStateManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(TripManager.shared)
                .environmentObject(UserManager.shared)
                .environmentObject(locationManager)
                .environmentObject(appStateManager)
                .onAppear {
                    // App-Setup beim ersten Start
                    setupApp()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // App wird inaktiv - speichere wichtige Daten
                    appStateManager.handleAppWillResignActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // App geht in Background - starte Background Tasks
                    appStateManager.handleAppDidEnterBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // App kommt aus Background zurück
                    appStateManager.handleAppWillEnterForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // App wird wieder aktiv
                    appStateManager.handleAppDidBecomeActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // App wird beendet - finale Datenspeicherung
                    appStateManager.handleAppWillTerminate()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Scene Phase Changes werden bereits über die UIApplication Notifications behandelt
                    // Zusätzliche Scene-spezifische Logik kann hier hinzugefügt werden
                    switch newPhase {
                    case .active:
                        appStateManager.handleAppDidBecomeActive()
                    case .inactive:
                        appStateManager.handleAppWillResignActive()
                    case .background:
                        appStateManager.handleAppDidEnterBackground()
                    @unknown default:
                        break
                    }
                }
        }
    }
    
    private func setupApp() {
        // Location-Berechtigung beim App-Start anfordern
        locationManager.requestPermission()
        
        // Background Tasks registrieren
        appStateManager.registerBackgroundTasks()
        
        // User Notifications Setup
        appStateManager.requestNotificationPermission()
        
        // Debug Logging aktivieren in Development
        #if DEBUG
        DebugLogger.shared.logLevel = .verbose
        DebugLogger.shared.log("🚀 TravelCompanion App gestartet - Debug Mode aktiv")
        #endif
    }
}
